import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SavingsCard extends StatelessWidget {
  final double totalSaved;
  final int goalCount;
  final VoidCallback? onTap;

  const SavingsCard({
    super.key,
    required this.totalSaved,
    required this.goalCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Savings Vault', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(totalSaved),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text('$goalCount active goals', style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
              const Icon(Icons.savings, size: 48, color: Color(0xFF22C55E)),
            ],
          ),
        ),
      ),
    );
  }
}