"""Fiyat serisi sağlayıcı — gerçek veri (yfinance/EVDS) + günlük yerel önbellek.

Veri kaynağı önceliği:
  1. Yerel önbellek (bugün çekilmişse) — günlük kullanımda tekrar ağ trafiği yok.
  2. yfinance (Yahoo Finance) — BIST hisseleri (`THYAO.IS`) ve altın; anahtar gerekmez.
  3. TCMB EVDS — `EVDS_API_KEY` tanımlıysa (altın/makro serileri).
  4. Fraktal (FBM) sentetik seri — internet/kütüphane yoksa pipeline yine çalışır.

`FRACTAL_FORCE_MOCK=1` ile her zaman sentetik veri (deterministik testler için).

Not: Bu modül araştırma prototipidir. Yayındaki uygulama veriyi lisanssız kaynaklardan
(EVDS/TEFAS/CoinGecko) `pipelines/` üzerinden alır; yfinance yalnızca yerel araştırma içindir.
"""
from __future__ import annotations

import os
import time
import zlib
from pathlib import Path

import numpy as np

DEFAULT_ASSETS = {
    "THYAO": {"mu": 0.18, "sigma": 0.35, "hurst": 0.62, "yahoo": "THYAO.IS"},
    "GARAN": {"mu": 0.14, "sigma": 0.28, "hurst": 0.55, "yahoo": "GARAN.IS"},
    "ASELS": {"mu": 0.22, "sigma": 0.40, "hurst": 0.68, "yahoo": "ASELS.IS"},
    "EREGL": {"mu": 0.10, "sigma": 0.25, "hurst": 0.50, "yahoo": "EREGL.IS"},
    # Altın: USD/ons vadeli (GC=F) USDTRY ile TL/gram'a çevrilir (bkz. _fetch_yfinance).
    "ALTIN": {"mu": 0.12, "sigma": 0.16, "hurst": 0.58, "yahoo": "GC=F", "to_try_gram": True},
}

# Önbellek dizini (proje kökü/.cache)
CACHE_DIR = Path(__file__).resolve().parent.parent / ".cache"
CACHE_TTL_SECONDS = 12 * 3600  # gün içi 12 saat taze sayılır
TROY_OUNCE_GRAMS = 31.1034768

# Varlık başına en son fiilen kullanılan kaynak (data_source bilgilendirmesi için).
_LAST_SOURCE: dict = {}


# --------------------------------------------------------------------------- #
# Önbellek
# --------------------------------------------------------------------------- #
def _cache_path(asset: str, days: int) -> Path:
    return CACHE_DIR / f"{asset}_{days}.npy"


def _read_cache(asset: str, days: int):
    p = _cache_path(asset, days)
    if not p.exists():
        return None
    if time.time() - p.stat().st_mtime > CACHE_TTL_SECONDS:
        return None  # bayat
    try:
        arr = np.load(p)
        return arr if len(arr) >= 30 else None
    except Exception:
        return None


def _write_cache(asset: str, days: int, prices: np.ndarray) -> None:
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        np.save(_cache_path(asset, days), np.asarray(prices, dtype=float))
    except Exception as exc:
        print(f"[data] önbellek yazılamadı ({asset}): {exc}")


# --------------------------------------------------------------------------- #
# Gerçek veri kaynakları
# --------------------------------------------------------------------------- #
def _yf_close(yf, symbol: str, period_days: int):
    """Tarih indeksli 1B kapanış serisi (pandas.Series) ya da None."""
    df = yf.download(symbol, period=f"{period_days}d", interval="1d",
                     auto_adjust=True, progress=False, threads=False)
    if df is None or df.empty:
        return None
    close = df["Close"]
    # yfinance bazen MultiIndex/2B (tek sütunlu DataFrame) döndürür -> Series'e indir.
    if getattr(close, "ndim", 1) == 2:
        close = close.iloc[:, 0]
    return close.dropna()


def _fetch_yfinance(asset: str, days: int):
    """Yahoo Finance'tan günlük kapanış serisi. yfinance/ağ yoksa None."""
    meta = DEFAULT_ASSETS.get(asset)
    symbol = meta["yahoo"] if meta else f"{asset}.IS"
    try:
        import yfinance as yf
    except ImportError:
        return None
    try:
        # Takvim günü > işlem günü olduğundan tampon payı bırak.
        period_days = int(days * 1.6) + 40
        close = _yf_close(yf, symbol, period_days)
        if close is None:
            return None
        if meta and meta.get("to_try_gram"):
            usdtry = _yf_close(yf, "USDTRY=X", period_days)
            if usdtry is None:
                return None
            # Tarihe göre hizala (inner join), ons -> gram, USD -> TL.
            joined = close.to_frame("px").join(usdtry.to_frame("fx"), how="inner").dropna()
            close = joined["px"] * joined["fx"] / TROY_OUNCE_GRAMS
        prices = close.to_numpy(dtype=float)
        prices = prices[~np.isnan(prices)]
        return prices[-days:] if len(prices) >= 30 else None
    except Exception as exc:
        print(f"[data] yfinance çekilemedi ({symbol}): {exc}")
        return None


# EVDS seri kodları (örnek; gerçek kodlarla doldurulabilir).
EVDS_SERIES = {
    "ALTIN": "TP.FG.A01",  # örnek altın serisi kodu
}


