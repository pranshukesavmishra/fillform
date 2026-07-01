import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/ai_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// AI-generated briefing/skill-gap calls hit a real LLM (Anthropic) via
/// ai_service. If no API key is configured on the backend, these throw --
/// callers should show a graceful fallback rather than a raw error.
final dailyBriefingProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dna = await ref.watch(careerDnaProvider.future);
  return ref.watch(aiServiceProvider).getDailyBriefing(dna);
});

final skillGapProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dna = await ref.watch(careerDnaProvider.future);
  return ref.watch(aiServiceProvider).analyzeSkillGap(careerDna: dna);
});
