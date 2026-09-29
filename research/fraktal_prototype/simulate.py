"""CLI portföy simülasyonu (arayüzsüz).

    python simulate.py --assets THYAO GARAN ALTIN --horizon 252 --sims 5000
"""
from __future__ import annotations

import argparse
import os
import sys

# Windows konsolunda Türkçe/özel karakterler (≈, ₺) çökmesin.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from src.data import get_price_series, daily_returns, data_source
from src.fractal import hurst_rs, market_regime
from src.montecarlo import simulate_portfolio
from src.sentiment import analyze_bulletin
from src.backtest import backtest
from src.optimize import max_sharpe


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--assets", nargs="+", default=["THYAO", "GARAN", "ALTIN"])
    ap.add_argument("--horizon", type=int, default=252)
    ap.add_argument("--sims", type=int, default=5000)
    ap.add_argument("--bulletin", default="Güçlü büyüme ve rekor kâr beklentisi olumlu.")
    ap.add_argument("--optimize", action="store_true",
                    help="Eşit ağırlık yerine maks-Sharpe (Markowitz) ağırlıklarını kullan")
    ap.add_argument("--mock", action="store_true",
                    help="Gerçek veri yerine sentetik (fraktal) seri kullan")
    a = ap.parse_args()

    if a.mock:
        os.environ["FRACTAL_FORCE_MOCK"] = "1"

    print("=== Veri Kaynağı ===")
    for asset in a.assets:
        print(f"  {asset}: {data_source(asset)}")
    print()

    n = len(a.assets)
    if a.optimize:
        alloc = max_sharpe(a.assets)
        weights = list(alloc.weights)
        print("=== Markowitz Optimizasyonu (maks. Sharpe) ===")
        for asset, w in zip(a.assets, weights):
            print(f"  {asset}: %{w*100:.1f}")
        print(f"  Sharpe={alloc.sharpe:.3f}  getiri=%{alloc.expected_return*100:.1f}  "
              f"vol=%{alloc.volatility*100:.1f}\n")
    else:
        weights = [1.0 / n] * n

    print("=== Fraktal Analiz (Hurst) ===")
    for asset in a.assets:
        h = hurst_rs(daily_returns(get_price_series(asset, 504, 0)))
        print(f"  {asset}: H={h:.3f}  {market_regime(h)}")

    sent = analyze_bulletin(a.bulletin)
    print(f"\nSentiment: {sent.label} ({sent.score:+.2f}) [{sent.backend}]")

    res = simulate_portfolio(a.assets, weights, a.horizon, a.sims,
                             sentiment=sent.score)
    print("\n=== Monte Carlo ===")
    print(f"  Beklenen değer : {res.expected_value:,.0f}")
    print(f"  VaR %95        : {res.var_95:,.0f}")
    print(f"  CVaR %95       : {res.cvar_95:,.0f}")
    print(f"  Zarar olasılığı: %{res.prob_loss*100:.1f}")
    print(f"  Persentiller   : {res.percentiles}")

    bt = backtest(a.assets, weights)
    print("\n=== Tarihsel Backtest (504 gün) ===")
    print(f"  Toplam getiri  : %{bt.total_return*100:.1f}")
    print(f"  CAGR (yıllık)  : %{bt.cagr*100:.1f}")
    print(f"  Volatilite     : %{bt.volatility*100:.1f}")
    print(f"  Sharpe         : {bt.sharpe:.2f}")
    print(f"  Maks. düşüş    : %{bt.max_drawdown*100:.1f}")


if __name__ == "__main__":
    main()
