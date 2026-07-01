import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/career_tools_provider.dart';

class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key});

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  final _goalController = TextEditingController();
  int _timelineMonths = 24;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roadmapState = ref.watch(roadmapProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Career Roadmap')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Build your career roadmap', style: AppTextStyles.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text('Tell your Career Twin your goal, and get a month-by-month plan.', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your goal', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _goalController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Become a government bank officer within 2 years',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Timeline: $_timelineMonths months', style: AppTextStyles.titleMedium),
                  Slider(
                    value: _timelineMonths.toDouble(),
                    min: 3,
                    max: 60,
                    divisions: 19,
                    label: '$_timelineMonths months',
                    onChanged: (v) => setState(() => _timelineMonths = v.round()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _goalController.text.trim().length < 10 || roadmapState.isLoading
                          ? null
                          : () async {
                              final dna = await ref.read(careerDnaProvider.future);
                              ref.read(roadmapProvider.notifier).generate(
                                careerDna: dna,
                                goal: _goalController.text.trim(),
                                timelineMonths: _timelineMonths,
                              );
                            },
                      child: roadmapState.isLoading
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Generate Roadmap'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            roadmapState.when(
              data: (data) {
                if (data == null) return const SizedBox.shrink();
                final phases = (data['phases'] as List?) ?? [];
                if (phases.isEmpty) {
                  return GlassCard(
                    child: Text(data['raw']?.toString() ?? 'No roadmap generated.', style: AppTextStyles.bodyMedium),
                  );
                }
                return Column(
                  children: phases.map((p) {
                    final phase = p as Map<String, dynamic>;
                    final steps = (phase['steps'] as List?)?.cast<String>() ?? [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(phase['phase_name']?.toString() ?? '', style: AppTextStyles.titleMedium)),
                                Text(phase['months']?.toString() ?? '', style: AppTextStyles.caption),
                              ],
                            ),
                            if (phase['objective'] != null) ...[
                              const SizedBox(height: 4),
                              Text(phase['objective'].toString(), style: AppTextStyles.bodyMedium),
                            ],
                            if (steps.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              ...steps.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• '),
                                    Expanded(child: Text(s, style: AppTextStyles.caption)),
                                  ],
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              error: (e, _) => GlassCard(
                child: Text(
                  'Your AI service needs an Anthropic API key configured on the backend to generate roadmaps.',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              loading: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
