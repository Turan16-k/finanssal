# Kurulum: sıfırdan yayına

Her adımın sonunda neyin çalışır hale geldiği yazıyor. Tüm servisler ücretsiz katmanda.

## 0. Yerel araçlar

```bash
brew install supabase/tap/supabase deno
# Android için: Android Studio kurun, ilk açılışta SDK'yı yükleyin, sonra:
flutter doctor --android-licenses
```

## 1. Supabase (dev ve prod için iki ücretsiz proje)

1. https://supabase.com → New project → `fraktal-dev` (bölge: Frankfurt, eu-central-1).
2. Authentication → Sign In / Providers:
   - **Anonymous sign-ins: açık**
   - Email: açık, "Confirm email" açık. Email OTP uzunluğu 6.
3. Authentication → Email Templates → "Change email address" ve "Magic link" şablonlarına `{{ .Token }}`
   ekleyin (uygulama bağlantı değil 6 haneli kod kullanır).
4. Şemayı yükleyin:
   ```bash
   supabase login
   supabase link --project-ref <ref>
   supabase db push                      # migrations
   psql "$(supabase db url)" -f supabase/seed.sql   # veya SQL Editor'e yapıştırın
   ```
5. Project Settings → API: `Project URL` ve **publishable** (anon) anahtarı alın.

✅ Uygulama gerçek arka uçla açılır (piyasa listeleri, veriler gelene kadar boş fiyatla).

## 2. Veri anahtarları

- **EVDS**: https://evds3.tcmb.gov.tr → üye ol → Profil → "API Anahtarını Kopyala".
- **CoinGecko** (isteğe bağlı, hız sınırını artırır): https://www.coingecko.com/en/api → Demo plan.

Seri kodlarını doğrulayın (yazma yapmaz):
```bash
EVDS_API_KEY=... python -m pipelines.ingest --check
```

## 3. GitHub

Repo → Settings → Secrets and variables → Actions:

| Secret | Değer |
|---|---|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Project Settings → API → service_role / secret key (**asla uygulamaya koymayın**) |
| `EVDS_API_KEY` | EVDS anahtarı |
| `COINGECKO_API_KEY` | (isteğe bağlı) |
| `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF` | deploy iş akışı için |

Actions → "Veri çekme" → Run workflow. İlk çalıştırma 5 yıllık geçmişi yükler (~5 dk).

✅ Piyasalar ekranında gerçek fiyatlar, detayda grafik ve fraktal analiz.

> İpucu: repo **public** ise GitHub Actions dakikaları sınırsızdır. Tüm sırlar secret'larda olduğundan
> kodu açık tutmak güvenlidir.

## 4. Firebase (Spark planı)

1. https://console.firebase.google.com → proje `fraktal-dev`. Analytics'i açın.
2. Uygulamayı bağlayın:
   ```bash
   dart pub global activate flutterfire_cli
   cd apps/mobile && flutterfire configure --project=fraktal-dev \
     --platforms=ios,android --ios-bundle-id=com.fraktal --android-package-name=com.fraktal
   ```
   Bu komut `google-services.json` ve `GoogleService-Info.plist` dosyalarını oluşturur (repoya eklenmez).
3. **iOS push**: Apple Developer → Keys → APNs anahtarı (.p8) oluşturun → Firebase → Project Settings →
   Cloud Messaging → APNs Authentication Key olarak yükleyin. Xcode → Runner → Signing & Capabilities →
   "+ Push Notifications" ve "+ Background Modes → Remote notifications".
4. **App Check**: Firebase → App Check → Android: Play Integrity, iOS: App Attest. Debug token'larını
   geliştirme cihazları için kaydedin.
5. Edge Function secret'ları (Supabase → Edge Functions → Secrets):

| Secret | Değer |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | Firebase → Project Settings → Service accounts → Generate new private key (JSON'un tamamı) |
| `FIREBASE_PROJECT_NUMBER` | Project Settings → General → Project number |
| `GEMINI_API_KEY` | https://aistudio.google.com/apikey (ücretsiz katman) |
| `APP_CHECK_ENFORCE` | geliştirmede `false`, yayında `true` |
| `AI_DAILY_LIMIT` | `10` |

6. Fonksiyonları yükleyin: `supabase functions deploy send-alerts && supabase functions deploy ai-analyze`.

✅ Fiyat alarmları bildirim olarak gelir; bülten analizi çalışır; çökme raporları Crashlytics'te.

## 5. Uygulamayı çalıştırma

```bash
cd apps/mobile
cp env/dev.example.json env/dev.json   # değerleri doldurun
flutter run --dart-define-from-file=env/dev.json
```

## 6. Yasal sayfalar (GitHub Pages)

`docs/legal/` altındaki taslakları gözden geçirin (bir hukukçuya okutmanız önerilir), sonra
repo → Settings → Pages → Branch: `main`, klasör `/docs`. Oluşan adresleri `env/prod.json` içindeki
`PRIVACY_POLICY_URL` ve `TERMS_URL` alanlarına yazın.

## 7. Yayın

### Android
```bash
keytool -genkey -v -keystore ~/fraktal-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cat > apps/mobile/android/key.properties <<EOF
storeFile=/Users/<siz>/fraktal-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
EOF
flutter build appbundle --dart-define-from-file=env/prod.json --obfuscate --split-debug-info=build/symbols
```
Play Console → uygulama oluştur (`com.fraktal`) → Play App Signing → **Kapalı test** (kişisel hesapta
12 test kullanıcısı × 14 gün zorunlu) → Data safety, Financial features beyanı, İçerik derecelendirmesi.

### iOS
```bash
flutter build ipa --dart-define-from-file=env/prod.json --obfuscate --split-debug-info=build/symbols
```
Xcode Organizer veya Transporter ile yükleyin → TestFlight → App Privacy etiketleri → İnceleme.
İnceleme notuna "eğitim/simülasyon aracı, yatırım tavsiyesi vermez, BIST fiyatı yayınlamaz" yazın.
