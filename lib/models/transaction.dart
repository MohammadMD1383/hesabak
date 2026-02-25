enum TransactionType { debt, credit, event }
enum Currency { rial, toman }

double convertCurrencyAmount(double amount, Currency from, Currency to) {
  if (from == to) return amount;
  if (from == Currency.rial && to == Currency.toman) return amount / 10;
  return amount * 10;
}

class FinancialTransaction {
  final String id;
  final double? amount;
  final Currency? currency;
  final TransactionType type;
  final String? description;
  final DateTime dateTime;

  FinancialTransaction({
    required this.id,
    this.amount,
    this.currency,
    required this.type,
    this.description,
    required this.dateTime,
  });

  Map<String, dynamic> toMap(String contactId) {
    return {
      'id': id,
      'contactId': contactId,
      'amount': amount,
      'currency': currency?.name,
      'type': type.name,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'],
      amount: map['amount'],
      currency: map['currency'] != null 
          ? Currency.values.firstWhere((e) => e.name == map['currency']) 
          : null,
      type: TransactionType.values.firstWhere((e) => e.name == map['type']),
      description: map['description'],
      dateTime: DateTime.parse(map['dateTime']),
    );
  }

  double amountInCurrency(Currency targetCurrency) {
    final value = amount ?? 0;
    final sourceCurrency = currency ?? Currency.rial;
    return convertCurrencyAmount(value, sourceCurrency, targetCurrency);
  }
}
