import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_lock.dart';
import 'core/providers.dart';
import 'core/push.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';

class FraktalApp extends ConsumerStatefulWidget {
  const FraktalApp({super.key});

  @override
  ConsumerState<FraktalApp> createState() => _FraktalAppState();
}

class _FraktalAppState extends ConsumerState<FraktalApp> {
  bool _pushStarted = false;

  /// Bildirimler: yalnızca Firebase + arka uç hazır ve uyarı kabul edilmişse.
  void _maybeStartPush(Locale locale) {
    if (_pushStarted) return;
    final account = ref.read(accountRepositoryProvider);
    if (account == null || !ref.read(firebaseReadyProvider)) return;
    if (!ref.read(settingsProvider).disclaimerAccepted || account.currentUser == null) return;
    _pushStarted = true;
    PushService(account).init(locale: locale.languageCode);
  }

  @override
  void initState() {
    super.initState();
    // Önceki oturumda uyarı kabul edildiyse misafir oturumunu garanti et.
    final account = ref.read(accountRepositoryProvider);
    if (account != null && ref.read(settingsProvider).disclaimerAccepted) {
      account.ensureSession().ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    ref.listen(authUserProvider, (_, _) => _maybeStartPush(settings.locale ?? const Locale('tr')));

    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        _maybeStartPush(Localizations.localeOf(context));
        return AppLock(child: child ?? const SizedBox());
      },
    );
  }
}
