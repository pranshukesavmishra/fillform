import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/opportunity_model.dart';
import '../../../../shared/services/opportunity_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class OpportunityFilter {
  final String? category;
  final String? state;
  final String searchQuery;
  final bool eligibleOnly;

  const OpportunityFilter({
    this.category,
    this.state,
    this.searchQuery = '',
    this.eligibleOnly = true,
  });

  OpportunityFilter copyWith({
    String? category,
    String? state,
    String? searchQuery,
    bool? eligibleOnly,
  }) {
    return OpportunityFilter(
      category: category ?? this.category,
      state: state ?? this.state,
      searchQuery: searchQuery ?? this.searchQuery,
      eligibleOnly: eligibleOnly ?? this.eligibleOnly,
    );
  }
}

final opportunityFilterProvider = StateProvider<OpportunityFilter>(
  (_) => const OpportunityFilter(),
);

final opportunitiesProvider = FutureProvider<List<OpportunityModel>>((ref) async {
  final filter = ref.watch(opportunityFilterProvider);
  final service = ref.watch(opportunityServiceProvider);

  String? educationLevel;
  if (filter.eligibleOnly) {
    final profile = await ref.watch(profileProvider.future);
    educationLevel = profile.educationLevel;
  }

  return service.listOpportunities(
    category: filter.category,
    state: filter.state,
    educationLevel: educationLevel,
    q: filter.searchQuery,
  );
});

final opportunityDetailProvider = FutureProvider.family<OpportunityModel, String>((ref, id) async {
  return ref.watch(opportunityServiceProvider).getOpportunity(id);
});

final savedOpportunitiesProvider = StateNotifierProvider<SavedOpportunityNotifier, Set<String>>(
  (ref) => SavedOpportunityNotifier(ref.watch(opportunityServiceProvider)),
);

class SavedOpportunityNotifier extends StateNotifier<Set<String>> {
  final OpportunityService _service;
  SavedOpportunityNotifier(this._service) : super({});

  Future<void> toggle(String id) async {
    await _service.toggleSave(id);
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }
}
