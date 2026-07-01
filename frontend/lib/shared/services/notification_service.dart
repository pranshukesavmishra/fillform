import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class NotificationApiService {
  final Dio _dio;
  NotificationApiService(this._dio);

  Future<Map<String, dynamic>> listMyNotifications({bool unreadOnly = false}) async {
    final resp = await _dio.get('/api/v1/notifications/my', queryParameters: {
      'unread_only': unreadOnly,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<void> markRead(String notificationId) async {
    await _dio.post('/api/v1/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await _dio.post('/api/v1/notifications/read-all');
  }
}

final notificationApiServiceProvider = Provider<NotificationApiService>(
  (ref) => NotificationApiService(ref.watch(dioProvider)),
);
