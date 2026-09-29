import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import 'create_alert_sheet.dart';

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final account = ref.watch(accountRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.alertsTitle)),
      body: account == null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.alertsNeedBackend)))
          : AsyncView(
              value: ref.watch(alertsProvider),
              onRetry: () => ref.invalidate(alertsProvider),
              data: (alerts) {
                if (alerts.isEmpty) {
                  return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.noAlerts)));
                }
                final f = Fmt.of(context);
                return ListView(children: [
                  for (final a in alerts)
                    Dismissible(
                      key: ValueKey(a.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) async {
                        await account.deleteAlert(a.id);
                        ref.invalidate(alertsProvider);
                      },
                      child: SwitchListTile(
                        title: Text(ref.watch(instrumentByIdProvider(a.instrumentId))?.symbol ?? '#${a.instrumentId}'),
                        subtitle: Text('${alertConditionLabel(l, a.condition)}: ${f.number(a.threshold)}'
                            '${a.lastTriggeredAt != null ? ' · ${l.lastTriggered(f.date(a.lastTriggeredAt!))}' : ''}'),
                        value: a.isActive,
                        onChanged: (v) async {
                          await account.setAlertActive(a.id, v);
                          ref.invalidate(alertsProvider);
                        },
                      ),
                    ),
                  DisclaimerNote(text: l.alertEodNote),
                ]);
              },
            ),
    );
  }
}
