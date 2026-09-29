import 'dart:math' as math;
import 'dart:typed_data';

import 'rng.dart';
import 'stats.dart';

class Allocation {
  const Allocation({
    required this.weights,
    required this.expectedReturn,
    required this.volatility,
    required this.sharpe,
  });

  final Float64List weights;

  /// Yıllık.
  final double expectedReturn;

  /// Yıllık.
  final double volatility;
  final double sharpe;

  Map<String, Object> toJson() => {
        'weights': weights.toList(),
        'expected_return': expectedReturn,
        'volatility': volatility,
        'sharpe': sharpe,
      };
}

/// Etkin sınır grafiği için tek bir portföy noktası.
class FrontierPoint {
  const FrontierPoint(this.volatility, this.expectedReturn, this.sharpe);
  final double volatility;
  final double expectedReturn;
  final double sharpe;
}

/// Yıllıklaştırılmış beklenen getiri vektörü ve kovaryans matrisi.
class MeanCov {
  MeanCov(this.mu, this.cov);

  /// Günlük log getirilerden (A, T) yıllık parametreler.
  factory MeanCov.fromLogReturns(List<List<double>> rows) {
    final aligned = alignTail(rows);
    final mu = Float64List.fromList([for (final r in aligned) mean(r) * tradingDays]);
    final cov = covariance(aligned);
    for (final row in cov) {
      for (var j = 0; j < row.length; j++) {
        row[j] *= tradingDays;
      }
    }
    return MeanCov(mu, cov);
  }

  final Float64List mu;
  final List<Float64List> cov;

  int get length => mu.length;

  ({double ret, double vol, double sharpe}) stats(List<double> w, double rf) {
    final ret = dot(w, mu);
    final vol = math.sqrt(math.max(0, quadForm(w, cov)));
    return (ret: ret, vol: vol, sharpe: vol > 0 ? (ret - rf) / vol : 0.0);
  }

  Allocation allocation(List<double> w, double rf) {
    final s = stats(w, rf);
    return Allocation(
      weights: Float64List.fromList(w),
      expectedReturn: s.ret,
      volatility: s.vol,
      sharpe: s.sharpe,
    );
  }
}

/// Açığa satış olmadan (0 ≤ w ≤ 1, Σw = 1) Sharpe oranını maksimize eder.
///
/// Simplex üzerine izdüşümlü gradyan yükselmesi + çoklu başlangıç (eşit ağırlık,
/// tek varlık köşeleri ve rastgele noktalar). SciPy SLSQP sonucuyla eşdeğerlik
/// testleri test/parity_test.dart içinde.
Allocation maxSharpe(MeanCov mc, {double riskFree = 0.45, int restarts = 12, int seed = 1}) {
  final n = mc.length;
  if (n == 0) throw ArgumentError('En az bir varlık gerekli.');
  if (n == 1) return mc.allocation([1.0], riskFree);

  final rng = Rng(seed);
  final starts = <Float64List>[
    Float64List(n)..fillRange(0, n, 1 / n),
    for (var i = 0; i < n; i++) _corner(n, i, 0.9),
    for (var r = 0; r < restarts; r++) _randomSimplex(n, rng),
  ];

  Float64List? best;
  var bestSharpe = -double.infinity;
  for (final start in starts) {
    final w = _ascend(start, (x) => _sharpeAndGrad(mc, x, riskFree));
    final s = mc.stats(w, riskFree).sharpe;
    if (s > bestSharpe) {
      bestSharpe = s;
      best = w;
    }
  }
  return mc.allocation(_clean(best!), riskFree);
}

/// En düşük varyanslı portföy (açığa satış yok).
Allocation minVariance(MeanCov mc, {double riskFree = 0.45}) {
  final n = mc.length;
  final w = _ascend(Float64List(n)..fillRange(0, n, 1 / n), (x) {
    // -wᵀΣw maksimize edilir; gradyan -2Σw.
    final g = Float64List(n);
    for (var i = 0; i < n; i++) {
      var s = 0.0;
      for (var j = 0; j < n; j++) {
        s += mc.cov[i][j] * x[j];
      }
      g[i] = -2 * s;
    }
    return (value: -quadForm(x, mc.cov), grad: g);
  });
  return mc.allocation(_clean(w), riskFree);
}

