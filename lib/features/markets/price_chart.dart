import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models.dart';

/// Tek serili fiyat grafiği; dokunmada tarih + fiyat gösterir.
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.points, this.height = 220});
  final List<PricePoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return SizedBox(height: height);
    final scheme = Theme.of(context).colorScheme;
    final f = Fmt.of(context);
    final up = points.last.close >= points.first.close;
    final color = up ? Colors.green.shade600 : scheme.error;
    var minY = points.first.close, maxY = minY;
    for (final p in points) {
      if (p.close < minY) minY = p.close;
      if (p.close > maxY) maxY = p.close;
    }
    final pad = (maxY - minY) * 0.08;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${f.date(points[s.x.toInt()].date)}\n${f.price(s.y)}',
                    TextStyle(color: scheme.onInverseSurface),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].close)],
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
