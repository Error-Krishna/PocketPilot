import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

/// Alert shown when a transaction pushes today's discretionary spend
/// above the flat daily limit. Lets the user decide how the overage gets
/// absorbed — as a genuine one-time exception, from banked savings, by
/// reducing the daily limit for the rest of the cycle, or a hybrid split
/// — with a live preview of both extremes before committing.
class OverageResolutionDialog extends StatefulWidget {
  final String transactionId;
  final double amount;
  final String? merchant;

  const OverageResolutionDialog({
    super.key,
    required this.transactionId,
    required this.amount,
    this.merchant,
  });

  @override
  State<OverageResolutionDialog> createState() =>
      _OverageResolutionDialogState();
}

class _OverageResolutionDialogState extends State<OverageResolutionDialog> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  Map<String, dynamic>? _preview;
  bool _loading = true;
  bool _hybridMode = false;
  double _sliderValue = 0; // 0 = all reduce-daily, overage = all savings

  @override
  void initState() {
    super.initState();
    _loadPreview(0);
  }

  Future<void> _loadPreview(double amountFromSavings) async {
    try {
      final api = context.read<ApiService>();
      final preview = await api.previewOverageResolution(
        widget.transactionId,
        amountFromSavings: amountFromSavings,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _resolve(String resolution, {double amountFromSavings = 0}) async {
    Navigator.pop(context); // Close dialog immediately, resolve in background.
    try {
      final api = context.read<ApiService>();
      await api.resolveOverage(
        widget.transactionId,
        resolution,
        amountFromSavings: amountFromSavings,
      );
    } catch (_) {
      // Non-fatal — the overage stays pending and will be surfaced again
      // next time the summary loads (see pendingOverageTransactionIds).
    }
  }

  @override
  Widget build(BuildContext context) {
    final overage = (_preview?['overage'] as num?)?.toDouble() ?? 0;
    final allSavings = _preview?['allFromSavings'] as Map<String, dynamic>?;
    final allDaily = _preview?['allFromReduceDaily'] as Map<String, dynamic>?;
    final requested = _preview?['requestedSplit'] as Map<String, dynamic>?;

    return AlertDialog(
      title: const Text('Over today\'s limit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.merchant ?? 'This purchase'} '
              '(${_currency.format(widget.amount)}) put you '
              '${_currency.format(overage)} over today\'s limit.\n\n'
              'How should this be covered?',
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _OptionTile(
                icon: Icons.warning_amber,
                title: 'This was an emergency / one-time expense',
                subtitle:
                    'Won\'t count against your daily limit, but still reduces this cycle\'s overall budget',
                onTap: () => _resolve('exception'),
              ),
              const Divider(),
              _OptionTile(
                icon: Icons.savings,
                title: 'Cover it from savings',
                subtitle: allSavings != null
                    ? 'Savings become ${_currency.format(allSavings['newBankedSavings'])}, daily limit stays the same'
                    : null,
                onTap: () => _resolve('savings'),
              ),
              _OptionTile(
                icon: Icons.trending_down,
                title: 'Lower my daily limit for the rest of the cycle',
                subtitle: allDaily != null
                    ? 'New daily limit: ${_currency.format(allDaily['newDailyLimit'])}, savings unchanged'
                    : null,
                onTap: () => _resolve('reduce_daily'),
              ),
              const Divider(),
              TextButton(
                onPressed: () => setState(() => _hybridMode = !_hybridMode),
                child: Text(_hybridMode ? 'Hide split option' : 'Split between both'),
              ),
              if (_hybridMode && requested != null) ...[
                Text(
                  'From savings: ${_currency.format(_sliderValue)}',
                  style: const TextStyle(fontSize: 13),
                ),
                Slider(
                  value: _sliderValue.clamp(0, overage),
                  max: overage <= 0 ? 1 : overage,
                  onChanged: (v) {
                    setState(() => _sliderValue = v);
                    _loadPreview(v);
                  },
                ),
                Text(
                  'New daily limit: ${_currency.format(requested['newDailyLimit'])} · '
                  'New savings: ${_currency.format(requested['newBankedSavings'])}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => _resolve('hybrid', amountFromSavings: _sliderValue),
                    child: const Text('Confirm split'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12))
          : null,
      onTap: onTap,
    );
  }
}
