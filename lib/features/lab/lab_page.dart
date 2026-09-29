import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quant_dart/quant_dart.dart' show Allocation;

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../markets/instrument_page.dart' show regimeLabel;
import 'bulletin_card.dart';
import 'lab_charts.dart';
import 'lab_engine.dart';

/// Başka ekrandan laboratuvara gönderilen başlangıç ağırlıkları (instrumentId -> ağırlık).
class LabSeed {
  const LabSeed({required this.weights});
  final Map<int, double> weights;
}

enum LabView { simulation, frontier, backtest, fractal }

class LabPage extends ConsumerStatefulWidget {
  const LabPage({super.key, this.initial});
  final LabSeed? initial;

  @override
  ConsumerState<LabPage> createState() => _LabPageState();
}

class _LabPageState extends ConsumerState<LabPage> {
  /// Seçim sırası korunur; değer 0..1 ham ağırlık (gösterimde normalize edilir).
  final Map<int, double> _weights = {};
  int _horizon = 252;
  int _sims = 5000;
  bool _jumps = false;
  double _riskFree = 0.40;
  double _initial = 100000;
  double _sentiment = 0;
  bool _applySentiment = false;

  LabView _view = LabView.simulation;
  LabResult? _result;
  Object? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _applySeed(widget.initial);
  }

  @override
  void didUpdateWidget(covariant LabPage old) {
    super.didUpdateWidget(old);
    if (widget.initial != old.initial) _applySeed(widget.initial);
  }

  void _applySeed(LabSeed? seed) {
    if (seed == null) return;
    // Manuel fiyatlı varlıkların geçmişi yok -> laboratuvara alınmaz.
    final insts = ref.read(instrumentsProvider).value ?? const [];
    final ok = {for (final i in insts.where((i) => i.hasHistory)) i.id};
    setState(() {
      _weights
        ..clear()
        ..addEntries(seed.weights.entries.where((e) => ok.isEmpty || ok.contains(e.key)));
      _result = null;
    });
  }

  Future<void> _pickAssets(List<Instrument> all) async {
    final selected = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _AssetPicker(all: all, selected: _weights.keys.toSet()),
    );
    if (selected == null) return;
    setState(() {
      _weights.removeWhere((id, _) => !selected.contains(id));
      for (final id in selected) {
        _weights.putIfAbsent(id, () => 1);
      }
      _result = null;
    });
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final r = await runLab(
        ref.read(marketRepositoryProvider),
        LabParams(
          instrumentIds: _weights.keys.toList(),
          weights: _weights.values.toList(),
          horizon: _horizon,
          nSims: _sims,
          jumps: _jumps,
          riskFree: _riskFree,
          initial: _initial,
          sentiment: _applySentiment ? _sentiment : 0,
        ),
      );
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _applyWeights(List<double> w) {
    final ids = _result!.instrumentIds;
    setState(() {
      for (var i = 0; i < ids.length; i++) {
        _weights[ids[i]] = w[i];
      }
    });
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final instruments = ref.watch(instrumentsProvider);
    final total = _weights.values.fold<double>(0, (a, b) => a + b);
    final f = Fmt.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.labTitle)),
      body: AsyncView(
        value: instruments,
        onRetry: () => ref.invalidate(instrumentsProvider),
        data: (all) {
          final byId = {for (final i in all) i.id: i};
          final eligible = all.where((i) => i.hasHistory).toList();
          return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(l.labIntro, style: Theme.of(context).textTheme.bodyMedium),
            ),
            SectionHeader(l.assets,
                trailing: TextButton.icon(
                  onPressed: () => _pickAssets(eligible),
                  icon: const Icon(Icons.add),
                  label: Text(l.selectAssets),
                )),
            if (_weights.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l.labEmpty))
            else ...[
              for (final e in _weights.entries)
                _WeightRow(
                  label: byId[e.key]?.symbol ?? '#${e.key}',
                  value: e.value,
                  share: total > 0 ? e.value / total : 0,
                  onChanged: (v) => setState(() => _weights[e.key] = v),
                  onRemove: () => setState(() {
                    _weights.remove(e.key);
                    _result = null;
                  }),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _weights.updateAll((_, _) => 1)),
                  child: Text(l.equalWeights),
                ),
              ),
            ],
            ExpansionTile(
              title: Text(l.parameters),
              subtitle: Text('${l.horizonDays(_horizon)} · ${l.simulationsCount(_sims)}'),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _LabeledSlider(
                  label: l.horizonDays(_horizon),
                  value: _horizon.toDouble(),
                  min: 21,
                  max: 756,
                  divisions: 35,
                  onChanged: (v) => setState(() => _horizon = v.round()),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: [
                    for (final n in const [1000, 5000, 10000])
                      ButtonSegment(value: n, label: Text(f.compact(n.toDouble()))),
                  ],
                  selected: {_sims},
                  onSelectionChanged: (s) => setState(() => _sims = s.first),
                  showSelectedIcon: false,
                ),
                _LabeledSlider(
                  label: '${l.riskFree}: ${f.pct(_riskFree, decimals: 0)}',
                  value: _riskFree,
                  min: 0,
                  max: 0.6,
                  divisions: 60,
                  onChanged: (v) => setState(() => _riskFree = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.jumps),
                  subtitle: Text(l.jumpsHint),
                  value: _jumps,
                  onChanged: (v) => setState(() => _jumps = v),
                ),
                TextFormField(
                  initialValue: _initial.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.initialCapital, suffixText: '₺'),
                  onChanged: (v) {
                    final d = parseDecimal(v);
                    if (d != null && d > 0) _initial = d;
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
            if (ref.watch(accountRepositoryProvider) != null)
              BulletinCard(
                sentiment: _sentiment,
                applied: _applySentiment,
                onResult: (s) => setState(() {
                  _sentiment = s;
                  _applySentiment = true;
                }),
                onToggle: (v) => setState(() => _applySentiment = v),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _weights.isEmpty || _running ? null : _run,
                icon: _running
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                label: Text(_running ? l.running : l.run),
              ),
            ),
            if (_error != null) _ErrorBox(error: _error!),
            if (_result != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<LabView>(
                  segments: [
                    ButtonSegment(value: LabView.simulation, label: Text(l.tabSimulation)),
                    ButtonSegment(value: LabView.frontier, label: Text(l.tabFrontier)),
                    ButtonSegment(value: LabView.backtest, label: Text(l.tabBacktest)),
                    ButtonSegment(value: LabView.fractal, label: Text(l.tabFractal)),
                  ],
                  selected: {_view},
                  onSelectionChanged: (s) => setState(() => _view = s.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  l.dataWindow(_result!.commonDays, f.date(_result!.startDate), f.date(_result!.endDate)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: switch (_view) {
                  LabView.simulation => _SimulationView(result: _result!),
                  LabView.frontier => _FrontierView(result: _result!, byId: byId, onApply: _applyWeights),
                  LabView.backtest => _BacktestView(result: _result!),
                  LabView.fractal => _FractalView(result: _result!, byId: byId),
                },
              ),
            ],
            DisclaimerNote(text: l.labDisclaimer),
          ]);
        },
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final msg = switch (error) {
      LabDataError(code: 'not_enough_history') => l.notEnoughHistory,
      _ => l.errorGeneric,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(padding: const EdgeInsets.all(12), child: Text(msg)),
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({
    required this.label,
    required this.value,
    required this.share,
    required this.onChanged,
    required this.onRemove,
  });

  final String label;
  final double value;
  final double share;
  final ValueChanged<double> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Slider(value: value.clamp(0, 1), onChanged: onChanged)),
          SizedBox(
            width: 52,
            child: Text(Fmt.of(context).pct(share, decimals: 0), textAlign: TextAlign.end, style: tabular),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: context.l10n.delete,
            onPressed: onRemove,
          ),
        ]),
      );
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Text(label),
        Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ]);
}

