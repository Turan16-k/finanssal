import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'portfolio_summary.dart';

class PortfoliosPage extends ConsumerWidget {
  const PortfoliosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.portfolios)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => createPortfolioDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.newPortfolio),
      ),
      body: AsyncView(
        value: ref.watch(portfoliosProvider),
        onRetry: () => ref.invalidate(portfoliosProvider),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l.noPortfolios, textAlign: TextAlign.center),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  for (final p in list) ...[
                    _PortfolioCard(portfolio: p),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PortfolioCard extends ConsumerWidget {
  const _PortfolioCard({required this.portfolio});
  final Portfolio portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = Fmt.of(context);
    final t = Theme.of(context).textTheme;
    final v = ref.watch(portfolioSummaryProvider(portfolio.id)).value?.valuation;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/portfolio/${portfolio.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(portfolio.name, style: t.titleMedium),
                const SizedBox(height: 4),
                Text(v == null ? '—' : f.money(v.marketValue), style: t.headlineSmall?.merge(tabular)),
              ]),
            ),
            if (v != null && v.costBasis > 0) ChangeChip(ratio: v.unrealizedPct),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

Future<void> createPortfolioDialog(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final ctrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.newPortfolio),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(labelText: l.portfolioName),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(l.save)),
      ],
    ),
  );
  if (name == null || name.trim().isEmpty) return;
  try {
    final p = await ref.read(portfolioRepositoryProvider).createPortfolio(name.trim());
    ref.invalidate(portfoliosProvider);
    if (context.mounted) context.go('/portfolio/${p.id}');
  } catch (_) {
    if (context.mounted) showSnack(context, l.errorGeneric);
  }
}
