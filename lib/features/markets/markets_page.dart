import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

/// Piyasa sekmeleri: tür grupları.
enum MarketTab { fx, gold, stockIndex, crypto, manual }

extension on MarketTab {
  bool matches(Instrument i) => switch (this) {
        MarketTab.fx => i.type == InstrumentType.fx,
        MarketTab.gold => i.type == InstrumentType.gold,
        MarketTab.stockIndex => i.type == InstrumentType.stockIndex,
        MarketTab.crypto => i.type == InstrumentType.crypto,
        MarketTab.manual => i.isManual,
      };

  String label(AppLocalizations l) => switch (this) {
        MarketTab.fx => l.typeFx,
        MarketTab.gold => l.typeGold,
        MarketTab.stockIndex => l.typeIndex,
        MarketTab.crypto => l.typeCrypto,
        MarketTab.manual => l.typeStocksFunds,
      };
}

class MarketsPage extends ConsumerWidget {
  const MarketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: MarketTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.navMarkets),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in MarketTab.values) Tab(text: t.label(l))],
          ),
        ),
        body: TabBarView(children: [for (final t in MarketTab.values) _MarketList(tab: t)]),
      ),
    );
  }
}

class _MarketList extends ConsumerWidget {
  const _MarketList({required this.tab});
  final MarketTab tab;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(quotesProvider);
    ref.invalidate(manualPricesProvider);
    await ref.read(quotesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instruments = ref.watch(instrumentsProvider);
    final quotes = ref.watch(quotesProvider);
    final manual = ref.watch(manualPricesProvider).value ?? const {};
    return AsyncView(
      value: instruments,
      onRetry: () => ref.invalidate(instrumentsProvider),
      data: (all) {
        final items = all.where(tab.matches).toList();
        final q = quotes.value ?? const {};
        return RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length + (tab == MarketTab.manual ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, i) {
              if (tab == MarketTab.manual && i == 0) {
                return DisclaimerNote(text: context.l10n.manualPriceHint);
              }
              final inst = items[tab == MarketTab.manual ? i - 1 : i];
              return InstrumentTile(instrument: inst, quote: q[inst.id], manualPrice: manual[inst.id]);
            },
          ),
        );
      },
    );
  }
}

class InstrumentTile extends StatelessWidget {
  const InstrumentTile({super.key, required this.instrument, this.quote, this.manualPrice});
  final Instrument instrument;
  final Quote? quote;
  final double? manualPrice;

  @override
  Widget build(BuildContext context) {
    final f = Fmt.of(context);
    final t = Theme.of(context).textTheme;
    final price = quote?.close ?? manualPrice;
    return ListTile(
      onTap: () => context.go('/markets/instrument/${instrument.id}'),
      title: Text(instrument.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(instrument.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(price == null ? '—' : f.price(price), style: t.titleSmall?.merge(tabular)),
          if (quote?.changePct != null)
            ChangeChip(ratio: quote!.changePct! / 100, dense: true)
          else if (instrument.isManual)
            Text(manualPrice == null ? context.l10n.enterPrice : context.l10n.yourPrice,
                style: t.labelSmall),
        ],
      ),
    );
  }
}
