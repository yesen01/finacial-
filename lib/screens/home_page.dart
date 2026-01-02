import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/vault_firestore.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = VaultFirestore();

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Vault')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<int>(
              stream: service.balanceCentsStream(),
              builder: (context, snap) {
                final cents = snap.data ?? 0;
                final balance = cents / 100.0;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Balance', style: TextStyle(fontSize: 18)),
                        Text(
                          NumberFormat.currency(symbol: '\$').format(balance),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: balance >= 0
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Today's summary card (Total In, Total Out, Today's Balance)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: service.dailyVaultStream(),
              builder: (context, dsnap) {
                final data = dsnap.data?.data() ?? {};
                final totalInCents = (data['totalCashIn'] as num?)?.toInt() ?? 0;
                final totalOutCents = (data['totalCashOut'] as num?)?.toInt() ?? 0;
                final closingCents = (data['closingBalance'] as num?)?.toInt() ?? 0;

                final totalIn = totalInCents / 100.0;
                final totalOut = totalOutCents / 100.0;
                final todayBalance = (totalInCents - totalOutCents) / 100.0;


                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Total In', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(
                              NumberFormat.currency(symbol: '\$').format(totalIn),
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Total Out', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(
                              NumberFormat.currency(symbol: '\$').format(totalOut),
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text("Today's Balance", style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(
                              NumberFormat.currency(symbol: '\$').format(todayBalance),
                              style: TextStyle(
                                color: todayBalance >= 0 ? Colors.green[700] : Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Vouchers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: service.vouchersStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No vouchers yet. Tap + to add.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();

                        final type = (data['type'] as String?) ?? 'Cash In';
                        final direction = (data['direction'] as String?)?.toLowerCase();
                        final method = (data['method'] as String?) ;
                      final amountCents = (data['amountCents'] as int?) ?? 0;
                      final description =
                          (data['description'] as String?) ?? '';
                      final ts = data['createdAt'] as Timestamp?;
                      final date = ts?.toDate() ?? DateTime.now();

                      final amount = amountCents / 100.0;
                      // Determine whether this transaction increases the balance.
                      bool isIncrease;
                      if (direction != null) {
                        isIncrease = direction == 'in' || direction == 'cash in';
                      } else {
                        isIncrease = (type == 'Cash In');
                      }

                      // Icon based on method (distinct icon per method)
                      IconData iconData;
                      Color methodColor;
                      final m = method ?? type;
                      if (m == 'Cash' || m == 'Cash In') {
                        iconData = Icons.monetization_on;
                        methodColor = Colors.green;
                      } else if (m == 'Check') {
                        iconData = Icons.receipt_long;
                        methodColor = Colors.orange;
                      } else if (m == 'Bank Transfer') {
                        iconData = Icons.account_balance;
                        methodColor = Colors.blue;
                      } else {
                        iconData = isIncrease ? Icons.arrow_downward : Icons.arrow_upward;
                        methodColor = isIncrease ? Colors.green : Colors.red;
                      }

                      // Amount color indicates increase/decrease
                      final amountColor = isIncrease ? Colors.green : Colors.red;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: methodColor.withOpacity(0.2),
                          child: Icon(iconData, color: methodColor),
                        ),
                        title: Text(
                          description.isNotEmpty
                              ? description
                              : '${m}${isIncrease ? ' In' : ' Out'}',
                        ),
                        subtitle: Text(
                          DateFormat.yMMMd().add_jm().format(date),
                        ),
                        trailing: Text(
                          NumberFormat.currency(symbol: '\$').format(amount),
                          style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
