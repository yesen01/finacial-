import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:js_util' as js_util;

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
    try {
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

        final dailyRef = _db.collection('daily_vault').doc(_todayId());
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
    } catch (e, st) {
      debugPrint('VaultFirestore.addVoucher transaction error: $e');
      debugPrint('error runtimeType: ${e.runtimeType}');
      debugPrint('stack runtimeType: ${st.runtimeType}');
      debugPrint('$st');

      String message = e.toString();

      // 1) If it's already a FirebaseException, use its fields
      if (e is FirebaseException) {
        message = e.message ?? e.code ?? message;
        debugPrint('mapped FirebaseException -> $message');
        throw StateError(message);
      }

      // 2) Try to unwrap common boxed shapes from web interop, including
      // NativeError objects produced by the JS runtime. Use `dart:js_util`
      // to safely read JS properties when available.
      try {
        if (identical(0, 0.0)) {}
        final dyn = e as dynamic;

        String? tryGet(dynamic obj, String prop) {
          try {
            final v = js_util.getProperty(obj, prop);
            if (v == null) return null;
            return v.toString();
          } catch (_) {
            return null;
          }
        }

        final boxedMsg = tryGet(dyn, 'error') ?? tryGet(dyn, 'message') ?? tryGet(dyn, 'code');
        if (boxedMsg != null) {
          message = boxedMsg;
          debugPrint('unwrapped JS property -> $message');
        }

        // If message looks like a plain JS object string, try JSON.stringify
        try {
          if (message.contains('[object') || message.trim() == '[object Object]') {
            final json = js_util.getProperty(js_util.globalThis, 'JSON');
            final boxed = js_util.getProperty(dyn, 'error') ?? dyn;
            final s = js_util.callMethod(json, 'stringify', [boxed]);
            if (s != null && s is String && s.isNotEmpty) {
              message = s;
              debugPrint('stringified boxed JS object -> $message');
            }
          }
        } catch (strErr) {
          debugPrint('JSON.stringify failed: $strErr');
        }

        // Also try nested `.error.message`
        try {
          final inner = js_util.getProperty(dyn, 'error');
          final innerMsg = tryGet(inner, 'message');
          if (innerMsg != null) {
            message = innerMsg;
            debugPrint('unwrapped inner.message -> $message');
          }
        } catch (_) {}

        // If the unwrapped value is an object that looks like a FirebaseException,
        // attempt to read its message/code
        try {
          final possibleCode = tryGet(dyn, 'code');
          final possibleMessage = tryGet(dyn, 'message');
          if (possibleMessage != null || possibleCode != null) {
            message = (possibleMessage ?? possibleCode)!;
            debugPrint('outer JS message/code -> $message');
          }
        } catch (_) {}
      } catch (unwrapErr) {
        debugPrint('error unwrapping converted Future: $unwrapErr');
      }

      // 3) Check stack trace string for hints
      try {
        final stStr = st?.toString();
        if (stStr != null && stStr.isNotEmpty) {
          debugPrint('raw stack trace (snippet): ${stStr.substring(0, stStr.length > 300 ? 300 : stStr.length)}');
        }
      } catch (_) {}

      // 4) Final fallback: throw readable StateError so UI displays it
      throw StateError(message);
    }
  }
}
