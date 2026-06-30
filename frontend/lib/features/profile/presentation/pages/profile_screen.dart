import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    _ProfileHeader(),
                    const SizedBox(height: AppSpacing.xl),
                    _CompletionCard(),
                    const SizedBox(height: AppSpacing.xl),
                    _CareerDNACard(),
                    const SizedBox(height: AppSpacing.xl),
                    _DocumentsCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withOpacity(0.3),
                child: Text('A', style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.primaryLight,
                )),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.primaryGradient),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgCard, width: 2),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Anshu Kumar Mishra', style: AppTextStyles.titleLarge),
                Text('B.Sc. (IT) • Varanasi, UP', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.successGradient),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('OBC-NCL', style: AppTextStyles.caption.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600,
                      )),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Trust Score: 72', style: AppTextStyles.caption.copyWith(
                        color: AppColors.accent, fontWeight: FontWeight.w600,
                      )),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }
}

class _CompletionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sections = [
      ('Basic Info', true),
      ('Education', true),
      ('Documents', false),
      ('Bank Details', false),
      ('Career Goals', true),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Profile Completeness', style: AppTextStyles.titleMedium),
              const Spacer(),
              Text('78%', style: AppTextStyles.titleMedium.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: 0.78,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation(AppColors.success),
            borderRadius: BorderRadius.circular(6),
            minHeight: 8,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sections.map((s) => _SectionChip(label: s.$1, isDone: s.$2)).toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  final String label;
  final bool isDone;
  const _SectionChip({required this.label, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDone ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? AppColors.success.withOpacity(0.4) : AppColors.error.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isDone ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption.copyWith(
            color: isDone ? AppColors.success : AppColors.error,
          )),
        ],
      ),
    );
  }
}

class _CareerDNACard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fields = {
      'Education Level': 'B.Sc. (IT) - 3rd Year',
      'Marks': '74.5%',
      'Board/University': 'BHU, Varanasi',
      'State': 'Uttar Pradesh',
      'District': 'Varanasi',
      'Category': 'OBC-NCL',
      'Annual Family Income': '₹2,40,000',
      'Age': '19 years',
    };

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.biotech, color: AppColors.primaryLight, size: 20),
              const SizedBox(width: 8),
              Text('Career DNA', style: AppTextStyles.titleMedium),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...fields.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 160, child: Text(e.key, style: AppTextStyles.caption)),
                Text(e.value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final docs = [
      ('Aadhaar Card', true, 'Verified'),
      ('10th Marksheet', true, 'AI Verified'),
      ('12th Marksheet', true, 'AI Verified'),
      ('Income Certificate', false, 'Not uploaded'),
      ('Caste Certificate', false, 'Not uploaded'),
      ('Bank Passbook', false, 'Not uploaded'),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_outlined, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Documents', style: AppTextStyles.titleMedium),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.upload_outlined, size: 14),
                label: const Text('Upload'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...docs.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  d.$2 ? Icons.check_circle : Icons.upload_file_outlined,
                  size: 18,
                  color: d.$2 ? AppColors.success : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(d.$1, style: AppTextStyles.bodyMedium)),
                Text(d.$3, style: AppTextStyles.caption.copyWith(
                  color: d.$2 ? AppColors.success : AppColors.textMuted,
                )),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
