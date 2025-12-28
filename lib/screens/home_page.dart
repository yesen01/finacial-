import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/vault_provider.dart';
import '../models/voucher_model.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final vouchers = vault.vouchers;

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Vault')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Balance', style: TextStyle(fontSize: 18)),
                    Text(
                      NumberFormat.currency(symbol: '\$').format(vault.balance),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: vault.balance >= 0 ? Colors.green[700] : Colors.red[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Vouchers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: vouchers.isEmpty
                  ? const Center(child: Text('No vouchers yet. Tap + to add.'))
                  : ListView.builder(
                      itemCount: vouchers.length,
                      itemBuilder: (context, index) {
                        final v = vouchers[index];
                        final color = v.type == 'Cash In' ? Colors.green : Colors.red;
                        return Dismissible(
                          key: ValueKey(v.id),
                          direction: DismissDirection.endToStart,
                          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                          onDismissed: (_) => context.read<VaultProvider>().deleteVoucher(v.id),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(v.type == 'Cash In' ? Icons.arrow_downward : Icons.arrow_upward, color: color)),
                            title: Text(v.description.isNotEmpty ? v.description : v.type),
                            subtitle: Text(DateFormat.yMMMd().add_jm().format(v.date)),
                            trailing: Text(NumberFormat.currency(symbol: '\$').format(v.amount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                          ),
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
