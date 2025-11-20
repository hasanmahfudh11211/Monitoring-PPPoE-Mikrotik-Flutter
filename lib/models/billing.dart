class Billing {
  final int id;
  final int userId;
  final String period;
  final double amount;
  final String dueDate;
  final String status;
  final String? paidAt;
  final String? note;

  Billing({
    required this.id,
    required this.userId,
    required this.period,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paidAt,
    this.note,
  });

  factory Billing.fromJson(Map<String, dynamic> json) {
    return Billing(
      id: int.parse(json['id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      period: json['period'],
      amount: double.parse(json['amount'].toString()),
      dueDate: json['due_date'],
      status: json['status'],
      paidAt: json['paid_at'],
      note: json['note'],
    );
  }
} 