-- =============================================================================
-- Fraktal — başlangıç şeması
--   * Piyasa verisi (instruments, prices_daily, quotes_latest, analytics_daily, news):
--     herkes okur, yalnızca service_role (pipelines/) yazar.
--   * Kullanıcı verisi: RLS ile yalnızca sahibi okur/yazar.
--   * Hesap silme: auth.users silinince tüm kullanıcı verisi CASCADE ile silinir.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipler
-- ---------------------------------------------------------------------------
create type public.instrument_type as enum
  ('fx', 'gold', 'fund', 'crypto', 'index', 'stock', 'rate', 'inflation');

create type public.data_source as enum ('evds', 'coingecko', 'manual');

create type public.tx_kind as enum
  ('buy', 'sell', 'dividend', 'fee', 'deposit', 'withdraw');

create type public.alert_condition as enum ('above', 'below', 'pct_change_up', 'pct_change_down');

-- ---------------------------------------------------------------------------
-- Piyasa verisi
-- ---------------------------------------------------------------------------
create table public.instruments (
  id           bigint generated always as identity primary key,
  symbol       text not null unique,
  name         text not null,
  type         public.instrument_type not null,
  currency     text not null default 'TRY',
  source       public.data_source not null,
  -- Kaynaktaki kimlik: EVDS seri kodu, CoinGecko id. manual için null.
  source_code  text,
  is_active    boolean not null default true,
  meta         jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  constraint instruments_source_code_chk
    check (source = 'manual' or source_code is not null)
);
comment on table public.instruments is
  'Takip edilen enstrümanlar. source=manual olanların (BIST hisseleri, fonlar) fiyatını kullanıcı girer.';

create table public.prices_daily (
  instrument_id bigint not null references public.instruments(id) on delete cascade,
  date          date not null,
  close         double precision not null check (close > 0),
  primary key (instrument_id, date)
);

create table public.quotes_latest (
  instrument_id  bigint primary key references public.instruments(id) on delete cascade,
  close          double precision not null,
  prev_close     double precision,
  change_pct_1d  double precision,
  as_of          date not null,
  updated_at     timestamptz not null default now()
);

create table public.analytics_daily (
  instrument_id bigint not null references public.instruments(id) on delete cascade,
  date          date not null,
  hurst         double precision,
  regime        text,
  vol_30d       double precision,
  vol_1y        double precision,
  return_1y     double precision,
  max_dd_1y     double precision,
  primary key (instrument_id, date)
);

create table public.news (
  id              bigint generated always as identity primary key,
  source          text not null,
  title           text not null,
  url             text not null unique,
  published_at    timestamptz not null,
  summary_tr      text,
  sentiment       double precision check (sentiment between -1 and 1),
  instrument_ids  bigint[] not null default '{}',
  created_at      timestamptz not null default now()
);
create index news_published_idx on public.news (published_at desc);

-- ---------------------------------------------------------------------------
-- Kullanıcı verisi
-- ---------------------------------------------------------------------------
create table public.profiles (
  id                      uuid primary key references auth.users(id) on delete cascade,
  display_name            text,
  base_currency           text not null default 'TRY',
  locale                  text not null default 'tr',
  disclaimer_accepted_at  timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create table public.portfolios (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name           text not null check (char_length(name) between 1 and 60),
  base_currency  text not null default 'TRY',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  -- İşlemlerin aynı kullanıcıya ait portföye bağlanmasını FK ile garanti etmek için.
  unique (id, user_id)
);
create index portfolios_user_idx on public.portfolios (user_id);

create table public.transactions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  portfolio_id   uuid not null,
  instrument_id  bigint references public.instruments(id),
  kind           public.tx_kind not null,
  quantity       double precision not null default 0 check (quantity >= 0),
  price          double precision not null default 0 check (price >= 0),
  fee            double precision not null default 0 check (fee >= 0),
  currency       text not null default 'TRY',
  -- İşlem para birimi -> portföy para birimi kuru (TRY portföyde TRY işlem için 1).
  fx_rate        double precision not null default 1 check (fx_rate > 0),
  executed_at    timestamptz not null,
  note           text check (char_length(note) <= 500),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  foreign key (portfolio_id, user_id) references public.portfolios(id, user_id) on delete cascade,
  constraint transactions_instrument_chk
    check (kind in ('deposit', 'withdraw', 'fee') or instrument_id is not null)
);
create index transactions_portfolio_idx on public.transactions (portfolio_id, executed_at);
create index transactions_user_updated_idx on public.transactions (user_id, updated_at);

-- BIST hisseleri gibi lisans gerektiren enstrümanlar için kullanıcının kendi girdiği fiyat.
create table public.manual_prices (
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  instrument_id  bigint not null references public.instruments(id) on delete cascade,
  price          double precision not null check (price > 0),
  as_of          timestamptz not null default now(),
  primary key (user_id, instrument_id)
);

