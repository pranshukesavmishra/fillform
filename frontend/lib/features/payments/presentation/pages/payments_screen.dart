import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/razorpay_checkout.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../providers/payment_provider.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String? _checkingOutPlanId;

  Future<void> _subscribe(Map<String, dynamic> plan) async {
    if (plan['price_paise'] == null) return; // free plan, nothing to buy
    setState(() => _checkingOutPlanId = plan['id'] as String);
    try {
      final order = await ref.read(checkoutProvider.notifier).createOrderForPlan(plan);
      openRazorpayCheckout(
        keyId: order['razorpay_key_id'] as String? ?? '',
        orderId: order['razorpay_order_id'] as String,
        amountPaise: order['amount_paise'] as int,
        currency: order['currency'] as String? ?? 'INR',
        name: 'FillFormAI',
        description: '${plan['name']} subscription',
        onSuccess: (paymentId, razorpayOrderId, signature) async {
          try {
            await ref.read(checkoutProvider.notifier).confirmPayment(
              razorpayOrderId: razorpayOrderId,
              razorpayPaymentId: paymentId,
              razorpaySignature: signature,
              internalOrderId: order['internal_order_id'] as String,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscription activated!')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Payment verification failed: $e')),
              );
            }
          } finally {
            if (mounted) setState(() => _checkingOutPlanId = null);
          }
        },
        onDismiss: () {
          if (mounted) setState(() => _checkingOutPlanId = null);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start checkout: $e')),
        );
        setState(() => _checkingOutPlanId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);
    final historyAsync = ref.watch(paymentHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Subscription & Payments')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            subscriptionAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('Failed to load subscription status', style: AppTextStyles.caption),
              data: (sub) => GlassCard(
                child: Row(
                  children: [
                    Icon(
                      sub['is_active'] == true ? Icons.verified : Icons.info_outline,
                      color: sub['is_active'] == true ? AppColors.success : AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        sub['is_active'] == true
                            ? 'Current plan: ${sub['plan']} (active until ${sub['expires_at']})'
                            : 'You are on the Free plan.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Plans', style: AppTextStyles.headlineLarge),
            const SizedBox(height: AppSpacing.md),
            plansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load plans: $e', style: AppTextStyles.bodyMedium),
              data: (plans) => Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: plans.map((plan) => _PlanCard(
                  plan: plan,
                  isCheckingOut: _checkingOutPlanId == plan['id'],
                  onSubscribe: () => _subscribe(plan),
                )).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Payment History', style: AppTextStyles.headlineLarge),
            const SizedBox(height: AppSpacing.md),
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load history', style: AppTextStyles.bodyMedium),
              data: (payments) {
                if (payments.isEmpty) {
                  return Text('No payments yet.', style: AppTextStyles.caption);
                }
                return Column(
                  children: payments.map((p) {
                    final amount = (p['amount_paise'] as num?) ?? 0;
                    return GlassCard(
                      child: Row(
                        children: [
                          Icon(
                            p['status'] == 'paid' ? Icons.check_circle : Icons.hourglass_top,
                            color: p['status'] == 'paid' ? AppColors.success : AppColors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['purpose']?.toString() ?? '', style: AppTextStyles.bodyMedium),
                                Text(p['created_at']?.toString() ?? '', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          Text('₹${(amount / 100).toStringAsFixed(2)}', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isCheckingOut;
  final VoidCallback onSubscribe;

  const _PlanCard({required this.plan, required this.isCheckingOut, required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    final features = (plan['features'] as List?)?.cast<String>() ?? [];
    final isFree = plan['id'] == 'free';
    final badge = plan['badge'] as String?;

    return SizedBox(
      width: 280,
      child: GlassCard(
        borderColor: badge != null ? AppColors.accent : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(plan['name']?.toString() ?? '', style: AppTextStyles.titleLarge),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge, style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '₹${plan['price_monthly']}/month',
              style: AppTextStyles.headlineLarge.copyWith(color: AppColors.primaryLight),
            ),
            const SizedBox(height: AppSpacing.md),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f, style: AppTextStyles.caption)),
                ],
              ),
            )),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isFree || isCheckingOut ? null : onSubscribe,
                child: isCheckingOut
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isFree ? 'Current' : 'Subscribe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
