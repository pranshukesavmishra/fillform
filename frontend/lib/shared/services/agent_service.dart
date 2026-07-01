import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class AgentService {
  final Dio _dio;
  AgentService(this._dio);

  Future<List<Map<String, dynamic>>> listAgents({
    String? district,
    String? specialization,
    String? language,
  }) async {
    final resp = await _dio.get('/api/v1/agents', queryParameters: {
      if (district != null) 'district': district,
      if (specialization != null) 'specialization': specialization,
      if (language != null) 'language': language,
    });
    return (resp.data['agents'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getAgent(String agentId) async {
    final resp = await _dio.get('/api/v1/agents/$agentId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bookSession({
    required String agentId,
    required String sessionType,
    required DateTime scheduledAt,
    required String issueDescription,
    int durationMinutes = 30,
    String preferredLanguage = 'hi',
  }) async {
    final resp = await _dio.post('/api/v1/agents/sessions/book', data: {
      'agent_id': agentId,
      'session_type': sessionType,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'issue_description': issueDescription,
      'preferred_language': preferredLanguage,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> mySessions() async {
    final resp = await _dio.get('/api/v1/agents/sessions/my');
    return (resp.data['sessions'] as List).cast<Map<String, dynamic>>();
  }
}

final agentServiceProvider = Provider<AgentService>(
  (ref) => AgentService(ref.watch(dioProvider)),
);
