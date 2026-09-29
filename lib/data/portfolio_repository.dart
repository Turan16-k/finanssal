import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Kullanıcının portföyleri, işlemleri ve manuel fiyatları.
abstract interface class PortfolioRepository {
  Future<List<Portfolio>> portfolios();
  Future<Portfolio> createPortfolio(String name);
  Future<void> renamePortfolio(String id, String name);
  Future<void> deletePortfolio(String id);

  Future<List<Txn>> transactions(String portfolioId);
  Future<void> addTransaction(Txn txn);
  Future<void> deleteTransaction(String id);

  /// instrumentId -> kullanıcının girdiği son fiyat (lisanslı veri yerine).
  Future<Map<int, double>> manualPrices();
  Future<void> setManualPrice(int instrumentId, double price);

  /// Yerel veriyi temizler (hesap silme / çıkış).
  Future<void> clear();
}

class SupabasePortfolioRepository implements PortfolioRepository {
  SupabasePortfolioRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<List<Portfolio>> portfolios() async {
    final rows = await _db.from('portfolios').select().order('created_at');
    return rows.map(Portfolio.fromJson).toList();
  }

  @override
  Future<Portfolio> createPortfolio(String name) async {
    final row = await _db.from('portfolios').insert({'name': name}).select().single();
    return Portfolio.fromJson(row);
  }

  @override
  Future<void> renamePortfolio(String id, String name) =>
      _db.from('portfolios').update({'name': name}).eq('id', id);

  @override
  Future<void> deletePortfolio(String id) => _db.from('portfolios').delete().eq('id', id);

  @override
  Future<List<Txn>> transactions(String portfolioId) async {
    final rows = await _db
        .from('transactions')
        .select()
        .eq('portfolio_id', portfolioId)
        .order('executed_at');
    return rows.map(Txn.fromJson).toList();
  }

  @override
  Future<void> addTransaction(Txn txn) => _db.from('transactions').insert(txn.toInsertJson());

  @override
  Future<void> deleteTransaction(String id) => _db.from('transactions').delete().eq('id', id);

  @override
  Future<Map<int, double>> manualPrices() async {
    final rows = await _db.from('manual_prices').select('instrument_id,price');
    return {for (final r in rows) (r['instrument_id'] as num).toInt(): (r['price'] as num).toDouble()};
  }

  @override
  Future<void> setManualPrice(int instrumentId, double price) => _db.from('manual_prices').upsert({
        'instrument_id': instrumentId,
        'price': price,
        'as_of': DateTime.now().toUtc().toIso8601String(),
      });

  @override
  Future<void> clear() async {}
}

/// Demo modu / arka uçsuz kullanım: her şey SharedPreferences'ta JSON olarak durur.
class LocalPortfolioRepository implements PortfolioRepository {
  LocalPortfolioRepository(this._prefs);
  final SharedPreferences _prefs;

  static const _kPortfolios = 'local.portfolios';
  static const _kTxns = 'local.transactions';
  static const _kPrices = 'local.manual_prices';
  final _rand = math.Random.secure();

  String _id() => List.generate(16, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  List<Map<String, dynamic>> _list(String key) =>
      (jsonDecode(_prefs.getString(key) ?? '[]') as List).cast<Map<String, dynamic>>();

  Future<void> _save(String key, Object value) => _prefs.setString(key, jsonEncode(value));

  @override
  Future<List<Portfolio>> portfolios() async => _list(_kPortfolios).map(Portfolio.fromJson).toList();

  @override
  Future<Portfolio> createPortfolio(String name) async {
    final p = Portfolio(id: _id(), name: name, createdAt: DateTime.now());
    await _save(_kPortfolios, [..._list(_kPortfolios), p.toJson()]);
    return p;
  }

  @override
  Future<void> renamePortfolio(String id, String name) => _save(_kPortfolios, [
        for (final p in _list(_kPortfolios)) p['id'] == id ? {...p, 'name': name} : p,
      ]);

  @override
  Future<void> deletePortfolio(String id) async {
    await _save(_kPortfolios, _list(_kPortfolios).where((p) => p['id'] != id).toList());
    await _save(_kTxns, _list(_kTxns).where((t) => t['portfolio_id'] != id).toList());
  }

  @override
  Future<List<Txn>> transactions(String portfolioId) async => _list(_kTxns)
      .where((t) => t['portfolio_id'] == portfolioId)
      .map(Txn.fromJson)
      .toList()
    ..sort((a, b) => a.executedAt.compareTo(b.executedAt));

  @override
  Future<void> addTransaction(Txn txn) => _save(_kTxns, [
        ..._list(_kTxns),
        {...txn.toJson(), 'id': _id()},
      ]);

  @override
  Future<void> deleteTransaction(String id) =>
      _save(_kTxns, _list(_kTxns).where((t) => t['id'] != id).toList());

  @override
  Future<Map<int, double>> manualPrices() async {
    final m = (jsonDecode(_prefs.getString(_kPrices) ?? '{}') as Map).cast<String, dynamic>();
    return {for (final e in m.entries) int.parse(e.key): (e.value as num).toDouble()};
  }

  @override
  Future<void> setManualPrice(int instrumentId, double price) async {
    final m = await manualPrices();
    m[instrumentId] = price;
    await _save(_kPrices, {for (final e in m.entries) '${e.key}': e.value});
  }

  @override
  Future<void> clear() async {
    for (final k in [_kPortfolios, _kTxns, _kPrices]) {
      await _prefs.remove(k);
    }
  }
}
