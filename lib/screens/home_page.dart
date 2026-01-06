import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/vault_firestore.dart';
import '../providers/theme_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = "";
  String selectedMethod = "All";

  // --- EDIT DIALOG WITH NOTIFICATION ---
  void _editDialog(String id, String currentDesc, int currentCents, String direction) {
    final descController = TextEditingController(text: currentDesc);
    final moneyController = TextEditingController(text: (currentCents / 100).toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Transaction"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController, 
              decoration: const InputDecoration(labelText: "Description"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: moneyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Amount (\$)", 
                prefixText: "\$ ",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              double amountDouble = double.tryParse(moneyController.text) ?? 0.0;
              int newAmountCents = (amountDouble * 100).round();

              await VaultFirestore().updateVoucher(
                docId: id,
                newDescription: descController.text,
                newAmountCents: newAmountCents,
                oldAmountCents: currentCents,
                direction: direction,
              );
              
              if (mounted) {
                Navigator.pop(context);
                // NOTIFICATION: Successful Update
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Transaction updated successfully!"),
                    backgroundColor: Colors.teal,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = VaultFirestore();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Vault'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // --- ADVANCED FEATURE: EXPORT BUTTON ---
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: "Export CSV",
            onPressed: () async {
              String message = await service.exportToCSV();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message), 
                    backgroundColor: Colors.teal,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          Consumer<ThemeProvider>(builder: (context, tp, _) => Switch(
            value: tp.themeMode == ThemeMode.dark,
            onChanged: (v) => tp.toggleTheme(v),
          )),
          IconButton(
            icon: const Icon(Icons.logout), 
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. GLOBAL BALANCE
            StreamBuilder<int>(
              stream: service.balanceCentsStream(),
              builder: (context, snap) {
                final balance = (snap.data ?? 0) / 100.0;
                return Card(
                  elevation: 4,
                  child: ListTile(
                    title: const Text('Global Balance'),
                    trailing: Text(
                      NumberFormat.currency(symbol: '\$').format(balance),
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: balance >= 0 ? Colors.green[700] : Colors.red[700]
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 2. DAILY SUMMARY
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: service.dailyVaultStream(),
              builder: (context, dsnap) {
                final data = dsnap.data?.data() ?? {};
                final inVal = ((data['totalCashIn'] as num?)?.toDouble() ?? 0.0) / 100.0;
                final outVal = ((data['totalCashOut'] as num?)?.toDouble() ?? 0.0) / 100.0;
                return Row(
                  children: [
                    _buildSummaryCard("Total In", inVal, Colors.green),
                    _buildSummaryCard("Total Out", outVal, Colors.red),
                    _buildSummaryCard("Net Today", inVal - outVal, Colors.blueGrey),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // 3. ADVANCED FEATURE: SEARCH & FILTER
            TextField(
              onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search descriptions...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["All", "Cash", "Check", "Bank Transfer"].map((method) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(method, style: const TextStyle(fontSize: 12)),
                    selected: selectedMethod == method,
                    onSelected: (s) => setState(() => selectedMethod = method),
                  ),
                )).toList(),
              ),
            ),

            const Divider(height: 24),

            // 4. TRANSACTION LIST WITH DELETE NOTIFICATION
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: service.vouchersStream(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final docs = snap.data!.docs.where((doc) {
                    final data = doc.data();
                    final desc = (data['description'] ?? "").toString().toLowerCase();
                    final method = data['method'] ?? "Cash";
                    return desc.contains(searchQuery) && (selectedMethod == "All" || method == selectedMethod);
                  }).toList();

                  if (docs.isEmpty) return const Center(child: Text("No transactions found."));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final id = docs[index].id;
                      final amountCents = data['amountCents'] as int;
                      final direction = data['direction'] as String;
                      final isIncrease = direction == 'in';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isIncrease ? Icons.arrow_downward : Icons.arrow_upward, 
                            color: isIncrease ? Colors.green : Colors.red
                          ),
                          title: Text(data['description'].isEmpty ? "Transaction" : data['description']),
                          subtitle: Text("\$${(amountCents / 100).toStringAsFixed(2)} • ${data['method']}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.teal),
                                onPressed: () => _editDialog(id, data['description'], amountCents, direction),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                                onPressed: () async {
                                  await service.deleteVoucher(id, amountCents, direction);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Transaction deleted"),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
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
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard(String label, double value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(
                NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(value),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}