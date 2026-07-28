class SpendTrendPoint {
  final DateTime date;
  final double spent;

  SpendTrendPoint({required this.date, required this.spent});

  factory SpendTrendPoint.fromJson(Map<String, dynamic> json) =>
      SpendTrendPoint(
        date: DateTime.parse(json['date']),
        spent: (json['spent'] as num).toDouble(),
      );
}
