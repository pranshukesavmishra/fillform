import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../providers/profile_provider.dart';

const _expectedDocumentTypes = [
  ('aadhaar', 'Aadhaar Card'),
  ('10th_marksheet', '10th Marksheet'),
  ('12th_marksheet', '12th Marksheet'),
  ('income_certificate', 'Income Certificate'),
  ('caste_certificate', 'Caste Certificate'),
  ('bank_passbook', 'Bank Passbook'),
];

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load profile: $e', style: AppTextStyles.bodyMedium),
        ),
        data: (user) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      _ProfileHeader(user: user),
                      const SizedBox(height: AppSpacing.xl),
                      _CompletionCard(user: user),
                      const SizedBox(height: AppSpacing.xl),
                      _CareerDNACard(user: user),
                      const SizedBox(height: AppSpacing.xl),
                      const _DocumentsCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';
    final eduLine = [
      if (user.educationLevel != null) user.educationLevel,
      if (user.district != null && user.state != null) '${user.district}, ${user.state}',
    ].join(' • ');

    return GlassCard(
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withOpacity(0.3),
                child: Text(initial, style: AppTextStyles.displayMedium.copyWith(
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
                Text(user.displayName, style: AppTextStyles.titleLarge),
                if (eduLine.isNotEmpty)
                  Text(eduLine, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (user.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.successGradient),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(user.category!, style: AppTextStyles.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600,
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
  final UserModel user;
  const _CompletionCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final sections = [
      ('Basic Info', user.fullName != null),
      ('Education', user.educationLevel != null),
      ('Location', user.state != null),
      ('Category', user.category != null),
      ('Career Goals', user.careerGoal != null),
    ];
    final pct = (user.completeness * 100).round();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Profile Completeness', style: AppTextStyles.titleMedium),
              const Spacer(),
              Text('$pct%', style: AppTextStyles.titleMedium.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: user.completeness,
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
  final UserModel user;
  const _CareerDNACard({required this.user});

  @override
  Widget build(BuildContext context) {
    final fields = <String, String>{
      if (user.educationLevel != null) 'Education Level': user.educationLevel!,
      if (user.marks12thPercent != null) 'Marks (12th)': '${user.marks12thPercent}%',
      if (user.state != null) 'State': user.state!,
      if (user.district != null) 'District': user.district!,
      if (user.category != null) 'Category': user.category!,
      if (user.familyIncomeAnnual != null)
        'Annual Family Income': '₹${user.familyIncomeAnnual}',
      if (user.careerGoal != null) 'Career Goal': user.careerGoal!,
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
          if (fields.isEmpty)
            Text(
              'Complete your profile to build your Career DNA.',
              style: AppTextStyles.caption,
            )
          else
            ...fields.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 160, child: Text(e.key, style: AppTextStyles.caption)),
                  Expanded(
                    child: Text(e.value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider);

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
                onPressed: () => context.go('/documents'),
                icon: const Icon(Icons.upload_outlined, size: 14),
                label: const Text('Upload'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          docsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Failed to load documents', style: AppTextStyles.caption),
            data: (docs) {
              final uploadedTypes = docs.map((d) => d['document_type'] as String?).toSet();
              return Column(
                children: _expectedDocumentTypes.map((entry) {
                  final (type, label) = entry;
                  final uploaded = docs.where((d) => d['document_type'] == type).toList();
                  final isUploaded = uploadedTypes.contains(type);
                  final isVerified = uploaded.isNotEmpty && uploaded.first['is_verified'] == true;
                  final statusText = isUploaded
                      ? (isVerified ? 'Verified' : 'Pending verification')
                      : 'Not uploaded';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          isUploaded ? Icons.check_circle : Icons.upload_file_outlined,
                          size: 18,
                          color: isUploaded ? AppColors.success : AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
                        Text(statusText, style: AppTextStyles.caption.copyWith(
                          color: isUploaded ? AppColors.success : AppColors.textMuted,
                        )),
                      ],
                    ),
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