class _SimulationView extends StatelessWidget {
  const _SimulationView({required this.result});
  final LabResult result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final mc = result.montecarlo;
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MetricGrid(children: [
        MetricTile(
          label: l.expectedValue,
          value: f.money(mc.expectedValue),
          hint: f.pct(mc.expectedValue / mc.initial - 1, signed: true),
        ),
        MetricTile(label: l.median, value: f.money(mc.p50)),
        MetricTile(label: l.var95, value: f.money(mc.var95), hint: l.var95Hint),
        MetricTile(label: l.cvar95, value: f.money(mc.cvar95), hint: l.cvar95Hint),
        MetricTile(label: l.probLoss, value: f.pct(mc.probLoss)),
        MetricTile(label: l.percentileBand, value: '${f.compact(mc.p5)} – ${f.compact(mc.p95)}'),
      ]),
      const SizedBox(height: 16),
      FanChart(result: mc, dayLabel: l.daysShort),
      const SizedBox(height: 8),
      ChartLegend(items: [
        (scheme.primary, l.median),
        (scheme.primary.withValues(alpha: 0.35), l.band25_75),
        (scheme.primary.withValues(alpha: 0.15), l.band5_95),
      ]),
    ]);
  }
}

class _FrontierView extends StatelessWidget {
  const _FrontierView({required this.result, required this.byId, required this.onApply});
  final LabResult result;
  final Map<int, Instrument> byId;
  final ValueChanged<List<double>> onApply;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final scheme = Theme.of(context).colorScheme;
    final opt = result.optimal;
    if (opt == null) return Text(l.needTwoAssets);

