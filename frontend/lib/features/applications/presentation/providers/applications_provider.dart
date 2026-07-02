import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/application_model.dart';
import '../../../../shared/services/application_service.dart';

final applicationsProvider = FutureProvider<List<ApplicationModel>>((ref) async {
  return ref.watch(applicationServiceProvider).getMyApplications();
});

final applicationStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(applicationServiceProvider).getStats();
});

class ApplyNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final ApplicationService _service;
  final Ref _ref;

  ApplyNotifier(this._service, this._ref) : super(const AsyncData(null));

  Future<void> apply({
    required String opportunityId,
    required Map<String, dynamic> formData,
    List<String> documentIds = const [],
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _service.apply(
        opportunityId: opportunityId,
        formData: formData,
        documentIds: documentIds,
      );
      _ref.invalidate(applicationsProvider);
      _ref.invalidate(applicationStatsProvider);
      state = AsyncData(result);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> withdraw(String applicationId) async {
    try {
      await _service.withdrawApplication(applicationId);
      _ref.invalidate(applicationsProvider);
    } catch (e) {
      rethrow;
    }
  }
}

final applyNotifierProvider = StateNotifierProvider<ApplyNotifier, AsyncValue<Map<String, dynamic>?>>(
  (ref) => ApplyNotifier(ref.watch(applicationServiceProvider), ref),
);
