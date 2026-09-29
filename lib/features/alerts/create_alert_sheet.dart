import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

String alertConditionLabel(AppLocalizations l, AlertCondition c) => switch (c) {
      AlertCondition.above => l.alertAbove,
      AlertCondition.below => l.alertBelow,
      AlertCondition.pctChangeUp => l.alertPctUp,
      AlertCondition.pctChangeDown => l.alertPctDown,
    };

Future<void> showCreateAlertSheet(BuildContext context, Instrument inst, double? lastPrice) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateAlertSheet(instrument: inst, lastPrice: lastPrice),
    );

class _CreateAlertSheet extends ConsumerStatefulWidget {
  const _CreateAlertSheet({required this.instrument, this.lastPrice});
  final Instrument instrument;
  final double? lastPrice;

  @override
  ConsumerState<_CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends ConsumerState<_CreateAlertSheet> {
  AlertCondition _condition = AlertCondition.above;
  late final _ctrl = TextEditingController(text: widget.lastPrice?.toStringAsFixed(2) ?? '');
  bool _busy = false;

  bool get _isPct =>
      _condition == AlertCondition.pctChangeUp || _condition == AlertCondition.pctChangeDown;

  Future<void> _save() async {
    final l = context.l10n;
    final v = parseDecimal(_ctrl.text);
    if (v == null || v <= 0) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider)!.createAlert(widget.instrument.id, _condition, v);
      ref.invalidate(alertsProvider);
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, l.alertCreated);
      }
    } catch (_) {
      if (mounted) showSnack(context, l.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${widget.instrument.symbol} — ${l.createAlert}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        DropdownButtonFormField<AlertCondition>(
          initialValue: _condition,
          items: [
            for (final c in AlertCondition.values)
              DropdownMenuItem(value: c, child: Text(alertConditionLabel(l, c))),
          ],
          onChanged: (c) => setState(() {
            _condition = c!;
            _ctrl.text = _isPct ? '3' : widget.lastPrice?.toStringAsFixed(2) ?? '';
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _isPct ? l.percentThreshold : l.priceThreshold,
            suffixText: _isPct ? '%' : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(l.alertEodNote, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
      ]),
    );
  }
}
