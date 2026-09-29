-- Başlangıç enstrümanları. Otomatik kaynaklar lisans gerektirmez (bkz. docs/architecture.md §3).
-- source=manual: fiyatı kullanıcı girer (BIST hisseleri: lisans; fonlar: TEFAS'ın API'si yok).
-- EVDS seri kodları `python -m pipelines.ingest --check` ile doğrulanmalıdır.
insert into public.instruments (symbol, name, type, currency, source, source_code, meta) values
  -- Döviz (TCMB döviz satış kuru)
  ('USDTRY',  'ABD Doları / TL',        'fx',        'TRY', 'evds', 'TP.DK.USD.S.YTL', '{"attribution":"TCMB EVDS"}'),
  ('EURTRY',  'Euro / TL',              'fx',        'TRY', 'evds', 'TP.DK.EUR.S.YTL', '{"attribution":"TCMB EVDS"}'),
  ('GBPTRY',  'İngiliz Sterlini / TL',  'fx',        'TRY', 'evds', 'TP.DK.GBP.S.YTL', '{"attribution":"TCMB EVDS"}'),
  ('CHFTRY',  'İsviçre Frangı / TL',    'fx',        'TRY', 'evds', 'TP.DK.CHF.S.YTL', '{"attribution":"TCMB EVDS"}'),
  -- Altın (TL/gram külçe)
  ('XAUTRYG', 'Gram Altın (külçe)',     'gold',      'TRY', 'evds', 'TP.MK.KUL.YTL',   '{"attribution":"TCMB EVDS","unit":"gram"}'),
  -- Endeks
  ('XU100',   'BIST 100 Endeksi',       'index',     'TRY', 'evds', 'TP.MK.F.BILESIK', '{"attribution":"TCMB EVDS"}'),
  -- Makro (aylık)
  ('TUFE',    'TÜFE (2003=100)',        'inflation', 'TRY', 'evds', 'TP.FG.J0',        '{"attribution":"TCMB EVDS","frequency":"monthly"}'),
  -- Kripto (TL karşılığı)
  ('BTC',     'Bitcoin',                'crypto',    'TRY', 'coingecko', 'bitcoin',    '{"attribution":"CoinGecko"}'),
  ('ETH',     'Ethereum',               'crypto',    'TRY', 'coingecko', 'ethereum',   '{"attribution":"CoinGecko"}'),
  ('SOL',     'Solana',                 'crypto',    'TRY', 'coingecko', 'solana',     '{"attribution":"CoinGecko"}'),
  -- Yatırım fonları (TEFAS fon kodu meta'da; fiyat manuel).
  ('TTE',     'İş Portföy BIST Teknoloji Ağırlık Sınırlamalı Endeks Hisse Senedi Fonu', 'fund', 'TRY', 'manual', null, '{"tefas_code":"TTE"}'),
  ('AFT',     'Ak Portföy Yeni Teknolojiler Yabancı Hisse Senedi Fonu', 'fund', 'TRY', 'manual', null, '{"tefas_code":"AFT"}'),
  ('IPB',     'İş Portföy Para Piyasası Fonu', 'fund', 'TRY', 'manual', null, '{"tefas_code":"IPB"}'),
  -- BIST hisseleri: fiyat yayınlanmaz, kullanıcı girer (manual_prices).
  ('THYAO',   'Türk Hava Yolları',      'stock',     'TRY', 'manual', null, '{}'),
  ('GARAN',   'Garanti BBVA',           'stock',     'TRY', 'manual', null, '{}'),
  ('ASELS',   'Aselsan',                'stock',     'TRY', 'manual', null, '{}'),
  ('EREGL',   'Ereğli Demir Çelik',     'stock',     'TRY', 'manual', null, '{}'),
  ('BIMAS',   'BİM Birleşik Mağazalar', 'stock',     'TRY', 'manual', null, '{}'),
  ('KCHOL',   'Koç Holding',            'stock',     'TRY', 'manual', null, '{}'),
  ('SISE',    'Şişecam',                'stock',     'TRY', 'manual', null, '{}'),
  ('TUPRS',   'Tüpraş',                 'stock',     'TRY', 'manual', null, '{}')
on conflict (symbol) do nothing;
