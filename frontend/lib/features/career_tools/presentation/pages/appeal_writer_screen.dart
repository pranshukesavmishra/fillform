import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../../../applications/presentation/providers/applications_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/career_tools_provider.dart';

class AppealWriterScreen extends ConsumerStatefulWidget {
  const AppealWriterScreen({super.key});

  @override
  ConsumerState<AppealWriterScreen> createState() => _AppealWriterScreenState();
}

class _AppealWriterScreenState extends ConsumerState<AppealWriterScreen> {
  String? _selectedApplicationId;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(applicationsProvider);
    final appealState = ref.watch(appealProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Rejection Appeal Writer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Draft an appeal for a rejected application', style: AppTextStyles.headlineLarge),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Application', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  applicationsAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Failed to load applications', style: AppTextStyles.caption),
                    data: (apps) {
                      if (apps.isEmpty) {
                        return Text('You have no applications yet.', style: AppTextStyles.caption);
                      }
                      return DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedApplicationId,
                        hint: const Text('Select an application'),
                        items: apps.map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.opportunityTitle} (${a.statusLabel})', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedApplicationId = v),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Rejection reason (optional, if stated by the authority)', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Income certificate did not match records',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedApplicationId == null || appealState.isLoading
                          ? null
                          : () async {
                              final dna = await ref.read(careerDnaProvider.future);
                              final apps = await ref.read(applicationsProvider.future);
                              final app = apps.firstWhere((a) => a.id == _selectedApplicationId);
                              ref.read(appealProvider.notifier).generate(
                                applicationData: {
                                  'id': app.id,
                                  'status': app.status,
                                  'opportunity_title': app.opportunityTitle,
                                  'rejection_reason': app.rejectionReason,
                                },
                                studentProfile: dna,
                                rejectionReason: _reasonController.text.trim().isEmpty
                                    ? app.rejectionReason
                                    : _reasonController.text.trim(),
                              );
                            },
                      child: appealState.isLoading
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Draft Appeal'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            appealState.when(
              data: (data) {
                if (data == null) return const SizedBox.shrink();
                final english = data['letter_english']?.toString() ?? data['raw']?.toString() ?? '';
                final hindi = data['letter_hindi']?.toString();
                final tips = (data['tips'] as List?)?.cast<String>() ?? [];
                return GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Draft Appeal Letter', style: AppTextStyles.titleLarge),
                      const SizedBox(height: AppSpacing.md),
                      SelectableText(english, style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
                      if (hindi != null && hindi.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text('Hindi Version', style: AppTextStyles.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        SelectableText(hindi, style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
                      ],
                      if (tips.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text('Tips: ${tips.join(" • ")}', style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                );
              },
              error: (e, _) => GlassCard(
                child: Text(
                  'Your AI service needs an Anthropic API key configured on the backend to draft appeals.',
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
