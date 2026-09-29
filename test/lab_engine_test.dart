import 'package:flutter_test/flutter_test.dart';
import 'package:fraktal/data/market_repository.dart';
import 'package:fraktal/data/models.dart';
import 'package:fraktal/features/lab/lab_engine.dart';

void main() {
  test('alignByDate yalnızca ortak günleri tutar', () {
    final a = [
      PricePoint(DateTime(2026, 1, 1), 1),
      PricePoint(DateTime(2026, 1, 2), 2),
      PricePoint(DateTime(2026, 1, 3), 3),
      PricePoint(DateTime(2026, 1, 4), 4), // hafta sonu (yalnızca kripto)
    ];
    final b = [
      PricePoint(DateTime(2026, 1, 2), 20),
      PricePoint(DateTime(2026, 1, 3), 30),
      PricePoint(DateTime(2026, 1, 5), 50),
    ];
    final r = alignByDate([a, b]);
    expect(r.dates, [DateTime.utc(2026, 1, 2), DateTime.utc(2026, 1, 3)]);
    expect(r.closes[0], [2, 3]);
    expect(r.closes[1], [20, 30]);
  });

  test('demo verisiyle tam laboratuvar hesabı', () async {
    final repo = DemoMarketRepository(today: DateTime(2026, 9, 25));
    final from = DateTime(2024, 9, 25);
    final ids = [1, 5, 8];
    final histories = [for (final id in ids) await repo.history(id, from, maxPoints: 100000)];
    final r = computeLab(histories, LabParams(instrumentIds: ids, weights: const [1, 1, 1], nSims: 500));

    expect(r.commonDays, greaterThan(400));
    expect(r.weights.reduce((a, b) => a + b), closeTo(1, 1e-12));
    expect(r.montecarlo.p5, lessThan(r.montecarlo.p95));
    expect(r.hurst.length, 3);
    expect(r.optimal, isNotNull);
    expect(r.optimal!.sharpe, greaterThanOrEqualTo(r.current.sharpe - 1e-9));
    expect(r.correlation[0][0], closeTo(1, 1e-12));
  });

  test('tek varlıkta optimizasyon yok', () async {
    final repo = DemoMarketRepository(today: DateTime(2026, 9, 25));
    final h = await repo.history(1, DateTime(2025, 1, 1), maxPoints: 100000);
    final r = computeLab([h], const LabParams(instrumentIds: [1], weights: [1], nSims: 200));
    expect(r.optimal, isNull);
    expect(r.cloud, isEmpty);
  });

  test('yetersiz geçmiş hata verir', () {
    final short = [for (var i = 0; i < 10; i++) PricePoint(DateTime(2026, 1, 1 + i), 100.0 + i)];
    expect(
      () => computeLab([short], const LabParams(instrumentIds: [1], weights: [1])),
      throwsA(isA<LabDataError>()),
    );
  });
}
