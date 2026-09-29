import 'dart:math' as math;

import 'package:quant_dart/quant_dart.dart' show syntheticPrices;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Piyasa verisi (yalnızca okuma). Kaynaklar: TCMB EVDS, CoinGecko (pipelines/ ile yüklenir).
abstract interface class MarketRepository {
  bool get isDemo;
  Future<List<Instrument>> instruments();
  Future<Map<int, Quote>> quotes();
  Future<List<PricePoint>> history(int instrumentId, DateTime from, {int maxPoints = 400});
  Future<InstrumentAnalytics?> analytics(int instrumentId);
}

class SupabaseMarketRepository implements MarketRepository {
  SupabaseMarketRepository(this._db);
  final SupabaseClient _db;

  @override
  bool get isDemo => false;

  @override
  Future<List<Instrument>> instruments() async {
    final rows = await _db
        .from('instruments')
        .select('id,symbol,name,type,currency,source,meta')
        .eq('is_active', true)
        .order('type')
        .order('symbol');
    return rows.map(Instrument.fromJson).toList();
  }

  @override
  Future<Map<int, Quote>> quotes() async {
    final rows = await _db.from('quotes_latest').select();
    return {for (final r in rows) (r['instrument_id'] as num).toInt(): Quote.fromJson(r)};
  }

  @override
  Future<List<PricePoint>> history(int instrumentId, DateTime from, {int maxPoints = 400}) async {
    final rows = await _db.rpc('price_history', params: {
      'p_instrument': instrumentId,
      'p_from': from.toIso8601String().substring(0, 10),
      'p_max_points': maxPoints,
    }) as List<dynamic>;
    return rows.cast<Map<String, dynamic>>().map(PricePoint.fromJson).toList();
  }

  @override
  Future<InstrumentAnalytics?> analytics(int instrumentId) async {
    final row = await _db
        .from('analytics_daily')
        .select()
        .eq('instrument_id', instrumentId)
        .order('date', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : InstrumentAnalytics.fromJson(row);
  }
}

/// Arka uç yokken kullanılan sentetik (FBM) piyasa verisi. Değerler gerçek değildir;
/// arayüz bunu "Demo verisi" etiketiyle belirtir.
class DemoMarketRepository implements MarketRepository {
  DemoMarketRepository({DateTime? today}) : _today = today ?? DateTime.now();

  final DateTime _today;
  final _cache = <int, List<PricePoint>>{};

  static const _specs = <(int, String, String, InstrumentType, DataSource, double, double, double, double)>[
    // id, sembol, ad, tür, kaynak, son seviye, yıllık drift, yıllık vol, Hurst
    (1, 'USDTRY', 'ABD Doları / TL', InstrumentType.fx, DataSource.evds, 41.5, 0.30, 0.10, 0.62),
    (2, 'EURTRY', 'Euro / TL', InstrumentType.fx, DataSource.evds, 48.6, 0.32, 0.12, 0.60),
    (3, 'GBPTRY', 'İngiliz Sterlini / TL', InstrumentType.fx, DataSource.evds, 55.8, 0.31, 0.13, 0.58),
    (4, 'CHFTRY', 'İsviçre Frangı / TL', InstrumentType.fx, DataSource.evds, 52.0, 0.33, 0.12, 0.57),
    (5, 'XAUTRYG', 'Gram Altın (külçe)', InstrumentType.gold, DataSource.evds, 4850, 0.45, 0.18, 0.58),
    (6, 'XU100', 'BIST 100 Endeksi', InstrumentType.stockIndex, DataSource.evds, 10400, 0.35, 0.26, 0.55),
    (8, 'BTC', 'Bitcoin', InstrumentType.crypto, DataSource.coingecko, 4.1e6, 0.60, 0.55, 0.60),
    (9, 'ETH', 'Ethereum', InstrumentType.crypto, DataSource.coingecko, 1.3e5, 0.55, 0.70, 0.57),
    (10, 'SOL', 'Solana', InstrumentType.crypto, DataSource.coingecko, 5.9e3, 0.70, 0.90, 0.55),
    (11, 'TTE', 'İş Portföy BIST Teknoloji Endeks Fonu', InstrumentType.fund, DataSource.manual, 0, 0, 0, 0),
    (12, 'AFT', 'Ak Portföy Yeni Teknolojiler Fonu', InstrumentType.fund, DataSource.manual, 0, 0, 0, 0),
    (14, 'THYAO', 'Türk Hava Yolları', InstrumentType.stock, DataSource.manual, 0, 0, 0, 0),
    (15, 'GARAN', 'Garanti BBVA', InstrumentType.stock, DataSource.manual, 0, 0, 0, 0),
    (16, 'ASELS', 'Aselsan', InstrumentType.stock, DataSource.manual, 0, 0, 0, 0),
    (17, 'EREGL', 'Ereğli Demir Çelik', InstrumentType.stock, DataSource.manual, 0, 0, 0, 0),
    (18, 'BIMAS', 'BİM Birleşik Mağazalar', InstrumentType.stock, DataSource.manual, 0, 0, 0, 0),
  ];

