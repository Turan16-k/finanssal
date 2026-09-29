"""CoinGecko adaptörü (Demo API — ücretsiz, anahtar: https://www.coingecko.com/en/api).

Kullanım koşulu: "Data provided by CoinGecko" atfı gösterilmelidir.
Demo planında geçmiş veri son 365 gün ile sınırlıdır.
"""
from __future__ import annotations

import os
from datetime import date, datetime, timezone

import requests

from . import PricePoint

BASE_URL = "https://api.coingecko.com/api/v3"
MAX_HISTORY_DAYS = 365


def parse_market_chart(payload: dict) -> list[PricePoint]:
    """[[ms, fiyat], ...] -> gün başına son değer (UTC)."""
    by_day: dict[date, float] = {}
    for ms, price in payload.get("prices", []):
        if price is None or price <= 0:
            continue
        d = datetime.fromtimestamp(ms / 1000, tz=timezone.utc).date()
        by_day[d] = float(price)
    return [PricePoint(d, v) for d, v in sorted(by_day.items())]


def fetch(coin_id: str, start: date, end: date, session: requests.Session | None = None,
          vs_currency: str = "try") -> list[PricePoint]:
    s = session or requests.Session()
    days = min(MAX_HISTORY_DAYS, max(1, (date.today() - start).days + 1))
    headers = {"accept": "application/json"}
    if key := os.getenv("COINGECKO_API_KEY"):
        headers["x-cg-demo-api-key"] = key
    resp = s.get(f"{BASE_URL}/coins/{coin_id}/market_chart",
                 params={"vs_currency": vs_currency, "days": days, "interval": "daily"},
                 headers=headers, timeout=30)
    resp.raise_for_status()
    return [p for p in parse_market_chart(resp.json()) if start <= p.date <= end]
