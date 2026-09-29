"""Supabase PostgREST istemcisi (service_role). Ek bağımlılık yok, yalnızca requests.

service_role anahtarı RLS'yi atlar: yalnızca GitHub Actions secret'ı olarak tutulur,
asla uygulamaya veya repoya girmez.
"""
from __future__ import annotations

import os
from datetime import date
from typing import Iterable

import requests

UPSERT_BATCH = 1000


class SupabaseStore:
    def __init__(self, url: str | None = None, service_key: str | None = None,
                 session: requests.Session | None = None):
        url = url or os.environ["SUPABASE_URL"]
        key = service_key or os.environ["SUPABASE_SERVICE_ROLE_KEY"]
        self.rest = url.rstrip("/") + "/rest/v1"
        self.functions = url.rstrip("/") + "/functions/v1"
        self.s = session or requests.Session()
        self.s.headers.update({
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        })

    # -- okuma --------------------------------------------------------------
    def instruments(self, source: str | None = None) -> list[dict]:
        params = {"select": "id,symbol,source,source_code,type,meta", "is_active": "eq.true",
                  "order": "id"}
        if source:
            params["source"] = f"eq.{source}"
        r = self.s.get(f"{self.rest}/instruments", params=params, timeout=30)
        r.raise_for_status()
        return r.json()

    def last_price_date(self, instrument_id: int) -> date | None:
        r = self.s.get(f"{self.rest}/prices_daily", timeout=30, params={
            "select": "date", "instrument_id": f"eq.{instrument_id}",
            "order": "date.desc", "limit": 1})
        r.raise_for_status()
        rows = r.json()
        return date.fromisoformat(rows[0]["date"]) if rows else None

    def closes(self, instrument_id: int, since: date) -> list[tuple[date, float]]:
        out: list[tuple[date, float]] = []
        offset = 0
        while True:
            r = self.s.get(f"{self.rest}/prices_daily", timeout=30, params={
                "select": "date,close", "instrument_id": f"eq.{instrument_id}",
                "date": f"gte.{since.isoformat()}", "order": "date",
                "limit": UPSERT_BATCH, "offset": offset})
            r.raise_for_status()
            rows = r.json()
            out += [(date.fromisoformat(x["date"]), float(x["close"])) for x in rows]
            if len(rows) < UPSERT_BATCH:
                return out
            offset += UPSERT_BATCH

    # -- yazma --------------------------------------------------------------
    def upsert(self, table: str, rows: Iterable[dict], on_conflict: str) -> int:
        rows = list(rows)
        for i in range(0, len(rows), UPSERT_BATCH):
            r = self.s.post(f"{self.rest}/{table}", params={"on_conflict": on_conflict},
                            json=rows[i:i + UPSERT_BATCH], timeout=60,
                            headers={"Prefer": "resolution=merge-duplicates,return=minimal"})
            r.raise_for_status()
        return len(rows)

    def invoke_function(self, name: str, body: dict | None = None) -> dict:
        r = self.s.post(f"{self.functions}/{name}", json=body or {}, timeout=120)
        r.raise_for_status()
        return r.json() if r.content else {}
