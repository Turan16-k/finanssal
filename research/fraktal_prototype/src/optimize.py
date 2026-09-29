"""Portföy optimizasyonu — Markowitz ortalama-varyans + maksimum Sharpe.

Tarihsel getirilerden beklenen getiri ve kovaryansı kestirip etkin sınır
(efficient frontier) üzerinde optimal ağırlıkları bulur. SciPy varsa kısıtlı
optimizasyon, yoksa rastgele arama (Monte Carlo) ile yaklaşık çözüm.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import List

import numpy as np

from .data import aligned_returns


@dataclass
class Allocation:
    weights: List[float]
    expected_return: float  # yıllık
    volatility: float       # yıllık
    sharpe: float


def _annualize(mu_daily: np.ndarray, cov_daily: np.ndarray):
    return mu_daily * 252, cov_daily * 252


def _portfolio_stats(w, mu_a, cov_a, rf):
    ret = float(w @ mu_a)
    vol = float(np.sqrt(w @ cov_a @ w))
    sharpe = (ret - rf) / vol if vol > 0 else 0.0
    return ret, vol, sharpe


def max_sharpe(assets: List[str], rf: float = 0.45, days: int = 504,
               seed: int = 1) -> Allocation:
    """Risksiz oran rf (TL mevduat ~%45) altında Sharpe'ı maksimize eden ağırlıklar.

    Not: rf Türkiye koşullarında yüksek; gerçek değer EVDS'ten alınabilir.
    """
    rets = aligned_returns(assets, days, seed)
    mu_a, cov_a = _annualize(rets.mean(axis=1), np.cov(rets))
    if cov_a.ndim == 0:
        cov_a = cov_a.reshape(1, 1)
    n = len(assets)

    try:
        from scipy.optimize import minimize
        cons = ({"type": "eq", "fun": lambda w: w.sum() - 1},)
        bounds = [(0.0, 1.0)] * n  # short yok
        res = minimize(lambda w: -_portfolio_stats(w, mu_a, cov_a, rf)[2],
                       x0=np.repeat(1 / n, n), bounds=bounds, constraints=cons)
        w = res.x
    except Exception:
        w = _random_search(mu_a, cov_a, rf, n, seed)

    w = np.clip(w, 0, None)
    w = w / w.sum()
    ret, vol, sharpe = _portfolio_stats(w, mu_a, cov_a, rf)
    return Allocation([round(float(x), 4) for x in w], round(ret, 4),
                      round(vol, 4), round(sharpe, 4))


def _random_search(mu_a, cov_a, rf, n, seed, n_iter=20000):
    rng = np.random.default_rng(seed)
    best_w, best_sharpe = None, -np.inf
    for _ in range(n_iter):
        w = rng.random(n)
        w /= w.sum()
        _, _, s = _portfolio_stats(w, mu_a, cov_a, rf)
        if s > best_sharpe:
            best_sharpe, best_w = s, w
    return best_w
