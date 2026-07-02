import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/notification_service.dart';

final notificationsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(notificationApiServiceProvider).listMyNotifications();
});

class NotificationActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationApiService _service;
  final Ref _ref;

  NotificationActionsNotifier(this._service, this._ref) : super(const AsyncData(null));

  Future<void> markRead(String id) async {
    await _service.markRead(id);
    _ref.invalidate(notificationsProvider);
  }

  Future<void> markAllRead() async {
    await _service.markAllRead();
    _ref.invalidate(notificationsProvider);
  }
}

final notificationActionsProvider =
    StateNotifierProvider<NotificationActionsNotifier, AsyncValue<void>>(
  (ref) => NotificationActionsNotifier(ref.watch(notificationApiServiceProvider), ref),
);