def _fetch_evds(asset: str, days: int):
    """TCMB EVDS'ten gerçek fiyat serisi. EVDS_API_KEY yoksa None."""
    key = os.getenv("EVDS_API_KEY")
    if not key:
        return None
    series_code = EVDS_SERIES.get(asset)
    if not series_code:
        return None
    try:
        import requests
        from datetime import date, timedelta
        end = date.today()
        start = end - timedelta(days=int(days * 1.6) + 40)
        url = (f"https://evds2.tcmb.gov.tr/service/evds/series={series_code}"
               f"&startDate={start:%d-%m-%Y}&endDate={end:%d-%m-%Y}"
               f"&type=json&aggregationTypes=last")
        resp = requests.get(url, headers={"key": key}, timeout=15)
        resp.raise_for_status()
        items = resp.json().get("items", [])
        col = series_code.replace(".", "_")
        prices = [float(it[col]) for it in items if it.get(col)]
        return np.array(prices[-days:], dtype=float) if len(prices) >= 30 else None
    except Exception as exc:
        print(f"[data] EVDS çekilemedi ({asset}): {exc}; sonraki kaynağa düşülüyor.")
        return None


# --------------------------------------------------------------------------- #
# Sentetik (mock) fraktal seri
# --------------------------------------------------------------------------- #
def fbm_series(n: int, hurst: float, sigma: float, seed: int) -> np.ndarray:
    """Fraktal Brownian Motion (uzun bellek) artımları — Cholesky ile tam kovaryans."""
    rng = np.random.default_rng(seed)
    t = np.arange(1, n + 1, dtype=float)
    # Cov(B_H(t), B_H(s)) = 0.5 (t^2H + s^2H - |t-s|^2H)
    cov = 0.5 * (t[:, None] ** (2 * hurst) + t[None, :] ** (2 * hurst)
                 - np.abs(t[:, None] - t[None, :]) ** (2 * hurst))
    cov += 1e-8 * np.eye(n)
    try:
        L = np.linalg.cholesky(cov)
        fbm = L @ rng.standard_normal(n)
        incr = np.diff(np.concatenate([[0.0], fbm]))
    except np.linalg.LinAlgError:
        incr = rng.standard_normal(n)
    incr = incr / (incr.std() or 1.0) * sigma / np.sqrt(252)
    return incr


def asset_seed(asset: str) -> int:
    """Süreçler arası kararlı tohum (hash() PYTHONHASHSEED ile her süreçte değişir)."""
    return zlib.crc32(asset.encode()) % 9999


def _mock_series(asset: str, days: int, seed: int) -> np.ndarray:
    p = DEFAULT_ASSETS.get(asset, {"mu": 0.12, "sigma": 0.3, "hurst": 0.55})
    drift = p["mu"] / 252
    incr = fbm_series(days, p["hurst"], p["sigma"], seed + asset_seed(asset))
    log_returns = drift + incr
    return 100.0 * np.exp(np.cumsum(log_returns))


# --------------------------------------------------------------------------- #
# Genel arayüz
# --------------------------------------------------------------------------- #
def get_price_series(asset: str, days: int = 504, seed: int = 0,
                     use_real: bool | None = None) -> np.ndarray:
    """Günlük kapanış fiyat serisi.

    use_real=None  : ortam değişkenine bak (FRACTAL_FORCE_MOCK=1 -> mock).
    use_real=True  : gerçek veriyi zorla (önbellek/yfinance/EVDS); yoksa mock'a düşer.
    use_real=False : her zaman sentetik (deterministik testler).
    """
    if use_real is None:
        use_real = os.getenv("FRACTAL_FORCE_MOCK") != "1"

    if use_real:
        cached = _read_cache(asset, days)
        if cached is not None:
            _LAST_SOURCE[asset] = "önbellek (gerçek)"
            return cached
        for name, fetch in (("yfinance", _fetch_yfinance), ("EVDS", _fetch_evds)):
            real = fetch(asset, days)
            if real is not None and len(real) >= 30:
                _write_cache(asset, days, real)
                _LAST_SOURCE[asset] = f"{name} (gerçek)"
                return real

    _LAST_SOURCE[asset] = "mock (sentetik)" if use_real else "mock (zorlanmış)"
    return _mock_series(asset, days, seed)


def data_source(asset: str, days: int = 504) -> str:
    """Bir varlık için fiilen kullanılan veri kaynağı (UI/CLI bilgilendirmesi).

    Kütüphanenin kurulu olmasına değil, serinin gerçekten nereden geldiğine bakar.
    """
    get_price_series(asset, days)
    return _LAST_SOURCE.get(asset, "bilinmiyor")


def daily_returns(prices: np.ndarray) -> np.ndarray:
    """Günlük log getiriler."""
    return np.diff(np.log(prices))


def normalize_weights(weights) -> np.ndarray:
    """Negatifleri sıfırlar ve toplamı 1'e ölçekler; toplam 0 ise eşit ağırlık verir."""
    w = np.clip(np.asarray(weights, dtype=float), 0.0, None)
    total = w.sum()
    return w / total if total > 0 else np.full(len(w), 1.0 / len(w))


def aligned_returns(assets, days: int = 504, seed: int = 0) -> np.ndarray:
    """(A, T) log getiri matrisi. Seriler farklı uzunluktaysa sondan hizalanır.

    Gerçek veride tarih bazlı hizalama pipelines/ tarafında yapılır; burada en azından
    farklı işlem takvimlerinden doğan uzunluk farkı çökmeye yol açmaz.
    """
    rets = [daily_returns(get_price_series(a, days, seed + i)) for i, a in enumerate(assets)]
    n = min(len(r) for r in rets)
    return np.array([r[-n:] for r in rets])
