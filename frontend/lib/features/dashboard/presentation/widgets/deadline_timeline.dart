import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class DeadlineTimeline extends StatelessWidget {
  const DeadlineTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final deadlines = [
      {'title': 'NSP Scholarship', 'days': 3, 'color': AppColors.error},
      {'title': 'UP Scholarship', 'days': 8, 'color': AppColors.warning},
      {'title': 'AICTE Pragati', 'days': 21, 'color': AppColors.success},
      {'title': 'NMMS Exam Reg.', 'days': 35, 'color': AppColors.primaryLight},
    ];

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
          ...deadlines.asMap().entries.map((e) {
            final item = e.value;
            final days = item['days'] as int;
            final color = item['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  // Timeline dot
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
                      if (e.key < deadlines.length - 1)
                        Container(width: 1, height: 28, color: AppColors.divider),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item['title'] as String,
                      style: AppTextStyles.bodyMedium,
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
          }),
        ],
      ),
    );
  }
}
