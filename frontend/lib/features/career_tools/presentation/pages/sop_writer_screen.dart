import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../../../opportunities/presentation/providers/opportunities_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/career_tools_provider.dart';

class SopWriterScreen extends ConsumerStatefulWidget {
  const SopWriterScreen({super.key});

  @override
  ConsumerState<SopWriterScreen> createState() => _SopWriterScreenState();
}

class _SopWriterScreenState extends ConsumerState<SopWriterScreen> {
  String? _selectedOpportunityId;
  String _tone = 'professional';

  @override
  Widget build(BuildContext context) {
    final opportunitiesAsync = ref.watch(opportunitiesProvider);
    final sopState = ref.watch(sopProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('SOP Writer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generate a Statement of Purpose', style: AppTextStyles.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Pick which opportunity you\'re applying to and let AI draft your SOP from your Career DNA.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Opportunity', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  opportunitiesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Failed to load opportunities', style: AppTextStyles.caption),
                    data: (opportunities) {
                      if (opportunities.isEmpty) {
                        return Text('No opportunities available yet.', style: AppTextStyles.caption);
                      }
                      return DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedOpportunityId,
                        hint: const Text('Select an opportunity'),
                        items: opportunities.map((o) => DropdownMenuItem(
                          value: o.id,
                          child: Text(o.title, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedOpportunityId = v),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Tone', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButton<String>(
                    value: _tone,
                    items: const [
                      DropdownMenuItem(value: 'professional', child: Text('Professional')),
                      DropdownMenuItem(value: 'academic', child: Text('Academic')),
                      DropdownMenuItem(value: 'personal', child: Text('Personal')),
                    ],
                    onChanged: (v) => setState(() => _tone = v ?? _tone),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedOpportunityId == null || sopState.isLoading
                          ? null
                          : () async {
                              final dna = await ref.read(careerDnaProvider.future);
                              final opportunities = await ref.read(opportunitiesProvider.future);
                              final opp = opportunities.firstWhere((o) => o.id == _selectedOpportunityId);
                              ref.read(sopProvider.notifier).generate(
                                careerDna: dna,
                                opportunity: {
                                  'title': opp.title,
                                  'issuing_authority': opp.issuingAuthority,
                                  'category': opp.category,
                                  'description': opp.description,
                                },
                                tone: _tone,
                              );
                            },
                      child: sopState.isLoading
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Generate SOP'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            sopState.when(
              data: (data) {
                if (data == null) return const SizedBox.shrink();
                final sopText = data['sop_text']?.toString() ?? data['raw']?.toString() ?? '';
                final themes = (data['key_themes'] as List?)?.cast<String>() ?? [];
                final tips = (data['improvement_tips'] as List?)?.cast<String>() ?? [];
                return GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Draft SOP', style: AppTextStyles.titleLarge),
                      if (data['word_count'] != null)
                        Text('${data['word_count']} words', style: AppTextStyles.caption),
                      const SizedBox(height: AppSpacing.md),
                      SelectableText(sopText, style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
                      if (themes.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text('Key Themes: ${themes.join(", ")}', style: AppTextStyles.caption),
                      ],
                      if (tips.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Tips: ${tips.join(" • ")}', style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                );
              },
              error: (e, _) => GlassCard(
                child: Text(
                  'Your AI service needs an Anthropic API key configured on the backend to generate SOPs.',
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
