import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class OpportunityDetailScreen extends StatelessWidget {
  final String opportunityId;
  const OpportunityDetailScreen({super.key, required this.opportunityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text('🎓', style: TextStyle(fontSize: 72)),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text('PM Scholarship Scheme 2024', style: AppTextStyles.headlineLarge),
                const SizedBox(height: AppSpacing.md),
                _InfoRow(icon: Icons.monetization_on_outlined, label: 'Amount', value: '₹36,000/year'),
                _InfoRow(icon: Icons.schedule, label: 'Deadline', value: '15 November 2024'),
                _InfoRow(icon: Icons.people_outline, label: 'Total Seats', value: '5,000'),
                _InfoRow(icon: Icons.location_on_outlined, label: 'Eligibility', value: 'All India'),
                const SizedBox(height: AppSpacing.xl),
                // Success probability
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Success Probability', style: AppTextStyles.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Text('78%', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.success)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: 0.78,
                                  backgroundColor: AppColors.divider,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.success),
                                  borderRadius: BorderRadius.circular(4),
                                  minHeight: 8,
                                ),
                                const SizedBox(height: 4),
                                Text('Higher than 65% of similar students', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.flash_on_rounded),
                    label: const Text('Apply with AI Auto-Fill →'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('$label: ', style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
