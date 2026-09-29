"""Günlük veri çekme: TCMB EVDS / CoinGecko -> Supabase.

TEFAS kullanılmıyor: sitesi otomatik erişimi bot korumasıyla engelliyor ve resmi API yok.
Fonlar (BIST hisseleri gibi) source=manual; fiyatı kullanıcı girer.

    python -m pipelines.ingest                 # tüm aktif enstrümanlar
    python -m pipelines.ingest --source evds   # tek kaynak
    python -m pipelines.ingest --check         # yazmadan, kaynakları doğrula (seri kodu testi)
    python -m pipelines.ingest --analytics     # sonrasında gece analitiğini de çalıştır
    python -m pipelines.ingest --notify        # sonrasında send-alerts fonksiyonunu tetikle

Artımlıdır: her enstrüman için son kayıtlı tarihten birkaç gün geriden başlar
(geç düzeltmeleri yakalamak için). İlk çalıştırmada BACKFILL_YEARS kadar geçmiş çekilir.
"""
from __future__ import annotations

import argparse
import logging
import sys
import time
from datetime import date, timedelta

import requests

from . import quant
from .sources import PricePoint, coingecko, evds
from .store import SupabaseStore

log = logging.getLogger("ingest")

BACKFILL_YEARS = 5
OVERLAP_DAYS = 7
FETCHERS = {"evds": evds.fetch, "coingecko": coingecko.fetch}
# Ücretsiz katman hız sınırlarına saygı (CoinGecko demo ~30 istek/dk).
PAUSE_SECONDS = {"evds": 0.3, "coingecko": 2.5}


def start_date(last: date | None, today: date) -> date:
    if last is None:
        return today.replace(year=today.year - BACKFILL_YEARS)
    return last - timedelta(days=OVERLAP_DAYS)


def quote_row(instrument_id: int, points: list[PricePoint]) -> dict:
    last = points[-1]
    prev = points[-2].close if len(points) > 1 else None
    return {
        "instrument_id": instrument_id,
        "close": last.close,
        "prev_close": prev,
        "change_pct_1d": round((last.close / prev - 1) * 100, 4) if prev else None,
        "as_of": last.date.isoformat(),
    }


def ingest_instrument(store: SupabaseStore | None, inst: dict, session: requests.Session,
                      today: date, check: bool) -> int:
    fetch = FETCHERS[inst["source"]]
    last = None if check else store.last_price_date(inst["id"])
    start = today - timedelta(days=30) if check else start_date(last, today)
    points = fetch(inst["source_code"], start, today, session=session)
    if check:
        tail = f"son={points[-1].date} {points[-1].close:.4f}" if points else "VERİ YOK"
        log.info("  %-8s %-18s %4d nokta  %s", inst["symbol"], inst["source_code"], len(points), tail)
        return len(points)
    if not points:
        log.warning("  %s: yeni veri yok (%s -> %s)", inst["symbol"], start, today)
        return 0
    store.upsert("prices_daily", [
        {"instrument_id": inst["id"], "date": p.date.isoformat(), "close": p.close} for p in points
    ], on_conflict="instrument_id,date")
    # Günlük değişim için önceki kapanış da gerekebilir (artımlı çekimde 1 nokta dönebilir).
    recent = store.closes(inst["id"], today - timedelta(days=40))
    store.upsert("quotes_latest", [quote_row(inst["id"], [PricePoint(d, c) for d, c in recent])],
                 on_conflict="instrument_id")
    log.info("  %-8s +%d nokta (son %s)", inst["symbol"], len(points), points[-1].date)
    return len(points)


def run_analytics(store: SupabaseStore, today: date) -> int:
    rows = []
    for inst in store.instruments():
        if inst["source"] == "manual" or inst["type"] in ("inflation", "rate"):
            continue
        closes = store.closes(inst["id"], today - timedelta(days=800))
        stats = quant.instrument_analytics([c for _, c in closes])
        if stats:
            rows.append({"instrument_id": inst["id"], "date": today.isoformat(), **stats})
    store.upsert("analytics_daily", rows, on_conflict="instrument_id,date")
    log.info("analitik: %d enstrüman", len(rows))
    return len(rows)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", choices=sorted(FETCHERS))
    ap.add_argument("--check", action="store_true", help="Yazmadan kaynakları doğrula")
    ap.add_argument("--analytics", action="store_true")
    ap.add_argument("--notify", action="store_true")
    ap.add_argument("--seed-file", default="supabase/seed.sql",
                    help="--check için Supabase olmadan enstrüman listesi")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    today = date.today()
    session = requests.Session()
    store = None if args.check else SupabaseStore(session=None)
    instruments = _seed_instruments(args.seed_file) if args.check else store.instruments()
    instruments = [i for i in instruments if i["source"] in FETCHERS
                   and (args.source is None or i["source"] == args.source)]

    failures = 0
    for inst in instruments:
        try:
            ingest_instrument(store, inst, session, today, args.check)
        except Exception as exc:  # bir kaynağın hatası diğerlerini durdurmasın
            failures += 1
            log.error("  %s (%s) başarısız: %s", inst["symbol"], inst["source"], exc)
        time.sleep(PAUSE_SECONDS.get(inst["source"], 0))

    if not args.check:
        if args.analytics:
            run_analytics(store, today)
        if args.notify:
            res = store.invoke_function("send-alerts")
            log.info("bildirim: %s", res)

    log.info("bitti: %d enstrüman, %d hata", len(instruments), failures)
    # Hepsi başarısızsa CI kırmızı olsun (kaynak değişikliği / anahtar sorunu sinyali).
    return 1 if instruments and failures == len(instruments) else 0


def _seed_instruments(path: str) -> list[dict]:
    """seed.sql'deki VALUES satırlarından (symbol, source, source_code) çıkarır."""
    import re
    rows = []
    pattern = re.compile(r"\('(?P<symbol>[^']+)',\s*'[^']*',\s*'(?P<type>\w+)',\s*'\w+',\s*"
                         r"'(?P<source>\w+)',\s*(?:'(?P<code>[^']+)'|null)")
    with open(path, encoding="utf-8") as f:
        for i, m in enumerate(pattern.finditer(f.read())):
            rows.append({"id": i, "symbol": m["symbol"], "type": m["type"],
                         "source": m["source"], "source_code": m["code"]})
    return rows


if __name__ == "__main__":
    sys.exit(main())