-- Kullanıcının eklediği özel enstrümanlar (ör. listede olmayan bir hisse).
create table public.user_instruments (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  symbol      text not null check (char_length(symbol) between 1 and 20),
  name        text not null,
  type        public.instrument_type not null default 'stock',
  currency    text not null default 'TRY',
  created_at  timestamptz not null default now(),
  unique (user_id, symbol)
);

create table public.watchlists (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 60),
  created_at  timestamptz not null default now(),
  unique (id, user_id)
);

create table public.watchlist_items (
  watchlist_id   uuid not null,
  user_id        uuid not null default auth.uid(),
  instrument_id  bigint not null references public.instruments(id) on delete cascade,
  sort           int not null default 0,
  primary key (watchlist_id, instrument_id),
  foreign key (watchlist_id, user_id) references public.watchlists(id, user_id) on delete cascade
);

create table public.alerts (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null default auth.uid() references auth.users(id) on delete cascade,
  instrument_id      bigint not null references public.instruments(id) on delete cascade,
  condition          public.alert_condition not null,
  threshold          double precision not null,
  is_active          boolean not null default true,
  -- true: tetiklenince pasifleşir; false: her yeni veride tekrar değerlendirilir.
  one_shot           boolean not null default true,
  last_triggered_at  timestamptz,
  created_at         timestamptz not null default now()
);
create index alerts_active_idx on public.alerts (instrument_id) where is_active;

create table public.devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  fcm_token   text not null unique,
  platform    text not null check (platform in ('ios', 'android')),
  locale      text not null default 'tr',
  updated_at  timestamptz not null default now()
);
create index devices_user_idx on public.devices (user_id);

create table public.saved_simulations (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  portfolio_id  uuid references public.portfolios(id) on delete set null,
  kind          text not null check (kind in ('montecarlo', 'optimize', 'backtest')),
  params        jsonb not null,
  result        jsonb not null,
  created_at    timestamptz not null default now()
);
create index saved_simulations_user_idx on public.saved_simulations (user_id, created_at desc);

-- AI kotası (Edge Function service_role ile yazar).
create table public.ai_usage (
  user_id  uuid not null references auth.users(id) on delete cascade,
  day      date not null default current_date,
  count    int not null default 0,
  primary key (user_id, day)
);

-- ---------------------------------------------------------------------------
-- updated_at tetikleyicisi
-- ---------------------------------------------------------------------------
create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
create trigger portfolios_touch before update on public.portfolios
  for each row execute function public.touch_updated_at();
create trigger transactions_touch before update on public.transactions
  for each row execute function public.touch_updated_at();

-- Yeni kullanıcıya profil satırı (anonim girişler dahil).
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.instruments      enable row level security;
alter table public.prices_daily     enable row level security;
alter table public.quotes_latest    enable row level security;
alter table public.analytics_daily  enable row level security;
alter table public.news             enable row level security;
alter table public.profiles         enable row level security;
alter table public.portfolios       enable row level security;
alter table public.transactions     enable row level security;
alter table public.manual_prices    enable row level security;
alter table public.user_instruments enable row level security;
alter table public.watchlists       enable row level security;
alter table public.watchlist_items  enable row level security;
alter table public.alerts           enable row level security;
alter table public.devices          enable row level security;
alter table public.saved_simulations enable row level security;
alter table public.ai_usage         enable row level security;

