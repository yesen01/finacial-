import 'package:flutter/material.dart';
import '../services/vault_firestore.dart';

class AddVoucherPage extends StatefulWidget {
  const AddVoucherPage({super.key});

  @override
  State<AddVoucherPage> createState() => _AddVoucherPageState();
}

class _AddVoucherPageState extends State<AddVoucherPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form State Variables
  String _direction = 'in'; // Default to "Cash In"
  String _method = 'Cash';   // Default method
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 1. Validate the form
    if (!_formKey.currentState!.validate()) return;

    // 2. Convert Dollars to Cents to avoid floating point math errors
    final cents = () {
      final text = _amountController.text.trim();
      final parsed = double.tryParse(text);
      if (parsed == null) throw const FormatException('Invalid amount');
      return (parsed * 100).round();
    }();

    try {
      // 3. Call the database service
      await VaultFirestore().addVoucher(
        type: _direction == 'in' ? 'Cash In' : 'Cash Out',
        amountCents: cents,
        description: _descController.text.trim(),
        direction: _direction,
        method: _method,
      );

      if (!mounted) return;
      Navigator.pop(context); // Go back to Home Screen on success
      
    } catch (e) {
      if (!mounted) return;
      
      // Handle "Insufficient Funds" or other errors
      String errorMsg = e.toString();
      if (errorMsg.contains('INSUFFICIENT_FUNDS')) {
        errorMsg = 'Transaction failed: Not enough money in the vault.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- DIRECTION & METHOD DROPDOWNS ---
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _direction,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'in', child: Text('Cash In')),
                        DropdownMenuItem(value: 'out', child: Text('Cash Out')),
                      ],
                      onChanged: (v) => setState(() => _direction = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _method,
                      decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
                      items: const ['Cash', 'Check', 'Bank Transfer']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setState(() => _method = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- AMOUNT FIELD ---
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Please enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- DESCRIPTION FIELD ---
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'e.g. Office Supplies, Salary...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // --- SAVE BUTTON ---
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save Transaction'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}