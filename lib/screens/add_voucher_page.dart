import 'package:flutter/material.dart';
import '../services/vault_firestore.dart';

class AddVoucherPage extends StatefulWidget {
  const AddVoucherPage({super.key});

  @override
  State<AddVoucherPage> createState() => _AddVoucherPageState();
}

class _AddVoucherPageState extends State<AddVoucherPage> {
  final _formKey = GlobalKey<FormState>();
  String _direction = 'in';
  String _method = 'Cash';

  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    final cents = (amount * 100).round();

    try {
      await VaultFirestore().addVoucher(
        type: _direction == 'in' ? 'Cash In' : 'Cash Out',
        amountCents: cents,
        description: _descController.text.trim(),
        direction: _direction,
        method: _method,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } on StateError catch (e) {
      if (!mounted) return;

      final msg = e.message == 'INSUFFICIENT_FUNDS'
          ? 'Not enough money in the vault.'
          : 'Operation failed';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Voucher')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField(
                      value: _direction,
                      items: const [
                        DropdownMenuItem(value: 'in', child: Text('Cash In')),
                        DropdownMenuItem(value: 'out', child: Text('Cash Out')),
                      ],
                      onChanged: (v) =>
                          setState(() => _direction = v!),
                      decoration:
                          const InputDecoration(labelText: 'Direction'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField(
                      value: _method,
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'Check', child: Text('Check')),
                        DropdownMenuItem(
                            value: 'Bank Transfer',
                            child: Text('Bank Transfer')),
                      ],
                      onChanged: (v) =>
                          setState(() => _method = v!),
                      decoration:
                          const InputDecoration(labelText: 'Method'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) {
                    return 'Enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
