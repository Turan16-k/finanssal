"""Fraktal piyasa analizi — Hurst üssü (R/S analizi).

H > 0.5  : trend/uzun bellek (persistent)
H = 0.5  : rastgele yürüyüş (random walk)
H < 0.5  : ortalamaya dönüş (mean-reverting)
"""
from __future__ import annotations

import numpy as np


def hurst_rs(series: np.ndarray, min_chunk: int = 8) -> float:
    """R/S (rescaled range) analizi ile Hurst üssü tahmini."""
    series = np.asarray(series, dtype=float)
    n = len(series)
    if n < min_chunk * 2:
        return 0.5
    sizes = []
    rs = []
    size = min_chunk
    while size <= n // 2:
        chunks = n // size
        rs_vals = []
        for i in range(chunks):
            seg = series[i * size:(i + 1) * size]
            mean = seg.mean()
            dev = np.cumsum(seg - mean)
            R = dev.max() - dev.min()
            S = seg.std()
            if S > 0:
                rs_vals.append(R / S)
        if rs_vals:
            sizes.append(size)
            rs.append(np.mean(rs_vals))
        size *= 2
    if len(sizes) < 2:
        return 0.5
    coef = np.polyfit(np.log(sizes), np.log(rs), 1)
    return float(np.clip(coef[0], 0.0, 1.0))


def market_regime(hurst: float) -> str:
    if hurst > 0.55:
        return "Trend/Persistent (H>0.55)"
    if hurst < 0.45:
        return "Mean-reverting (H<0.45)"
    return "Random Walk (H≈0.5)"