  @override
  bool get isDemo => true;

  @override
  Future<List<Instrument>> instruments() async => [
        for (final s in _specs)
          Instrument(
            id: s.$1,
            symbol: s.$2,
            name: s.$3,
            type: s.$4,
            source: s.$5,
            meta: const {'attribution': 'Demo verisi'},
          ),
      ];

  List<PricePoint> _series(int id) => _cache.putIfAbsent(id, () {
        final s = _specs.firstWhere((x) => x.$1 == id);
        if (s.$5 == DataSource.manual) return const [];
        const days = 5 * 252;
        final raw = syntheticPrices(days, mu: s.$7, sigma: s.$8, hurst: s.$9, seed: id);
        final scale = s.$6 / raw.last;
        final dates = _businessDays(days);
        return [for (var i = 0; i < days; i++) PricePoint(dates[i], raw[i] * scale)];
      });

  List<DateTime> _businessDays(int n) {
    final out = <DateTime>[];
    var d = DateTime(_today.year, _today.month, _today.day);
    while (out.length < n) {
      if (d.weekday <= DateTime.friday) out.add(d);
      d = d.subtract(const Duration(days: 1));
    }
    return out.reversed.toList();
  }

  @override
  Future<Map<int, Quote>> quotes() async {
    final out = <int, Quote>{};
    for (final s in _specs) {
      final series = _series(s.$1);
      if (series.length < 2) continue;
      final last = series.last, prev = series[series.length - 2];
      out[s.$1] = Quote(
        instrumentId: s.$1,
        close: last.close,
        prevClose: prev.close,
        changePct: (last.close / prev.close - 1) * 100,
        asOf: last.date,
      );
    }
    return out;
  }

  @override
  Future<List<PricePoint>> history(int instrumentId, DateTime from, {int maxPoints = 400}) async {
    final s = _series(instrumentId).where((p) => !p.date.isBefore(from)).toList();
    if (s.length <= maxPoints) return s;
    final step = (s.length / maxPoints).ceil();
    return [
      for (var i = 0; i < s.length; i += step) s[i],
      if ((s.length - 1) % step != 0) s.last,
    ];
  }

  @override
  Future<InstrumentAnalytics?> analytics(int instrumentId) async {
    final s = _series(instrumentId);
    if (s.length < 300) return null;
    final spec = _specs.firstWhere((x) => x.$1 == instrumentId);
    final year = s.sublist(s.length - 253);
    var peak = year.first.close, mdd = 0.0;
    for (final p in year) {
      peak = math.max(peak, p.close);
      mdd = math.max(mdd, 1 - p.close / peak);
    }
    return InstrumentAnalytics(
      date: s.last.date,
      hurst: spec.$9,
      regime: spec.$9 > 0.55 ? 'trending' : 'random_walk',
      vol1y: spec.$8,
      vol30d: spec.$8,
      return1y: year.last.close / year.first.close - 1,
      maxDd1y: mdd,
    );
  }
}
