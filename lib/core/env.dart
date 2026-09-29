/// Derleme zamanı yapılandırması: `flutter run --dart-define-from-file=env/dev.json`.
///
/// Supabase bilgileri verilmezse uygulama **demo modunda** çalışır: piyasa verisi
/// sentetik üretilir, portföyler yalnızca cihazda saklanır. Böylece arka uç kurulmadan
/// geliştirme ve mağaza incelemesi mümkündür.
class Env {
  const Env._();

  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  /// Supabase "publishable" anahtarı (eski adıyla anon key). Herkese açıktır; yetki RLS ile.
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'));
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');

  static bool get hasBackend =>
      supabaseUrl.startsWith('https://') && supabaseKey.isNotEmpty;

  static bool get isProd => flavor == 'prod';
}
