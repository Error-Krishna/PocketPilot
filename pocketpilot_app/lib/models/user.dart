class User {
  final String id;
  final String firebaseUid;
  final String email;
  final String displayName;
  final String? phone;
  final double? monthlyBudget;
  final int? budgetResetDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    this.phone,
    this.monthlyBudget,
    this.budgetResetDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        firebaseUid: json['firebase_uid'],
        email: json['email'],
        displayName: json['display_name'],
        phone: json['phone'],
        monthlyBudget: (json['monthly_budget'] as num?)?.toDouble(),
        budgetResetDate: json['budget_reset_date'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );
}