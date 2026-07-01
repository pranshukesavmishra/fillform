import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/user_model.dart';

class ProfileService {
  final Dio _dio;
  ProfileService(this._dio);

  Future<UserModel> getMyProfile() async {
    final resp = await _dio.get('/api/v1/profile/me');
    return UserModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getCareerDna() async {
    final resp = await _dio.get('/api/v1/profile/career-dna');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _dio.put('/api/v1/profile/me', data: data);
  }

  Future<List<Map<String, dynamic>>> getDocuments() async {
    final resp = await _dio.get('/api/v1/profile/documents');
    return (resp.data['documents'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getStats() async {
    final resp = await _dio.get('/api/v1/profile/stats');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteDocument(String docId) async {
    await _dio.delete('/api/v1/profile/documents/$docId');
  }

  /// Records that a document was uploaded. NOTE: this only stores metadata
  /// (document type, file name) -- there's no S3-compatible object storage
  /// configured for this deploy yet, so the actual file bytes aren't
  /// persisted anywhere. Once real object storage credentials are added,
  /// this should upload the bytes first and pass the real storage key.
  Future<void> recordDocumentUploaded({
    required String documentType,
    required String fileName,
  }) async {
    await _dio.post('/api/v1/profile/documents', data: {
      'document_type': documentType,
      'file_name': fileName,
      's3_key': 'unconfigured/$documentType/$fileName',
    });
  }
}

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(dioProvider)),
);
