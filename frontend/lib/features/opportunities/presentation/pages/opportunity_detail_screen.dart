import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/opportunity_model.dart';
import '../providers/opportunities_provider.dart';

class OpportunityDetailScreen extends ConsumerWidget {
  final String opportunityId;
  const OpportunityDetailScreen({super.key, required this.opportunityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunityAsync = ref.watch(opportunityDetailProvider(opportunityId));

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: opportunityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load opportunity: $e', style: AppTextStyles.bodyMedium),
        ),
        data: (o) => _DetailBody(opportunity: o),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final OpportunityModel opportunity;
  const _DetailBody({required this.opportunity});

  @override
  Widget build(BuildContext context) {
    final eligibilitySummaryList = (opportunity.eligibilityRules['eligibility_summary'] as List?)
            ?.cast<String>() ??
        [];
    final eligibilityText = eligibilitySummaryList.isNotEmpty
        ? eligibilitySummaryList.join(', ')
        : (opportunity.state ?? 'All India');

    return CustomScrollView(
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
              Text(opportunity.title, style: AppTextStyles.headlineLarge),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(
                icon: Icons.monetization_on_outlined,
                label: 'Amount',
                value: opportunity.amountDisplay,
              ),
              _InfoRow(
                icon: Icons.schedule,
                label: 'Deadline',
                value: opportunity.deadline ?? 'Rolling',
              ),
              _InfoRow(
                icon: Icons.apartment_outlined,
                label: 'Issuing Authority',
                value: opportunity.issuingAuthority ?? 'N/A',
              ),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Eligibility',
                value: eligibilityText,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (opportunity.description != null) ...[
                Text(opportunity.description!, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.xl),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/opportunities/${opportunity.id}/apply'),
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
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
