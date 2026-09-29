"""Supabase şemasını gömülü bir Postgres'te (pgserver) uygular ve RLS/RPC davranışını test eder.

Docker veya Supabase CLI gerektirmez. Supabase'in `auth` şeması ve rolleri minimal
bir taklitle kurulur; `auth.uid()` JWT yerine `request.jwt.claim.sub` ayarından okunur.

    pip install -r pipelines/requirements-dev.txt
    python -m pytest supabase/tests -q
"""
from __future__ import annotations

import shutil
import tempfile
import uuid
from datetime import date, timedelta
from pathlib import Path

import psycopg
import pytest

pgserver = pytest.importorskip("pgserver")

ROOT = Path(__file__).resolve().parents[1]

SUPABASE_STUB = """
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema public, auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
"""

# Supabase projelerindeki varsayılan tablo yetkileri (erişimi RLS belirler).
SUPABASE_GRANTS = """
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
"""


@pytest.fixture(scope="module")
def db():
    tmp = tempfile.mkdtemp(prefix="fraktal_pg_")
    srv = pgserver.get_server(tmp, cleanup_mode="stop")
    dbname = f"t_{uuid.uuid4().hex[:8]}"
    srv.psql(f"create database {dbname};")
    uri = srv.get_uri(dbname)
    with psycopg.connect(uri, autocommit=True) as conn:
        conn.execute(SUPABASE_STUB)
        for m in sorted((ROOT / "migrations").glob("*.sql")):
            conn.execute(m.read_text())
        conn.execute(SUPABASE_GRANTS)
        conn.execute((ROOT / "seed.sql").read_text())
        yield conn
    srv.cleanup()
    shutil.rmtree(tmp, ignore_errors=True)


def new_user(conn) -> str:
    return str(conn.execute("insert into auth.users default values returning id").fetchone()[0])


class As:
    """`with As(conn, role, uid):` bloğu içinde sorgular o kullanıcı olarak çalışır."""

    def __init__(self, conn, role: str, uid: str | None = None):
        self.conn, self.role, self.uid = conn, role, uid

    def __enter__(self):
        self.conn.execute(f"set role {self.role}")
        self.conn.execute("select set_config('request.jwt.claim.sub', %s, false)", (self.uid or "",))
        return self.conn

    def __exit__(self, *exc):
        self.conn.execute("reset role")
        self.conn.execute("select set_config('request.jwt.claim.sub', '', false)")


def instrument_id(conn, symbol: str) -> int:
    return conn.execute("select id from instruments where symbol = %s", (symbol,)).fetchone()[0]


# --------------------------------------------------------------------------- #

def test_seed_loaded(db):
    n = db.execute("select count(*) from instruments").fetchone()[0]
    assert n >= 20
    manual = db.execute("select count(*) from instruments where source = 'manual'").fetchone()[0]
    assert manual >= 8


def test_profile_created_on_signup(db):
    uid = new_user(db)
    assert db.execute("select 1 from profiles where id = %s", (uid,)).fetchone()


def test_anon_reads_market_but_cannot_write(db):
    with As(db, "anon"):
        assert db.execute("select count(*) from instruments").fetchone()[0] > 0
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute("insert into instruments (symbol, name, type, source) "
                       "values ('X', 'X', 'stock', 'manual')")


def test_anon_cannot_read_user_data(db):
    a = new_user(db)
    with As(db, "authenticated", a):
        db.execute("insert into portfolios (name) values ('gizli')")
    with As(db, "anon"):
        assert db.execute("select count(*) from portfolios").fetchone()[0] == 0


def test_rls_isolates_users(db):
    a, b = new_user(db), new_user(db)
    thyao = instrument_id(db, "THYAO")
    with As(db, "authenticated", a):
        pid = db.execute("insert into portfolios (name) values ('A portföy') returning id").fetchone()[0]
        db.execute("insert into transactions (portfolio_id, instrument_id, kind, quantity, price, executed_at)"
                   " values (%s, %s, 'buy', 10, 300, now())", (pid, thyao))
    with As(db, "authenticated", b):
        assert db.execute("select count(*) from portfolios where id = %s", (pid,)).fetchone()[0] == 0
        assert db.execute("select count(*) from transactions where portfolio_id = %s", (pid,)).fetchone()[0] == 0
        # B, A'nın portföyüne işlem ekleyemez (bileşik FK: portfolio_id + user_id).
        with pytest.raises(psycopg.errors.ForeignKeyViolation):
            db.execute("insert into transactions (portfolio_id, instrument_id, kind, quantity, price, executed_at)"
                       " values (%s, %s, 'buy', 1, 1, now())", (pid, thyao))
        # user_id'yi A olarak sahtelemek RLS ile engellenir.
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute("insert into portfolios (user_id, name) values (%s, 'sahte')", (a,))
        # A'nın satırını güncellemek sessizce 0 satır etkiler.
        cur = db.execute("update portfolios set name = 'ele geçirildi' where id = %s", (pid,))
        assert cur.rowcount == 0


