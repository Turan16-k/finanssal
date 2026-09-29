import 'dart:math' as math;

import 'stats.dart';

/// Piyasa rejimi (Hurst üssüne göre).
enum MarketRegime {
  /// H > 0.55: trend / uzun bellek.
  trending,

  /// 0.45 ≤ H ≤ 0.55: rastgele yürüyüş.
  randomWalk,

  /// H < 0.45: ortalamaya dönüş.
  meanReverting;

  static MarketRegime fromHurst(double h) {
    if (h > 0.55) return MarketRegime.trending;
    if (h < 0.45) return MarketRegime.meanReverting;
    return MarketRegime.randomWalk;
  }
}

/// R/S (rescaled range) analizi ile Hurst üssü. Genelde getiri serisine uygulanır.
///
/// Referans: research/fraktal_prototype/src/fractal.py `hurst_rs` (birebir port).
double hurstRS(List<double> series, {int minChunk = 8}) {
  final n = series.length;
  if (n < minChunk * 2) return 0.5;
  final logSizes = <double>[];
  final logRs = <double>[];
  for (var size = minChunk; size <= n ~/ 2; size *= 2) {
    final chunks = n ~/ size;
    var rsSum = 0.0;
    var rsCount = 0;
    for (var c = 0; c < chunks; c++) {
      final seg = series.sublist(c * size, (c + 1) * size);
      final m = mean(seg);
      var cum = 0.0, maxDev = -double.infinity, minDev = double.infinity;
      for (final v in seg) {
        cum += v - m;
        if (cum > maxDev) maxDev = cum;
        if (cum < minDev) minDev = cum;
      }
      final s = std(seg);
      if (s > 0) {
        rsSum += (maxDev - minDev) / s;
        rsCount++;
      }
    }
    if (rsCount > 0) {
      logSizes.add(math.log(size.toDouble()));
      logRs.add(math.log(rsSum / rsCount));
    }
  }
  if (logSizes.length < 2) return 0.5;
  return _slope(logSizes, logRs).clamp(0.0, 1.0).toDouble();
}

/// En küçük kareler doğru eğimi (numpy `polyfit(x, y, 1)[0]`).
double _slope(List<double> x, List<double> y) {
  final mx = mean(x), my = mean(y);
  var num = 0.0, den = 0.0;
  for (var i = 0; i < x.length; i++) {
    num += (x[i] - mx) * (y[i] - my);
    den += (x[i] - mx) * (x[i] - mx);
  }
  return den == 0 ? 0 : num / den;
}
