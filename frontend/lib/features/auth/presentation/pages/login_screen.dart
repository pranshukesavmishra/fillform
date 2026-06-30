import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? phone;

  const LoginScreen({super.key, this.phone});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  int _resendTimer = 0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.phone != null) {
      _phoneController.text = widget.phone!;
      _otpSent = true;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (_phoneController.text.length != 10) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    await ref.read(authProvider.notifier).sendOtp(_phoneController.text);
    final state = ref.read(authProvider);
    if (!mounted) return;
    if (state.step == AuthStep.error) {
      setState(() {
        _isLoading = false;
        _errorText = state.error;
      });
      return;
    }
    setState(() {
      _isLoading = false;
      _otpSent = true;
      _resendTimer = 30;
    });
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendTimer = (_resendTimer - 1).clamp(0, 30));
      return _resendTimer > 0;
    });
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    final success = await ref.read(authProvider.notifier).verifyOtp(_otpController.text);
    if (!mounted) return;
    if (!success) {
      setState(() {
        _isLoading = false;
        _errorText = ref.read(authProvider).error;
      });
      return;
    }
    setState(() => _isLoading = false);
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0E17),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
              ),
            ),
          ),

          // Decorative blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: isWide ? _wideLayout() : _mobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _mobileLayout() => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        _buildLogo(),
        const SizedBox(height: AppSpacing.xxl),
        _buildForm(),
        const SizedBox(height: AppSpacing.xl),
        _buildSocialLogin(),
        const SizedBox(height: AppSpacing.xl),
        _buildFooter(),
      ],
    ),
  );

  Widget _wideLayout() => Row(
    children: [
      // Left panel - branding
      Expanded(
        flex: 5,
        child: Padding(
          padding: const EdgeInsets.all(64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogo(),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'India\'s Smartest\nCareer Platform',
                style: AppTextStyles.displayLarge,
              ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.3),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Join 2M+ students who never miss an opportunity.\nAI-powered. Vernacular. Free.',
                style: AppTextStyles.bodyLarge.copyWith(height: 1.8),
              ).animate().fadeIn(delay: 300.ms, duration: 800.ms),
              const SizedBox(height: AppSpacing.xxl),
              // Stats
              Row(
                children: [
                  _statBadge('2M+', 'Students'),
                  const SizedBox(width: AppSpacing.lg),
                  _statBadge('₹40Cr+', 'Scholarships Won'),
                  const SizedBox(width: AppSpacing.lg),
                  _statBadge('500+', 'Opportunities'),
                ],
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),

      // Right panel - form
      Expanded(
        flex: 4,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildForm(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSocialLogin(),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildLogo() => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 26),
      ),
      const SizedBox(width: 12),
      Text(
        'FillFormAI',
        style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  ).animate().fadeIn().slideX(begin: -0.2);

  Widget _buildForm() => GlassCard(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: AnimatedSwitcher(
      duration: AppDurations.medium,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _otpSent ? _otpForm() : _phoneForm(),
    ),
  );

  Widget _phoneForm() => Column(
    key: const ValueKey('phone'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Welcome Back 👋', style: AppTextStyles.headlineMedium),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Enter your mobile number to get started',
        style: AppTextStyles.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.xl),

      // Phone input
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        style: AppTextStyles.titleMedium,
        decoration: InputDecoration(
          hintText: '10-digit mobile number',
          counterText: '',
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🇮🇳', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text('+91', style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                )),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: AppColors.divider),
              ],
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),

      if (_errorText != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(_errorText!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
      ],

      const SizedBox(height: AppSpacing.lg),

      SizedBox(
        width: double.infinity,
        child: _GradientButton(
          onPressed: _phoneController.text.length == 10 && !_isLoading
              ? _sendOTP
              : null,
          isLoading: _isLoading,
          label: 'Send OTP →',
        ),
      ),

      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('or continue with', style: AppTextStyles.caption),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    ],
  );

  Widget _otpForm() => Column(
    key: const ValueKey('otp'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Back button
      GestureDetector(
        onTap: () => setState(() => _otpSent = false),
        child: Row(
          children: [
            const Icon(Icons.arrow_back_ios_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('Change number', style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            )),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),

      Text('Verify OTP 🔐', style: AppTextStyles.headlineMedium),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Sent to +91 ${_phoneController.text}',
        style: AppTextStyles.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.xl),

      TextFormField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: AppTextStyles.headlineMedium.copyWith(letterSpacing: 12),
        decoration: InputDecoration(
          hintText: '• • • • • •',
          hintStyle: AppTextStyles.headlineMedium.copyWith(
            letterSpacing: 12,
            color: AppColors.textMuted,
          ),
          counterText: '',
        ),
        onChanged: (v) {
          setState(() {});
          if (v.length == 6) _verifyOTP();
        },
      ),

      const SizedBox(height: AppSpacing.md),
      Center(
        child: _resendTimer > 0
            ? Text(
                'Resend OTP in ${_resendTimer}s',
                style: AppTextStyles.caption,
              )
            : TextButton(
                onPressed: _sendOTP,
                child: Text(
                  'Resend OTP',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
      ),

      if (_errorText != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(_errorText!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
        ),
      ],

      const SizedBox(height: AppSpacing.md),

      SizedBox(
        width: double.infinity,
        child: _GradientButton(
          onPressed: _otpController.text.length == 6 && !_isLoading
              ? _verifyOTP
              : null,
          isLoading: _isLoading,
          label: 'Verify & Continue →',
        ),
      ),
    ],
  );

  Widget _buildSocialLogin() => Column(
    children: [
      _SocialButton(
        onPressed: () {},
        icon: 'G',
        label: 'Continue with Google',
        color: const Color(0xFF4285F4),
      ),
    ],
  );

  Widget _buildFooter() => Center(
    child: Text(
      'By continuing, you agree to our Terms & Privacy Policy.\nYour data is encrypted and never sold.',
      style: AppTextStyles.caption,
      textAlign: TextAlign.center,
    ),
  );

  Widget _statBadge(String value, String label) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: AppTextStyles.caption),
      ],
    ),
  );
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const _GradientButton({
    required this.onPressed,
    required this.label,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.5,
      duration: AppDurations.fast,
      child: Container(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(colors: AppColors.primaryGradient)
              : null,
          color: enabled ? null : AppColors.divider,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String icon;
  final String label;
  final Color color;

  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.bgCardLight,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTextStyles.labelLarge),
        ],
      ),
    );
  }
}
