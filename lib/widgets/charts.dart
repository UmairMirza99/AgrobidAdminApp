import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// One labelled value for a chart.
class ChartDatum {
  const ChartDatum(this.label, this.value, [this.color]);

  final String label;
  final num value;
  final Color? color;
}

Color _colorAt(List<ChartDatum> data, int i) => data[i].color ?? AppColors.chart[i % AppColors.chart.length];

/// Headline metric: icon tile, big value, label and a short caption underneath.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, required this.icon, this.caption, this.color = AppColors.primary, this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Card wrapper for a chart: title, optional subtitle and trailing action.
class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title, this.subtitle, this.trailing, required this.child, this.height = 260});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }
}

class ChartEmpty extends StatelessWidget {
  const ChartEmpty(this.message, {super.key, this.icon = Icons.insert_chart_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: AppColors.border),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.data, {this.compact = false});

  final List<ChartDatum> data;

  /// Two columns of label + value, for the narrow layout under the donut.
  final bool compact;

  static const compactRowHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<num>(0, (sum, d) => sum + d.value);
    Widget dot(int i) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: _colorAt(data, i), borderRadius: BorderRadius.circular(3)),
    );
    if (compact) {
      return LayoutBuilder(
        builder: (context, c) => Wrap(
          children: [
            for (var i = 0; i < data.length; i++)
              SizedBox(
                width: c.maxWidth / 2,
                height: compactRowHeight,
                child: Row(
                  children: [
                    dot(i),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(data[i].label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                    ),
                    const SizedBox(width: 6),
                    Text(fmtNum(data[i].value), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < data.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                dot(i),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(data[i].label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                ),
                Text(fmtNum(data[i].value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(
                  width: 48,
                  child: Text(
                    total == 0 ? '' : '${(data[i].value / total * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Donut with the total in the middle and a legend beside it (below it when narrow).
class DonutChart extends StatefulWidget {
  const DonutChart({super.key, required this.data, this.centerLabel = 'Total', this.emptyMessage = 'No data yet'});

  final List<ChartDatum> data;
  final String centerLabel;
  final String emptyMessage;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  /// Index into widget.data of the hovered slice, or -1.
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final total = data.fold<num>(0, (sum, d) => sum + d.value);
    if (total == 0) return ChartEmpty(widget.emptyMessage, icon: Icons.donut_large);
    // Zero values get no slice, so map slice positions back to data positions.
    final shown = [
      for (var i = 0; i < data.length; i++)
        if (data[i].value > 0) i,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth >= 380;
        final legendHeight = side ? 0.0 : (data.length / 2).ceil() * _Legend.compactRowHeight + 16;
        final size = math.max(80.0, math.min(side ? constraints.maxWidth * 0.48 : constraints.maxWidth, constraints.maxHeight - legendHeight));
        final radius = size / 2;
        final focused = _touched >= 0 && _touched < data.length;
        final donut = SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: radius * 0.62,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final slice = event.isInterestedForInteractions ? response?.touchedSection?.touchedSectionIndex ?? -1 : -1;
                      final index = slice >= 0 && slice < shown.length ? shown[slice] : -1;
                      if (index != _touched) setState(() => _touched = index);
                    },
                  ),
                  sections: [for (final i in shown) PieChartSectionData(value: data[i].value.toDouble(), color: _colorAt(data, i), radius: radius * (i == _touched ? 0.42 : 0.36), showTitle: false)],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fmtNum(focused ? data[_touched].value : total), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(focused ? data[_touched].label : widget.centerLabel, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        );
        return side
            ? Row(
                children: [
                  donut,
                  const SizedBox(width: 24),
                  Expanded(child: _Legend(data)),
                ],
              )
            : Column(
                children: [
                  Center(child: donut),
                  const SizedBox(height: 16),
                  _Legend(data, compact: true),
                ],
              );
      },
    );
  }
}

/// Horizontal bars with labels on the left and values on the right; good for status breakdowns.
class HorizontalBars extends StatelessWidget {
  const HorizontalBars({super.key, required this.data, this.emptyMessage = 'No data yet', this.valueFormat});

  final List<ChartDatum> data;
  final String emptyMessage;
  final String Function(num value)? valueFormat;

  @override
  Widget build(BuildContext context) {
    final max = data.fold<num>(0, (m, d) => math.max(m, d.value));
    if (max == 0) return ChartEmpty(emptyMessage, icon: Icons.bar_chart);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < data.length; i++)
          Row(
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  data[i].label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(color: AppColors.tableHeader, borderRadius: BorderRadius.circular(6)),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        height: 12,
                        width: c.maxWidth * (data[i].value / max),
                        decoration: BoxDecoration(color: _colorAt(data, i), borderRadius: BorderRadius.circular(6)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  valueFormat?.call(data[i].value) ?? fmtNum(data[i].value),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Vertical bar chart with a light grid and hover tooltips.
class VerticalBars extends StatelessWidget {
  const VerticalBars({super.key, required this.data, this.emptyMessage = 'No data yet', this.valueFormat, this.barWidth = 28});

  final List<ChartDatum> data;
  final String emptyMessage;
  final String Function(num value)? valueFormat;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final max = data.fold<num>(0, (m, d) => math.max(m, d.value));
    if (max == 0) return ChartEmpty(emptyMessage, icon: Icons.bar_chart);
    final scale = _niceScale(max.toDouble());
    final top = scale.top;
    final format = valueFormat ?? fmtNum;
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = (constraints.maxWidth - 52) / data.length;
        return BarChart(
          BarChartData(
            maxY: top,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: scale.interval,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  interval: scale.interval,
                  getTitlesWidget: (v, meta) => Text(_compact(v), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: slot - 4,
                        child: Text(
                          data[i].label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.text,
                tooltipBorderRadius: BorderRadius.circular(6),
                getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                  '${data[group.x].label}\n',
                  const TextStyle(color: Colors.white70, fontSize: 12),
                  children: [
                    TextSpan(
                      text: format(data[group.x].value),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].value.toDouble(),
                      color: _colorAt(data, i),
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: top, color: AppColors.tableHeader),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One line on a [TrendChart].
class TrendSeries {
  const TrendSeries(this.label, this.values, this.color);

  final String label;
  final List<num> values;
  final Color color;
}

/// Smooth area/line chart over [xLabels] (for example, one label per day), with a legend on top.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.xLabels, required this.series, this.labelEvery = 5});

  final List<String> xLabels;
  final List<TrendSeries> series;
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    final max = series.expand((s) => s.values).fold<num>(0, (m, v) => math.max(m, v));
    final scale = _niceScale(max.toDouble());
    final top = scale.top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            for (final s in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text('${s.label} (${fmtNum(s.values.fold<num>(0, (a, b) => a + b))})', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: top,
              minX: 0,
              maxX: (xLabels.length - 1).toDouble(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: scale.interval,
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: scale.interval,
                    getTitlesWidget: (v, meta) => Text(_compact(v), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (v != i || i < 0 || i >= xLabels.length || (xLabels.length - 1 - i) % labelEvery != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(xLabels[i], style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.text,
                  tooltipBorderRadius: BorderRadius.circular(6),
                  getTooltipItems: (spots) => [
                    for (final spot in spots)
                      LineTooltipItem(
                        '${spot.barIndex == 0 ? '${xLabels[spot.x.toInt()]}\n' : ''}${series[spot.barIndex].label}: ${fmtNum(spot.y)}',
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                for (final s in series)
                  LineChartBarData(
                    spots: [for (var i = 0; i < s.values.length; i++) FlSpot(i.toDouble(), s.values[i].toDouble())],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: s.color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [s.color.withValues(alpha: 0.22), s.color.withValues(alpha: 0)]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A readable axis: 4 or 5 gridlines on round steps (1, 2, 2.5 or 5 times a power of ten), whole numbers for counts.
({double top, double interval}) _niceScale(double max, {bool whole = true}) {
  final raw = math.max(max, whole ? 4.0 : 1.0) / 4;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  var interval = 10 * magnitude;
  for (final step in [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (step * magnitude >= raw) {
      interval = step * magnitude;
      break;
    }
  }
  if (whole) interval = math.max(1, interval.ceilToDouble());
  // One step of headroom above the tallest value.
  return (top: ((max / interval).floor() + 1) * interval, interval: interval);
}

String _compact(double v) {
  if (v >= 1000000) return '${fmtNum((v / 1000000 * 10).round() / 10)}M';
  if (v >= 1000) return '${fmtNum((v / 1000 * 10).round() / 10)}k';
  return fmtNum(v.round());
}
