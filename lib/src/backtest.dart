import 'dart:math' as math;
import 'dart:typed_data';

import 'stats.dart';

class BacktestResult {
  const BacktestResult({
    required this.totalReturn,
    required this.cagr,
    required this.volatility,
    required this.sharpe,
    required this.maxDrawdown,
    required this.days,
    required this.equity,
    required this.drawdown,
  });

  final double totalReturn;
  final double cagr;
  final double volatility;
  final double sharpe;

  /// Pozitif oran (0.3 = %30 düşüş).
  final double maxDrawdown;
  final int days;

  /// 1.0'dan başlayan bileşik değer eğrisi (grafik için).
  final Float64List equity;

  /// Her gün için tepeden düşüş (≤ 0).
  final Float64List drawdown;

  Map<String, Object> toJson() => {
        'total_return': totalReturn,
        'cagr': cagr,
        'volatility': volatility,
        'sharpe': sharpe,
        'max_drawdown': maxDrawdown,
        'days': days,
      };
}

/// Tepe-dip en büyük düşüş (pozitif oran).
double maxDrawdown(List<double> equity) {
  var peak = -double.infinity, worst = 0.0;
  for (final v in equity) {
    if (v > peak) peak = v;
    final dd = (v - peak) / peak;
    if (dd < worst) worst = dd;
  }
  return -worst;
}

/// Sabit ağırlıklı portföyün tarihsel performansı.
///
/// [logReturnRows] (A, T) günlük log getiriler (farklı uzunluklar sondan hizalanır).
/// [rebalance] true ise günlük yeniden dengeleme, false ise al-tut.
/// Referans: research/fraktal_prototype/src/backtest.py.
BacktestResult backtest(
  List<List<double>> logReturnRows,
  List<double> weights, {
  double riskFree = 0.45,
  bool rebalance = true,
}) {
  final w = normalizeWeights(weights);
  final rows = alignTail(logReturnRows);
  final a = rows.length;
  final t = a == 0 ? 0 : rows.first.length;

  // Log -> basit getiri.
  final simple = [
    for (final r in rows) Float64List.fromList([for (final v in r) math.exp(v) - 1]),
  ];

  final port = Float64List(t);
  if (rebalance) {
    for (var k = 0; k < t; k++) {
      var s = 0.0;
      for (var i = 0; i < a; i++) {
        s += w[i] * simple[i][k];
      }
      port[k] = s;
    }
  } else {
    final growth = Float64List(a)..fillRange(0, a, 1.0);
    var prev = 1.0;
    for (var k = 0; k < t; k++) {
      var value = 0.0;
      for (var i = 0; i < a; i++) {
        growth[i] *= 1 + simple[i][k];
        value += w[i] * growth[i];
      }
      port[k] = value / prev - 1;
      prev = value;
    }
  }

  final equity = Float64List(t);
  final drawdown = Float64List(t);
  var e = 1.0, peak = 1.0;
  for (var k = 0; k < t; k++) {
    e *= 1 + port[k];
    equity[k] = e;
    if (e > peak) peak = e;
    drawdown[k] = (e - peak) / peak;
  }

  final total = t > 0 ? equity[t - 1] - 1 : 0.0;
  final cagr = t > 0 ? math.pow(equity[t - 1], tradingDays / t) - 1 : 0.0;
  final vol = std(port) * math.sqrt(tradingDays);
  final sharpe = vol > 0 ? (cagr - riskFree) / vol : 0.0;
  return BacktestResult(
    totalReturn: total,
    cagr: cagr.toDouble(),
    volatility: vol,
    sharpe: sharpe,
    maxDrawdown: maxDrawdown(equity),
    days: t,
    equity: equity,
    drawdown: drawdown,
  );
}
