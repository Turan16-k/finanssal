import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:quant_dart/quant_dart.dart';

import '../../core/format.dart';

const _noTitles = FlTitlesData(
  topTitles: AxisTitles(),
  rightTitles: AxisTitles(),
);

FlTitlesData _titles(BuildContext context, {required String Function(double) left, String Function(double)? bottom}) {
  final style = Theme.of(context).textTheme.labelSmall;
  return _noTitles.copyWith(
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 52,
        getTitlesWidget: (v, meta) => SideTitleWidget(
          meta: meta,
          child: Text(left(v), style: style),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: bottom != null,
        reservedSize: 24,
        getTitlesWidget: (v, meta) => SideTitleWidget(
          meta: meta,
          child: Text(bottom?.call(v) ?? '', style: style),
        ),
      ),
    ),
  );
}

/// Monte Carlo fan grafiği: %5–95 ve %25–75 bantları + medyan.
class FanChart extends StatelessWidget {
  const FanChart({super.key, required this.result, required this.dayLabel});
  final MonteCarloResult result;
  final String Function(int days) dayLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = Fmt.of(context);
    final steps = result.bandSteps;
    List<FlSpot> line(int q) => [
          for (var i = 0; i < steps.length; i++) FlSpot(steps[i].toDouble(), result.bands[q]![i]),
        ];
    LineChartBarData bar(int q, {Color? color, double width = 0}) => LineChartBarData(
          spots: line(q),
          color: color ?? Colors.transparent,
          barWidth: width,
          dotData: const FlDotData(show: false),
        );
    final bars = [
      bar(5),
      bar(95),
      bar(25),
      bar(75),
      bar(50, color: scheme.primary, width: 2.5),
    ];
    return SizedBox(
      height: 240,
      child: LineChart(LineChartData(
        lineBarsData: bars,
        betweenBarsData: [
          BetweenBarsData(fromIndex: 0, toIndex: 1, color: scheme.primary.withValues(alpha: 0.12)),
          BetweenBarsData(fromIndex: 2, toIndex: 3, color: scheme.primary.withValues(alpha: 0.22)),
        ],
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: result.initial,
            color: scheme.outline,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ]),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context, left: f.compact, bottom: (v) => v == 0 ? '' : dayLabel(v.toInt())),
        lineTouchData: const LineTouchData(enabled: false),
      )),
    );
  }
}

/// Backtest değer eğrisi (1.0 = başlangıç).
class EquityChart extends StatelessWidget {
  const EquityChart({super.key, required this.equity});
  final List<double> equity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = Fmt.of(context);
    final step = (equity.length / 300).ceil().clamp(1, 1 << 20);
    final spots = <FlSpot>[
      const FlSpot(0, 1),
      for (var i = 0; i < equity.length; i += step) FlSpot((i + 1).toDouble(), equity[i]),
      FlSpot(equity.length.toDouble(), equity.last),
    ];
    return SizedBox(
      height: 200,
      child: LineChart(LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: scheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: scheme.primary.withValues(alpha: 0.08)),
          ),
        ],
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context, left: (v) => f.pct(v - 1, decimals: 0)),
        lineTouchData: const LineTouchData(enabled: false),
      )),
    );
  }
}

/// Etkin sınır: rastgele portföy bulutu + mevcut / optimal / min-varyans noktaları.
class FrontierChart extends StatelessWidget {
  const FrontierChart({
    super.key,
    required this.cloud,
    required this.current,
    this.optimal,
    this.minVariance,
  });

  final List<FrontierPoint> cloud;
  final Allocation current;
  final Allocation? optimal;
  final Allocation? minVariance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = Fmt.of(context);
    ScatterSpot spot(double x, double y, Color c, double r) =>
        ScatterSpot(x, y, dotPainter: FlDotCirclePainter(radius: r, color: c, strokeWidth: 0));
    return SizedBox(
      height: 260,
      child: ScatterChart(ScatterChartData(
        scatterSpots: [
          for (final p in cloud) spot(p.volatility, p.expectedReturn, scheme.outlineVariant, 2),
          if (minVariance != null)
            spot(minVariance!.volatility, minVariance!.expectedReturn, scheme.secondary, 6),
          spot(current.volatility, current.expectedReturn, scheme.tertiary, 7),
          if (optimal != null) spot(optimal!.volatility, optimal!.expectedReturn, scheme.primary, 8),
        ],
        gridData: const FlGridData(),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context,
            left: (v) => f.pct(v, decimals: 0), bottom: (v) => f.pct(v, decimals: 0)),
        scatterTouchData: ScatterTouchData(enabled: false),
      )),
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});
  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 16, runSpacing: 4, children: [
        for (final (c, label) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ]),
      ]);
}
