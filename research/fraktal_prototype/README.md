# 📈 Fraktal Piyasa Analizi Destekli Portföy Simülasyonu

> **Not:** Bu klasör araştırma prototipidir. Yayındaki uygulama `apps/mobile` + `packages/quant_dart`
> ile çalışır; buradaki kod Dart portunun eşdeğerlik referansıdır (`tools/export_parity_fixtures.py`).
> yfinance verisi yalnızca kişisel/yerel araştırma içindir, uygulamada kullanılmaz.

> Proje 8 · Teknolojiler: **Python, Gemini API, FinBERT, Monte Carlo**
> Mimari: Hibrit veri işleme. Bir yanda TCMB/TEFAS sayısal zaman serileri **Monte
> Carlo** ile simüle edilir; diğer yanda PDF/haber bültenleri **FinBERT + Gemini**
> ile analiz edilip **duygu (sentiment) skoru** matematiksel modele entegre edilir.

## Bileşenler

1. **Veri** (`src/data.py`): **gerçek fiyat verisi** — Yahoo Finance (yfinance) ile
   BIST hisseleri (`THYAO.IS` vb.) ve altın çekilir; sonuç günlük olarak `.cache/`
   altında saklanır (12 saat taze). yfinance/EVDS yoksa fraktal (FBM) sentetik seriye
   düşer. Önceliği: önbellek → yfinance → TCMB EVDS (`EVDS_API_KEY`) → sentetik.
2. **Fraktal analiz** (`src/fractal.py`): **Hurst üssü** (R/S analizi) → piyasa rejimi
   (trend / random walk / mean-reverting).
3. **Sentiment** (`src/sentiment.py`): FinBERT (`transformers` varsa) ya da sözlük-mock;
   özetleme Gemini (`GEMINI_API_KEY` varsa) ya da çıkarımsal mock.
4. **Monte Carlo** (`src/montecarlo.py`): korelasyonlu GBM yörüngeleri; **sentiment ile
   uyarlanmış drift**; VaR/CVaR %95, zarar olasılığı, persentiller.
5. **Optimizasyon** (`src/optimize.py`): Markowitz ortalama-varyans, **maks-Sharpe**
   ağırlıkları (SciPy varsa kısıtlı optimizasyon, yoksa rastgele arama).
6. **Backtest** (`src/backtest.py`): tarihsel performans — toplam getiri, CAGR,
   volatilite, Sharpe, maksimum düşüş. Hem CLI (`--optimize`) hem arayüzde gösterilir.

## Kurulum & Çalıştırma

```bash
cd research/fraktal_prototype
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

python simulate.py --assets THYAO GARAN ALTIN --sims 5000              # gerçek veri + CLI
python simulate.py --assets THYAO GARAN ALTIN --optimize               # Markowitz ağırlıkları
python simulate.py --assets THYAO GARAN ALTIN --mock                   # sentetik veriyi zorla
streamlit run app.py                                                   # arayüz
```

- **Gerçek fiyat verisi** `yfinance` ile otomatik gelir (anahtar gerekmez). İnternet
  yoksa sentetik seriye düşer, pipeline yine çalışır.
- **FinBERT** (`transformers`+`torch`) kuruluysa duygu analizi gerçek modelle yapılır.
  Not: `ProsusAI/finbert` İngilizce eğitimlidir; Türkçe bültenler için sözlük-mock
  (`--mock` kapalıyken bile sentiment için) daha isabetli olabilir.
- **Gerçek özet** için `export GEMINI_API_KEY=...`; yoksa çıkarımsal özet kullanılır.
- **TCMB EVDS** için `export EVDS_API_KEY=...` (altın/makro serileri).
- Veri önbelleğini temizlemek: `.cache/` klasörünü silin.

## Testler

```bash
python -m pytest tests/ -q   # veya: python tests/test_sim.py
```

## Yapı

```
research/fraktal_prototype/
├── app.py · simulate.py
├── src/{data,fractal,sentiment,montecarlo,optimize,backtest}.py
├── .cache/                # otomatik oluşan günlük fiyat önbelleği
└── tests/test_sim.py
```

## Production Notları

- Gerçek fiyat verisi `yfinance` ile bağlıdır; daha resmi kaynak için `data.py`
  içindeki EVDS uçları gerçek seri kodlarıyla doldurulabilir.
- PDF bültenler için LangChain + PyPDF ile metin çıkarımı ekleyin.
- Türkçe bültenlerde İngilizce `ProsusAI/finbert` nötr eğilimli olabilir; Türkçe bir
  finansal sentiment modeli (ör. `savasy/bert-base-turkish-sentiment-cased`) ile
  `src/sentiment.py` içindeki model adı değiştirilebilir.
- `.cache/` 12 saat tazedir; gün içi tekrar çalıştırmalarda ağ trafiği oluşmaz.
