import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../widgets/opportunity_mini_card.dart';
import '../widgets/career_twin_bubble.dart';
import '../widgets/trust_score_ring.dart';
import '../widgets/deadline_timeline.dart';
import '../widgets/daily_briefing_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Mock data — replace with Riverpod providers
  final String studentName = 'Anshu';
  final int trustScore = 72;
  final int activeApplications = 3;
  final int savedOpportunities = 12;
  final double profileCompleteness = 0.78;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 1100;
    final isMedium = size.width > 700;

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
                  trustScore: trustScore,
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
                          trustScore: trustScore,
                          activeApplications: activeApplications,
                          savedOpportunities: savedOpportunities,
                          profileCompleteness: profileCompleteness,
                        )
                      : _StatsRowCompact(
                          trustScore: trustScore,
                          activeApplications: activeApplications,
                          savedOpportunities: savedOpportunities,
                          profileCompleteness: profileCompleteness,
                        ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

              // Main content grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: isWide
                      ? _WideLayout()
                      : _CompactLayout(),
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
class _DashboardAppBar extends StatelessWidget {
  final String studentName;
  final int trustScore;

  const _DashboardAppBar({required this.studentName, required this.trustScore});

  @override
  Widget build(BuildContext context) {
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
            Stack(
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
  final int trustScore;
  final int activeApplications;
  final int savedOpportunities;
  final double profileCompleteness;

  const _StatsRowWide({
    required this.trustScore,
    required this.activeApplications,
    required this.savedOpportunities,
    required this.profileCompleteness,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          value: '$activeApplications',
          label: 'Active Applications',
          icon: Icons.assignment_outlined,
          gradient: AppColors.primaryGradient,
          delay: 0,
        )),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(
          value: '$savedOpportunities',
          label: 'Saved Opportunities',
          icon: Icons.bookmark_outline,
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
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(
          value: '₹2.4L',
          label: 'Eligible Value',
          icon: Icons.monetization_on_outlined,
          gradient: AppColors.goldGradient,
          delay: 300,
        )),
      ],
    );
  }
}

class _StatsRowCompact extends StatelessWidget {
  final int trustScore;
  final int activeApplications;
  final int savedOpportunities;
  final double profileCompleteness;

  const _StatsRowCompact({
    required this.trustScore,
    required this.activeApplications,
    required this.savedOpportunities,
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
        _StatCard(value: '$activeApplications', label: 'Active', icon: Icons.assignment_outlined, gradient: AppColors.primaryGradient, delay: 0),
        _StatCard(value: '$savedOpportunities', label: 'Saved', icon: Icons.bookmark_outline, gradient: [const Color(0xFF7C3AED), const Color(0xFFEC4899)], delay: 100),
        _StatCard(value: '${(profileCompleteness * 100).toInt()}%', label: 'Profile', icon: Icons.person_outline, gradient: AppColors.successGradient, delay: 200),
        _StatCard(value: '₹2.4L', label: 'Eligible', icon: Icons.monetization_on_outlined, gradient: AppColors.goldGradient, delay: 300),
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
class _TopOpportunitiesSection extends StatelessWidget {
  const _TopOpportunitiesSection();

  @override
  Widget build(BuildContext context) {
    final mockOpportunities = [
      {
        'title': 'PM Scholarship Scheme 2024',
        'amount': '₹36,000',
        'deadline': '15 Nov',
        'probability': 0.78,
        'category': 'Scholarship',
        'isNew': true,
      },
      {
        'title': 'UP Mukhyamantri Scholarship',
        'amount': '₹25,000',
        'deadline': '30 Nov',
        'probability': 0.85,
        'category': 'State Scholarship',
        'isNew': false,
      },
      {
        'title': 'AICTE Pragati Scholarship',
        'amount': '₹50,000',
        'deadline': '8 Dec',
        'probability': 0.62,
        'category': 'Central Govt',
        'isNew': true,
      },
    ];

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
        ...mockOpportunities.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: OpportunityMiniCard(
              data: e.value,
              index: e.key,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Active Applications ────────────────────────────────────────────────────────
class _ActiveApplicationsSection extends StatelessWidget {
  const _ActiveApplicationsSection();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active Applications', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.md),
          _applicationRow('NSP Scholarship 2024', 0.65, 'In Progress', AppColors.warning),
          const Divider(height: AppSpacing.xl),
          _applicationRow('NMMS Examination', 0.90, 'Submitted', AppColors.success),
          const Divider(height: AppSpacing.xl),
          _applicationRow('Bihar Mukhyamantri Scholarship', 0.30, 'Draft', AppColors.textMuted),
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
              Text(title, style: AppTextStyles.titleMedium),
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
class _SkillGapSection extends StatelessWidget {
  const _SkillGapSection();

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Get a NIELIT O-Level certificate and unlock 47 more government opportunities worth ₹2.4L',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Learn More'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Start Now →'),
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
class _CareerTwinSidebar extends StatelessWidget {
  const _CareerTwinSidebar();

  @override
  Widget build(BuildContext context) {
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
          // Mock message
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Text(
              '"Anshu, the UP Scholarship portal opens in 8 days. Your success probability is 78%. Want me to start preparing your application?"',
              style: AppTextStyles.bodyMedium.copyWith(fontStyle: FontStyle.italic),
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
