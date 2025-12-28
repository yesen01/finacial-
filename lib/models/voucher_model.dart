class Voucher {
  final String id;
  final String type; // "Cash In" or "Cash Out"
  final double amount;
  final String description;
  final DateTime date;

  Voucher({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
  });

  factory Voucher.create({required String type, required double amount, String description = ''}) {
    return Voucher(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      amount: amount,
      description: description,
      date: DateTime.now(),
    );
  }
}
