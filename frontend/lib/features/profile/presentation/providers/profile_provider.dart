import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/user_model.dart';
import '../../../../shared/services/profile_service.dart';

final profileProvider = FutureProvider<UserModel>((ref) async {
  return ref.watch(profileServiceProvider).getMyProfile();
});

final careerDnaProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(profileServiceProvider).getCareerDna();
});

final profileStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(profileServiceProvider).getStats();
});

final documentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(profileServiceProvider).getDocuments();
});

class ProfileUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  final ProfileService _service;
  final Ref _ref;

  ProfileUpdateNotifier(this._service, this._ref) : super(const AsyncData(null));

  Future<void> update(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await _service.updateProfile(data);
      _ref.invalidate(profileProvider);
      _ref.invalidate(careerDnaProvider);
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> deleteDocument(String docId) async {
    try {
      await _service.deleteDocument(docId);
      _ref.invalidate(documentsProvider);
    } catch (e) {
      rethrow;
    }
  }
}

final profileUpdateProvider = StateNotifierProvider<ProfileUpdateNotifier, AsyncValue<void>>(
  (ref) => ProfileUpdateNotifier(ref.watch(profileServiceProvider), ref),
);
