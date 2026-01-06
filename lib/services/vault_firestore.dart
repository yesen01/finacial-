import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Needed for kIsWeb check
import 'package:universal_html/html.dart' as html; // Requires universal_html package

class VaultFirestore {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection References
  DocumentReference<Map<String, dynamic>> get _vaultRef => 
      _db.collection('vault').doc('main');
  CollectionReference<Map<String, dynamic>> get _vouchersRef => 
      _vaultRef.collection('vouchers');

  String _todayId() => DateTime.now().toIso8601String().split('T')[0];
  DocumentReference<Map<String, dynamic>> get _dailyRef => 
      _db.collection('daily_vault').doc(_todayId());

  // --- STREAMS ---
  Stream<int> balanceCentsStream() => 
      _vaultRef.snapshots().map((s) => (s.data()?['balanceCents'] as int?) ?? 0);
  
  Stream<QuerySnapshot<Map<String, dynamic>>> vouchersStream() => 
      _vouchersRef.orderBy('createdAt', descending: true).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> dailyVaultStream() => 
      _dailyRef.snapshots();

  // --- METHODS ---
  Future<void> ensureVaultExists() async {
    final doc = await _vaultRef.get();
    if (!doc.exists) {
      await _vaultRef.set({'balanceCents': 0});
    }
  }

  Future<void> addVoucher({
    required String type,
    required int amountCents,
    required String description,
    required String direction,
    required String method,
  }) async {
    final batch = _db.batch();
    final isIncrease = direction == 'in';
    final voucherRef = _vouchersRef.doc();

    batch.set(voucherRef, {
      'type': type,
      'amountCents': amountCents,
      'description': description,
      'direction': direction,
      'method': method,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(_vaultRef, {
      'balanceCents': FieldValue.increment(isIncrease ? amountCents : -amountCents),
    });

    batch.set(_dailyRef, {
      isIncrease ? 'totalCashIn' : 'totalCashOut': FieldValue.increment(amountCents),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> updateVoucher({
  required String docId,
  required String newDescription,
  required int newAmountCents,
  required int oldAmountCents,
  required String direction,
}) async {
  final batch = _db.batch();
  final isIncrease = direction == 'in';

  int difference = newAmountCents - oldAmountCents;

  batch.update(_vouchersRef.doc(docId), {
    'description': newDescription,
    'amountCents': newAmountCents,
    'lastModified': FieldValue.serverTimestamp(),
  });

  batch.update(_vaultRef, {
    'balanceCents': FieldValue.increment(
      isIncrease ? difference : -difference,
    ),
  });

  batch.set(
    _dailyRef,
    {
      isIncrease
          ? 'totalCashIn'
          : 'totalCashOut': FieldValue.increment(difference),
    },
    SetOptions(merge: true),
  );

  await batch.commit();
}


  Future<void> deleteVoucher(String docId, int amountCents, String direction) async {
    final batch = _db.batch();
    final isIncrease = direction == 'in';

    batch.delete(_vouchersRef.doc(docId));
    
    batch.update(_vaultRef, {
      'balanceCents': FieldValue.increment(isIncrease ? -amountCents : amountCents),
    });

    batch.update(_dailyRef, {
      isIncrease ? 'totalCashIn' : 'totalCashOut': FieldValue.increment(-amountCents),
    });

    await batch.commit();
  }

  // --- UPDATED ADVANCED FEATURE: EXPORT TO CSV (WEB & MOBILE) ---
  Future<String> exportToCSV() async {
    final snapshot = await _vouchersRef.orderBy('createdAt', descending: true).get();
    
    List<List<dynamic>> rows = [];
    rows.add(["Description", "Amount (\$)", "Direction", "Method", "Date"]);

    for (var doc in snapshot.docs) {
      final data = doc.data();
      rows.add([
        data['description'] ?? "",
        ((data['amountCents'] ?? 0) / 100).toStringAsFixed(2),
        data['direction'] ?? "",
        data['method'] ?? "",
        data['createdAt']?.toDate().toString() ?? "N/A",
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    if (kIsWeb) {
      // --- WEB DOWNLOAD LOGIC ---
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'vault_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return "File downloaded to your browser";
    } else {
      // --- MOBILE SAVING LOGIC ---
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/vault_export_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csvData);
      return path;
    }
  }

  // --- UPDATED ADVANCED FEATURE: IMPORT FROM CSV ---
  Future<void> importFromCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: kIsWeb, // Mandatory for web to read the file content
    );

    if (result != null) {
      List<List<dynamic>> fields;
      
      if (kIsWeb) {
        // Web reads data from bytes
        final fileBytes = result.files.first.bytes;
        final csvString = utf8.decode(fileBytes!);
        fields = const CsvToListConverter().convert(csvString);
      } else {
        // Mobile reads data from file path
        final file = File(result.files.single.path!);
        final input = file.openRead();
        fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();
      }

      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.length < 4) continue;

        await addVoucher(
          description: row[0].toString(),
          amountCents: (double.parse(row[1].toString()) * 100).round(),
          direction: row[2].toString().toLowerCase(),
          method: row[3].toString(),
          type: row[2].toString().toLowerCase() == 'in' ? 'Cash In' : 'Cash Out',
        );
      }
    }
  }
}