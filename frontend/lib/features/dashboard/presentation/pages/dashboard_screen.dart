import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../../../applications/presentation/providers/applications_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../opportunities/presentation/providers/opportunities_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/opportunity_mini_card.dart';
import '../widgets/career_twin_bubble.dart';
import '../widgets/trust_score_ring.dart';
import '../widgets/deadline_timeline.dart';
import '../widgets/daily_briefing_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 1100;

    final profileAsync = ref.watch(profileProvider);
    final profileStatsAsync = ref.watch(profileStatsProvider);
    final applicationStatsAsync = ref.watch(applicationStatsProvider);

    final studentName = profileAsync.maybeWhen(
      data: (u) => u.displayName,
      orElse: () => '',
    );
    final completeness = profileAsync.maybeWhen(
      data: (u) => u.completeness,
      orElse: () => 0.0,
    );
    final activeDocuments = profileStatsAsync.maybeWhen(
      data: (s) => (s['active_documents'] as num?)?.toInt() ?? 0,
      orElse: () => 0,
    );
    final activeApplications = applicationStatsAsync.maybeWhen(
      data: (s) => (s['total'] as num?)?.toInt() ?? 0,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Animated mesh background
          const _MeshBackground(),

          // Scrollable content
          CustomScrollView(
            slivers: [
              // App bar
              SliverToBoxAdapter(
                child: _DashboardAppBar(
                  studentName: studentName,
                  trustScore: (completeness * 100).round(),
                ),
              ),

              // Daily briefing
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: const DailyBriefingCard()
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: 0.3),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              // Stats row
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: isWide
                      ? _StatsRowWide(
                          activeApplications: activeApplications,
                          activeDocuments: activeDocuments,
                          profileCompleteness: completeness,
                        )
                      : _StatsRowCompact(
                          activeApplications: activeApplications,
                          activeDocuments: activeDocuments,
                          profileCompleteness: completeness,
                        ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

              // Main content grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: isWide
                      ? const _WideLayout()
                      : const _CompactLayout(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // Floating Career Twin button (mobile)
          if (!isWide)
            const Positioned(
              bottom: 90,
              right: AppSpacing.xl,
              child: CareerTwinBubble(),
            ),
        ],
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────
class _DashboardAppBar extends ConsumerWidget {
  final String studentName;
  final int trustScore;

  const _DashboardAppBar({required this.studentName, required this.trustScore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationsProvider).maybeWhen(
      data: (data) => (data['unread_count'] as num?)?.toInt() ?? 0,
      orElse: () => 0,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md,
        ),
        child: Row(
          children: [
            // Greeting
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '$studentName 👋',
                    style: AppTextStyles.headlineLarge,
                  ).animate().fadeIn().slideX(begin: -0.2),
                ],
              ),
            ),

            // Trust score ring
            TrustScoreRing(score: trustScore),

            const SizedBox(width: AppSpacing.md),

            // Notification bell
            GestureDetector(
              onTap: () => context.go('/notifications'),
              child: Stack(
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    showShadow: false,
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bgDark, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ── Stats ──────────────────────────────────────────────────────────────────────
class _StatsRowWide extends StatelessWidget {
  final int activeApplications;
  final int activeDocuments;
  final double profileCompleteness;

  const _StatsRowWide({
    required this.activeApplications,
    required this.activeDocuments,
    required this.profileCompleteness,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          value: '$activeApplications',
          label: 'Applications',
          icon: Icons.assignment_outlined,
          gradient: AppColors.primaryGradient,
          delay: 0,
        )),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(
          value: '$activeDocuments',
          label: 'Documents on File',
          icon: Icons.folder_outlined,
          gradient: [const Color(0xFF7C3AED), const Color(0xFFEC4899)],
          delay: 100,
        )),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(
          value: '${(profileCompleteness * 100).toInt()}%',
          label: 'Profile Complete',
          icon: Icons.person_outline,
          gradient: AppColors.successGradient,
          delay: 200,
        )),
      ],
    );
  }
}

class _StatsRowCompact extends StatelessWidget {
  final int activeApplications;
  final int activeDocuments;
  final double profileCompleteness;

