import 'dart:math' as math;

import 'package:quant_dart/quant_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Rng', () {
    test('aynı tohum aynı dizi', () {
      final a = Rng(42), b = Rng(42);
      for (var i = 0; i < 100; i++) {
        expect(a.normal(), b.normal());
      }
    });

    test('normal dağılım momentleri', () {
      final r = Rng(1);
      final xs = [for (var i = 0; i < 200000; i++) r.normal()];
      expect(mean(xs), closeTo(0, 0.01));
      expect(std(xs), closeTo(1, 0.01));
    });

    test('poisson ortalaması lambda', () {
      final r = Rng(3);
      final xs = [for (var i = 0; i < 200000; i++) r.poisson(0.3).toDouble()];
      expect(mean(xs), closeTo(0.3, 0.01));
    });
  });

  group('stats', () {
    test('cholesky L·Lᵀ = A', () {
      final a = [
        [4.0, 2.0, 0.6],
        [2.0, 3.0, 0.4],
        [0.6, 0.4, 1.0],
      ];
      final l = cholesky(a, jitter: 0);
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          var s = 0.0;
          for (var k = 0; k < 3; k++) {
            s += l[i][k] * l[j][k];
          }
          expect(s, closeTo(a[i][j], 1e-12));
        }
      }
    });

    test('pozitif tanımlı olmayan matris hata verir', () {
      expect(() => cholesky([[1.0, 2.0], [2.0, 1.0]], jitter: 0), throwsArgumentError);
    });

    test('normalizeWeights sıfır toplamda eşit ağırlık', () {
      expect(normalizeWeights([0, 0, 0]), [1 / 3, 1 / 3, 1 / 3]);
      expect(normalizeWeights([2, -1, 2]), [0.5, 0, 0.5]);
    });

    test('alignTail farklı uzunlukları sondan hizalar', () {
      expect(alignTail([[1, 2, 3, 4], [9, 8]]), [[3, 4], [9, 8]]);
    });
  });

  group('Hurst', () {
    test('beyaz gürültü ≈ 0.5, trendli FBM > 0.5', () {
      final r = Rng(11);
      final noise = [for (var i = 0; i < 2048; i++) r.normal()];
      expect(hurstRS(noise), closeTo(0.5, 0.1));
      final persistent = fbmIncrements(512, hurst: 0.8, sigma: 0.3, seed: 5);
      expect(hurstRS(persistent), greaterThan(0.6));
    });

    test('kısa seri 0.5 döner', () {
      expect(hurstRS([0.1, 0.2, 0.3]), 0.5);
    });

    test('rejim eşikleri', () {
      expect(MarketRegime.fromHurst(0.7), MarketRegime.trending);
      expect(MarketRegime.fromHurst(0.5), MarketRegime.randomWalk);
      expect(MarketRegime.fromHurst(0.3), MarketRegime.meanReverting);
    });
  });

  group('Monte Carlo', () {
    // Bilinen parametrelerle üretilmiş log getiriler: mu=0.0005/gün, sigma=0.01/gün.
    List<List<double>> gbmRows(int assets, {int seed = 2}) {
      final r = Rng(seed);
      return [
        for (var a = 0; a < assets; a++) [for (var t = 0; t < 1000; t++) 0.0005 + 0.01 * r.normal()],
      ];
    }

    test('beklenen değer lognormal teorisine yakın', () {
      final rows = gbmRows(1);
      final res = simulatePortfolio(MonteCarloParams(
        logReturnRows: rows,
        weights: [1],
        horizon: 252,
        nSims: 20000,
        sentimentWeight: 0,
      ));
      final m = mean(rows[0]), s = std(rows[0]);
      final theory = 100000 * math.exp(252 * (m + s * s / 2));
      expect(res.expectedValue, closeTo(theory, theory * 0.01));
      expect(res.p5, lessThan(res.p50));
      expect(res.p50, lessThan(res.p95));
      expect(res.probLoss, inInclusiveRange(0, 1));
      expect(res.cvar95, greaterThanOrEqualTo(res.var95));
    });

    test('pozitif sentiment beklenen değeri artırır', () {
      final rows = gbmRows(2);
      MonteCarloResult run(double s) => simulatePortfolio(MonteCarloParams(
            logReturnRows: rows,
            weights: [0.5, 0.5],
            nSims: 3000,
            sentiment: s,
            seed: 5,
          ));
      expect(run(0.8).expectedValue, greaterThan(run(0).expectedValue));
      expect(run(-0.8).expectedValue, lessThan(run(0).expectedValue));
    });

    test('negatif sıçramalar kuyruk riskini artırır', () {
      final rows = gbmRows(1);
      final base = simulatePortfolio(MonteCarloParams(logReturnRows: rows, weights: [1], nSims: 5000));
      final jumpy = simulatePortfolio(
          MonteCarloParams(logReturnRows: rows, weights: [1], nSims: 5000, jumps: true));
      expect(jumpy.cvar95, greaterThan(base.cvar95));
    });

    test('bantlar ve örnek yollar tutarlı', () {
      final res = simulatePortfolio(MonteCarloParams(
          logReturnRows: gbmRows(3), weights: [1, 1, 1], horizon: 100, nSims: 500));
      expect(res.bandSteps.first, 0);
      expect(res.bandSteps.last, 100);
      for (final q in bandPercentiles) {
        expect(res.bands[q]!.length, res.bandSteps.length);
        expect(res.bands[q]!.first, 100000);
      }
      expect(res.samplePaths.length, 30);
      expect(res.bands[95]!.last, closeTo(res.p95, 1e-6));
    });

    test('ağırlık sayısı uyuşmazlığı hata verir', () {
      expect(
        () => simulatePortfolio(MonteCarloParams(logReturnRows: gbmRows(2), weights: [1])),
        throwsArgumentError,
      );
    });
  });

  group('Markowitz', () {
    test('simplex izdüşümü', () {
      final w = projectToSimplex([0.5, 0.8, -0.2]);
      expect(w.reduce((a, b) => a + b), closeTo(1, 1e-12));
      expect(w.every((x) => x >= 0), isTrue);
    });

    test('min-varyans en düşük volatiliteyi verir', () {
      final mc = MeanCov.fromLogReturns([
        for (var a = 0; a < 3; a++)
          fbmIncrements(300, hurst: 0.5, sigma: 0.1 + 0.1 * a, seed: a).toList(),
      ]);
      final mv = minVariance(mc);
      for (final p in randomPortfolios(mc, count: 500)) {
        expect(mv.volatility, lessThanOrEqualTo(p.volatility + 1e-9));
      }
    });
  });

  group('backtest', () {
    test('sabit %1 günlük getiri', () {
      final r = backtest([List.filled(10, math.log(1.01))], [1], riskFree: 0);
      expect(r.totalReturn, closeTo(math.pow(1.01, 10) - 1, 1e-12));
      expect(r.maxDrawdown, 0);
      expect(r.equity.length, 10);
    });

    test('maxDrawdown', () {
      expect(maxDrawdown([1, 2, 1, 1.5, 0.5, 3]), closeTo(0.75, 1e-12));
    });
  });
}
