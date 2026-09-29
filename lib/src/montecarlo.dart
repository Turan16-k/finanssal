import 'dart:math' as math;
import 'dart:typed_data';

import 'rng.dart';
import 'stats.dart';

/// Monte Carlo girdileri. Isolate'ler arasında taşınabilir düz veri.
class MonteCarloParams {
  const MonteCarloParams({
    required this.logReturnRows,
    required this.weights,
    this.horizon = tradingDays,
    this.nSims = 5000,
    this.initial = 100000,
    this.sentiment = 0,
    this.sentimentWeight = 0.3,
    this.sentimentAnnualPremium = 0.12,
    this.jumps = false,
    this.jumpIntensity = 0.05,
    this.jumpMean = -0.02,
    this.jumpStd = 0.05,
    this.seed = 1,
    this.bandPoints = 60,
    this.samplePaths = 30,
  });

  /// (A, T) tarihsel günlük log getiriler; drift ve kovaryans buradan kestirilir.
  final List<List<double>> logReturnRows;
  final List<double> weights;
  final int horizon;
  final int nSims;
  final double initial;

  /// [-1, 1] aralığında duygu skoru. Drift'e toplamsal prim olarak eklenir:
  /// mu_adj = mu + sentimentWeight * sentiment * annualPremium / 252.
  final double sentiment;
  final double sentimentWeight;
  final double sentimentAnnualPremium;

  /// Merton jump-diffusion: günde N~Poisson(jumpIntensity) adet N(jumpMean, jumpStd) log-şok.
  final bool jumps;
  final double jumpIntensity;
  final double jumpMean;
  final double jumpStd;

  final int seed;

  /// Fan grafiği için yol boyunca kaç noktada persentil bandı hesaplanacağı.
  final int bandPoints;

  /// Grafikte çizilecek örnek yol sayısı.
  final int samplePaths;
}

class MonteCarloResult {
  const MonteCarloResult({
    required this.horizon,
    required this.nSims,
    required this.initial,
    required this.expectedValue,
    required this.var95,
    required this.cvar95,
    required this.probLoss,
    required this.p5,
    required this.p50,
    required this.p95,
    required this.bandSteps,
    required this.bands,
    required this.samplePaths,
  });

  final int horizon;
  final int nSims;
  final double initial;
  final double expectedValue;

  /// %95 Value at Risk (kayıp tutarı, ≥ 0).
  final double var95;

  /// %95 Conditional VaR / Expected Shortfall (kayıp tutarı, ≥ 0).
  final double cvar95;
  final double probLoss;
  final double p5;
  final double p50;
  final double p95;

  /// Bantların hesaplandığı gün indeksleri (0 = başlangıç).
  final List<int> bandSteps;

  /// Persentil -> bandSteps ile aynı uzunlukta değerler. Anahtarlar: 5, 25, 50, 75, 95.
  final Map<int, Float64List> bands;
  final List<Float64List> samplePaths;

  Map<String, Object> toJson() => {
        'horizon': horizon,
        'n_sims': nSims,
        'expected_value': expectedValue,
        'var_95': var95,
        'cvar_95': cvar95,
        'prob_loss': probLoss,
        'percentiles': {'p5': p5, 'p50': p50, 'p95': p95},
      };
}

const bandPercentiles = [5, 25, 50, 75, 95];

