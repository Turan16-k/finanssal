"""Veri kaynağı adaptörleri. Her adaptör `fetch(code, start, end) -> list[PricePoint]` sağlar."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class PricePoint:
    date: date
    close: float