  const _StatsRowCompact({
    required this.activeApplications,
    required this.activeDocuments,
    required this.profileCompleteness,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.8,
      children: [
        _StatCard(value: '$activeApplications', label: 'Applications', icon: Icons.assignment_outlined, gradient: AppColors.primaryGradient, delay: 0),
        _StatCard(value: '$activeDocuments', label: 'Documents', icon: Icons.folder_outlined, gradient: [const Color(0xFF7C3AED), const Color(0xFFEC4899)], delay: 100),
        _StatCard(value: '${(profileCompleteness * 100).toInt()}%', label: 'Profile', icon: Icons.person_outline, gradient: AppColors.successGradient, delay: 200),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final int delay;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.3);
  }
}

// ── Wide Layout ───────────────────────────────────────────────────────────────
class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column (2/3)
        Expanded(
          flex: 7,
          child: Column(
            children: [
              const _TopOpportunitiesSection(),
              const SizedBox(height: AppSpacing.xl),
              const _ActiveApplicationsSection(),
              const SizedBox(height: AppSpacing.xl),
              const _SkillGapSection(),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.xl),

        // Right column (1/3)
        Expanded(
          flex: 3,
          child: Column(
            children: [
              const DeadlineTimeline(),
              const SizedBox(height: AppSpacing.xl),
              const _CareerTwinSidebar(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _TopOpportunitiesSection(),
        SizedBox(height: AppSpacing.xl),
        DeadlineTimeline(),
        SizedBox(height: AppSpacing.xl),
        _ActiveApplicationsSection(),
      ],
    );
  }
}

// ── Top Opportunities ─────────────────────────────────────────────────────────
class _TopOpportunitiesSection extends ConsumerWidget {
  const _TopOpportunitiesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunitiesAsync = ref.watch(opportunitiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Picks For You', style: AppTextStyles.titleLarge),
                Text(
                  'Based on your profile • Updated just now',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.go('/opportunities'),
              child: Text(
                'View All →',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        opportunitiesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('Failed to load opportunities', style: AppTextStyles.bodyMedium),
          ),
          data: (opportunities) => Column(
            children: opportunities.take(3).toList().asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: OpportunityMiniCard(
                  data: {
                    'id': e.value.id,
                    'title': e.value.title,
                    'amount': e.value.amountDisplay,
                    'deadline': e.value.deadline ?? 'No deadline',
                    // Real backend difficulty_score (0=hardest, 1=easiest),
                    // inverted into a "fit" indicator. Not a true per-user AI
                    // prediction (that needs POST /api/v1/ai/success-probability
                    // per opportunity) but a real signal, not a fake number.
                    'probability': 1.0 - (e.value.difficultyScore ?? 0.5),
                    'category': e.value.categoryLabel,
                    // No "recently added" timestamp is exposed to the
                    // frontend yet, so don't fabricate a NEW badge.
                    'isNew': false,
                  },
                  index: e.key,
                ),
              ),
            ).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Active Applications ────────────────────────────────────────────────────────
class _ActiveApplicationsSection extends ConsumerWidget {
  const _ActiveApplicationsSection();

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppColors.success;
      case 'submitted':
      case 'under_review': return AppColors.warning;
      case 'rejected': return AppColors.error;
      default: return AppColors.textMuted;
    }
  }

  double _statusProgress(String status) {
    switch (status) {
      case 'approved': return 1.0;
      case 'submitted': return 0.7;
      case 'under_review': return 0.85;
      case 'rejected': return 1.0;
      default: return 0.3;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(applicationsProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Applications', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.md),
          applicationsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Failed to load applications', style: AppTextStyles.caption),
            data: (apps) {
              if (apps.isEmpty) {
                return Text(
                  'No applications yet. Apply to an opportunity to see it tracked here.',
                  style: AppTextStyles.caption,
                );
              }
              final top = apps.take(3).toList();
              return Column(
                children: top.asMap().entries.map((e) {
                  final app = e.value;
                  final color = _statusColor(app.status);
                  return Column(
                    children: [
                      _applicationRow(app.opportunityTitle, _statusProgress(app.status), app.statusLabel, color),
                      if (e.key < top.length - 1) const Divider(height: AppSpacing.xl),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _applicationRow(String title, double progress, String status, Color statusColor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: AppTextStyles.caption.copyWith(color: statusColor),
          ),
        ),
      ],
    );
  }
}

// ── Skill Gap ─────────────────────────────────────────────────────────────────
class _SkillGapSection extends ConsumerWidget {
  const _SkillGapSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillGapAsync = ref.watch(skillGapProvider);

    return GradientCard(
      gradient: const [Color(0xFF1A1835), Color(0xFF231F45)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high, color: AppColors.accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('AI Opportunity Unlock', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          skillGapAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(
              'Ask your Career Twin for a personalized skill-gap analysis once the AI service is configured.',
              style: AppTextStyles.bodyMedium,
            ),
            data: (data) {
              final gaps = (data['gaps'] as List?) ?? [];
              if (gaps.isEmpty) {
                return Text(
                  data['raw']?.toString() ?? 'No skill gaps found — your profile looks strong!',
                  style: AppTextStyles.bodyMedium,
                );
              }
              final top = gaps.first as Map<String, dynamic>;
              final skillName = top['skill_name']?.toString() ?? 'a new skill';
              final unlockCount = top['opportunity_unlock_count'];
              return Text(
                'Learn $skillName${unlockCount != null ? " and unlock ~$unlockCount more opportunities" : ""}.',
                style: AppTextStyles.bodyMedium,
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/career-twin'),
                  child: const Text('Ask Career Twin'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Career Twin Sidebar ────────────────────────────────────────────────────────
class _CareerTwinSidebar extends ConsumerWidget {
  const _CareerTwinSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(dailyBriefingProvider);
    return NeonCard(
      neonColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Career Twin', style: AppTextStyles.titleMedium),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('Active', style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                      )),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: briefingAsync.when(
              loading: () => const SizedBox(
                height: 16, width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, _) => Text(
                '"Ask me anything about scholarships, exams, or your career path."',
                style: AppTextStyles.bodyMedium.copyWith(fontStyle: FontStyle.italic),
              ),
              data: (data) {
                final text = data['insight']?.toString() ??
                    data['daily_action']?.toString() ??
                    data['raw']?.toString() ??
                    'Ask me anything about scholarships, exams, or your career path.';
                return Text(
                  '"$text"',
                  style: AppTextStyles.bodyMedium.copyWith(fontStyle: FontStyle.italic),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/career-twin'),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Chat with Twin'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeshBackground extends StatelessWidget {
  const _MeshBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -200,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -200,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.08),
                    Colors.transparent,
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