    Widget allocationCard(String title, Allocation a, {bool primary = false}) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text('${l.sharpe} ${f.number(a.sharpe)} · ${l.expectedReturnShort} ${f.pct(a.expectedReturn)} · '
                  '${l.volatilityShort} ${f.pct(a.volatility)}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (var i = 0; i < result.instrumentIds.length; i++)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${byId[result.instrumentIds[i]]?.symbol} ${f.pct(a.weights[i], decimals: 0)}'),
                  ),
              ]),
              if (primary)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => onApply(a.weights.toList()), child: Text(l.applyWeights)),
                ),
            ]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FrontierChart(
        cloud: result.cloud,
        current: result.current,
        optimal: opt,
        minVariance: result.minVariance,
      ),
      const SizedBox(height: 8),
      ChartLegend(items: [
        (scheme.primary, l.optimalWeights),
        (scheme.secondary, l.minVariance),
        (scheme.tertiary, l.currentPortfolio),
      ]),
      Text(l.frontierAxes, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      allocationCard(l.optimalWeights, opt, primary: true),
      const SizedBox(height: 8),
      if (result.minVariance != null) allocationCard(l.minVariance, result.minVariance!),
      const SizedBox(height: 8),
      Text(l.optimizerNote, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _BacktestView extends StatelessWidget {
  const _BacktestView({required this.result});
  final LabResult result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final bt = result.backtest;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MetricGrid(children: [
        MetricTile(
            label: l.totalReturn,
            value: f.pct(bt.totalReturn, signed: true),
            valueColor: changeColor(context, bt.totalReturn)),
        MetricTile(label: l.cagr, value: f.pct(bt.cagr, signed: true)),
        MetricTile(label: l.volatility1y, value: f.pct(bt.volatility)),
        MetricTile(label: l.sharpe, value: f.number(bt.sharpe)),
        MetricTile(label: l.maxDrawdown, value: f.pct(-bt.maxDrawdown)),
      ]),
      const SizedBox(height: 16),
      if (bt.equity.isNotEmpty) EquityChart(equity: bt.equity),
      Text(l.backtestNote, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _FractalView extends StatelessWidget {
  const _FractalView({required this.result, required this.byId});
  final LabResult result;
  final Map<int, Instrument> byId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final ids = result.instrumentIds;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.hurstExplainer, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      for (var i = 0; i < ids.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(byId[ids[i]]?.symbol ?? ''),
          subtitle: Text(regimeLabel(l, _regime(result.hurst[i]))),
          trailing: Text('H = ${f.number(result.hurst[i])}', style: tabular),
        ),
      if (ids.length > 1) ...[
        SectionHeader(l.correlation),
        _CorrelationTable(ids: ids, byId: byId, matrix: result.correlation),
      ],
    ]);
  }

  static String _regime(double h) => h > 0.55 ? 'trending' : h < 0.45 ? 'mean_reverting' : 'random_walk';
}

class _CorrelationTable extends StatelessWidget {
  const _CorrelationTable({required this.ids, required this.byId, required this.matrix});
  final List<int> ids;
  final Map<int, Instrument> byId;
  final List<List<double>> matrix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = Fmt.of(context);
    Widget cell(Widget child, {Color? color}) => Container(
          width: 64,
          height: 36,
          alignment: Alignment.center,
          color: color,
          child: child,
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(children: [
        Row(children: [
          cell(const SizedBox()),
          for (final id in ids) cell(Text(byId[id]?.symbol ?? '', style: Theme.of(context).textTheme.labelSmall)),
        ]),
        for (var i = 0; i < ids.length; i++)
          Row(children: [
            cell(Text(byId[ids[i]]?.symbol ?? '', style: Theme.of(context).textTheme.labelSmall)),
            for (var j = 0; j < ids.length; j++)
              cell(
                Text(f.number(matrix[i][j]), style: tabular),
                color: (matrix[i][j] >= 0 ? scheme.primary : scheme.error)
                    .withValues(alpha: (matrix[i][j].abs() * 0.5).clamp(0.05, 0.5)),
              ),
          ]),
      ]),
    );
  }
}

class _AssetPicker extends StatefulWidget {
  const _AssetPicker({required this.all, required this.selected});
  final List<Instrument> all;
  final Set<int> selected;

  @override
  State<_AssetPicker> createState() => _AssetPickerState();
}

class _AssetPickerState extends State<_AssetPicker> {
  late final Set<int> _sel = {...widget.selected};
  static const _max = 12;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: Text(l.selectAssets, style: Theme.of(context).textTheme.titleLarge)),
          FilledButton(onPressed: () => Navigator.pop(context, _sel), child: Text(l.save)),
        ]),
      ),
      Expanded(
        child: ListView(children: [
          for (final i in widget.all)
            CheckboxListTile(
              value: _sel.contains(i.id),
              title: Text(i.symbol),
              subtitle: Text(i.name),
              onChanged: (v) => setState(() {
                if (v == true && _sel.length < _max) {
                  _sel.add(i.id);
                } else {
                  _sel.remove(i.id);
                }
              }),
            ),
        ]),
      ),
    ]);
  }
}