def test_transaction_requires_instrument_for_trades(db):
    a = new_user(db)
    with As(db, "authenticated", a):
        pid = db.execute("insert into portfolios (name) values ('p') returning id").fetchone()[0]
        with pytest.raises(psycopg.errors.CheckViolation):
            db.execute("insert into transactions (portfolio_id, kind, quantity, price, executed_at)"
                       " values (%s, 'buy', 1, 1, now())", (pid,))
        db.execute("insert into transactions (portfolio_id, kind, price, executed_at)"
                   " values (%s, 'deposit', 1000, now())", (pid,))


def test_row_limit(db):
    a = new_user(db)
    with As(db, "authenticated", a):
        for i in range(10):
            db.execute("insert into watchlists (name) values (%s)", (f"l{i}",))
        with pytest.raises(psycopg.errors.RaiseException, match="sınır"):
            db.execute("insert into watchlists (name) values ('fazla')")


def test_register_device_takes_over_token(db):
    a, b = new_user(db), new_user(db)
    with As(db, "authenticated", a):
        db.execute("select register_device('tok-1', 'ios')")
    with As(db, "authenticated", b):
        db.execute("select register_device('tok-1', 'ios')")
        assert db.execute("select count(*) from devices").fetchone()[0] == 1
    with As(db, "authenticated", a):
        assert db.execute("select count(*) from devices").fetchone()[0] == 0


def test_delete_my_account_cascades(db):
    a = new_user(db)
    with As(db, "authenticated", a):
        pid = db.execute("insert into portfolios (name) values ('silinecek') returning id").fetchone()[0]
        db.execute("insert into alerts (instrument_id, condition, threshold) values (%s, 'above', 1)",
                   (instrument_id(db, "USDTRY"),))
        db.execute("select delete_my_account()")
    assert db.execute("select count(*) from auth.users where id = %s", (a,)).fetchone()[0] == 0
    assert db.execute("select count(*) from portfolios where id = %s", (pid,)).fetchone()[0] == 0
    assert db.execute("select count(*) from alerts where user_id = %s", (a,)).fetchone()[0] == 0


def test_delete_my_account_requires_session(db):
    with As(db, "anon"):
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute("select delete_my_account()")


def test_privileged_rpcs_not_callable_by_users(db):
    a = new_user(db)
    with As(db, "authenticated", a):
        for sql in ("select * from claim_triggered_alerts()",
                    f"select consume_ai_quota('{a}', 10)"):
            with pytest.raises(psycopg.errors.InsufficientPrivilege):
                db.execute(sql)


def test_ai_quota(db):
    a = new_user(db)
    results = [db.execute("select consume_ai_quota(%s, 3)", (a,)).fetchone()[0] for _ in range(5)]
    assert results == [True, True, True, False, False]
    assert db.execute("select count from ai_usage where user_id = %s", (a,)).fetchone()[0] == 3


def test_claim_triggered_alerts(db):
    a = new_user(db)
    usd = instrument_id(db, "USDTRY")
    db.execute("insert into quotes_latest (instrument_id, close, prev_close, change_pct_1d, as_of)"
               " values (%s, 42.0, 41.0, 2.44, current_date)"
               " on conflict (instrument_id) do update set close = excluded.close,"
               " change_pct_1d = excluded.change_pct_1d, as_of = excluded.as_of", (usd,))
    with As(db, "authenticated", a):
        db.execute("select register_device('tok-alert', 'android')")
        db.execute("insert into alerts (instrument_id, condition, threshold) values (%s, 'above', 41.5)", (usd,))
        db.execute("insert into alerts (instrument_id, condition, threshold) values (%s, 'below', 30)", (usd,))
        db.execute("insert into alerts (instrument_id, condition, threshold, one_shot)"
                   " values (%s, 'pct_change_up', 2, false)", (usd,))
    rows = db.execute("select symbol, condition::text, fcm_token from claim_triggered_alerts()"
                      " where user_id = %s order by condition", (a,)).fetchall()
    assert rows == [("USDTRY", "above", "tok-alert"), ("USDTRY", "pct_change_up", "tok-alert")]
    # Aynı gün tekrar tetiklenmez; tek seferlik olan pasifleşir, tekrarlı olan aktif kalır.
    again = db.execute("select * from claim_triggered_alerts() where user_id = %s", (a,)).fetchall()
    assert again == []
    active = db.execute("select condition::text, is_active from alerts where user_id = %s"
                        " order by condition", (a,)).fetchall()
    assert active == [("above", False), ("below", True), ("pct_change_up", True)]


def test_price_history_downsamples(db):
    eth = instrument_id(db, "ETH")
    start = date(2024, 1, 1)
    with db.cursor() as cur:
        cur.executemany("insert into prices_daily (instrument_id, date, close) values (%s, %s, %s)",
                        [(eth, start + timedelta(days=i), 100 + i) for i in range(1000)])
    with As(db, "anon"):
        rows = db.execute("select * from price_history(%s, %s, 100)", (eth, start)).fetchall()
        assert 100 <= len(rows) <= 101
        assert rows[0][0] == start and rows[-1][0] == start + timedelta(days=999)
        full = db.execute("select count(*) from price_history(%s, %s, 5000)", (eth, start)).fetchone()[0]
        assert full == 1000
