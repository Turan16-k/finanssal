# Fraktal — Mimari

## 1. İlke: sunucu yok, iş dört ücretsiz parçaya bölünür

| Parça | Nerede | Neden |
|---|---|---|
| Kullanıcıya özel hesap (Monte Carlo, Markowitz, backtest, Hurst, K/Z) | Cihaz — `packages/quant_dart`, `Isolate.run` | Sunucu maliyeti sıfır, çevrimdışı çalışır, kullanıcı sayısıyla ölçeklenir |
| Toplu işler (veri çekme, gece analitiği) | GitHub Actions cron — `pipelines/` | Python ekosistemi, ücretsiz dakika |
| Gizli anahtar isteyen işler (Gemini, FCM gönderimi) | Supabase Edge Functions | Anahtarlar uygulamaya hiç girmez |
| Veri, kimlik, yetki | Supabase Postgres + Auth + RLS | 500 MB DB, 50k MAU ücretsiz |

Firebase (Spark): FCM, Crashlytics, Analytics, Remote Config, App Check. Cloud Functions **kullanılmaz** (Blaze ister).

```
Flutter app ──REST/JWT──▶ Supabase (Postgres+RLS, Auth, Edge Functions) ──FCM v1──▶ cihazlar
    │  quant_dart (Isolate)          ▲ service_role (yalnızca CI secret)
    │                                │
    └─ demo modu: sentetik veri      GitHub Actions: pipelines.ingest (EVDS, CoinGecko) + analitik
```

## 2. Veri kaynakları ve lisans

| Varlık | Kaynak | Durum |
|---|---|---|
| Döviz, gram altın, BIST 100, TÜFE | TCMB EVDS (`evds3.tcmb.gov.tr/igmevdsms-dis/`, ücretsiz anahtar) | Otomatik, kaynak gösterilerek |
| Kripto | CoinGecko Demo API | Otomatik, atıf zorunlu, 365 gün geçmiş |
| BIST hisseleri | — | Borsa İstanbul lisansı gerekir → **kullanıcı fiyat girer** (`manual_prices`) |
| Yatırım fonları | — | TEFAS'ın resmi API'si yok ve site bot korumalı → **kullanıcı fiyat girer** |

Lisanslı bir sağlayıcıya geçiş: `pipelines/sources/` altına adaptör + `data_source` enum değeri +
ilgili enstrümanların `source` alanını güncellemek yeterli; uygulama değişmez.

EVDS seri kodları `supabase/seed.sql` içindedir; doğrulamak için
`EVDS_API_KEY=... python -m pipelines.ingest --check --source evds`.

## 3. Veritabanı

`supabase/migrations/20260925000000_init.sql`

- Piyasa tabloları (`instruments`, `prices_daily`, `quotes_latest`, `analytics_daily`, `news`): herkes okur,
  yazma politikası yok → yalnızca `service_role`.
- Kullanıcı tabloları: `user_id = auth.uid()` politikası. `transactions` ve `watchlist_items`, üst tabloya
  **bileşik FK** (`id, user_id`) ile bağlıdır: başka kullanıcının portföyüne kayıt eklenemez.
- Kötüye kullanım sınırları tetikleyicilerle (ör. 20 portföy, 50 alarm).
- RPC'ler: `delete_my_account` (mağaza zorunluluğu), `register_device`, `price_history` (seyreltme),
  `claim_triggered_alerts` ve `consume_ai_quota` (yalnızca service_role).
- Testler: `supabase/tests/test_schema.py` — gömülü Postgres'te RLS izolasyonu, cascade, alarm, kota.

Boyut: ~600 enstrüman × 5 yıl ≈ 750 bin satır ≈ 100 MB (500 MB sınırının altında).

## 4. Kimlik

- İlk açılışta **anonim oturum** (Supabase anonymous sign-in): kayıt olmadan tüm özellikler.
- İsteğe bağlı: e-postaya 6 haneli kodla bağlama (`updateUser` → `verifyOTP(emailChange)`), veriler korunur.
- Apple / Google ile giriş: yapılandırması `supabase/config.toml`'da hazır, uygulama tarafı yol haritasında.
- Uygulama içi hesap silme: Ayarlar → Hesabı sil.

## 5. Uygulama (apps/mobile)

- Riverpod 3 (durum), go_router (StatefulShellRoute ile 4 sekme), fl_chart, gen-l10n (TR/EN).
- `core/env.dart`: `--dart-define-from-file=env/dev.json`. Supabase bilgisi yoksa **demo modu**
  (`DemoMarketRepository` + `LocalPortfolioRepository`).
- Laboratuvar: seçilen varlıkların geçmişi **tarih bazında hizalanır** (kripto hafta sonları atılır),
  hesap `Isolate.run` içinde yapılır.
- Güvenlik: biyometrik kilit, App Check (Edge Function'da doğrulanır), RLS.

## 6. Güvenlik kontrol listesi

- [x] Her tabloda RLS; piyasa verisine yazma yalnızca service_role
- [x] service_role ve Gemini/FCM anahtarları yalnızca GitHub/Supabase secret
- [x] Edge Function: JWT + App Check (+ `APP_CHECK_ENFORCE=true`) + kullanıcı başına günlük kota
- [x] Hesap silme cascade testi
- [ ] Yayın öncesi: `APP_CHECK_ENFORCE=true`, Supabase Auth rate limit ayarları, e-posta şablonları

## 7. Bilinçli olarak dışarıda bırakılanlar (sonraki sürümler)

- Haber akışı + otomatik sentiment (tablo hazır: `news`)
- Bütçe / gelir-gider modülü
- İzleme listeleri arayüzü (tablo hazır)
- Çevrimdışı önbellek (Drift) — şu an demo modu dışında ağ gerekir
- Apple/Google ile giriş
