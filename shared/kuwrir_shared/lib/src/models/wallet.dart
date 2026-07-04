class Wallet {
  final String id;
  final double balance;
  final double totalEarned;
  final double totalWithdrawn;

  const Wallet({
    required this.id,
    this.balance = 0,
    this.totalEarned = 0,
    this.totalWithdrawn = 0,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        id: json['id'] as String,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0,
        totalWithdrawn: (json['total_withdrawn'] as num?)?.toDouble() ?? 0,
      );
}

class WalletTransaction {
  final String id;
  final String type; // credit | debit
  final String category; // order_earning | withdrawal | refund | adjustment | cod_deposit
  final double amount;
  final double balanceAfter;
  final String? notes;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.notes,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        balanceAfter: (json['balance_after'] as num).toDouble(),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
