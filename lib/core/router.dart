import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alerts/alerts_page.dart';
import '../features/auth/email_auth_page.dart';
import '../features/lab/lab_page.dart';
import '../features/markets/instrument_page.dart';
import '../features/markets/markets_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/portfolio/portfolio_detail_page.dart';
import '../features/portfolio/portfolios_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/home_shell.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Uyarı kabul durumu değişince yönlendirme yeniden değerlendirilir.
  final disclaimer = ValueNotifier(ref.read(settingsProvider).disclaimerAccepted);
  ref.listen(settingsProvider, (_, s) => disclaimer.value = s.disclaimerAccepted);
  ref.onDispose(disclaimer.dispose);

  return GoRouter(
    initialLocation: '/markets',
    refreshListenable: disclaimer,
    redirect: (context, state) {
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (!disclaimer.value) return onOnboarding ? null : '/onboarding';
      if (onOnboarding) return '/markets';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/markets',
              builder: (_, _) => const MarketsPage(),
              routes: [
                GoRoute(
                  path: 'instrument/:id',
                  builder: (_, s) => InstrumentPage(id: int.parse(s.pathParameters['id']!)),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/portfolio',
              builder: (_, _) => const PortfoliosPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) => PortfolioDetailPage(portfolioId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/lab',
              builder: (_, s) => LabPage(initial: s.extra as LabSeed?),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsPage(),
              routes: [
                GoRoute(path: 'alerts', builder: (_, _) => const AlertsPage()),
                GoRoute(
                  path: 'email',
                  builder: (_, s) => EmailAuthPage(
                    mode: s.uri.queryParameters['mode'] == 'signin'
                        ? EmailAuthMode.signIn
                        : EmailAuthMode.link,
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});
