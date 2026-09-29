import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/account_repository.dart';

/// FCM kurulumu: izin, token kaydı (Supabase `register_device`), ön plan bildirimleri.
class PushService {
  PushService(this._account);
  final AccountRepository _account;

  static const _channel = AndroidNotificationChannel(
    'price_alerts',
    'Fiyat alarmları',
    description: 'Kurduğunuz fiyat alarmları tetiklendiğinde',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();

  Future<void> init({required String locale}) async {
    final fm = FirebaseMessaging.instance;
    final perm = await fm.requestPermission();
    if (perm.authorizationStatus == AuthorizationStatus.denied) return;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // iOS ön planda da sistem bildirimi göstersin.
    await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen(_showForeground);

    Future<void> register(String? token) async {
      if (token == null || _account.currentUser == null) return;
      try {
        await _account.registerDevice(token, Platform.isIOS ? 'ios' : 'android', locale);
      } catch (e) {
        debugPrint('Cihaz kaydı başarısız: $e');
      }
    }

    await register(await fm.getToken());
    fm.onTokenRefresh.listen(register);
  }

  Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    // iOS'ta setForegroundNotificationPresentationOptions zaten gösterir.
    if (n == null || !Platform.isAndroid) return;
    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(_channel.id, _channel.name,
            channelDescription: _channel.description, importance: Importance.high, priority: Priority.high),
      ),
    );
  }
}
