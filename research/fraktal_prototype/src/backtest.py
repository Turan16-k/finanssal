"""Backtesting — sabit-ağırlık portföyün tarihsel performansını ölçer.

Çıktı metrikleri: toplam getiri, yıllık (CAGR), volatilite, Sharpe, maksimum
düşüş (max drawdown). Strateji karşılaştırması ve risk değerlendirmesi için.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import List

import numpy as np

from .data import aligned_returns, normalize_weights


@dataclass
class BacktestResult:
    total_return: float
    cagr: float
    volatility: float
    sharpe: float
    max_drawdown: float
    n_days: int


def max_drawdown(equity: np.ndarray) -> float:
    """Tepe-dip en büyük düşüş (pozitif oran, ör. 0.3 = %30 düşüş)."""
    peak = np.maximum.accumulate(equity)
    dd = (equity - peak) / peak
    return float(-dd.min()) if len(dd) else 0.0


def backtest(assets: List[str], weights: List[float], days: int = 504,
             rf: float = 0.45, rebalance: bool = True, seed: int = 1) -> BacktestResult:
    w = normalize_weights(weights)
    # daily_returns log getiri verir; bileşik büyüme için basit getiriye çevir.
    rets = np.expm1(aligned_returns(assets, days, seed))  # (A, T)

    if rebalance:
        # Günlük yeniden dengeleme: portföy getirisi = ağırlıklı ortalama.
        port = w @ rets
    else:
        # Al-tut: ilk ağırlıklar zamanla kayar.
        growth = np.cumprod(1 + rets, axis=1)
        port_value = (w[:, None] * growth).sum(axis=0)
        port = np.diff(np.concatenate([[1.0], port_value])) / \
            np.concatenate([[1.0], port_value[:-1]])

    equity = np.cumprod(1 + port)
    total = float(equity[-1] - 1) if len(equity) else 0.0
    n = len(port)
    cagr = float(equity[-1] ** (252 / n) - 1) if n else 0.0
    vol = float(port.std() * np.sqrt(252))
    sharpe = (cagr - rf) / vol if vol > 0 else 0.0
    return BacktestResult(round(total, 4), round(cagr, 4), round(vol, 4),
                          round(sharpe, 4), round(max_drawdown(equity), 4), n)
