import 'dart:isolate';
import 'dart:typed_data';

import 'package:quant_dart/quant_dart.dart';

import '../../data/market_repository.dart';
import '../../data/models.dart';

class LabParams {
  const LabParams({
    required this.instrumentIds,
    required this.weights,
    this.horizon = 252,
    this.nSims = 5000,
    this.jumps = false,
    this.riskFree = 0.40,
    this.initial = 100000,
    this.sentiment = 0,
    this.sentimentWeight = 0.3,
    this.lookbackDays = 2 * 365,
  });

  final List<int> instrumentIds;
  final List<double> weights;
  final int horizon;
  final int nSims;
  final bool jumps;
  final double riskFree;
  final double initial;
  final double sentiment;
  final double sentimentWeight;
  final int lookbackDays;
}

class LabResult {
  const LabResult({
    required this.instrumentIds,
    required this.weights,
    required this.commonDays,
    required this.startDate,
    required this.endDate,
    required this.montecarlo,
    required this.backtest,
    required this.hurst,
    required this.optimal,
    required this.minVariance,
    required this.current,
    required this.cloud,
    required this.correlation,
  });

  final List<int> instrumentIds;
  final Float64List weights;
  final int commonDays;
  final DateTime startDate;
  final DateTime endDate;
  final MonteCarloResult montecarlo;
  final BacktestResult backtest;
  final Float64List hurst;
  final Allocation? optimal;
  final Allocation? minVariance;
  final Allocation current;
  final List<FrontierPoint> cloud;
  final List<Float64List> correlation;
}

class LabDataError implements Exception {
  const LabDataError(this.code);

  /// 'no_assets' | 'not_enough_history'
  final String code;
}

/// Seçili varlıkların geçmişini çeker, **tarih bazında** hizalar (yalnızca tüm
/// varlıkların fiyatı olan günler) ve ağır hesapları arka plan isolate'inde yapar.
Future<LabResult> runLab(MarketRepository market, LabParams p, {DateTime? today}) async {
  if (p.instrumentIds.isEmpty) throw const LabDataError('no_assets');
  final now = today ?? DateTime.now();
  final from = now.subtract(Duration(days: p.lookbackDays));
  final histories = await Future.wait([
    for (final id in p.instrumentIds) market.history(id, from, maxPoints: 100000),
  ]);
  return Isolate.run(() => computeLab(histories, p));
}

/// Saf hesaplama (testlerde doğrudan çağrılır).
LabResult computeLab(List<List<PricePoint>> histories, LabParams p) {
  final aligned = alignByDate(histories);
  final days = aligned.dates.length;
  if (days < 60) throw const LabDataError('not_enough_history');

  final rets = [for (final s in aligned.closes) logReturns(s)];
  final w = normalizeWeights(p.weights);

  final mc = simulatePortfolio(MonteCarloParams(
    logReturnRows: rets,
    weights: w,
    horizon: p.horizon,
    nSims: p.nSims,
    initial: p.initial,
    jumps: p.jumps,
    sentiment: p.sentiment,
    sentimentWeight: p.sentimentWeight,
    seed: 42,
  ));
  final bt = backtest(rets, w, riskFree: p.riskFree);
  final meanCov = MeanCov.fromLogReturns(rets);
  final multi = rets.length > 1;

  return LabResult(
    instrumentIds: p.instrumentIds,
    weights: w,
    commonDays: days,
    startDate: aligned.dates.first,
    endDate: aligned.dates.last,
    montecarlo: mc,
    backtest: bt,
    hurst: Float64List.fromList([for (final r in rets) hurstRS(r)]),
    optimal: multi ? maxSharpe(meanCov, riskFree: p.riskFree) : null,
    minVariance: multi ? minVariance(meanCov, riskFree: p.riskFree) : null,
    current: meanCov.allocation(w, p.riskFree),
    cloud: multi ? randomPortfolios(meanCov, count: 800, riskFree: p.riskFree) : const [],
    correlation: correlation(rets),
  );
}

class AlignedSeries {
  const AlignedSeries(this.dates, this.closes);
  final List<DateTime> dates;
  final List<Float64List> closes;
}

/// Ortak tarihlerin kesişimi. Kripto (7/24) ile döviz/endeks (iş günü) birlikte
/// seçildiğinde hafta sonu kripto verileri atılır; getiriler aynı günlere denk gelir.
AlignedSeries alignByDate(List<List<PricePoint>> histories) {
  if (histories.isEmpty) return const AlignedSeries([], []);
  DateTime day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final maps = [
    for (final h in histories) {for (final p in h) day(p.date): p.close},
  ];
  final common = maps.first.keys.where((d) => maps.every((m) => m.containsKey(d))).toList()..sort();
  return AlignedSeries(common, [
    for (final m in maps) Float64List.fromList([for (final d in common) m[d]!]),
  ]);
}
