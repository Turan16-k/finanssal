# Fraktal

Portföy takibi ve fraktal analiz laboratuvarı — iOS & Android (Flutter), Supabase + Firebase,
tamamen ücretsiz katmanlarla çalışan mimari.

```
apps/mobile/            Flutter uygulaması (com.fraktal)
packages/quant_dart/    Cihaz üstü hesaplama motoru: Hurst, Monte Carlo, Markowitz, backtest, portföy defteri
supabase/               Postgres şeması + RLS (migrations), seed, Edge Functions, şema testleri
pipelines/              Python veri işleri (TCMB EVDS, CoinGecko) — GitHub Actions cron
research/               Orijinal Python/Streamlit prototipi + Dart eşdeğerlik fixture üreticisi
docs/                   Mimari, kurulum, yasal metin taslakları
```

## Hızlı başlangıç (arka uç olmadan — demo modu)

```bash
cd apps/mobile
flutter pub get
flutter run            # Supabase bilgisi yoksa sentetik veriyle demo modunda açılır
```

Gerçek verilerle çalıştırmak ve yayına hazırlamak için: [docs/setup.md](docs/setup.md).

## Testler

```bash
# Hesaplama motoru (Python/SciPy ile eşdeğerlik testleri dahil)
cd packages/quant_dart && dart test

# Uygulama
cd apps/mobile && flutter analyze && flutter test

# Pipeline + Supabase şeması/RLS (gömülü Postgres, Docker gerekmez)
python3 -m venv .venv && .venv/bin/pip install -r pipelines/requirements-dev.txt
.venv/bin/python -m pytest pipelines/tests supabase/tests research/fraktal_prototype/tests

# Edge Functions tip kontrolü
deno check supabase/functions/*/index.ts
```

## Mimari özeti

Ayrıntılar: [docs/architecture.md](docs/architecture.md).

- **Veri**: yalnızca lisans gerektirmeyen kaynaklar (EVDS, CoinGecko). BIST hisse ve fon fiyatları
  yayınlanmaz; kullanıcı kendi fiyatını girer.
- **Hesaplama**: kullanıcıya özel analizler cihazda (`quant_dart`, Isolate içinde) — sunucu maliyeti yok.
- **Sunucu**: Supabase (Postgres + RLS, Auth, Edge Functions). Toplu işler GitHub Actions'ta.
- **Firebase**: yalnızca ücretsiz Spark planı servisleri (FCM, Crashlytics, Analytics, App Check, Remote Config).
