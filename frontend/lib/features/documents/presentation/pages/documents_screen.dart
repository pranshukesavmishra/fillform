import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

const _documentTypes = [
  ('aadhaar', 'Aadhaar Card'),
  ('10th_marksheet', '10th Marksheet'),
  ('12th_marksheet', '12th Marksheet'),
  ('income_certificate', 'Income Certificate'),
  ('caste_certificate', 'Caste Certificate'),
  ('domicile_certificate', 'Domicile Certificate'),
  ('bank_passbook', 'Bank Passbook'),
  ('bonafide', 'Bonafide Certificate'),
  ('character_certificate', 'Character Certificate'),
];

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final docType = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('What document is this?'),
        children: _documentTypes.map((d) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, d.$1),
          child: Text(d.$2),
        )).toList(),
      ),
    );
    if (docType == null) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final fileName = result.files.single.name;
    setState(() => _isUploading = true);
    try {
      await ref.read(profileUpdateProvider.notifier).uploadDocument(
        documentType: docType,
        fileName: fileName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document recorded. Verification is pending.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _delete(String docId) async {
    try {
      await ref.read(profileUpdateProvider.notifier).deleteDocument(docId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  String _labelFor(String? type) {
    return _documentTypes.firstWhere(
      (d) => d.$1 == type,
      orElse: () => (type ?? 'unknown', type ?? 'Unknown document'),
    ).$2;
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('My Documents')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientCard(
              gradient: const [Color(0xFF1E1B4B), Color(0xFF312E81)],
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primaryLight),
                  const SizedBox(height: AppSpacing.md),
                  Text('Upload your documents', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'These get linked to your Career DNA and used for auto-filling applications.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickAndUpload,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload Document'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Uploaded Documents', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: docsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Failed to load documents: $e', style: AppTextStyles.bodyMedium),
                data: (docs) {
                  if (docs.isEmpty) {
                    return GlassCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              const Text('📂', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: AppSpacing.md),
                              Text('Upload your first document', style: AppTextStyles.titleMedium),
                              Text('AI will verify and organize them automatically', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final isVerified = doc['is_verified'] == true;
                      final isExpired = doc['is_expired'] == true;
                      return GlassCard(
                        child: Row(
                          children: [
                            Icon(
                              isVerified ? Icons.check_circle : Icons.hourglass_top_outlined,
                              color: isExpired
                                  ? AppColors.error
                                  : isVerified
                                      ? AppColors.success
                                      : AppColors.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_labelFor(doc['document_type'] as String?), style: AppTextStyles.bodyMedium),
                                  Text(
                                    doc['file_name']?.toString() ?? '',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              isExpired ? 'Expired' : (isVerified ? 'Verified' : 'Pending verification'),
                              style: AppTextStyles.caption.copyWith(
                                color: isExpired
                                    ? AppColors.error
                                    : isVerified
                                        ? AppColors.success
                                        : AppColors.textMuted,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                              onPressed: () => _delete(doc['id'].toString()),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
