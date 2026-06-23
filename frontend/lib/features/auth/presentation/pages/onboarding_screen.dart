import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      emoji: '🎯',
      title: 'Never Miss an\nOpportunity Again',
      subtitle: 'AI scans 500+ portals 24/7 and alerts you to scholarships, jobs, and admissions the moment they open — matched to YOUR profile.',
      stat: '₹2.4L avg. scholarship value missed by students like you',
      statIcon: Icons.monetization_on_outlined,
      gradient: AppColors.primaryGradient,
    ),
    OnboardingPage(
      emoji: '🤖',
      title: 'Your AI Career\nManager',
      subtitle: 'Meet your Career Twin — an AI that knows your profile, predicts your success rate, and guides you step-by-step until you get selected.',
      stat: '94.2% eligibility accuracy across 2.3M assessments',
      statIcon: Icons.verified_outlined,
      gradient: [Color(0xFF7C3AED), Color(0xFFEC4899)],
    ),
    OnboardingPage(
      emoji: '📝',
      title: 'Forms Fill\nThemselves',
      subtitle: 'Upload your documents once. Our AI reads every form field, maps your data, and fills applications in seconds — with 98% accuracy.',
      stat: '4.2 hours saved per application on average',
      statIcon: Icons.timer_outlined,
      gradient: [Color(0xFF0891B2), Color(0xFF4F46E5)],
    ),
    OnboardingPage(
      emoji: '🤝',
      title: 'Expert Help\nWhen You Need It',
      subtitle: 'Can\'t do it alone? Book a verified local agent via video call. Get expert assistance from ₹49 — available in your language.',
      stat: '12,000+ verified agents across India',
      statIcon: Icons.people_outline,
      gradient: AppColors.successGradient,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          _AnimatedBackground(page: _currentPage),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.primaryGradient,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'FillFormAI',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(
                          'Skip',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return _OnboardingPageView(
                        page: page,
                        isWide: isWide,
                      );
                    },
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      // Page indicator
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: _pages.length,
                        effect: ExpandingDotsEffect(
                          activeDotColor: AppColors.primaryLight,
                          dotColor: AppColors.divider,
                          dotHeight: 8,
                          dotWidth: 8,
                          expansionFactor: 4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // CTA Button
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          duration: AppDurations.medium,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _pages[_currentPage].gradient,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _pages[_currentPage].gradient.first.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (_currentPage < _pages.length - 1) {
                                _pageController.nextPage(
                                  duration: AppDurations.medium,
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                context.go('/login');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _currentPage < _pages.length - 1
                                  ? 'Continue'
                                  : 'Get Started Free →',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_currentPage == _pages.length - 1) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No credit card needed • Free forever for students',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  final OnboardingPage page;
  final bool isWide;

  const _OnboardingPageView({required this.page, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji with animated glow ring
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  page.gradient.first.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 64),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds)
                  .then()
                  .scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1), duration: 2.seconds),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: AppSpacing.xl),

          // Title
          Text(
            page.title,
            style: AppTextStyles.displayMedium.copyWith(
              fontSize: isWide ? 44 : 32,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),

          const SizedBox(height: AppSpacing.md),

          // Subtitle
          Text(
            page.subtitle,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.3, end: 0),

          const SizedBox(height: AppSpacing.xl),

          // Stat card
          GlassCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: page.gradient),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(page.statIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    page.stat,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5, end: 0),
        ],
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  final int page;
  const _AnimatedBackground({required this.page});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.slow,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.bgDark,
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String stat;
  final IconData statIcon;
  final List<Color> gradient;

  const OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.stat,
    required this.statIcon,
    required this.gradient,
  });
}
