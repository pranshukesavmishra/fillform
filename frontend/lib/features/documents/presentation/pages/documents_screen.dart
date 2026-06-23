import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('My Documents')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload zone
            GradientCard(
              gradient: const [Color(0xFF1E1B4B), Color(0xFF312E81)],
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primaryLight),
                  const SizedBox(height: AppSpacing.md),
                  Text('Drop documents here or tap to upload', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text('AI will automatically identify and verify your documents', style: AppTextStyles.caption, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Upload Document'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Uploaded Documents', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.md),
            // Document list placeholder
            GlassCard(
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
            ),
          ],
        ),
      ),
    );
  }
}
