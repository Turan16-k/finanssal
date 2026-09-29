import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class BootstrapResult {
  const BootstrapResult({required this.prefs, required this.firebaseReady});
  final SharedPreferences prefs;
  final bool firebaseReady;
}

/// Uygulama başlamadan önceki kurulum. Hiçbir dış servis zorunlu değildir:
/// Firebase yapılandırılmamışsa veya Supabase bilgileri yoksa uygulama yine açılır.
Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final firebaseReady = await _initFirebase();

  if (Env.hasBackend) {
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseKey);
  }
  return BootstrapResult(prefs: prefs, firebaseReady: firebaseReady);
}

Future<bool> _initFirebase() async {
  try {
    // Yapılandırma: android/app/google-services.json ve ios/Runner/GoogleService-Info.plist
    // (flutterfire configure ile üretilir; repoya eklenmez).
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase yapılandırılmamış, devre dışı: $e');
    return false;
  }

  // Çökme raporları (debug'da kapalı).
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // App Check: Edge Function'lar yalnızca gerçek uygulamadan gelen istekleri kabul eder.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid:
          kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (e) {
    debugPrint('App Check etkinleştirilemedi: $e');
  }
  return true;
}