/// Korelasyonlu GBM (+ isteğe bağlı Merton sıçramaları) ile portföy simülasyonu.
///
/// Referans: research/fraktal_prototype/src/montecarlo.py. RNG farklı olduğundan
/// sonuçlar Python ile birebir değil, istatistiksel olarak uyumludur.
MonteCarloResult simulatePortfolio(MonteCarloParams p) {
  final rows = alignTail(p.logReturnRows);
  final a = rows.length;
  if (a == 0) throw ArgumentError('En az bir varlık gerekli.');
  if (p.weights.length != a) {
    throw ArgumentError('Ağırlık sayısı (${p.weights.length}) varlık sayısına ($a) eşit değil.');
  }
  final w = normalizeWeights(p.weights);
  final premium = p.sentimentWeight * p.sentiment * p.sentimentAnnualPremium / tradingDays;
  final mu = Float64List.fromList([for (final r in rows) mean(r) + premium]);
  final chol = cholesky(covariance(rows));

  // Portföy log getirisi = wᵀ(mu + L z) = wᵀmu + Σ_k (wᵀL)_k z_k.
  // wᵀL bir kez hesaplanır; her gün A adet bağımsız normal çekilir.
  final wL = Float64List(a);
  for (var k = 0; k < a; k++) {
    var s = 0.0;
    for (var i = k; i < a; i++) {
      s += w[i] * chol[i][k];
    }
    wL[k] = s;
  }
  final portMu = dot(w, mu);

  final horizon = math.max(1, p.horizon);
  final stride = math.max(1, (horizon / math.max(1, p.bandPoints)).ceil());
  final bandSteps = <int>[0];
  for (var s = stride; s < horizon; s += stride) {
    bandSteps.add(s);
  }
  bandSteps.add(horizon);
  final checkpoints = List.generate(bandSteps.length, (_) => Float64List(p.nSims));

  final rng = Rng(p.seed);
  final finals = Float64List(p.nSims);
  final samples = <Float64List>[];
  final nSamples = math.min(p.samplePaths, p.nSims);

  for (var sim = 0; sim < p.nSims; sim++) {
    var logV = 0.0;
    var cp = 1;
    checkpoints[0][sim] = p.initial;
    final path = sim < nSamples ? Float64List(bandSteps.length) : null;
    path?[0] = p.initial;
    for (var day = 1; day <= horizon; day++) {
      var shock = 0.0;
      for (var k = 0; k < a; k++) {
        shock += wL[k] * rng.normal();
      }
      var r = portMu + shock;
      if (p.jumps) {
        final n = rng.poisson(p.jumpIntensity);
        if (n > 0) r += n * p.jumpMean + math.sqrt(n) * p.jumpStd * rng.normal();
      }
      logV += r;
      if (cp < bandSteps.length && day == bandSteps[cp]) {
        final v = p.initial * math.exp(logV);
        checkpoints[cp][sim] = v;
        path?[cp] = v;
        cp++;
      }
    }
    finals[sim] = p.initial * math.exp(logV);
    if (path != null) samples.add(path);
  }

  final sortedFinals = Float64List.fromList(finals)..sort();
  final losses = Float64List.fromList([for (final f in finals) p.initial - f])..sort();
  final var95 = percentileSorted(losses, 95);
  var tailSum = 0.0, tailN = 0;
  for (final l in losses) {
    if (l >= var95) {
      tailSum += l;
      tailN++;
    }
  }
  final cvar95 = tailN > 0 ? tailSum / tailN : var95;
  var lossCount = 0;
  for (final f in finals) {
    if (f < p.initial) lossCount++;
  }

  final bands = <int, Float64List>{
    for (final q in bandPercentiles) q: Float64List(bandSteps.length),
  };
  for (var c = 0; c < bandSteps.length; c++) {
    final sorted = checkpoints[c]..sort();
    for (final q in bandPercentiles) {
      bands[q]![c] = percentileSorted(sorted, q.toDouble());
    }
  }

  return MonteCarloResult(
    horizon: horizon,
    nSims: p.nSims,
    initial: p.initial,
    expectedValue: mean(finals),
    var95: math.max(0, var95),
    cvar95: math.max(0, cvar95),
    probLoss: p.nSims > 0 ? lossCount / p.nSims : 0,
    p5: percentileSorted(sortedFinals, 5),
    p50: percentileSorted(sortedFinals, 50),
    p95: percentileSorted(sortedFinals, 95),
    bandSteps: bandSteps,
    bands: bands,
    samplePaths: samples,
  );
}
