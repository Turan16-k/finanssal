"""Gece analitiği için hesaplamalar (numpy).

hurst_rs, research/fraktal_prototype/src/fractal.py ve packages/quant_dart ile aynı
algoritmadır; üçü arasındaki eşdeğerlik parity fixture'larıyla test edilir.
"""
from __future__ import annotations

import numpy as np

TRADING_DAYS = 252


def hurst_rs(series, min_chunk: int = 8) -> float:
    series = np.asarray(series, dtype=float)
    n = len(series)
    if n < min_chunk * 2:
        return 0.5
    sizes, rs = [], []
    size = min_chunk
    while size <= n // 2:
        vals = []
        for i in range(n // size):
            seg = series[i * size:(i + 1) * size]
            dev = np.cumsum(seg - seg.mean())
            s = seg.std()
            if s > 0:
                vals.append((dev.max() - dev.min()) / s)
        if vals:
            sizes.append(size)
            rs.append(np.mean(vals))
        size *= 2
    if len(sizes) < 2:
        return 0.5
    return float(np.clip(np.polyfit(np.log(sizes), np.log(rs), 1)[0], 0.0, 1.0))


def regime(h: float) -> str:
    if h > 0.55:
        return "trending"
    if h < 0.45:
        return "mean_reverting"
    return "random_walk"


def max_drawdown(prices) -> float:
    p = np.asarray(prices, dtype=float)
    if len(p) == 0:
        return 0.0
    peak = np.maximum.accumulate(p)
    return float(-((p - peak) / peak).min())


def instrument_analytics(closes) -> dict | None:
    """Son ~1 yıllık kapanışlardan özet metrikler. Yetersiz veride None."""
    p = np.asarray(closes, dtype=float)
    if len(p) < 60:
        return None
    rets = np.diff(np.log(p))
    last_year = p[-(TRADING_DAYS + 1):]
    h = hurst_rs(rets[-504:])
    return {
        "hurst": round(h, 4),
        "regime": regime(h),
        "vol_30d": round(float(rets[-30:].std() * np.sqrt(TRADING_DAYS)), 4),
        "vol_1y": round(float(rets[-TRADING_DAYS:].std() * np.sqrt(TRADING_DAYS)), 4),
        "return_1y": round(float(last_year[-1] / last_year[0] - 1), 4),
        "max_dd_1y": round(max_drawdown(last_year), 4),
    }
