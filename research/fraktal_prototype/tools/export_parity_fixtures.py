"""quant_dart eşdeğerlik (parity) fixture'larını üretir.

Python prototipi referans kabul edilir; Dart portu aynı girdilerle aynı sonuçları
(tolerans içinde) vermelidir. Çıktı: packages/quant_dart/test/fixtures/parity.json

    FRACTAL_FORCE_MOCK=1 python tools/export_parity_fixtures.py
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

os.environ["FRACTAL_FORCE_MOCK"] = "1"
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import numpy as np  # noqa: E402

from src.backtest import backtest  # noqa: E402
from src.data import aligned_returns  # noqa: E402
from src.fractal import hurst_rs  # noqa: E402
from src.optimize import max_sharpe  # noqa: E402

OUT = ROOT.parents[1] / "packages" / "quant_dart" / "test" / "fixtures" / "parity.json"
ASSETS = ["THYAO", "GARAN", "ALTIN"]
WEIGHTS = [0.5, 0.3, 0.2]
SEED = 1
DAYS = 504


def _interior_case() -> dict:
    """İç (köşe olmayan) çözümü olan elle kurulmuş örnek; SLSQP ile çözülür."""
    from scipy.optimize import minimize
    mu = np.array([0.20, 0.15, 0.10, 0.12])
    vol = np.array([0.30, 0.22, 0.12, 0.18])
    corr = np.array([[1.0, 0.4, 0.1, 0.3],
                     [0.4, 1.0, 0.2, 0.25],
                     [0.1, 0.2, 1.0, -0.1],
                     [0.3, 0.25, -0.1, 1.0]])
    cov = corr * np.outer(vol, vol)
    rf = 0.03

    def neg_sharpe(w):
        return -(w @ mu - rf) / np.sqrt(w @ cov @ w)

    res = minimize(neg_sharpe, np.repeat(0.25, 4), bounds=[(0, 1)] * 4,
                   constraints=({"type": "eq", "fun": lambda w: w.sum() - 1},),
                   options={"ftol": 1e-12, "maxiter": 500})
    w = np.clip(res.x, 0, None)
    w /= w.sum()
    return {"mu": mu.tolist(), "cov": cov.tolist(), "rf": rf,
            "weights": w.tolist(), "sharpe": float(-neg_sharpe(w))}


def main() -> None:
    rets = aligned_returns(ASSETS, DAYS, SEED)
    fixtures = {
        "assets": ASSETS,
        "weights": WEIGHTS,
        "log_returns": rets.tolist(),
        "hurst": [hurst_rs(r) for r in rets],
        "cov_daily": np.cov(rets).tolist(),
        "percentile": {
            "data": rets[0][:37].tolist(),
            "q": [5, 25, 50, 95],
            "values": [float(np.percentile(rets[0][:37], q)) for q in (5, 25, 50, 95)],
        },
        "backtest": {},
        "max_sharpe": {},
    }
    for rebalance in (True, False):
        bt = backtest(ASSETS, WEIGHTS, DAYS, rf=0.45, rebalance=rebalance, seed=SEED)
        fixtures["backtest"]["rebalance" if rebalance else "buy_hold"] = bt.__dict__
    for rf in (0.0, 0.10):
        alloc = max_sharpe(ASSETS, rf=rf, days=DAYS, seed=SEED)
        fixtures["max_sharpe"][str(rf)] = alloc.__dict__
    fixtures["max_sharpe_interior"] = _interior_case()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(fixtures, indent=1))
    print(f"yazıldı: {OUT}")


if __name__ == "__main__":
    main()
