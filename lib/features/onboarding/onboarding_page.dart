import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets.dart';

/// İlk açılış: yasal uyarı ve veri kaynakları. Kabul edilmeden uygulama kullanılamaz.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _checked = false;
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final account = ref.read(accountRepositoryProvider);
      if (account != null) {
        await account.ensureSession();
        await account.acceptDisclaimer();
      }
      await ref.read(settingsProvider.notifier).acceptDisclaimer();
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Icon(Icons.stacked_line_chart, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(l.appTitle, style: t.headlineMedium),
              const SizedBox(height: 4),
              Text(l.appTagline, style: t.bodyLarge),
              const SizedBox(height: 24),
              Text(l.disclaimerTitle, style: t.titleMedium),
              const SizedBox(height: 8),
              Text(l.disclaimerBody),
              const SizedBox(height: 24),
              Text(l.dataSources, style: t.titleMedium),
              const SizedBox(height: 8),
              Text(l.dataSourcesBody),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              CheckboxListTile(
                value: _checked,
                onChanged: (v) => setState(() => _checked = v ?? false),
                title: Text(l.disclaimerAccept),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _checked && !_busy ? _accept : null,
                  child: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l.continueLabel),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
