import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class AgentListScreen extends StatelessWidget {
  const AgentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agents = [
      {'name': 'Rahul Verma', 'city': 'Lucknow, UP', 'rating': 4.9, 'sessions': 342, 'languages': ['Hindi', 'English'], 'speciality': 'Scholarships & Admissions', 'price': '₹149/session', 'badge': 'Platinum'},
      {'name': 'Priya Singh', 'city': 'Varanasi, UP', 'rating': 4.7, 'sessions': 218, 'languages': ['Hindi', 'Bhojpuri'], 'speciality': 'Government Jobs', 'price': '₹99/session', 'badge': 'Gold'},
      {'name': 'Suresh Patel', 'city': 'Patna, Bihar', 'rating': 4.8, 'sessions': 507, 'languages': ['Hindi', 'Maithili'], 'speciality': 'UPSC & State PSC', 'price': '₹199/session', 'badge': 'Platinum'},
    ];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expert Agents', style: AppTextStyles.headlineLarge),
                  Text('Verified experts in your language & region', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: agents.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _AgentCard(agent: agents[i], index: i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final Map<String, dynamic> agent;
  final int index;
  const _AgentCard({required this.agent, required this.index});

  Color get _badgeColor {
    switch (agent['badge']) {
      case 'Platinum': return const Color(0xFFE5E4E2);
      case 'Gold': return AppColors.trustGold;
      case 'Silver': return AppColors.trustSilver;
      default: return AppColors.trustBronze;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: Text(
                  (agent['name'] as String).substring(0, 1),
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.primaryLight),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(agent['name'], style: AppTextStyles.titleMedium),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _badgeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _badgeColor.withOpacity(0.5)),
                          ),
                          child: Text(agent['badge'], style: AppTextStyles.caption.copyWith(color: _badgeColor)),
                        ),
                      ],
                    ),
                    Text(agent['city'], style: AppTextStyles.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.accent, size: 16),
                      const SizedBox(width: 4),
                      Text(agent['rating'].toString(), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent)),
                    ],
                  ),
                  Text('${agent['sessions']} sessions', style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(agent['speciality'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryLight)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              ...(agent['languages'] as List<String>).map((lang) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgCardLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(lang, style: AppTextStyles.caption),
                ),
              )),
              const Spacer(),
              Text(agent['price'], style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.success, fontWeight: FontWeight.w700,
              )),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.video_call_outlined, size: 18),
              label: const Text('Book Session'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideY(begin: 0.2);
  }
}
