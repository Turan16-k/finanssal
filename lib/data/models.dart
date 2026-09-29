import 'package:quant_dart/quant_dart.dart' show TxnKind;

export 'package:quant_dart/quant_dart.dart' show TxnKind;

enum InstrumentType {
  fx,
  gold,
  fund,
  crypto,

  /// Veritabanında 'index' (Dart enum'larında `index` ayrılmış bir üye adı).
  stockIndex,
  stock,
  rate,
  inflation;

  String get dbName => this == stockIndex ? 'index' : name;

  static InstrumentType parse(Object? s) =>
      values.firstWhere((v) => v.dbName == s, orElse: () => InstrumentType.stock);
}

enum DataSource { evds, coingecko, manual }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

double? _toDouble(Object? v) => v == null ? null : (v as num).toDouble();

class Instrument {
  const Instrument({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.source,
    this.currency = 'TRY',
    this.meta = const {},
  });

  factory Instrument.fromJson(Map<String, dynamic> j) => Instrument(
        id: (j['id'] as num).toInt(),
        symbol: j['symbol'] as String,
        name: j['name'] as String,
        type: InstrumentType.parse(j['type']),
        source: _enumByName(DataSource.values, j['source'], DataSource.manual),
        currency: (j['currency'] as String?) ?? 'TRY',
        meta: (j['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  final int id;
  final String symbol;
  final String name;
  final InstrumentType type;
  final DataSource source;
  final String currency;
  final Map<String, dynamic> meta;

  /// Fiyatı kullanıcının girdiği (lisans gerektiren) enstrüman.
  bool get isManual => source == DataSource.manual;

  /// Analiz laboratuvarında kullanılabilir mi (günlük fiyat serisi var mı).
  bool get hasHistory => !isManual && type != InstrumentType.inflation && type != InstrumentType.rate;

  String? get attribution => meta['attribution'] as String?;

  @override
  bool operator ==(Object other) => other is Instrument && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Quote {
  const Quote({
    required this.instrumentId,
    required this.close,
    required this.asOf,
    this.prevClose,
    this.changePct,
  });

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        instrumentId: (j['instrument_id'] as num).toInt(),
        close: (j['close'] as num).toDouble(),
        prevClose: _toDouble(j['prev_close']),
        changePct: _toDouble(j['change_pct_1d']),
        asOf: DateTime.parse(j['as_of'] as String),
      );

  final int instrumentId;
  final double close;
  final double? prevClose;

  /// Yüzde (2.5 = %2,5).
  final double? changePct;
  final DateTime asOf;
}

class PricePoint {
  const PricePoint(this.date, this.close);

  factory PricePoint.fromJson(Map<String, dynamic> j) =>
      PricePoint(DateTime.parse(j['date'] as String), (j['close'] as num).toDouble());

  final DateTime date;
  final double close;
}

class InstrumentAnalytics {
  const InstrumentAnalytics({
    required this.date,
    this.hurst,
    this.regime,
    this.vol30d,
    this.vol1y,
    this.return1y,
    this.maxDd1y,
  });

  factory InstrumentAnalytics.fromJson(Map<String, dynamic> j) => InstrumentAnalytics(
        date: DateTime.parse(j['date'] as String),
        hurst: _toDouble(j['hurst']),
        regime: j['regime'] as String?,
        vol30d: _toDouble(j['vol_30d']),
        vol1y: _toDouble(j['vol_1y']),
        return1y: _toDouble(j['return_1y']),
        maxDd1y: _toDouble(j['max_dd_1y']),
      );

  final DateTime date;
  final double? hurst;
  final String? regime;
  final double? vol30d;
  final double? vol1y;
  final double? return1y;
  final double? maxDd1y;
}

class Portfolio {
  const Portfolio({required this.id, required this.name, this.baseCurrency = 'TRY', this.createdAt});

  factory Portfolio.fromJson(Map<String, dynamic> j) => Portfolio(
        id: j['id'] as String,
        name: j['name'] as String,
        baseCurrency: (j['base_currency'] as String?) ?? 'TRY',
        createdAt: j['created_at'] == null ? null : DateTime.parse(j['created_at'] as String),
      );

  final String id;
  final String name;
  final String baseCurrency;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base_currency': baseCurrency,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

class Txn {
  const Txn({
    required this.id,
    required this.portfolioId,
    required this.kind,
    required this.executedAt,
    this.instrumentId,
    this.quantity = 0,
    this.price = 0,
    this.fee = 0,
    this.currency = 'TRY',
    this.fxRate = 1,
    this.note,
  });

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        portfolioId: j['portfolio_id'] as String,
        instrumentId: (j['instrument_id'] as num?)?.toInt(),
        kind: _enumByName(TxnKind.values, j['kind'], TxnKind.buy),
        quantity: (j['quantity'] as num).toDouble(),
        price: (j['price'] as num).toDouble(),
        fee: (j['fee'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? 'TRY',
        fxRate: (j['fx_rate'] as num?)?.toDouble() ?? 1,
        executedAt: DateTime.parse(j['executed_at'] as String),
        note: j['note'] as String?,
      );

  final String id;
  final String portfolioId;
  final int? instrumentId;
  final TxnKind kind;
  final double quantity;
  final double price;
  final double fee;
  final String currency;
  final double fxRate;
  final DateTime executedAt;
  final String? note;

  /// Sunucuya gönderim için (id ve user_id sunucuda üretilir).
  Map<String, dynamic> toInsertJson() => {
        'portfolio_id': portfolioId,
        'instrument_id': instrumentId,
        'kind': kind.name,
        'quantity': quantity,
        'price': price,
        'fee': fee,
        'currency': currency,
        'fx_rate': fxRate,
        'executed_at': executedAt.toUtc().toIso8601String(),
        'note': note,
      };

  Map<String, dynamic> toJson() => {'id': id, ...toInsertJson()};
}

enum AlertCondition { above, below, pctChangeUp, pctChangeDown }

extension AlertConditionDb on AlertCondition {
  String get dbName => switch (this) {
        AlertCondition.above => 'above',
        AlertCondition.below => 'below',
        AlertCondition.pctChangeUp => 'pct_change_up',
        AlertCondition.pctChangeDown => 'pct_change_down',
      };

  static AlertCondition parse(String s) =>
      AlertCondition.values.firstWhere((c) => c.dbName == s, orElse: () => AlertCondition.above);
}

class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.instrumentId,
    required this.condition,
    required this.threshold,
    required this.isActive,
    this.lastTriggeredAt,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> j) => PriceAlert(
        id: j['id'] as String,
        instrumentId: (j['instrument_id'] as num).toInt(),
        condition: AlertConditionDb.parse(j['condition'] as String),
        threshold: (j['threshold'] as num).toDouble(),
        isActive: j['is_active'] as bool,
        lastTriggeredAt:
            j['last_triggered_at'] == null ? null : DateTime.parse(j['last_triggered_at'] as String),
      );

  final String id;
  final int instrumentId;
  final AlertCondition condition;
  final double threshold;
  final bool isActive;
  final DateTime? lastTriggeredAt;
}
