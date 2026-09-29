import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quant_dart/quant_dart.dart';

import '../../core/providers.dart';
import '../../data/models.dart';

/// Bir portföyün işlemlerinden hesaplanan defter + güncel değerleme.
class PortfolioSummary {
  const PortfolioSummary({required this.ledger, required this.valuation, required this.error});

  final Ledger? ledger;
  final PortfolioValuation? valuation;

  /// Tutarsız işlem geçmişi (ör. eldekinden fazla satış) — kullanıcıya gösterilir.
  final String? error;

  static int instrumentIdOf(String key) => int.parse(key);
}

LedgerTxn toLedgerTxn(Txn t) => LedgerTxn(
      kind: t.kind,
      executedAt: t.executedAt,
      instrument: t.instrumentId?.toString(),
      quantity: t.quantity,
      price: t.price,
      fee: t.fee,
      fxRate: t.fxRate,
    );

final portfolioSummaryProvider =
    FutureProvider.family<PortfolioSummary, String>((ref, portfolioId) async {
  final txns = await ref.watch(transactionsProvider(portfolioId).future);
  final prices = await ref.watch(effectivePricesProvider.future);
  try {
    final ledger = Ledger.fromTransactions(txns.map(toLedgerTxn));
    final valuation = ledger.value({for (final e in prices.entries) '${e.key}': e.value});
    return PortfolioSummary(ledger: ledger, valuation: valuation, error: null);
  } on LedgerError catch (e) {
    return PortfolioSummary(ledger: null, valuation: null, error: e.message);
  }
});
