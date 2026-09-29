import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'portfolio_detail_page.dart' show txnKindLabel;

Future<void> showAddTransactionSheet(BuildContext context, String portfolioId) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _AddTransactionSheet(portfolioId: portfolioId),
    );

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet({required this.portfolioId});
  final String portfolioId;

  @override
  ConsumerState<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _form = GlobalKey<FormState>();
  TxnKind _kind = TxnKind.buy;
  Instrument? _instrument;
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _fee = TextEditingController(text: '0');
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _busy = false;

  bool get _needsInstrument => _kind == TxnKind.buy || _kind == TxnKind.sell || _kind == TxnKind.dividend;
  bool get _isTrade => _kind == TxnKind.buy || _kind == TxnKind.sell;

  @override
  void dispose() {
    for (final c in [_qty, _price, _fee, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefillPrice(Instrument? inst) {
    if (inst == null || !_isTrade) return;
    final p = ref.read(effectivePricesProvider).value?[inst.id];
    if (p != null) _price.text = p.toStringAsFixed(p >= 1000 ? 2 : 4);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      await ref.read(portfolioRepositoryProvider).addTransaction(Txn(
            id: '',
            portfolioId: widget.portfolioId,
            kind: _kind,
            instrumentId: _needsInstrument ? _instrument!.id : null,
            quantity: _isTrade ? parseDecimal(_qty.text)! : 0,
            price: parseDecimal(_price.text)!,
            fee: parseDecimal(_fee.text) ?? 0,
            executedAt: _date,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ));
      ref.invalidate(transactionsProvider(widget.portfolioId));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showSnack(context, l.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _positive(String? v) {
    final d = parseDecimal(v ?? '');
    return d == null || d <= 0 ? context.l10n.invalidNumber : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final instruments = ref.watch(instrumentsProvider).value ?? const [];
    final tradable = instruments.where((i) => i.type != InstrumentType.inflation && i.type != InstrumentType.rate).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Text(l.addTransaction, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in TxnKind.values)
              ChoiceChip(
                label: Text(txnKindLabel(l, k)),
                selected: _kind == k,
                onSelected: (_) => setState(() => _kind = k),
              ),
          ]),
          const SizedBox(height: 16),
          if (_needsInstrument) ...[
            DropdownMenu<Instrument>(
              expandedInsets: EdgeInsets.zero,
              enableFilter: true,
              requestFocusOnTap: true,
              label: Text(l.instrument),
              initialSelection: _instrument,
              onSelected: (i) => setState(() {
                _instrument = i;
                _prefillPrice(i);
              }),
              dropdownMenuEntries: [
                for (final i in tradable) DropdownMenuEntry(value: i, label: i.symbol, labelWidget: Text('${i.symbol} · ${i.name}', overflow: TextOverflow.ellipsis)),
              ],
            ),
            if (_instrument == null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(l.selectInstrument, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
          ],
          if (_isTrade) ...[
            TextFormField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.quantity),
              validator: _positive,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: _isTrade ? l.unitPrice : l.amount, suffixText: '₺'),
            validator: _positive,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _fee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.fee, suffixText: '₺'),
                validator: (v) => (parseDecimal(v ?? '') ?? -1) < 0 ? l.invalidNumber : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(Fmt.of(context).date(_date)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _note, maxLength: 500, decoration: InputDecoration(labelText: l.note)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || (_needsInstrument && _instrument == null) ? null : _save,
            child: Text(l.save),
          ),
        ]),
      ),
    );
  }
}
