import 'dart:math' as math;
import 'dart:typed_data';

import 'rng.dart';
import 'stats.dart';

/// Fraktal Brownian hareket (FBM) artımları: tam kovaryans + Cholesky.
///
/// Demo modu ve testler içindir (O(n³); n ≈ 500 için birkaç ms).
/// Referans: research/fraktal_prototype/src/data.py `fbm_series`.
Float64List fbmIncrements(int n, {required double hurst, required double sigma, int seed = 0}) {
  final rng = Rng(seed);
  final h2 = 2 * hurst;
  final cov = List.generate(n, (i) {
    final ti = i + 1.0;
    return Float64List.fromList([
      for (var j = 0; j < n; j++)
        0.5 * (math.pow(ti, h2) + math.pow(j + 1.0, h2) - math.pow((ti - j - 1).abs(), h2)),
    ]);
  });
  Float64List incr;
  try {
    final l = cholesky(cov, jitter: 1e-8);
    final z = [for (var i = 0; i < n; i++) rng.normal()];
    incr = Float64List(n);
    var prev = 0.0;
    for (var i = 0; i < n; i++) {
      var s = 0.0;
      for (var k = 0; k <= i; k++) {
        s += l[i][k] * z[k];
      }
      incr[i] = s - prev;
      prev = s;
    }
  } on ArgumentError {
    incr = Float64List.fromList([for (var i = 0; i < n; i++) rng.normal()]);
  }
  final sd = std(incr);
  final scale = (sd > 0 ? 1 / sd : 1) * sigma / math.sqrt(tradingDays);
  for (var i = 0; i < n; i++) {
    incr[i] *= scale;
  }
  return incr;
}

/// Yıllık [mu] drift ve FBM şokları ile 100'den başlayan sentetik fiyat serisi.
Float64List syntheticPrices(int days,
    {required double mu, required double sigma, required double hurst, int seed = 0}) {
  final incr = fbmIncrements(days, hurst: hurst, sigma: sigma, seed: seed);
  final out = Float64List(days);
  var logP = 0.0;
  for (var i = 0; i < days; i++) {
    logP += mu / tradingDays + incr[i];
    out[i] = 100 * math.exp(logP);
  }
  return out;
}
