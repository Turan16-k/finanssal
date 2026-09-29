import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Oturum, hesap yönetimi, alarmlar, cihaz kaydı ve AI analizi (arka uç gerektirir).
class AccountRepository {
  AccountRepository(this._db);
  final SupabaseClient _db;

  GoTrueClient get _auth => _db.auth;

  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;
  Stream<AuthState> get authChanges => _auth.onAuthStateChange;

  /// İlk açılışta misafir oturumu: kayıt olmadan tüm özellikler, veriler buluta bağlı.
  Future<void> ensureSession() async {
    if (_auth.currentSession == null) await _auth.signInAnonymously();
  }

  /// Misafir hesabı e-postaya bağlar: 6 haneli kod gönderilir, veriler korunur.
  Future<void> startLinkEmail(String email) => _auth.updateUser(UserAttributes(email: email));

  Future<void> confirmLinkEmail(String email, String code) =>
      _auth.verifyOTP(email: email, token: code, type: OtpType.emailChange);

  /// Var olan hesaba giriş (başka cihazdan): e-postaya kod gönderir.
  Future<void> startEmailSignIn(String email) =>
      _auth.signInWithOtp(email: email, shouldCreateUser: false);

  Future<void> confirmEmailSignIn(String email, String code) =>
      _auth.verifyOTP(email: email, token: code, type: OtpType.email);

  Future<void> signOut() => _auth.signOut();

  /// Tüm kullanıcı verisini sunucuda siler (App Store / Google Play zorunluluğu).
  Future<void> deleteAccount() async {
    await _db.rpc('delete_my_account');
    await _auth.signOut();
  }

  Future<void> acceptDisclaimer() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _db
        .from('profiles')
        .update({'disclaimer_accepted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', uid);
  }

  // -- Cihaz / bildirim ------------------------------------------------------
  Future<void> registerDevice(String token, String platform, String locale) =>
      _db.rpc('register_device', params: {'p_token': token, 'p_platform': platform, 'p_locale': locale});

  // -- Alarmlar --------------------------------------------------------------
  Future<List<PriceAlert>> alerts() async {
    final rows = await _db.from('alerts').select().order('created_at', ascending: false);
    return rows.map(PriceAlert.fromJson).toList();
  }

  Future<void> createAlert(int instrumentId, AlertCondition condition, double threshold) =>
      _db.from('alerts').insert({
        'instrument_id': instrumentId,
        'condition': condition.dbName,
        'threshold': threshold,
      });

  Future<void> setAlertActive(String id, bool active) =>
      _db.from('alerts').update({'is_active': active, 'last_triggered_at': null}).eq('id', id);

  Future<void> deleteAlert(String id) => _db.from('alerts').delete().eq('id', id);

  // -- AI --------------------------------------------------------------------
  Future<BulletinAnalysis> analyzeBulletin(String text, {String? appCheckToken}) async {
    final res = await _db.functions.invoke(
      'ai-analyze',
      body: {'text': text},
      headers: {'X-Firebase-AppCheck': ?appCheckToken},
    );
    return BulletinAnalysis.fromJson((res.data as Map).cast<String, dynamic>());
  }
}

class BulletinAnalysis {
  const BulletinAnalysis({
    required this.summary,
    required this.sentiment,
    required this.label,
    required this.keyPoints,
    required this.mentionedAssets,
  });

  factory BulletinAnalysis.fromJson(Map<String, dynamic> j) => BulletinAnalysis(
        summary: j['summary'] as String? ?? '',
        sentiment: (j['sentiment'] as num?)?.toDouble() ?? 0,
        label: j['label'] as String? ?? 'nötr',
        keyPoints: (j['key_points'] as List?)?.cast<String>() ?? const [],
        mentionedAssets: (j['mentioned_assets'] as List?)?.cast<String>() ?? const [],
      );

  final String summary;
  final double sentiment;
  final String label;
  final List<String> keyPoints;
  final List<String> mentionedAssets;
}
