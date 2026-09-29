/// Portföy defteri: işlemlerden pozisyon, ağırlıklı ortalama maliyet ve K/Z hesabı.
///
/// Tüm tutarlar portföy para birimindedir (işlem tutarı × [LedgerTxn.fxRate]).
/// Ücretler maliyete eklenir (alış) veya gelirden düşülür (satış).
library;

enum TxnKind { buy, sell, dividend, fee, deposit, withdraw }

class LedgerTxn {
  const LedgerTxn({
    required this.kind,
    required this.executedAt,
    this.instrument,
    this.quantity = 0,
    this.price = 0,
    this.fee = 0,
    this.fxRate = 1,
  });

  final TxnKind kind;
  final DateTime executedAt;

  /// Enstrüman anahtarı (alış/satış/temettü için zorunlu).
  final String? instrument;
  final double quantity;

  /// Alış/satış: birim fiyat. Temettü, ücret, para yatırma/çekme: toplam tutar.
  final double price;
  final double fee;
  final double fxRate;
}

class Position {
  Position(this.instrument);

  final String instrument;
  double quantity = 0;

  /// Kalan adetlerin toplam maliyeti (ücretler dahil).
  double costBasis = 0;
  double realizedPnl = 0;
  double dividends = 0;

  double get averageCost => quantity > 0 ? costBasis / quantity : 0;
  bool get isOpen => quantity > _eps;

  double marketValue(double price) => quantity * price;
  double unrealizedPnl(double price) => marketValue(price) - costBasis;
  double unrealizedPct(double price) => costBasis > 0 ? unrealizedPnl(price) / costBasis : 0;
}

class LedgerError implements Exception {
  LedgerError(this.message);
  final String message;
  @override
  String toString() => 'LedgerError: $message';
}

const _eps = 1e-9;

class Ledger {
  Ledger._(this.positions, this.cash, this.netDeposits, this.totalFees);

  /// İşlemleri tarih sırasıyla işler (aynı andakiler verilen sırayla).
  ///
  /// Eldeki adetten fazla satış [LedgerError] fırlatır.
  factory Ledger.fromTransactions(Iterable<LedgerTxn> txns) {
    final sorted = txns.toList()
      ..sort((a, b) => a.executedAt.compareTo(b.executedAt));
    final positions = <String, Position>{};
    var cash = 0.0, netDeposits = 0.0, fees = 0.0;

    Position pos(LedgerTxn t) {
      final key = t.instrument;
      if (key == null) throw LedgerError('${t.kind.name} işlemi için enstrüman gerekli');
      return positions.putIfAbsent(key, () => Position(key));
    }

    for (final t in sorted) {
      final fx = t.fxRate;
      final fee = t.fee * fx;
      fees += fee;
      switch (t.kind) {
        case TxnKind.buy:
          final p = pos(t);
          final gross = t.quantity * t.price * fx;
          p.quantity += t.quantity;
          p.costBasis += gross + fee;
          cash -= gross + fee;
        case TxnKind.sell:
          final p = pos(t);
          if (t.quantity > p.quantity + _eps) {
            throw LedgerError(
                '${t.instrument}: eldeki ${p.quantity} adetten fazla (${t.quantity}) satış');
          }
          final avg = p.averageCost;
          final proceeds = t.quantity * t.price * fx - fee;
          p.realizedPnl += proceeds - avg * t.quantity;
          p.costBasis -= avg * t.quantity;
          p.quantity -= t.quantity;
          if (p.quantity.abs() < _eps) {
            p.quantity = 0;
            p.costBasis = 0;
          }
          cash += proceeds;
        case TxnKind.dividend:
          final p = pos(t);
          final amount = t.price * fx - fee;
          p.dividends += amount;
          cash += amount;
        case TxnKind.fee:
          fees += t.price * fx;
          cash -= t.price * fx + fee;
        case TxnKind.deposit:
          cash += t.price * fx - fee;
          netDeposits += t.price * fx;
        case TxnKind.withdraw:
          cash -= t.price * fx + fee;
          netDeposits -= t.price * fx;
      }
    }
    return Ledger._(positions, cash, netDeposits, fees);
  }

  final Map<String, Position> positions;

  /// Nakit bakiyesi. Para yatırma kaydı tutulmuyorsa negatif olabilir (yatırılan sermaye).
  final double cash;
  final double netDeposits;
  final double totalFees;

  Iterable<Position> get openPositions => positions.values.where((p) => p.isOpen);

  double get realizedPnl => positions.values.fold(0, (s, p) => s + p.realizedPnl);
  double get dividends => positions.values.fold(0, (s, p) => s + p.dividends);
  double get costBasis => openPositions.fold(0, (s, p) => s + p.costBasis);

  /// Fiyatı bilinmeyen pozisyonlar maliyetinden değerlenir ([missing] listesine eklenir).
  PortfolioValuation value(Map<String, double> prices) {
    var market = 0.0;
    final missing = <String>[];
    final weights = <String, double>{};
    for (final p in openPositions) {
      final price = prices[p.instrument];
      final v = price == null ? p.costBasis : p.marketValue(price);
      if (price == null) missing.add(p.instrument);
      weights[p.instrument] = v;
      market += v;
    }
    if (market > 0) weights.updateAll((_, v) => v / market);
    return PortfolioValuation(
      marketValue: market,
      costBasis: costBasis,
      unrealizedPnl: market - costBasis,
      realizedPnl: realizedPnl,
      dividends: dividends,
      weights: weights,
      missingPrices: missing,
    );
  }
}

class PortfolioValuation {
  const PortfolioValuation({
    required this.marketValue,
    required this.costBasis,
    required this.unrealizedPnl,
    required this.realizedPnl,
    required this.dividends,
    required this.weights,
    required this.missingPrices,
  });

  final double marketValue;
  final double costBasis;
  final double unrealizedPnl;
  final double realizedPnl;
  final double dividends;

  /// Piyasa değerine göre ağırlıklar (toplam 1).
  final Map<String, double> weights;
  final List<String> missingPrices;

  double get totalPnl => unrealizedPnl + realizedPnl + dividends;
  double get unrealizedPct => costBasis > 0 ? unrealizedPnl / costBasis : 0;
}

/// Nominal getiriyi enflasyondan arındırır: (1 + nominal) / (1 + enflasyon) - 1.
double realReturn(double nominal, double inflation) => (1 + nominal) / (1 + inflation) - 1;
