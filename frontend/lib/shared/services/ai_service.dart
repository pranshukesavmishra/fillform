import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class AIService {
  final Dio _dio;
  AIService(this._dio);

  Future<Map<String, dynamic>> chatWithCareerTwin({
    required String message,
    required Map<String, dynamic> careerDna,
    String? conversationId,
    String language = 'hi',
  }) async {
    final resp = await _dio.post('/api/v1/ai/career-twin/chat', data: {
      'message': message,
      'career_dna': careerDna,
      if (conversationId != null) 'conversation_id': conversationId,
      'language': language,
      'stream': false,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fillForm({
    required List<Map<String, dynamic>> formFields,
    required Map<String, dynamic> careerDna,
    required String opportunityId,
  }) async {
    final resp = await _dio.post('/api/v1/ai/form/fill', data: {
      'form_fields': formFields,
      'career_dna': careerDna,
      'opportunity_id': opportunityId,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> predictSuccess({
    required Map<String, dynamic> careerDna,
    required String opportunityId,
    required Map<String, dynamic> opportunityData,
  }) async {
    final resp = await _dio.post('/api/v1/ai/success-probability', data: {
      'career_dna': careerDna,
      'opportunity_id': opportunityId,
      'opportunity_data': opportunityData,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> buildSop({
    required Map<String, dynamic> careerDna,
    required Map<String, dynamic> opportunity,
    String tone = 'professional',
    int wordLimit = 500,
    String language = 'en',
  }) async {
    final resp = await _dio.post('/api/v1/ai/sop', data: {
      'career_dna': careerDna,
      'opportunity': opportunity,
      'tone': tone,
      'word_limit': wordLimit,
      'language': language,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> writeAppeal({
    required Map<String, dynamic> applicationData,
    required Map<String, dynamic> studentProfile,
    String? rejectionReason,
    Map<String, dynamic>? opportunityData,
    String language = 'both',
  }) async {
    final resp = await _dio.post('/api/v1/ai/appeal', data: {
      'application_data': applicationData,
      'student_profile': studentProfile,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (opportunityData != null) 'opportunity_data': opportunityData,
      'language': language,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> analyzeSkillGap({
    required Map<String, dynamic> careerDna,
    String? careerGoal,
  }) async {
    final resp = await _dio.post('/api/v1/ai/skill-gap', data: {
      'career_dna': careerDna,
      if (careerGoal != null) 'career_goal': careerGoal,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateRoadmap({
    required Map<String, dynamic> careerDna,
    required String goal,
    int timelineMonths = 24,
    String language = 'hi',
  }) async {
    final resp = await _dio.post('/api/v1/ai/roadmap', data: {
      'career_dna': careerDna,
      'goal': goal,
      'timeline_months': timelineMonths,
      'language': language,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDailyBriefing(Map<String, dynamic> careerDna) async {
    final resp = await _dio.get('/api/v1/ai/briefing', queryParameters: {
      'career_dna': careerDna.toString(),
    });
    return resp.data as Map<String, dynamic>;
  }
}

final aiServiceProvider = Provider<AIService>(
  (ref) => AIService(ref.watch(dioProvider)),
);
