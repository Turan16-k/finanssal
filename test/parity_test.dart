// Python prototipiyle eşdeğerlik testleri.
// Fixture'ı yeniden üretmek için:
//   cd research/fraktal_prototype && python tools/export_parity_fixtures.py
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:quant_dart/quant_dart.dart';
import 'package:test/test.dart';

List<List<double>> _matrix(Object? m) => [
      for (final row in m as List) [for (final v in row as List) (v as num).toDouble()],
    ];

List<double> _vector(Object? v) => [for (final x in v as List) (x as num).toDouble()];

void main() {
  final fx = jsonDecode(File('test/fixtures/parity.json').readAsStringSync())
      as Map<String, dynamic>;
  final rets = _matrix(fx['log_returns']);
  final weights = _vector(fx['weights']);

  test('Hurst (R/S) Python ile aynı', () {
    final expected = _vector(fx['hurst']);
    for (var i = 0; i < rets.length; i++) {
      expect(hurstRS(rets[i]), closeTo(expected[i], 1e-10));
    }
  });

  test('kovaryans numpy.cov ile aynı', () {
    final expected = _matrix(fx['cov_daily']);
    final cov = covariance(rets);
    for (var i = 0; i < cov.length; i++) {
      for (var j = 0; j < cov.length; j++) {
        expect(cov[i][j], closeTo(expected[i][j], 1e-15));
      }
    }
  });

  test('percentile numpy ile aynı', () {
    final p = fx['percentile'] as Map<String, dynamic>;
    final data = _vector(p['data']);
    final qs = _vector(p['q']);
    final values = _vector(p['values']);
    for (var i = 0; i < qs.length; i++) {
      expect(percentile(data, qs[i]), closeTo(values[i], 1e-15));
    }
  });

  for (final mode in ['rebalance', 'buy_hold']) {
    test('backtest ($mode) Python ile aynı', () {
      final e = (fx['backtest'] as Map<String, dynamic>)[mode] as Map<String, dynamic>;
      final r = backtest(rets, weights, riskFree: 0.45, rebalance: mode == 'rebalance');
      // Python değerleri 4 haneye yuvarlanmış.
      expect(r.totalReturn, closeTo(e['total_return'] as num, 5e-5));
      expect(r.cagr, closeTo(e['cagr'] as num, 5e-5));
      expect(r.volatility, closeTo(e['volatility'] as num, 5e-5));
      expect(r.sharpe, closeTo(e['sharpe'] as num, 5e-5));
      expect(r.maxDrawdown, closeTo(e['max_drawdown'] as num, 5e-5));
      expect(r.days, e['n_days']);
    });
  }

  test('maks-Sharpe (köşe çözümü) SciPy ile aynı', () {
    final mc = MeanCov.fromLogReturns(rets);
    (fx['max_sharpe'] as Map<String, dynamic>).forEach((rf, e) {
      final a = maxSharpe(mc, riskFree: double.parse(rf));
      final ew = _vector((e as Map<String, dynamic>)['weights']);
      for (var i = 0; i < ew.length; i++) {
        expect(a.weights[i], closeTo(ew[i], 1e-3), reason: 'rf=$rf, w[$i]');
      }
      expect(a.sharpe, closeTo(e['sharpe'] as num, 5e-4));
    });
  });

  test('maks-Sharpe (iç çözüm) SciPy ile aynı', () {
    final e = fx['max_sharpe_interior'] as Map<String, dynamic>;
    final mc = MeanCov(
      _vector(e['mu']).toFloat64(),
      [for (final r in _matrix(e['cov'])) r.toFloat64()],
    );
    final a = maxSharpe(mc, riskFree: (e['rf'] as num).toDouble());
    final ew = _vector(e['weights']);
    for (var i = 0; i < ew.length; i++) {
      expect(a.weights[i], closeTo(ew[i], 2e-3), reason: 'w[$i]');
    }
    // Sharpe SLSQP'den kötü olmamalı.
    expect(a.sharpe, greaterThanOrEqualTo((e['sharpe'] as num) - 1e-6));
  });
}

extension on List<double> {
  Float64List toFloat64() => Float64List.fromList(this);
}