-- Piyasa verisi: herkese okuma. Yazma politikası yok -> yalnızca service_role (RLS'yi atlar).
create policy "market read" on public.instruments     for select to anon, authenticated using (true);
create policy "market read" on public.prices_daily    for select to anon, authenticated using (true);
create policy "market read" on public.quotes_latest   for select to anon, authenticated using (true);
create policy "market read" on public.analytics_daily for select to anon, authenticated using (true);
create policy "market read" on public.news            for select to anon, authenticated using (true);

-- Profil: yalnızca kendi satırı (insert tetikleyiciyle yapılır).
create policy "own profile read" on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy "own profile update" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Sahiplik politikaları (user_id = auth.uid()).
do $$
declare t text;
begin
  foreach t in array array['portfolios', 'transactions', 'manual_prices', 'user_instruments',
                           'watchlists', 'watchlist_items', 'alerts', 'devices',
                           'saved_simulations']
  loop
    execute format(
      'create policy "own rows" on public.%I for all to authenticated
         using (user_id = (select auth.uid()))
         with check (user_id = (select auth.uid()))', t);
  end loop;
end $$;

-- Kötüye kullanım sınırları (ücretsiz katmanı korumak için).
create function public.enforce_row_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  lim int := tg_argv[0]::int;
  n   int;
begin
  execute format('select count(*) from public.%I where user_id = $1', tg_table_name)
    into n using new.user_id;
  if n >= lim then
    raise exception 'Kayıt sınırına ulaşıldı (% en fazla %)', tg_table_name, lim
      using errcode = 'P0001';
  end if;
  return new;
end $$;

create trigger portfolios_limit   before insert on public.portfolios
  for each row execute function public.enforce_row_limit('20');
create trigger transactions_limit before insert on public.transactions
  for each row execute function public.enforce_row_limit('10000');
create trigger alerts_limit       before insert on public.alerts
  for each row execute function public.enforce_row_limit('50');
create trigger watchlists_limit   before insert on public.watchlists
  for each row execute function public.enforce_row_limit('10');
create trigger devices_limit      before insert on public.devices
  for each row execute function public.enforce_row_limit('10');
create trigger simulations_limit  before insert on public.saved_simulations
  for each row execute function public.enforce_row_limit('100');

-- ---------------------------------------------------------------------------
-- RPC'ler
-- ---------------------------------------------------------------------------

-- Uygulama içi hesap silme (App Store 5.1.1(v) ve Google Play zorunluluğu).
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Oturum yok' using errcode = '28000';
  end if;
  delete from auth.users where id = uid;  -- tüm kullanıcı tabloları CASCADE
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Aynı FCM token başka kullanıcıdaysa devralır (cihazda hesap değişimi).
create function public.register_device(p_token text, p_platform text, p_locale text default 'tr')
returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Oturum yok' using errcode = '28000';
  end if;
  insert into public.devices (user_id, fcm_token, platform, locale)
  values (uid, p_token, p_platform, p_locale)
  on conflict (fcm_token) do update
    set user_id = excluded.user_id, platform = excluded.platform,
        locale = excluded.locale, updated_at = now();
end $$;
revoke all on function public.register_device(text, text, text) from public, anon;
grant execute on function public.register_device(text, text, text) to authenticated;

-- AI kotası: kullanılabiliyorsa sayacı artırıp true döner. Yalnızca service_role çağırır.
create function public.consume_ai_quota(p_user uuid, p_daily_limit int) returns boolean
language plpgsql security definer set search_path = '' as $$
declare used int;
begin
  insert into public.ai_usage (user_id, day, count) values (p_user, current_date, 1)
  on conflict (user_id, day) do update set count = public.ai_usage.count + 1
  returning count into used;
  if used > p_daily_limit then
    update public.ai_usage set count = count - 1 where user_id = p_user and day = current_date;
    return false;
  end if;
  return true;
end $$;
revoke all on function public.consume_ai_quota(uuid, int) from public, anon, authenticated;

-- Tetiklenen alarmlar + bildirim gönderilecek cihazlar. send-alerts Edge Function kullanır.
create function public.claim_triggered_alerts()
returns table (alert_id uuid, user_id uuid, symbol text, name text, condition public.alert_condition,
               threshold double precision, close double precision, change_pct double precision,
               fcm_token text, locale text)
language sql security definer set search_path = '' as $$
  with hit as (
    select a.id, a.user_id, a.one_shot, i.symbol, i.name, a.condition, a.threshold,
           q.close, q.change_pct_1d
    from public.alerts a
    join public.quotes_latest q on q.instrument_id = a.instrument_id
    join public.instruments i on i.id = a.instrument_id
    where a.is_active
      and (a.last_triggered_at is null or a.last_triggered_at::date < q.as_of)
      and case a.condition
            when 'above' then q.close >= a.threshold
            when 'below' then q.close <= a.threshold
            when 'pct_change_up' then q.change_pct_1d >= a.threshold
            when 'pct_change_down' then q.change_pct_1d <= -abs(a.threshold)
          end
  ),
  upd as (
    update public.alerts a
       set last_triggered_at = now(),
           is_active = not hit.one_shot
      from hit
     where a.id = hit.id
    returning a.id
  )
  select hit.id, hit.user_id, hit.symbol, hit.name, hit.condition, hit.threshold,
         hit.close, hit.change_pct_1d, d.fcm_token, d.locale
  from hit
  join upd on upd.id = hit.id
  join public.devices d on d.user_id = hit.user_id;
$$;
revoke all on function public.claim_triggered_alerts() from public, anon, authenticated;

-- Grafik için seyreltilmiş fiyat serisi (uzun aralıklarda veri trafiğini azaltır).
create function public.price_history(p_instrument bigint, p_from date, p_max_points int default 400)
returns table (date date, close double precision)
language sql stable set search_path = '' as $$
  with s as (
    select p.date, p.close, row_number() over (order by p.date) as rn, count(*) over () as n
    from public.prices_daily p
    where p.instrument_id = p_instrument and p.date >= p_from
  )
  select s.date, s.close from s
  where s.n <= p_max_points
     or (s.rn - 1) % ceil(s.n::numeric / p_max_points)::int = 0
     or s.rn = s.n
  order by s.date;
$$;
grant execute on function public.price_history(bigint, date, int) to anon, authenticated;
