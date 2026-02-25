import 'transaction.dart';

class Contact {
  final String id;
  final String name;
  final List<FinancialTransaction> transactions;

  Contact({
    required this.id,
    required this.name,
    required this.transactions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map, List<FinancialTransaction> transactions) {
    return Contact(
      id: map['id'],
      name: map['name'],
      transactions: transactions,
    );
  }

  double get totalBalance {
    return totalBalanceIn(Currency.toman);
  }

  double totalBalanceIn(Currency targetCurrency) {
    double total = 0;
    for (var t in transactions) {
      if (t.type == TransactionType.event) continue;

      final convertedAmount = t.amountInCurrency(targetCurrency);
      if (t.type == TransactionType.credit) {
        // بستانکاری - سبز - طلب ما
        total += convertedAmount;
      } else {
        // بدهکاری - قرمز - بدهی ما
        total -= convertedAmount;
      }
    }
    return total;
  }
}
