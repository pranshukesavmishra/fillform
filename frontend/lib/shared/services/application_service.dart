import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../models/application_model.dart';

class ApplicationService {
  final Dio _dio;
  ApplicationService(this._dio);

  Future<Map<String, dynamic>> apply({
    required String opportunityId,
    required Map<String, dynamic> formData,
    List<String> documentIds = const [],
    String? registrationNumber,
  }) async {
    final resp = await _dio.post('/api/v1/applications/apply', data: {
      'opportunity_id': opportunityId,
      'form_data': formData,
      'documents': documentIds,
      if (registrationNumber != null) 'registration_number': registrationNumber,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<List<ApplicationModel>> getMyApplications({String? status}) async {
    final resp = await _dio.get('/api/v1/applications/my', queryParameters: {
      if (status != null) 'status': status,
    });
    final list = resp.data['applications'] as List? ?? [];
    return list.map((e) => ApplicationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getApplication(String id) async {
    final resp = await _dio.get('/api/v1/applications/$id');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStats() async {
    final resp = await _dio.get('/api/v1/applications/stats/summary');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> withdrawApplication(String id) async {
    await _dio.delete('/api/v1/applications/$id/withdraw');
  }
}

final applicationServiceProvider = Provider<ApplicationService>(
  (ref) => ApplicationService(ref.watch(dioProvider)),
);
