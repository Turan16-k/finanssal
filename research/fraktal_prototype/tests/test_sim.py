import os
import sys
from pathlib import Path

import numpy as np

# Testler ağ trafiğinden bağımsız ve deterministik olmalı -> sentetik veriyi zorla.
os.environ["FRACTAL_FORCE_MOCK"] = "1"

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from src.data import get_price_series, daily_returns  # noqa: E402
from src.fractal import hurst_rs  # noqa: E402
from src.montecarlo import simulate_portfolio  # noqa: E402
from src.sentiment import analyze_bulletin, _lexicon_score  # noqa: E402


def test_price_series_positive():
    p = get_price_series("THYAO", 252, 0)
    assert len(p) == 252 and np.all(p > 0)


def test_hurst_in_range():
    h = hurst_rs(daily_returns(get_price_series("ASELS", 504, 1)))
    assert 0.0 <= h <= 1.0


def test_mc_result_consistency():
    res = simulate_portfolio(["THYAO", "GARAN"], [0.5, 0.5], horizon=126, n_sims=2000)
    assert res.expected_value > 0
    assert 0.0 <= res.prob_loss <= 1.0
    assert res.percentiles["p5"] <= res.percentiles["p50"] <= res.percentiles["p95"]


def test_positive_sentiment_raises_expected_value():
    base = simulate_portfolio(["THYAO"], [1.0], 252, 3000, sentiment=0.0, seed=5)
    pos = simulate_portfolio(["THYAO"], [1.0], 252, 3000, sentiment=0.8, seed=5)
    assert pos.expected_value >= base.expected_value


def test_lexicon_sentiment():
    assert _lexicon_score("güçlü büyüme rekor kâr") > 0
    assert _lexicon_score("zarar kriz iflas düşüş") < 0


if __name__ == "__main__":
    test_price_series_positive(); test_hurst_in_range(); test_mc_result_consistency()
    test_positive_sentiment_raises_expected_value(); test_lexicon_sentiment()
    print("Tum testler gecti")
