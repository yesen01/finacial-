import 'package:cloud_firestore/cloud_firestore.dart';

class VaultFirestore {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _vaultRef =>
      _db.collection('vault').doc('main');

  CollectionReference<Map<String, dynamic>> get _vouchersRef =>
      _vaultRef.collection('vouchers');

  String _todayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference<Map<String, dynamic>> get _dailyRef =>
      _db.collection('daily_vault').doc(_todayId());

  Future<void> ensureVaultExists() async {
    final snap = await _vaultRef.get();
    if (!snap.exists) {
      await _vaultRef.set({
        'balanceCents': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<int> balanceCentsStream() {
    return _vaultRef.snapshots().map(
          (s) => (s.data()?['balanceCents'] as int?) ?? 0,
        );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> vouchersStream() {
    return _vouchersRef
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> dailyVaultStream() {
    return _dailyRef.snapshots();
  }

  Future<void> addVoucher({
    required String type,        // "Cash In" / "Cash Out"
    required int amountCents,
    required String description,
    required String direction,   // "in" / "out"
    required String method,      // "Cash" / "Check" / "Bank Transfer"
  }) async {
    if (amountCents <= 0) throw StateError('INVALID_AMOUNT');

    // 1) Read current balance (simple + reliable on web)
    final vaultSnap = await _vaultRef.get();
    final current = (vaultSnap.data()?['balanceCents'] as num?)?.toInt() ?? 0;

    final isIncrease = direction == 'in';
    final next = isIncrease ? current + amountCents : current - amountCents;

    if (next < 0) {
      throw StateError('INSUFFICIENT_FUNDS');
    }

    // 2) Prepare writes
    final voucherRef = _vouchersRef.doc();
    final dailySnap = await _dailyRef.get();

    final batch = _db.batch();

    // voucher doc
    batch.set(voucherRef, {
      'type': type,
      'amountCents': amountCents,
      'description': description,
      'direction': direction,
      'method': method,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtClient': DateTime.now().millisecondsSinceEpoch, // optional sorting
    });

    // vault balance
    batch.set(
      _vaultRef,
      {'balanceCents': next, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    // daily totals (store closingBalance as the vault’s current balance)
    if (!dailySnap.exists) {
      batch.set(_dailyRef, {
        'date': _todayId(),
        'openingBalance': current,
        'totalCashIn': isIncrease ? amountCents : 0,
        'totalCashOut': isIncrease ? 0 : amountCents,
        'closingBalance': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(
        _dailyRef,
        {
          'totalCashIn': FieldValue.increment(isIncrease ? amountCents : 0),
          'totalCashOut': FieldValue.increment(isIncrease ? 0 : amountCents),
          'closingBalance': next,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    // 3) Commit
    await batch.commit();
  }
}
