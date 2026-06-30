import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/payment_service.dart';

class PaymentResultScreen extends StatelessWidget {
  final PaymentResult result;

  const PaymentResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Status icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: result.approved
                      ? AppColors.primaryLight
                      : const Color(0xFFFFEBEE),
                ),
                child: Icon(
                  result.approved ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 56,
                  color: result.approved ? AppColors.primary : AppColors.danger,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                result.approved ? 'Payment Approved' : 'Payment Declined',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: result.approved ? AppColors.primary : AppColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.approved
                    ? 'Transaction completed successfully.'
                    : 'The card was declined. Please try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),

              const SizedBox(height: 32),

              // Details card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    if (result.approved && result.authCode.isNotEmpty)
                      _DetailRow(label: 'Auth Code', value: result.authCode),
                    if (result.cardLast4.isNotEmpty && result.cardLast4 != '****')
                      _DetailRow(label: 'Card', value: '•••• ${result.cardLast4.length > 4 ? result.cardLast4.substring(result.cardLast4.length - 4) : result.cardLast4}'),
                    _DetailRow(label: 'Ref ID', value: result.refId),
                    if (result.responseCode.isNotEmpty)
                      _DetailRow(label: 'Response Code', value: result.responseCode),
                    if (result.responseMessage.isNotEmpty)
                      _DetailRow(label: 'Message', value: result.responseMessage),
                  ],
                ),
              ),

              const Spacer(),

              // Actions
              if (result.approved) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/pos'),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('New Sale', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/tee-sheet'),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Back to Tee Sheet', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again', style: TextStyle(fontSize: 15)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => context.go('/pos'),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
