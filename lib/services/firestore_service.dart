import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tax_transaction.dart';

/// Reads and writes [TaxTransaction] documents scoped to a single user.
///
/// Data layout: `users/{uid}/transactions/{transactionId}`.
class FirestoreService {
  FirestoreService(this.uid, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('transactions');

  /// Live stream of transactions for a given tax year, newest first.
  Stream<List<TaxTransaction>> watchTransactions(int taxYear) {
    return _col
        .where('taxYear', isEqualTo: taxYear)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TaxTransaction.fromMap(d.id, d.data()))
            .toList(growable: false));
  }

  /// One-shot fetch of every transaction for a tax year (used for exports).
  Future<List<TaxTransaction>> getTransactions(int taxYear) async {
    final snap = await _col.where('taxYear', isEqualTo: taxYear).get();
    return snap.docs
        .map((d) => TaxTransaction.fromMap(d.id, d.data()))
        .toList(growable: false);
  }

  /// Distinct tax years that have at least one transaction.
  Future<List<int>> getTaxYears() async {
    final snap = await _col.get();
    final years = <int>{
      for (final d in snap.docs)
        (d.data()['taxYear'] as num?)?.toInt() ?? DateTime.now().year,
    };
    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  Future<void> add(TaxTransaction tx) => _col.add(tx.toMap());

  /// Bulk-insert (used by CSV import). Firestore caps a batch at 500 writes,
  /// so we commit in chunks.
  Future<void> addAll(List<TaxTransaction> txs) async {
    const chunkSize = 450;
    for (var start = 0; start < txs.length; start += chunkSize) {
      final batch = _db.batch();
      final end =
          (start + chunkSize) < txs.length ? start + chunkSize : txs.length;
      for (var i = start; i < end; i++) {
        batch.set(_col.doc(), txs[i].toMap());
      }
      await batch.commit();
    }
  }

  Future<void> update(TaxTransaction tx) {
    assert(tx.id != null, 'Cannot update a transaction without an id');
    return _col.doc(tx.id).set(tx.toMap(), SetOptions(merge: true));
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
