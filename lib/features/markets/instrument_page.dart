import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../alerts/create_alert_sheet.dart';
import '../lab/lab_page.dart';
import 'price_chart.dart';

enum ChartRange { m1, m3, y1, y5 }

extension on ChartRange {
  Duration get span => switch (this) {
        ChartRange.m1 => const Duration(days: 31),
        ChartRange.m3 => const Duration(days: 92),
        ChartRange.y1 => const Duration(days: 366),
        ChartRange.y5 => const Duration(days: 5 * 366),
      };

  String label(AppLocalizations l) => switch (this) {
        ChartRange.m1 => l.range1m,
        ChartRange.m3 => l.range3m,
        ChartRange.y1 => l.range1y,
        ChartRange.y5 => l.range5y,
      };
}

class InstrumentPage extends ConsumerStatefulWidget {
  const InstrumentPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<InstrumentPage> createState() => _InstrumentPageState();
}

class _InstrumentPageState extends ConsumerState<InstrumentPage> {
  ChartRange _range = ChartRange.y1;
  // Sağlayıcı anahtarı sabit kalsın diye gün başına yuvarlanır.
  final _today = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final inst = ref.watch(instrumentByIdProvider(widget.id));
    if (inst == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final quote = ref.watch(quotesProvider).value?[inst.id];
    final hasAccount = ref.watch(accountRepositoryProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(inst.symbol),
        actions: [
          if (!inst.isManual && hasAccount)
            IconButton(
              tooltip: l.createAlert,
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: () => showCreateAlertSheet(context, inst, quote?.close),
            ),
        ],
      ),
      body: ListView(children: [
        _Header(instrument: inst, quote: quote),
        if (inst.isManual)
          _ManualPriceCard(instrument: inst)
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Consumer(builder: (context, ref, _) {
              final hist = ref.watch(historyProvider(
                  (id: inst.id, from: _today.subtract(_range.span), maxPoints: 300)));
              return AsyncView(
                value: hist,
                onRetry: () => ref.invalidate(historyProvider),
                data: (pts) => PriceChart(points: pts),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<ChartRange>(
              segments: [
                for (final r in ChartRange.values) ButtonSegment(value: r, label: Text(r.label(l))),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
              showSelectedIcon: false,
            ),
          ),
          _AnalyticsSection(instrument: inst),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.science_outlined),
              label: Text(l.sendToLab),
              onPressed: () => context.go('/lab', extra: LabSeed(weights: {inst.id: 1})),
            ),
          ),
        ],
        DisclaimerNote(
          text: [
            if (inst.attribution != null) l.sourceLabel(inst.attribution!),
            if (quote != null) l.asOf(Fmt.of(context).date(quote.asOf)),
            l.disclaimerShort,
          ].join(' · '),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.instrument, this.quote});
  final Instrument instrument;
  final Quote? quote;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(instrument.name, style: t.bodyLarge),
        if (quote != null) ...[
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.of(context).price(quote!.close), style: t.headlineMedium?.merge(tabular)),
            const SizedBox(width: 8),
            if (quote!.changePct != null) ChangeChip(ratio: quote!.changePct! / 100),
          ]),
        ],
      ]),
    );
  }
}

class _AnalyticsSection extends ConsumerWidget {
  const _AnalyticsSection({required this.instrument});
  final Instrument instrument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final a = ref.watch(analyticsProvider(instrument.id)).value;
    if (a == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(l.analyticsTitle),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: MetricGrid(children: [
          if (a.hurst != null)
            MetricTile(label: l.hurst, value: f.number(a.hurst!), hint: regimeLabel(l, a.regime)),
          if (a.vol1y != null) MetricTile(label: l.volatility1y, value: f.pct(a.vol1y!)),
          if (a.return1y != null)
            MetricTile(
                label: l.return1y,
                value: f.pct(a.return1y!, signed: true),
                valueColor: changeColor(context, a.return1y!)),
          if (a.maxDd1y != null) MetricTile(label: l.maxDrawdown, value: f.pct(-a.maxDd1y!)),
        ]),
      ),
      const SizedBox(height: 12),
    ]);
  }
}

String regimeLabel(AppLocalizations l, String? regime) => switch (regime) {
      'trending' => l.regimeTrending,
      'mean_reverting' => l.regimeMeanReverting,
      _ => l.regimeRandomWalk,
    };

class _ManualPriceCard extends ConsumerWidget {
  const _ManualPriceCard({required this.instrument});
  final Instrument instrument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final price = ref.watch(manualPricesProvider).value?[instrument.id];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.manualPriceHint),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(
                  price == null ? '—' : Fmt.of(context).price(price),
                  style: Theme.of(context).textTheme.headlineSmall?.merge(tabular),
                ),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.enterPrice),
                onPressed: () => editManualPrice(context, ref, instrument, price),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

Future<void> editManualPrice(BuildContext context, WidgetRef ref, Instrument inst, double? current) async {
  final l = context.l10n;
  final ctrl = TextEditingController(text: current?.toString() ?? '');
  final value = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${inst.symbol} — ${l.yourPrice}'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: l.unitPrice, suffixText: '₺'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, parseDecimal(ctrl.text)),
          child: Text(l.save),
        ),
      ],
    ),
  );
  if (value == null || value <= 0) return;
  await ref.read(portfolioRepositoryProvider).setManualPrice(inst.id, value);
  ref.invalidate(manualPricesProvider);
}
