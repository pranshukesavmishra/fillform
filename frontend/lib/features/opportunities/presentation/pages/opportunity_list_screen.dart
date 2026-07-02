import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/opportunity_model.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../providers/opportunities_provider.dart';

class OpportunityListScreen extends ConsumerStatefulWidget {
  const OpportunityListScreen({super.key});
  @override
  ConsumerState<OpportunityListScreen> createState() => _OpportunityListScreenState();
}

class _OpportunityListScreenState extends ConsumerState<OpportunityListScreen> {
  String _selectedCategory = 'All';
  bool _showEligibleOnly = true;

  static const Map<String, String> _categoryToApi = {
    'Scholarship': 'scholarship',
    'Govt Job': 'government_job',
    'Admission': 'admission',
    'Fellowship': 'fellowship',
    'Skill Training': 'skill_program',
  };

  final List<String> _categories = [
    'All', 'Scholarship', 'Govt Job', 'Admission', 'Fellowship', 'Skill Training',
  ];

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(opportunityFilterProvider);
    final opportunitiesAsync = ref.watch(opportunitiesProvider);

    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discover Opportunities', style: AppTextStyles.headlineLarge)
                      .animate().fadeIn().slideX(begin: -0.2),
                  Text(
                    opportunitiesAsync.maybeWhen(
                      data: (list) => '${list.length} matching your profile',
                      orElse: () => 'Loading…',
                    ),
                    style: AppTextStyles.bodyMedium,
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: TextField(
                onChanged: (v) => ref.read(opportunityFilterProvider.notifier).state =
                    filter.copyWith(searchQuery: v),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '🔍  Search scholarships, jobs, admissions...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.verified_outlined,
                          color: _showEligibleOnly ? AppColors.success : AppColors.textMuted,
                        ),
                        tooltip: 'Eligible Only',
                        onPressed: () {
                          setState(() => _showEligibleOnly = !_showEligibleOnly);
                          ref.read(opportunityFilterProvider.notifier).state =
                              filter.copyWith(eligibleOnly: _showEligibleOnly);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune_outlined, color: AppColors.textMuted),
                        onPressed: () {},
                        tooltip: 'Filters',
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms),
            ),

            const SizedBox(height: AppSpacing.md),

            // Category chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: _categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat);
                      ref.read(opportunityFilterProvider.notifier).state =
                          filter.copyWith(category: _categoryToApi[cat]);
                    },
                    selectedColor: AppColors.primary.withOpacity(0.3),
                    checkmarkColor: AppColors.primaryLight,
                    side: BorderSide(
                      color: _selectedCategory == cat
                          ? AppColors.primaryLight
                          : AppColors.divider,
                    ),
                  ),
                )).toList(),
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: AppSpacing.lg),

            // Results
            Expanded(
              child: opportunitiesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Failed to load opportunities: $e', style: AppTextStyles.bodyMedium),
                ),
                data: (opportunities) => opportunities.isEmpty
                    ? _EmptyState(showEligibleOnly: _showEligibleOnly)
                    : isWide
                        ? _GridView(opportunities: opportunities)
                        : _ListView(opportunities: opportunities),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  final List<OpportunityModel> opportunities;
  const _ListView({required this.opportunities});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      itemCount: opportunities.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => _OpportunityCard(
        data: opportunities[i],
        index: i,
      ),
    );
  }
}

class _GridView extends StatelessWidget {
  final List<OpportunityModel> opportunities;
  const _GridView({required this.opportunities});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 480,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
        childAspectRatio: 1.6,
      ),
      itemCount: opportunities.length,
      itemBuilder: (context, i) => _OpportunityCard(data: opportunities[i], index: i),
    );
  }
}

class _OpportunityCard extends StatefulWidget {
  final OpportunityModel data;
  final int index;
  const _OpportunityCard({required this.data, required this.index});

  @override
  State<_OpportunityCard> createState() => _OpportunityCardState();
}

class _OpportunityCardState extends State<_OpportunityCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.data;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/opportunities/${o.id}'),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          child: GlassCard(
            borderColor: o.isVerified ? AppColors.success : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        o.categoryLabel,
                        style: AppTextStyles.caption.copyWith(color: AppColors.primaryLight),
                      ),
                    ),
                    const Spacer(),
                    if (o.isVerified)
                      const Icon(Icons.verified, color: AppColors.success, size: 18),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  o.title,
                  style: AppTextStyles.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      o.amountDisplay,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.success, fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (o.state != null) Text(' · ${o.state}', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(o.deadline ?? 'No deadline', style: AppTextStyles.caption),
                      ],
                    ),
                    const Spacer(),
                    if (o.issuingAuthority != null)
                      Flexible(
                        child: Text(
                          o.issuingAuthority!,
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: widget.index * 80)).slideY(begin: 0.2);
  }
}

class _EmptyState extends StatelessWidget {
  final bool showEligibleOnly;
  const _EmptyState({required this.showEligibleOnly});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 64)),
          const SizedBox(height: AppSpacing.lg),
          Text('No opportunities found', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            showEligibleOnly
                ? 'Try turning off "Eligible Only" filter'
                : 'Try a different search term',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
