import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/ai_service.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../../../opportunities/presentation/providers/opportunities_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class ApplicationScreen extends ConsumerStatefulWidget {
  final String opportunityId;
  const ApplicationScreen({super.key, required this.opportunityId});

  @override
  ConsumerState<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends ConsumerState<ApplicationScreen> {
  bool _isFilling = false;
  Map<String, dynamic>? _result;
  String? _error;
  String? _portalUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAutoFill());
  }

  Future<void> _runAutoFill() async {
    setState(() {
      _isFilling = true;
      _error = null;
    });
    try {
      final opportunity =
          await ref.read(opportunityDetailProvider(widget.opportunityId).future);
      final portalUrl = opportunity.portalUrl;
      _portalUrl = portalUrl;
      if (portalUrl == null || portalUrl.isEmpty) {
        setState(() {
          _isFilling = false;
          _error = 'This opportunity has no linked application portal yet.';
        });
        return;
      }

      final careerDna = await ref.read(careerDnaProvider.future);
      final result = await ref.read(aiServiceProvider).autoFillForm(
            portalUrl: portalUrl,
            careerDna: careerDna,
            opportunityId: widget.opportunityId,
          );
      setState(() {
        _result = result;
        _isFilling = false;
      });
    } catch (e) {
      setState(() {
        _isFilling = false;
        _error = 'Auto-fill failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final opportunityAsync = ref.watch(opportunityDetailProvider(widget.opportunityId));

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(
          opportunityAsync.maybeWhen(
            data: (o) => 'Apply: ${o.title}',
            orElse: () => 'Apply',
          ),
        ),
      ),
      body: _isFilling
          ? _LoadingState(portalUrl: _portalUrl)
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _runAutoFill)
              : _result == null
                  ? const SizedBox.shrink()
                  : _ReviewState(
                      result: _result!,
                      portalUrl: _portalUrl,
                      onRetry: _runAutoFill,
                    ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final String? portalUrl;
  const _LoadingState({this.portalUrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('AI is opening the real application portal…', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            portalUrl ?? '',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This can take up to 30 seconds — it is filling the live form,\nnot a simulation.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ReviewState extends StatelessWidget {
  final Map<String, dynamic> result;
  final String? portalUrl;
  final VoidCallback onRetry;
  const _ReviewState({required this.result, required this.portalUrl, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final steps = (result['steps'] as List? ?? []).cast<Map<String, dynamic>>();
    final screenshotB64 = result['screenshot_b64'] as String?;
    final fieldsFilled = result['fields_filled'] as int? ?? 0;
    final fieldsTotal = result['fields_total'] as int? ?? 0;
    final needsReview = (result['requires_manual_review'] as List? ?? []).cast<String>();
    final backendError = result['error'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Row(
              children: [
                Icon(
                  fieldsFilled > 0 ? Icons.smart_toy_outlined : Icons.warning_amber_rounded,
                  color: fieldsFilled > 0 ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    backendError ??
                        'AI filled $fieldsFilled of $fieldsTotal fields on the live portal. '
                            'Nothing was submitted — review below, then finish on the official site.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (screenshotB64 != null) ...[
            Text('Portal screenshot (after auto-fill)', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(base64Decode(screenshotB64)),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          if (steps.isNotEmpty) ...[
            Text('Field-by-field report', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...steps.map((s) => _StepRow(step: s)),
            const SizedBox(height: AppSpacing.lg),
          ],

          if (needsReview.isNotEmpty)
            GlassCard(
              borderColor: AppColors.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Needs your attention before submitting:',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.warning)),
                  const SizedBox(height: 6),
                  ...needsReview.map((f) => Text('• $f', style: AppTextStyles.caption)),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onRetry, child: const Text('Re-run Auto-Fill')),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: portalUrl == null
                      ? null
                      : () => launchUrl(Uri.parse(portalUrl!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Portal to Review & Submit'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'FillFormAI never submits government forms on your behalf — '
            'you always confirm and submit yourself on the official portal.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final Map<String, dynamic> step;
  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final status = step['status'] as String? ?? '';
    final label = step['label'] as String? ?? '';
    final value = step['value'] as String?;
    final note = step['note'] as String? ?? '';

    final IconData icon;
    final Color color;
    switch (status) {
      case 'filled':
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case 'needs_review':
        icon = Icons.error_outline;
        color = AppColors.warning;
        break;
      case 'failed':
        icon = Icons.cancel_outlined;
        color = AppColors.error;
        break;
      default:
        icon = Icons.remove_circle_outline;
        color = AppColors.textMuted;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyMedium),
                if (value != null && value.isNotEmpty)
                  Text(value, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                if (note.isNotEmpty) Text(note, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
