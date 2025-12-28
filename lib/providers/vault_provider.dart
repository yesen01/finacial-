import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/voucher_model.dart';

class VaultProvider extends ChangeNotifier {
  final List<Voucher> _vouchers = [];

  UnmodifiableListView<Voucher> get vouchers => UnmodifiableListView(_vouchers);

  double get balance {
    double total = 0.0;
    for (final v in _vouchers) {
      if (v.type == 'Cash In') {
        total += v.amount;
      } else {
        total -= v.amount;
      }
    }
    return total;
  }

  void addVoucher(Voucher voucher) {
    _vouchers.insert(0, voucher);
    notifyListeners();
  }

  void deleteVoucher(String id) {
    _vouchers.removeWhere((v) => v.id == id);
    notifyListeners();
  }
}
