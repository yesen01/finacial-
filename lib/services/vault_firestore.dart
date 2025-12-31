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
    return _db.collection('daily_vault').doc(_todayId()).snapshots();
  }

  /// ✅ الحل هنا
  Future<void> addVoucher({
    required String type,
    required int amountCents,
    required String description,
    required String direction,
    required String method,
  }) async {
    await _db.runTransaction((tx) async {
      final vaultSnap = await tx.get(_vaultRef);
      final current =
        (vaultSnap.data()?['balanceCents'] as num?)?.toInt() ?? 0;


      final isIncrease = direction == 'in';
      final next = isIncrease
          ? current + amountCents
          : current - amountCents;

      /// ❗ منع الرصيد السالب
      if (next < 0) {
        throw StateError('INSUFFICIENT_FUNDS');
      }

      final voucherRef = _vouchersRef.doc();

      tx.set(voucherRef, {
        'type': type,
        'amountCents': amountCents,
        'description': description,
        'direction': direction,
        'method': method,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        _vaultRef,
        {
          'balanceCents': next,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final dailyRef =
          _db.collection('daily_vault').doc(_todayId());
      final dailySnap = await tx.get(dailyRef);

      if (!dailySnap.exists) {
        tx.set(dailyRef, {
          'date': _todayId(),
          'openingBalance': current,
          'totalCashIn': isIncrease ? amountCents : 0,
          'totalCashOut': isIncrease ? 0 : amountCents,
          'closingBalance': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = dailySnap.data()!;

final prevIn =
    (data['totalCashIn'] as num?)?.toInt() ?? 0;
final prevOut =
    (data['totalCashOut'] as num?)?.toInt() ?? 0;

final totalIn = prevIn + (isIncrease ? amountCents : 0);
final totalOut = prevOut + (isIncrease ? 0 : amountCents);


        tx.update(dailyRef, {
          'totalCashIn': totalIn,
          'totalCashOut': totalOut,
          'closingBalance': current + totalIn - totalOut,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
