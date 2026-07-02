import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/ai_service.dart';

class SopNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final AIService _service;
  SopNotifier(this._service) : super(const AsyncData(null));

  Future<void> generate({
    required Map<String, dynamic> careerDna,
    required Map<String, dynamic> opportunity,
    String tone = 'professional',
    int wordLimit = 500,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _service.buildSop(
        careerDna: careerDna,
        opportunity: opportunity,
        tone: tone,
        wordLimit: wordLimit,
      );
      state = AsyncData(result);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}

final sopProvider = StateNotifierProvider<SopNotifier, AsyncValue<Map<String, dynamic>?>>(
  (ref) => SopNotifier(ref.watch(aiServiceProvider)),
);

class AppealNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final AIService _service;
  AppealNotifier(this._service) : super(const AsyncData(null));

  Future<void> generate({
    required Map<String, dynamic> applicationData,
    required Map<String, dynamic> studentProfile,
    String? rejectionReason,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _service.writeAppeal(
        applicationData: applicationData,
        studentProfile: studentProfile,
        rejectionReason: rejectionReason,
      );
      state = AsyncData(result);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}

final appealProvider = StateNotifierProvider<AppealNotifier, AsyncValue<Map<String, dynamic>?>>(
  (ref) => AppealNotifier(ref.watch(aiServiceProvider)),
);

class RoadmapNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final AIService _service;
  RoadmapNotifier(this._service) : super(const AsyncData(null));

  Future<void> generate({
    required Map<String, dynamic> careerDna,
    required String goal,
    int timelineMonths = 24,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _service.generateRoadmap(
        careerDna: careerDna,
        goal: goal,
        timelineMonths: timelineMonths,
        language: 'en',
      );
      state = AsyncData(result);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}

final roadmapProvider = StateNotifierProvider<RoadmapNotifier, AsyncValue<Map<String, dynamic>?>>(
  (ref) => RoadmapNotifier(ref.watch(aiServiceProvider)),
);
