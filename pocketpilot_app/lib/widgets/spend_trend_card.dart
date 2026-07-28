import 'package:flutter/material.dart';
import '../models/spend_trend.dart';

/// Quick-glance spend trend card — a simple bar chart of daily
/// discretionary spend, not a full analytics view. Tappable range toggle
/// between 7 and 30 days; tapping the card itself can be wired to a
/// detail sheet by the caller via [onTap].
class SpendTrendCard extends StatelessWidget {
  final List<SpendTrendPoint> series;
  final int selectedDays;
  final ValueChanged<int> onRangeChanged;
  final VoidCallback? onTap;

  const SpendTrendCard({
    super.key,
    required this.series,
    required this.selectedDays,
    required this.onRangeChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxSpent = series.isEmpty
        ? 1.0
        : series.map((p) => p.spent).fold<double>(0, (a, b) => a > b ? a : b);
    final safeMax = maxSpent <= 0 ? 1.0 : maxSpent;

    return Card(
      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Spending Trend',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  _RangeToggle(
                    selectedDays: selectedDays,
                    onChanged: onRangeChanged,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 90,
                child: series.isEmpty
                    ? const Center(
                        child: Text('No data yet',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: series
                            .map(
                              (p) => Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 1.5),
                                  child: Tooltip(
                                    message:
                                        '₹${p.spent.toStringAsFixed(0)} on ${p.date.day}/${p.date.month}',
                                    child: FractionallySizedBox(
                                      alignment: Alignment.bottomCenter,
                                      heightFactor:
                                          (p.spent / safeMax).clamp(0.03, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onChanged;

  const _RangeToggle({required this.selectedDays, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip('7D', 7),
        const SizedBox(width: 6),
        _chip('30D', 30),
      ],
    );
  }

  Widget _chip(String label, int days) {
    final selected = selectedDays == days;
    return GestureDetector(
      onTap: () => onChanged(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6366F1)
              : const Color(0xFF6366F1).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }
}
