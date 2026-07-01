import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/agent_service.dart';

final agentListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(agentServiceProvider).listAgents();
});

class SessionBookingNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final AgentService _service;

  SessionBookingNotifier(this._service) : super(const AsyncData(null));

  Future<void> book({
    required String agentId,
    required String sessionType,
    required DateTime scheduledAt,
    required String issueDescription,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _service.bookSession(
        agentId: agentId,
        sessionType: sessionType,
        scheduledAt: scheduledAt,
        issueDescription: issueDescription,
      );
      state = AsyncData(result);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}

final sessionBookingProvider =
    StateNotifierProvider<SessionBookingNotifier, AsyncValue<Map<String, dynamic>?>>(
  (ref) => SessionBookingNotifier(ref.watch(agentServiceProvider)),
);
