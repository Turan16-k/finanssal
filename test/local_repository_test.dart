import 'package:flutter_test/flutter_test.dart';
import 'package:fraktal/data/models.dart';
import 'package:fraktal/data/portfolio_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalPortfolioRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalPortfolioRepository(await SharedPreferences.getInstance());
  });

  test('portföy oluştur, işlem ekle, sil', () async {
    final p = await repo.createPortfolio('Emeklilik');
    expect((await repo.portfolios()).single.name, 'Emeklilik');

    await repo.addTransaction(Txn(
      id: '',
      portfolioId: p.id,
      kind: TxnKind.buy,
      instrumentId: 14,
      quantity: 10,
      price: 300,
      executedAt: DateTime(2026, 1, 2),
    ));
    await repo.addTransaction(Txn(
      id: '',
      portfolioId: p.id,
      kind: TxnKind.deposit,
      price: 5000,
      executedAt: DateTime(2026, 1, 1),
    ));
    final txns = await repo.transactions(p.id);
    expect(txns.map((t) => t.kind), [TxnKind.deposit, TxnKind.buy]); // tarih sıralı
    expect(txns.map((t) => t.id).toSet().length, 2);

    await repo.deleteTransaction(txns.first.id);
    expect((await repo.transactions(p.id)).single.kind, TxnKind.buy);

    await repo.deletePortfolio(p.id);
    expect(await repo.portfolios(), isEmpty);
    expect(await repo.transactions(p.id), isEmpty);
  });

  test('manuel fiyatlar', () async {
    await repo.setManualPrice(14, 312.5);
    await repo.setManualPrice(15, 120);
    await repo.setManualPrice(14, 315);
    expect(await repo.manualPrices(), {14: 315, 15: 120});
    await repo.clear();
    expect(await repo.manualPrices(), isEmpty);
  });
}
