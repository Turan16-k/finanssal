import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/account_repository.dart';
import '../data/market_repository.dart';
import '../data/models.dart';
import '../data/portfolio_repository.dart';
import 'env.dart';

/// main() içinde gerçek örnekle override edilir.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider override edilmedi'),
);

/// Firebase başarıyla başlatıldı mı (yapılandırma dosyaları yoksa false).
final firebaseReadyProvider = Provider<bool>((ref) => false);

final backendEnabledProvider = Provider<bool>((ref) => Env.hasBackend);

final supabaseProvider = Provider<SupabaseClient?>(
  (ref) => ref.watch(backendEnabledProvider) ? Supabase.instance.client : null,
);

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  final db = ref.watch(supabaseProvider);
  return db == null ? DemoMarketRepository() : SupabaseMarketRepository(db);
});

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  final db = ref.watch(supabaseProvider);
  return db == null
      ? LocalPortfolioRepository(ref.watch(sharedPrefsProvider))
      : SupabasePortfolioRepository(db);
});

final accountRepositoryProvider = Provider<AccountRepository?>((ref) {
  final db = ref.watch(supabaseProvider);
  return db == null ? null : AccountRepository(db);
});

/// Oturum değişikliklerinde kullanıcıya bağlı sağlayıcıların yenilenmesi için.
final authUserProvider = StreamProvider<User?>((ref) {
  final account = ref.watch(accountRepositoryProvider);
  if (account == null) return Stream.value(null);
  return account.authChanges.map((s) => s.session?.user);
});

// ---------------------------------------------------------------------------
// Piyasa verisi
// ---------------------------------------------------------------------------
final instrumentsProvider = FutureProvider<List<Instrument>>(
  (ref) => ref.watch(marketRepositoryProvider).instruments(),
);

final instrumentByIdProvider = Provider.family<Instrument?, int>((ref, id) {
  final list = ref.watch(instrumentsProvider).value ?? const [];
  for (final i in list) {
    if (i.id == id) return i;
  }
  return null;
});

final quotesProvider = FutureProvider<Map<int, Quote>>(
  (ref) => ref.watch(marketRepositoryProvider).quotes(),
);

typedef HistoryKey = ({int id, DateTime from, int maxPoints});

final historyProvider = FutureProvider.autoDispose.family<List<PricePoint>, HistoryKey>(
  (ref, k) => ref.watch(marketRepositoryProvider).history(k.id, k.from, maxPoints: k.maxPoints),
);

final analyticsProvider = FutureProvider.autoDispose.family<InstrumentAnalytics?, int>(
  (ref, id) => ref.watch(marketRepositoryProvider).analytics(id),
);

// ---------------------------------------------------------------------------
// Kullanıcı verisi
// ---------------------------------------------------------------------------
final portfoliosProvider = FutureProvider<List<Portfolio>>((ref) {
  ref.watch(authUserProvider);
  return ref.watch(portfolioRepositoryProvider).portfolios();
});

final transactionsProvider = FutureProvider.family<List<Txn>, String>((ref, portfolioId) {
  ref.watch(authUserProvider);
  return ref.watch(portfolioRepositoryProvider).transactions(portfolioId);
});

final manualPricesProvider = FutureProvider<Map<int, double>>((ref) {
  ref.watch(authUserProvider);
  return ref.watch(portfolioRepositoryProvider).manualPrices();
});

/// Otomatik (quotes) + manuel fiyatlar birleşik: instrumentId -> fiyat.
final effectivePricesProvider = FutureProvider<Map<int, double>>((ref) async {
  final quotes = await ref.watch(quotesProvider.future);
  final manual = await ref.watch(manualPricesProvider.future);
  return {
    for (final q in quotes.values) q.instrumentId: q.close,
    ...manual,
  };
});

final alertsProvider = FutureProvider<List<PriceAlert>>((ref) {
  ref.watch(authUserProvider);
  final account = ref.watch(accountRepositoryProvider);
  return account == null ? Future.value(const []) : account.alerts();
});

// ---------------------------------------------------------------------------
// Ayarlar (cihazda)
// ---------------------------------------------------------------------------
class Settings {
  const Settings({
    required this.themeMode,
    required this.disclaimerAccepted,
    required this.biometricLock,
    this.locale,
  });

  final ThemeMode themeMode;
  final bool disclaimerAccepted;
  final bool biometricLock;

  /// null: cihaz dili.
  final Locale? locale;

  Settings copyWith({
    ThemeMode? themeMode,
    bool? disclaimerAccepted,
    bool? biometricLock,
    Locale? Function()? locale,
  }) =>
      Settings(
        themeMode: themeMode ?? this.themeMode,
        disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
        biometricLock: biometricLock ?? this.biometricLock,
        locale: locale == null ? this.locale : locale(),
      );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _kTheme = 'settings.theme';
  static const _kDisclaimer = 'settings.disclaimer_v1';
  static const _kBiometric = 'settings.biometric';
  static const _kLocale = 'settings.locale';

  SharedPreferences get _p => ref.read(sharedPrefsProvider);

  @override
  Settings build() {
    final p = ref.watch(sharedPrefsProvider);
    final lang = p.getString(_kLocale);
    return Settings(
      themeMode: ThemeMode.values.byName(p.getString(_kTheme) ?? ThemeMode.system.name),
      disclaimerAccepted: p.getBool(_kDisclaimer) ?? false,
      biometricLock: p.getBool(_kBiometric) ?? false,
      locale: lang == null ? null : Locale(lang),
    );
  }

  Future<void> setThemeMode(ThemeMode m) async {
    await _p.setString(_kTheme, m.name);
    state = state.copyWith(themeMode: m);
  }

  Future<void> acceptDisclaimer() async {
    await _p.setBool(_kDisclaimer, true);
    state = state.copyWith(disclaimerAccepted: true);
  }

  Future<void> setBiometricLock(bool v) async {
    await _p.setBool(_kBiometric, v);
    state = state.copyWith(biometricLock: v);
  }

  Future<void> setLocale(Locale? l) async {
    l == null ? await _p.remove(_kLocale) : await _p.setString(_kLocale, l.languageCode);
    state = state.copyWith(locale: () => l);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
