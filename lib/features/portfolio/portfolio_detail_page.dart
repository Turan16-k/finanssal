import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quant_dart/quant_dart.dart' show Position;

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../lab/lab_page.dart';
import '../markets/instrument_page.dart' show editManualPrice;
import 'add_transaction_sheet.dart';
import 'portfolio_summary.dart';

String txnKindLabel(AppLocalizations l, TxnKind k) => switch (k) {
      TxnKind.buy => l.txBuy,
      TxnKind.sell => l.txSell,
      TxnKind.dividend => l.txDividend,
      TxnKind.fee => l.txFee,
      TxnKind.deposit => l.txDeposit,
      TxnKind.withdraw => l.txWithdraw,
    };

class PortfolioDetailPage extends ConsumerWidget {
  const PortfolioDetailPage({super.key, required this.portfolioId});
  final String portfolioId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Portfolio p) async {
    final l = context.l10n;
    final ok = await confirmDialog(context,
        title: l.delete, message: l.deletePortfolioConfirm(p.name), destructive: true, confirmLabel: l.delete);
    if (!ok) return;
    await ref.read(portfolioRepositoryProvider).deletePortfolio(p.id);
    ref.invalidate(portfoliosProvider);
    if (context.mounted) context.go('/portfolio');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final portfolio = ref
        .watch(portfoliosProvider)
        .value
        ?.where((p) => p.id == portfolioId)
        .firstOrNull;
    final summary = ref.watch(portfolioSummaryProvider(portfolioId));
    final txns = ref.watch(transactionsProvider(portfolioId));

    return Scaffold(
      appBar: AppBar(
        title: Text(portfolio?.name ?? ''),
        actions: [
          if (portfolio != null)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'delete' ? _delete(context, ref, portfolio) : null,
              itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(l.delete))],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddTransactionSheet(context, portfolioId),
        icon: const Icon(Icons.add),
        label: Text(l.addTransaction),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(transactionsProvider(portfolioId));
          ref.invalidate(quotesProvider);
          ref.invalidate(manualPricesProvider);
          await ref.read(portfolioSummaryProvider(portfolioId).future);
        },
        child: AsyncView(
          value: summary,
          onRetry: () => ref.invalidate(transactionsProvider(portfolioId)),
          data: (s) => ListView(padding: const EdgeInsets.only(bottom: 96), children: [
            if (s.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(l.ledgerError(s.error!)),
                  ),
                ),
              ),
            if (s.valuation != null) _Summary(summary: s),
            if (s.ledger != null && s.ledger!.openPositions.isNotEmpty) ...[
              SectionHeader(l.positions,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: Text(l.sendToLab),
                    onPressed: () => context.go('/lab',
                        extra: LabSeed(weights: {
                          for (final e in s.valuation!.weights.entries)
                            PortfolioSummary.instrumentIdOf(e.key): e.value,
                        })),
                  )),
              _AllocationChart(weights: s.valuation!.weights),
              for (final p in s.ledger!.openPositions) _PositionTile(position: p),
            ],
            SectionHeader(l.transactions),
            AsyncView(
              value: txns,
              data: (list) => list.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text(l.noTransactions))
                  : Column(children: [
                      for (final t in list.reversed) _TxnTile(txn: t, portfolioId: portfolioId),
                    ]),
            ),
            const DisclaimerNote(),
          ]),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final v = summary.valuation!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.marketValue, style: Theme.of(context).textTheme.labelLarge),
        Text(f.money(v.marketValue), style: Theme.of(context).textTheme.displaySmall?.merge(tabular)),
        if (v.missingPrices.isNotEmpty)
          Text(l.priceMissing, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        MetricGrid(children: [
          MetricTile(label: l.costBasis, value: f.money(v.costBasis)),
          MetricTile(
            label: l.unrealizedPnl,
            value: '${f.money(v.unrealizedPnl)} (${f.pct(v.unrealizedPct, signed: true)})',
            valueColor: changeColor(context, v.unrealizedPnl),
          ),
          MetricTile(
            label: l.realizedPnl,
            value: f.money(v.realizedPnl),
            valueColor: changeColor(context, v.realizedPnl),
          ),
          MetricTile(label: l.dividends, value: f.money(v.dividends)),
        ]),
      ]),
    );
  }
}

class _AllocationChart extends StatelessWidget {
  const _AllocationChart({required this.weights});
  final Map<String, double> weights;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [scheme.primary, scheme.tertiary, scheme.secondary, scheme.error,
      scheme.primaryContainer, scheme.tertiaryContainer, scheme.secondaryContainer, scheme.outline];
    final entries = weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Consumer(builder: (context, ref, _) {
      return SizedBox(
        height: 160,
        child: Row(children: [
          Expanded(
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: palette[i % palette.length],
                    radius: 36,
                    showTitle: false,
                  ),
              ],
            )),
          ),
          Expanded(
            child: ListView(shrinkWrap: true, children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Container(width: 10, height: 10, color: palette[i % palette.length]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ref.watch(instrumentByIdProvider(PortfolioSummary.instrumentIdOf(entries[i].key)))?.symbol ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(Fmt.of(context).pct(entries[i].value), style: tabular),
                    const SizedBox(width: 16),
                  ]),
                ),
            ]),
          ),
        ]),
      );
    });
  }
}

class _PositionTile extends ConsumerWidget {
  const _PositionTile({required this.position});
  final Position position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final id = PortfolioSummary.instrumentIdOf(position.instrument);
    final inst = ref.watch(instrumentByIdProvider(id));
    final price = ref.watch(effectivePricesProvider).value?[id];
    return ListTile(
      title: Text(inst?.symbol ?? '#$id', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${l.quantityShort(f.number(position.quantity, decimals: 4))} · '
          '${l.avgCost(f.price(position.averageCost))}'),
      onTap: inst == null
          ? null
          : inst.isManual
              ? () => editManualPrice(context, ref, inst, price)
              : () => context.go('/markets/instrument/$id'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: price == null
            ? [
                Text(l.enterPrice, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ]
            : [
                Text(f.money(position.marketValue(price)), style: tabular),
                ChangeChip(ratio: position.unrealizedPct(price), dense: true),
              ],
      ),
    );
  }
}

class _TxnTile extends ConsumerWidget {
  const _TxnTile({required this.txn, required this.portfolioId});
  final Txn txn;
  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final inst = txn.instrumentId == null ? null : ref.watch(instrumentByIdProvider(txn.instrumentId!));
    final isTrade = txn.kind == TxnKind.buy || txn.kind == TxnKind.sell;
    return Dismissible(
      key: ValueKey(txn.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline),
      ),
      confirmDismiss: (_) => confirmDialog(context,
          title: l.delete, message: l.deleteTransactionConfirm, destructive: true, confirmLabel: l.delete),
      onDismissed: (_) async {
        await ref.read(portfolioRepositoryProvider).deleteTransaction(txn.id);
        ref.invalidate(transactionsProvider(portfolioId));
      },
      child: ListTile(
        dense: true,
        title: Text('${txnKindLabel(l, txn.kind)}${inst != null ? ' · ${inst.symbol}' : ''}'),
        subtitle: Text(f.date(txn.executedAt)),
        trailing: Text(
          isTrade
              ? '${f.number(txn.quantity, decimals: 4)} × ${f.price(txn.price)}'
              : f.money(txn.price),
          style: tabular,
        ),
      ),
    );
  }
}
