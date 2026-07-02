import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../providers/dashboard_provider.dart';

class DailyBriefingCard extends ConsumerWidget {
  const DailyBriefingCard({super.key});

  String _briefingText(Map<String, dynamic> data) {
    if (data['raw'] != null) return data['raw'].toString();
    final parts = <String>[];
    if (data['insight'] != null) parts.add(data['insight'].toString());
    if (data['daily_action'] != null) parts.add(data['daily_action'].toString());
    if (parts.isEmpty) return 'No briefing available right now.';
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(dailyBriefingProvider);

    return GradientCard(
      gradient: const [Color(0xFF1E1B4B), Color(0xFF312E81)],
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI Daily Briefing',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          briefingAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Text(
              'Your Career Twin needs an AI key configured on the backend to generate briefings. Chat with it directly instead.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.5),
            ),
            data: (data) => Text(
              _briefingText(data),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.6),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _actionChip('📄 Upload Docs', () => context.go('/documents')),
              const SizedBox(width: 8),
              _actionChip('💬 Ask Twin', () => context.go('/career-twin')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primaryLight,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
