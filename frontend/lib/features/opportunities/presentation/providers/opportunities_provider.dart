import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/opportunity_model.dart';
import '../../../../shared/services/opportunity_service.dart';

class OpportunityFilter {
  final String? category;
  final String? state;
  final String searchQuery;
  final bool matchOnly;

  const OpportunityFilter({
    this.category,
    this.state,
    this.searchQuery = '',
    this.matchOnly = false,
  });

  OpportunityFilter copyWith({
    String? category,
    String? state,
    String? searchQuery,
    bool? matchOnly,
  }) {
    return OpportunityFilter(
      category: category ?? this.category,
      state: state ?? this.state,
      searchQuery: searchQuery ?? this.searchQuery,
      matchOnly: matchOnly ?? this.matchOnly,
    );
  }
}

final opportunityFilterProvider = StateProvider<OpportunityFilter>(
  (_) => const OpportunityFilter(),
);

final opportunitiesProvider = FutureProvider<List<OpportunityModel>>((ref) async {
  final filter = ref.watch(opportunityFilterProvider);
  final service = ref.watch(opportunityServiceProvider);

  if (filter.searchQuery.isNotEmpty) {
    return service.searchOpportunities(filter.searchQuery);
  }

  return service.listOpportunities(
    category: filter.category,
    state: filter.state,
    matchOnly: filter.matchOnly,
  );
});

final opportunityDetailProvider = FutureProvider.family<OpportunityModel, String>((ref, id) async {
  return ref.watch(opportunityServiceProvider).getOpportunity(id);
});

final bookmarkProvider = StateNotifierProvider<BookmarkNotifier, Set<String>>(
  (ref) => BookmarkNotifier(ref.watch(opportunityServiceProvider)),
);

class BookmarkNotifier extends StateNotifier<Set<String>> {
  final OpportunityService _service;
  BookmarkNotifier(this._service) : super({});

  Future<void> toggle(String id) async {
    if (state.contains(id)) {
      await _service.removeBookmark(id);
      state = {...state}..remove(id);
    } else {
      await _service.bookmarkOpportunity(id);
      state = {...state, id};
    }
  }
}
