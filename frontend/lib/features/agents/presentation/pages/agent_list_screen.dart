import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../providers/agent_provider.dart';

class AgentListScreen extends ConsumerWidget {
  const AgentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentListProvider);

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
              child: agentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Failed to load agents: $e', style: AppTextStyles.bodyMedium),
                ),
                data: (agents) {
                  if (agents.isEmpty) {
                    return Center(
                      child: Text('No verified agents available yet.', style: AppTextStyles.bodyMedium),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    itemCount: agents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) => _AgentCard(agent: agents[i], index: i),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentCard extends ConsumerWidget {
  final Map<String, dynamic> agent;
  final int index;
  const _AgentCard({required this.agent, required this.index});

  Color _badgeColor(int totalSessions) {
    if (totalSessions >= 400) return const Color(0xFFE5E4E2);
    if (totalSessions >= 150) return AppColors.trustGold;
    if (totalSessions >= 50) return AppColors.trustSilver;
    return AppColors.trustBronze;
  }

  String _badgeLabel(int totalSessions) {
    if (totalSessions >= 400) return 'Platinum';
    if (totalSessions >= 150) return 'Gold';
    if (totalSessions >= 50) return 'Silver';
    return 'Bronze';
  }

  Future<void> _showBookingDialog(BuildContext context, WidgetRef ref) async {
    final issueController = TextEditingController();
    String sessionType = 'video_call';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Book session with ${agent['full_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: sessionType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'video_call', child: Text('Video Call')),
                  DropdownMenuItem(value: 'phone_call', child: Text('Phone Call')),
                  DropdownMenuItem(value: 'in_person', child: Text('In Person')),
                  DropdownMenuItem(value: 'document_pickup', child: Text('Document Pickup')),
                ],
                onChanged: (v) => setState(() => sessionType = v ?? sessionType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: issueController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe what you need help with (min 10 characters)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: issueController.text.trim().length >= 10
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(sessionBookingProvider.notifier).book(
      agentId: agent['id'].toString(),
      sessionType: sessionType,
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      issueDescription: issueController.text.trim(),
    );

    final result = ref.read(sessionBookingProvider);
    if (!context.mounted) return;
    result.when(
      data: (data) {
        if (data != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message']?.toString() ?? 'Session booked')),
          );
        }
      },
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e')),
      ),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = agent['full_name']?.toString() ?? 'Agent';
    final rating = (agent['average_rating'] as num?)?.toDouble() ?? 0.0;
    final totalSessions = (agent['total_sessions'] as num?)?.toInt() ?? 0;
    final languages = (agent['languages'] as List?)?.cast<String>() ?? [];
    final specializations = (agent['specializations'] as List?)?.cast<String>() ?? [];
    final districts = (agent['districts_covered'] as List?)?.cast<String>() ?? [];
    final fee = (agent['fee_per_session'] as num?)?.toInt();
    final badgeColor = _badgeColor(totalSessions);

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
                  name.isNotEmpty ? name.substring(0, 1) : '?',
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
                        Text(name, style: AppTextStyles.titleMedium),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: badgeColor.withOpacity(0.5)),
                          ),
                          child: Text(_badgeLabel(totalSessions), style: AppTextStyles.caption.copyWith(color: badgeColor)),
                        ),
                      ],
                    ),
                    if (districts.isNotEmpty)
                      Text(districts.join(', '), style: AppTextStyles.caption),
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
                      Text(rating.toStringAsFixed(1), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent)),
                    ],
                  ),
                  Text('$totalSessions sessions', style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (specializations.isNotEmpty)
            Text(specializations.join(', '), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryLight)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              ...languages.map((lang) => Padding(
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
              if (fee != null)
                Text('₹$fee/session', style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.success, fontWeight: FontWeight.w700,
                )),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showBookingDialog(context, ref),
              icon: const Icon(Icons.video_call_outlined, size: 18),
              label: const Text('Book Session'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideY(begin: 0.2);
  }
}
