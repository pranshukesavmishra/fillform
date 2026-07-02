import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/opportunity_model.dart';

class OpportunityService {
  final Dio _dio;
  OpportunityService(this._dio);

  Future<List<OpportunityModel>> listOpportunities({
    String? category,
    String? state,
    String? educationLevel,
    String? q,
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _dio.get('/api/v1/opportunities', queryParameters: {
      if (category != null) 'category': category,
      if (state != null) 'state': state,
      if (educationLevel != null) 'education_level': educationLevel,
      if (q != null && q.isNotEmpty) 'q': q,
      'page': page,
      'page_size': pageSize,
    });
    final list = resp.data['data'] as List? ?? [];
    return list.map((e) => OpportunityModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OpportunityModel> getOpportunity(String id) async {
    final resp = await _dio.get('/api/v1/opportunities/$id');
    return OpportunityModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> toggleSave(String id) async {
    await _dio.post('/api/v1/opportunities/$id/save');
  }

  Future<List<Map<String, dynamic>>> checkEligibility(
    Map<String, dynamic> careerDna, {
    List<String>? opportunityIds,
  }) async {
    final resp = await _dio.post('/api/v1/opportunities/check-eligibility', data: {
      'career_dna': careerDna,
      if (opportunityIds != null) 'opportunity_ids': opportunityIds,
    });
    return (resp.data as List).cast<Map<String, dynamic>>();
  }
}

final opportunityServiceProvider = Provider<OpportunityService>(
  (ref) => OpportunityService(ref.watch(dioProvider)),
);
