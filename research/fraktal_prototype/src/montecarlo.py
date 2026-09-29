"""Monte Carlo portföy simülasyonu — sentiment ile uyarlanmış drift.

Sentiment skoru, beklenen getiriyi (drift) hafifçe kaydırarak sayısal modele
entegre edilir: mu_adj = mu + sentiment_weight * sentiment * (0.12 / 252)
(toplamsal günlük prim; tam pozitif sentiment yıllık +%12 drift ekler).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List

import numpy as np

from .data import aligned_returns, normalize_weights


@dataclass
class MCResult:
    horizon: int
    n_sims: int
    expected_value: float
    var_95: float            # %95 Value at Risk (kayıp, pozitif sayı)
    cvar_95: float
    prob_loss: float
    percentiles: Dict[str, float] = field(default_factory=dict)
    paths_sample: List[List[float]] = field(default_factory=list)
    sentiment_applied: float = 0.0


def simulate_portfolio(assets: List[str], weights: List[float],
                       horizon: int = 252, n_sims: int = 5000,
                       sentiment: float = 0.0, sentiment_weight: float = 0.3,
                       initial: float = 100_000.0, seed: int = 1,
                       jumps: bool = False, jump_intensity: float = 0.05,
                       jump_mean: float = -0.02, jump_std: float = 0.05) -> MCResult:
    """Monte Carlo portföy simülasyonu.

    jumps=True ise Merton jump-diffusion: normal GBM'e ek olarak Poisson süreçli
    ani sıçramalar (kriz/şok) eklenir — kuyruk riskini (fat tails) daha gerçekçi
    modeller. jump_intensity günlük sıçrama olasılığı (lambda)."""
    weights = normalize_weights(weights)
    rng = np.random.default_rng(seed)

    # Her varlık için tarihsel (mock) getirilerden mu/sigma kestir
    rets = aligned_returns(assets, days=504, seed=seed)  # (A, T)
    mu = rets.mean(axis=1)                     # günlük ortalama
    cov = np.cov(rets)                         # günlük kovaryans
    if cov.ndim == 0:
        cov = cov.reshape(1, 1)

    # Sentiment ile drift uyarlaması (toplamsal premium; işaret garantili).
    # Pozitif sentiment günlük driftleri yukarı, negatif aşağı kaydırır.
    daily_premium = 0.12 / 252.0  # yıllık %12'lik tam-sentiment etkisi
    mu_adj = mu + sentiment_weight * sentiment * daily_premium

    chol = np.linalg.cholesky(cov + 1e-10 * np.eye(len(assets)))
    finals = np.empty(n_sims)
    sample_paths = []
    for s in range(n_sims):
        z = rng.standard_normal((horizon, len(assets)))
        daily = mu_adj + z @ chol.T
        port_daily = daily @ weights
        if jumps:
            # Merton sıçramaları: günde N~Poisson(lambda) adet N(m, s) log-şok;
            # N şokun toplamı ~ N(N*m, sqrt(N)*s).
            n_jumps = rng.poisson(jump_intensity, size=horizon)
            jump_sizes = (n_jumps * jump_mean
                          + np.sqrt(n_jumps) * jump_std * rng.standard_normal(horizon))
            port_daily = port_daily + jump_sizes
        path = initial * np.exp(np.cumsum(port_daily))
        finals[s] = path[-1]
        if s < 50:
            sample_paths.append(path[:: max(1, horizon // 60)].tolist())

    losses = initial - finals
    var95 = float(np.percentile(losses, 95))
    cvar95 = float(losses[losses >= var95].mean()) if np.any(losses >= var95) else var95
    return MCResult(
        horizon=horizon, n_sims=n_sims,
        expected_value=float(finals.mean()),
        var_95=max(0.0, var95), cvar_95=max(0.0, cvar95),
        prob_loss=float((finals < initial).mean()),
        percentiles={
            "p5": float(np.percentile(finals, 5)),
            "p50": float(np.percentile(finals, 50)),
            "p95": float(np.percentile(finals, 95)),
        },
        paths_sample=sample_paths,
        sentiment_applied=sentiment,
    )
