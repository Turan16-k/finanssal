import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await confirmDialog(context,
        title: l.deleteAccount, message: l.deleteAccountConfirm, destructive: true, confirmLabel: l.delete);
    if (!ok) return;
    try {
      await ref.read(accountRepositoryProvider)?.deleteAccount();
      await ref.read(portfolioRepositoryProvider).clear();
      ref
        ..invalidate(portfoliosProvider)
        ..invalidate(manualPricesProvider)
        ..invalidate(alertsProvider);
      // Yeni boş misafir oturumu.
      await ref.read(accountRepositoryProvider)?.ensureSession();
      if (context.mounted) showSnack(context, l.accountDeleted);
    } catch (_) {
      if (context.mounted) showSnack(context, l.errorGeneric);
    }
  }

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool v) async {
    if (v) {
      final auth = LocalAuthentication();
      final can = await auth.isDeviceSupported();
      if (!can) {
        if (context.mounted) showSnack(context, context.l10n.biometricUnavailable);
        return;
      }
      if (!context.mounted) return;
      final ok = await auth.authenticate(localizedReason: context.l10n.biometricReason);
      if (!ok) return;
    }
    await ref.read(settingsProvider.notifier).setBiometricLock(v);
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final account = ref.watch(accountRepositoryProvider);
    final user = ref.watch(authUserProvider).value ?? account?.currentUser;
    final isGuest = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(children: [
        if (account != null) ...[
          SectionHeader(l.account),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(isGuest ? l.guestAccount : (user?.email ?? '')),
            subtitle: isGuest ? Text(l.guestAccountHint) : null,
          ),
          if (isGuest) ...[
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l.linkEmail),
              onTap: () => context.go('/settings/email?mode=link'),
            ),
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(l.signInExisting),
              onTap: () => context.go('/settings/email?mode=signin'),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l.signOut),
              onTap: () async {
                await account.signOut();
                await account.ensureSession();
                ref.invalidate(portfoliosProvider);
              },
            ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l.alertsTitle),
            onTap: () => context.go('/settings/alerts'),
          ),
        ],
        SectionHeader(l.appearance),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l.themeSystem)),
              ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => ref.read(settingsProvider.notifier).setThemeMode(s.first),
            showSelectedIcon: false,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l.language),
          trailing: DropdownButton<String>(
            value: settings.locale?.languageCode ?? 'system',
            underline: const SizedBox(),
            items: [
              DropdownMenuItem(value: 'system', child: Text(l.languageSystem)),
              const DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
              const DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setLocale(v == null || v == 'system' ? null : Locale(v)),
          ),
        ),
        SectionHeader(l.security),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: Text(l.biometricLock),
          value: settings.biometricLock,
          onChanged: (v) => _toggleBiometric(context, ref, v),
        ),
        SectionHeader(l.legal),
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: Text(l.disclaimerTitle),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l.disclaimerTitle),
              content: SingleChildScrollView(child: Text('${l.disclaimerBody}\n\n${l.dataSourcesBody}')),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close))],
            ),
          ),
        ),
        if (Env.privacyPolicyUrl.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.privacyPolicy),
            onTap: () => _open(Env.privacyPolicyUrl),
          ),
        if (Env.termsUrl.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.terms),
            onTap: () => _open(Env.termsUrl),
          ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l.openSourceLicenses),
          onTap: () => showLicensePage(context: context, applicationName: l.appTitle),
        ),
        if (account != null) ...[
          SectionHeader(l.dangerZone),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text(l.deleteAccount, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _deleteAccount(context, ref),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}
