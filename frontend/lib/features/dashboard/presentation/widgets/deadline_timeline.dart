import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../../../opportunities/presentation/providers/opportunities_provider.dart';

class DeadlineTimeline extends ConsumerWidget {
  const DeadlineTimeline({super.key});

  Color _colorForDays(int days) {
    if (days <= 7) return AppColors.error;
    if (days <= 14) return AppColors.warning;
    if (days <= 30) return AppColors.success;
    return AppColors.primaryLight;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunitiesAsync = ref.watch(opportunitiesProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text('Upcoming Deadlines', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          opportunitiesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Failed to load deadlines', style: AppTextStyles.caption),
            data: (opportunities) {
              final now = DateTime.now();
              final withDeadlines = opportunities
                  .where((o) => o.deadline != null)
                  .map((o) {
                    final deadline = DateTime.tryParse(o.deadline!);
                    final days = deadline == null ? null : deadline.difference(now).inDays;
                    return (o, days);
                  })
                  .where((e) => e.$2 != null && e.$2! >= 0)
                  .toList()
                ..sort((a, b) => a.$2!.compareTo(b.$2!));

              final top = withDeadlines.take(4).toList();
              if (top.isEmpty) {
                return Text('No upcoming deadlines found.', style: AppTextStyles.caption);
              }

              return Column(
                children: top.asMap().entries.map((e) {
                  final (opp, days) = e.value;
                  final color = _colorForDays(days!);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
                                ],
                              ),
                            ),
                            if (e.key < top.length - 1)
                              Container(width: 1, height: 28, color: AppColors.divider),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            opp.title,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            days <= 7 ? '$days days left!' : 'In $days days',
                            style: AppTextStyles.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: Duration(milliseconds: e.key * 100)),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
