import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class ApplicationScreen extends StatefulWidget {
  final String opportunityId;
  const ApplicationScreen({super.key, required this.opportunityId});

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  int _currentStep = 0;
  double _aiFilledPercent = 0.0;
  bool _isAIFilling = false;

  @override
  void initState() {
    super.initState();
    _simulateAIFill();
  }

  void _simulateAIFill() async {
    setState(() => _isAIFilling = true);
    for (int i = 0; i <= 80; i += 5) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) setState(() => _aiFilledPercent = i / 100);
    }
    setState(() => _isAIFilling = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Apply: PM Scholarship 2024'),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Save Draft'),
          ),
        ],
      ),
      body: Column(
        children: [
          // AI fill banner
          if (_isAIFilling || _aiFilledPercent > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.2), AppColors.bgCard],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_outlined, color: AppColors.primaryLight, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAIFilling
                              ? 'AI is filling your form...'
                              : 'AI filled ${(_aiFilledPercent * 100).toInt()}% of fields',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryLight),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: _aiFilledPercent,
                          backgroundColor: AppColors.divider,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
                          borderRadius: BorderRadius.circular(2),
                          minHeight: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),

          // Form content
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Steps sidebar
                if (MediaQuery.of(context).size.width > 700)
                  _StepsSidebar(currentStep: _currentStep),

                // Form fields
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: _FormStep(
                      step: _currentStep,
                      aiFilledPercent: _aiFilledPercent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom actions
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('← Previous'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentStep < 3) {
                        setState(() => _currentStep++);
                      }
                    },
                    child: Text(_currentStep < 3 ? 'Next →' : 'Submit Application'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsSidebar extends StatelessWidget {
  final int currentStep;
  const _StepsSidebar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = ['Personal Info', 'Education', 'Documents', 'Review'];
    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: steps.asMap().entries.map((e) => _StepItem(
          label: e.value,
          index: e.key,
          currentStep: currentStep,
        )).toList(),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String label;
  final int index;
  final int currentStep;
  const _StepItem({required this.label, required this.index, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final isDone = index < currentStep;
    final isCurrent = index == currentStep;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AppColors.success : isCurrent ? AppColors.primary : AppColors.bgCardLight,
              border: isCurrent ? Border.all(color: AppColors.primaryLight, width: 2) : null,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${index + 1}', style: AppTextStyles.caption.copyWith(
                      color: isCurrent ? Colors.white : AppColors.textMuted,
                    )),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isCurrent ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormStep extends StatelessWidget {
  final int step;
  final double aiFilledPercent;
  const _FormStep({required this.step, required this.aiFilledPercent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Confidence badge
        if (aiFilledPercent > 0)
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'AI Auto-filled with 94% accuracy. Review each field carefully.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ),

        if (aiFilledPercent > 0) const SizedBox(height: AppSpacing.xl),

        // Form fields
        _AiFilledField(label: 'Full Name (as per Aadhaar)', value: 'Anshu Kumar Mishra', confidence: 0.99),
        _AiFilledField(label: "Father's Name", value: 'Rajesh Kumar Mishra', confidence: 0.98),
        _AiFilledField(label: 'Date of Birth', value: '14/03/2005', confidence: 0.99),
        _AiFilledField(label: 'Category', value: 'OBC-NCL', confidence: 0.95),
        _AiFilledField(label: 'Mobile Number', value: '9876543210', confidence: 0.99),
        _AiFilledField(label: 'Email Address', value: 'anshu@example.com', confidence: 0.95),
        _AiFilledField(label: 'State', value: 'Uttar Pradesh', confidence: 0.99),
        _AiFilledField(label: 'District', value: 'Varanasi', confidence: 0.99),
        _AiFilledField(
          label: 'Annual Family Income (₹)',
          value: '',
          confidence: 0.0,
          isRequired: true,
          hint: 'Please enter your annual family income',
        ),
      ],
    );
  }
}

class _AiFilledField extends StatelessWidget {
  final String label;
  final String value;
  final double confidence;
  final bool isRequired;
  final String? hint;

  const _AiFilledField({
    required this.label,
    required this.value,
    required this.confidence,
    this.isRequired = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.labelLarge),
              if (isRequired)
                Text(' *', style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
              const Spacer(),
              if (!isEmpty && confidence > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.smart_toy_outlined, size: 10, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'AI ${(confidence * 100).toInt()}%',
                        style: AppTextStyles.caption.copyWith(color: AppColors.success, fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: value,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: isEmpty
                  ? AppColors.error.withOpacity(0.05)
                  : AppColors.success.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isEmpty
                      ? AppColors.error.withOpacity(0.4)
                      : AppColors.success.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isEmpty
                      ? AppColors.error.withOpacity(0.4)
                      : AppColors.success.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
