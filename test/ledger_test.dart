import 'package:quant_dart/quant_dart.dart';
import 'package:test/test.dart';

DateTime d(int day) => DateTime.utc(2026, 1, day);

void main() {
  test('ağırlıklı ortalama maliyet ve gerçekleşmiş K/Z', () {
    final l = Ledger.fromTransactions([
      LedgerTxn(kind: TxnKind.buy, instrument: 'THYAO', quantity: 10, price: 100, fee: 2, executedAt: d(1)),
      LedgerTxn(kind: TxnKind.buy, instrument: 'THYAO', quantity: 10, price: 120, fee: 2, executedAt: d(2)),
      LedgerTxn(kind: TxnKind.sell, instrument: 'THYAO', quantity: 5, price: 150, fee: 1, executedAt: d(3)),
    ]);
    final p = l.positions['THYAO']!;
    // Maliyet: 1000+2 + 1200+2 = 2204 / 20 = 110.2
    expect(p.quantity, 15);
    expect(p.averageCost, closeTo(110.2, 1e-9));
    // Satış: 750 - 1 - 5*110.2 = 198
    expect(p.realizedPnl, closeTo(198, 1e-9));
    // Satış ortalama maliyeti değiştirmez.
    expect(p.averageCost, closeTo(110.2, 1e-9));
    expect(p.unrealizedPnl(130), closeTo(15 * 130 - 15 * 110.2, 1e-9));
    expect(l.totalFees, 5);
  });

  test('işlemler tarih sırasına göre işlenir', () {
    final l = Ledger.fromTransactions([
      LedgerTxn(kind: TxnKind.sell, instrument: 'X', quantity: 1, price: 20, executedAt: d(5)),
      LedgerTxn(kind: TxnKind.buy, instrument: 'X', quantity: 1, price: 10, executedAt: d(1)),
    ]);
    expect(l.realizedPnl, 10);
    expect(l.openPositions, isEmpty);
  });

  test('fazla satış hata verir', () {
    expect(
      () => Ledger.fromTransactions([
        LedgerTxn(kind: TxnKind.buy, instrument: 'X', quantity: 1, price: 10, executedAt: d(1)),
        LedgerTxn(kind: TxnKind.sell, instrument: 'X', quantity: 2, price: 10, executedAt: d(2)),
      ]),
      throwsA(isA<LedgerError>()),
    );
  });

  test('döviz kuru ile portföy para birimine çevrim', () {
    final l = Ledger.fromTransactions([
      LedgerTxn(kind: TxnKind.buy, instrument: 'AAPL', quantity: 2, price: 100, fee: 1, fxRate: 40, executedAt: d(1)),
    ]);
    expect(l.positions['AAPL']!.costBasis, 2 * 100 * 40 + 40);
  });

  test('nakit, temettü ve değerleme', () {
    final l = Ledger.fromTransactions([
      LedgerTxn(kind: TxnKind.deposit, price: 10000, executedAt: d(1)),
      LedgerTxn(kind: TxnKind.buy, instrument: 'A', quantity: 10, price: 500, executedAt: d(2)),
      LedgerTxn(kind: TxnKind.buy, instrument: 'B', quantity: 100, price: 30, executedAt: d(2)),
      LedgerTxn(kind: TxnKind.dividend, instrument: 'A', price: 120, executedAt: d(3)),
      LedgerTxn(kind: TxnKind.fee, price: 20, executedAt: d(4)),
    ]);
    expect(l.cash, 10000 - 5000 - 3000 + 120 - 20);
    expect(l.netDeposits, 10000);
    final v = l.value({'A': 600});
    expect(v.marketValue, 6000 + 3000); // B fiyatsız: maliyetten
    expect(v.missingPrices, ['B']);
    expect(v.unrealizedPnl, 1000);
    expect(v.dividends, 120);
    expect(v.totalPnl, 1120);
    expect(v.weights['A'], closeTo(6000 / 9000, 1e-12));
  });

  test('pozisyon tamamen kapanınca maliyet sıfırlanır', () {
    final l = Ledger.fromTransactions([
      LedgerTxn(kind: TxnKind.buy, instrument: 'X', quantity: 3, price: 10, executedAt: d(1)),
      LedgerTxn(kind: TxnKind.sell, instrument: 'X', quantity: 3, price: 11, executedAt: d(2)),
    ]);
    expect(l.positions['X']!.costBasis, 0);
    expect(l.costBasis, 0);
    expect(l.realizedPnl, closeTo(3, 1e-12));
  });

  test('reel getiri', () {
    expect(realReturn(0.50, 0.40), closeTo(1.5 / 1.4 - 1, 1e-12));
  });
}