/// Etkin sınır görselleştirmesi için rastgele portföy bulutu.
List<FrontierPoint> randomPortfolios(MeanCov mc,
    {int count = 1500, double riskFree = 0.45, int seed = 7}) {
  final rng = Rng(seed);
  return [
    for (var i = 0; i < count; i++)
      () {
        final s = mc.stats(_randomSimplex(mc.length, rng), riskFree);
        return FrontierPoint(s.vol, s.ret, s.sharpe);
      }(),
  ];
}

// --------------------------------------------------------------------------- //

typedef _Objective = ({double value, Float64List grad}) Function(Float64List w);

({double value, Float64List grad}) _sharpeAndGrad(MeanCov mc, Float64List w, double rf) {
  final n = w.length;
  final sw = Float64List(n);
  for (var i = 0; i < n; i++) {
    var s = 0.0;
    for (var j = 0; j < n; j++) {
      s += mc.cov[i][j] * w[j];
    }
    sw[i] = s;
  }
  final variance = math.max(dot(w, sw), 1e-18);
  final vol = math.sqrt(variance);
  final excess = dot(w, mc.mu) - rf;
  final g = Float64List(n);
  for (var i = 0; i < n; i++) {
    g[i] = mc.mu[i] / vol - excess * sw[i] / (variance * vol);
  }
  return (value: excess / vol, grad: g);
}

/// Armijo geri izlemeli, simplex izdüşümlü gradyan yükselmesi.
Float64List _ascend(Float64List start, _Objective f, {int maxIter = 2000, double tol = 1e-12}) {
  var w = projectToSimplex(start);
  var cur = f(w);
  var step = 1.0;
  for (var it = 0; it < maxIter; it++) {
    var improved = false;
    while (step > 1e-14) {
      final cand = Float64List(w.length);
      for (var i = 0; i < w.length; i++) {
        cand[i] = w[i] + step * cur.grad[i];
      }
      final proj = projectToSimplex(cand);
      final next = f(proj);
      if (next.value > cur.value + tol) {
        w = proj;
        cur = next;
        step *= 2;
        improved = true;
        break;
      }
      step /= 2;
    }
    if (!improved) break;
  }
  return w;
}

/// Öklid izdüşümü: {w ≥ 0, Σw = 1} (Duchi ve ark., 2008).
Float64List projectToSimplex(List<double> v) {
  final n = v.length;
  final u = List<double>.of(v)..sort((a, b) => b.compareTo(a));
  var css = 0.0, theta = 0.0;
  for (var i = 0; i < n; i++) {
    css += u[i];
    final t = (css - 1) / (i + 1);
    if (u[i] - t > 0) theta = t;
  }
  return Float64List.fromList([for (final x in v) math.max(0, x - theta)]);
}

Float64List _corner(int n, int i, double mass) {
  final w = Float64List(n)..fillRange(0, n, (1 - mass) / (n - 1));
  w[i] = mass;
  return w;
}

Float64List _randomSimplex(int n, Rng rng) {
  // Dirichlet(1, ..., 1): üstel dağılımlı örneklerin normalize edilmesi.
  final w = Float64List.fromList([for (var i = 0; i < n; i++) -math.log(1 - rng.uniform())]);
  final s = w.fold<double>(0, (a, b) => a + b);
  for (var i = 0; i < n; i++) {
    w[i] /= s;
  }
  return w;
}

/// Sayısal gürültüyü (ör. 1e-17) sıfırlayıp yeniden normalize eder.
Float64List _clean(Float64List w) =>
    normalizeWeights([for (final x in w) x < 1e-9 ? 0.0 : x]);
