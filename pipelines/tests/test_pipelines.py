import json
from datetime import date
from pathlib import Path

import numpy as np
import pytest

from pipelines import ingest, quant
from pipelines.sources import PricePoint, coingecko, evds

ROOT = Path(__file__).resolve().parents[2]


def test_evds_parse_daily_skips_holidays():
    items = [
        {"Tarih": "01-01-2024", "TP_DK_USD_S_YTL": None},
        {"Tarih": "02-01-2024", "TP_DK_USD_S_YTL": "29.7412"},
        {"Tarih": "03-01-2024", "TP_DK_USD_S_YTL": "29.80"},
    ]
    assert evds.parse_items(items, "TP.DK.USD.S.YTL") == [
        PricePoint(date(2024, 1, 2), 29.7412), PricePoint(date(2024, 1, 3), 29.80)]


def test_evds_parse_monthly():
    items = [{"Tarih": "2024-3", "TP_FG_J0": "2139.47"}]
    assert evds.parse_items(items, "TP.FG.J0") == [PricePoint(date(2024, 3, 1), 2139.47)]


def test_evds_requires_key(monkeypatch):
    monkeypatch.delenv("EVDS_API_KEY", raising=False)
    with pytest.raises(RuntimeError):
        evds.fetch("TP.DK.USD.S.YTL", date(2024, 1, 1), date(2024, 2, 1))


def test_coingecko_keeps_last_value_per_day():
    day_ms = 1704067200000  # 2024-01-01T00:00Z
    payload = {"prices": [[day_ms, 100.0], [day_ms + 3600_000, 101.0], [day_ms + 86400_000, 105.0]]}
    assert coingecko.parse_market_chart(payload) == [
        PricePoint(date(2024, 1, 1), 101.0), PricePoint(date(2024, 1, 2), 105.0)]


def test_start_date_backfill_and_overlap():
    today = date(2026, 9, 25)
    assert ingest.start_date(None, today) == date(2021, 9, 25)
    assert ingest.start_date(date(2026, 9, 20), today) == date(2026, 9, 13)


def test_quote_row_change_pct():
    row = ingest.quote_row(7, [PricePoint(date(2026, 9, 24), 40.0), PricePoint(date(2026, 9, 25), 41.0)])
    assert row == {"instrument_id": 7, "close": 41.0, "prev_close": 40.0,
                   "change_pct_1d": 2.5, "as_of": "2026-09-25"}
    assert ingest.quote_row(7, [PricePoint(date(2026, 9, 25), 41.0)])["change_pct_1d"] is None


def test_seed_parser_reads_all_instruments():
    rows = ingest._seed_instruments(str(ROOT / "supabase" / "seed.sql"))
    by_symbol = {r["symbol"]: r for r in rows}
    assert by_symbol["USDTRY"]["source"] == "evds"
    assert by_symbol["USDTRY"]["source_code"] == "TP.DK.USD.S.YTL"
    assert by_symbol["BTC"]["source_code"] == "bitcoin"
    assert by_symbol["THYAO"]["source"] == "manual" and by_symbol["THYAO"]["source_code"] is None
    assert by_symbol["TTE"]["source"] == "manual"
    assert len(rows) >= 20


def test_hurst_matches_prototype_and_dart_fixtures():
    fx = json.loads((ROOT / "packages/quant_dart/test/fixtures/parity.json").read_text())
    for rets, expected in zip(fx["log_returns"], fx["hurst"]):
        assert quant.hurst_rs(rets) == pytest.approx(expected, abs=1e-12)


def test_instrument_analytics():
    rng = np.random.default_rng(0)
    prices = 100 * np.exp(np.cumsum(0.0005 + 0.01 * rng.standard_normal(600)))
    a = quant.instrument_analytics(prices)
    assert set(a) == {"hurst", "regime", "vol_30d", "vol_1y", "return_1y", "max_dd_1y"}
    assert 0.1 < a["vol_1y"] < 0.2
    assert quant.instrument_analytics(prices[:30]) is None
