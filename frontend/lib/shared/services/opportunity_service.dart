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
    int limit = 20,
    int offset = 0,
    bool matchOnly = false,
  }) async {
    final resp = await _dio.get('/api/v1/opportunities', queryParameters: {
      if (category != null) 'category': category,
      if (state != null) 'state': state,
      'limit': limit,
      'offset': offset,
      if (matchOnly) 'match_only': true,
    });
    final list = resp.data['opportunities'] as List? ?? [];
    return list.map((e) => OpportunityModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OpportunityModel> getOpportunity(String id) async {
    final resp = await _dio.get('/api/v1/opportunities/$id');
    return OpportunityModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<OpportunityModel>> searchOpportunities(String query) async {
    final resp = await _dio.get('/api/v1/opportunities/search', queryParameters: {'q': query});
    final list = resp.data['opportunities'] as List? ?? [];
    return list.map((e) => OpportunityModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> bookmarkOpportunity(String id) async {
    await _dio.post('/api/v1/opportunities/$id/bookmark');
  }

  Future<void> removeBookmark(String id) async {
    await _dio.delete('/api/v1/opportunities/$id/bookmark');
  }

  Future<Map<String, dynamic>> checkEligibility(String id, Map<String, dynamic> careerDna) async {
    final resp = await _dio.post('/api/v1/opportunities/$id/eligibility', data: {'career_dna': careerDna});
    return resp.data as Map<String, dynamic>;
  }
}

final opportunityServiceProvider = Provider<OpportunityService>(
  (ref) => OpportunityService(ref.watch(dioProvider)),
);
