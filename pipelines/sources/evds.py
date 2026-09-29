"""TCMB EVDS adaptörü. Ücretsiz API anahtarı: https://evds3.tcmb.gov.tr (Profil > API Anahtarını Kopyala).

EVDS 2025'te evds2 -> evds3 adresine taşındı; eski /service/evds/ ucu çalışmıyor.
Parametreler "?" olmadan doğrudan yola eklenir, anahtar `key` HTTP başlığında gönderilir.

Kullanım koşulu: veriler kaynak gösterilerek ("TCMB EVDS") kullanılabilir; uygulama bu
ibareyi ilgili ekranlarda gösterir (instruments.meta.attribution).
"""
from __future__ import annotations

import os
from datetime import date, datetime

import requests

from . import PricePoint

DEFAULT_BASE_URL = "https://evds3.tcmb.gov.tr/igmevdsms-dis/"
# EVDS tek istekte çok uzun aralıkları reddedebilir; yıllık parçalara böleriz.
MAX_SPAN_DAYS = 365


def _base_url() -> str:
    return os.getenv("EVDS_BASE_URL", DEFAULT_BASE_URL).rstrip("/") + "/"


def parse_date(raw: str) -> date | None:
    """EVDS 'Tarih' alanı: günlük '02-01-2024', aylık '2024-1', yıllık '2024'."""
    raw = raw.strip()
    for fmt in ("%d-%m-%Y", "%Y-%m", "%Y"):
        try:
            return datetime.strptime(raw, fmt).date()
        except ValueError:
            continue
    return None


def parse_items(items: list[dict], series_code: str) -> list[PricePoint]:
    col = series_code.replace(".", "_")
    out = []
    for it in items:
        value, d = it.get(col), parse_date(str(it.get("Tarih", "")))
        if value in (None, "", "null") or d is None:
            continue  # tatil/eksik gün
        try:
            v = float(value)
        except (TypeError, ValueError):
            continue
        if v > 0:
            out.append(PricePoint(d, v))
    return out


def fetch(series_code: str, start: date, end: date, session: requests.Session | None = None,
          api_key: str | None = None) -> list[PricePoint]:
    key = api_key or os.getenv("EVDS_API_KEY")
    if not key:
        raise RuntimeError("EVDS_API_KEY tanımlı değil")
    s = session or requests.Session()
    points: dict[date, PricePoint] = {}
    cur = start
    while cur <= end:
        chunk_end = min(end, date.fromordinal(cur.toordinal() + MAX_SPAN_DAYS))
        url = (f"{_base_url()}series={series_code}"
               f"&startDate={cur:%d-%m-%Y}&endDate={chunk_end:%d-%m-%Y}&type=json")
        resp = s.get(url, headers={"key": key}, timeout=30)
        resp.raise_for_status()
        for p in parse_items(resp.json().get("items", []), series_code):
            points[p.date] = p
        cur = date.fromordinal(chunk_end.toordinal() + 1)
    return sorted(points.values(), key=lambda p: p.date)
