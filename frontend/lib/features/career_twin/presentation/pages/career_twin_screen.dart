import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/career_twin_provider.dart';

class CareerTwinScreen extends ConsumerStatefulWidget {
  const CareerTwinScreen({super.key});
  @override
  ConsumerState<CareerTwinScreen> createState() => _CareerTwinScreenState();
}

class _CareerTwinScreenState extends ConsumerState<CareerTwinScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage(Map<String, dynamic> dna, String text) {
    if (text.trim().isEmpty) return;
    _msgController.clear();
    ref.read(careerTwinProvider((dna: dna, lang: 'en')).notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDurations.medium,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final careerDnaAsync = ref.watch(careerDnaProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: careerDnaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Failed to load your profile: $e', style: AppTextStyles.bodyMedium),
          ),
          data: (dna) => _ChatBody(
            dna: dna,
            msgController: _msgController,
            scrollController: _scrollController,
            onSend: (text) => _sendMessage(dna, text),
          ),
        ),
      ),
    );
  }
}

class _ChatBody extends ConsumerWidget {
  final Map<String, dynamic> dna;
  final TextEditingController msgController;
  final ScrollController scrollController;
  final void Function(String) onSend;

  const _ChatBody({
    required this.dna,
    required this.msgController,
    required this.scrollController,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final state = ref.watch(careerTwinProvider((dna: dna, lang: 'en')));

    return Column(
      children: [
        _buildHeader(),
        if (state.messages.isEmpty) _buildGoalSuggestions(),
        Expanded(
          child: state.messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Ask your Career Twin about scholarships, exams, or your career path.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 80 : AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: state.messages.length + (state.isThinking ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length) return const _TypingIndicator();
                    return _MessageBubble(message: state.messages[index], onActionTap: onSend);
                  },
                ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
            child: Text(state.error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        _buildInput(isWide),
      ],
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.primaryGradient),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 24),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Career Twin', style: AppTextStyles.titleLarge),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Always available • Powered by Claude', style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildGoalSuggestions() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
    child: Row(
      children: [
        Text('Try: ', style: AppTextStyles.caption),
        const SizedBox(width: 8),
        ...[
          'I want to study M.Tech in Germany',
          'Show me scholarship opportunities',
          'What government jobs can I get?',
          'Build my career roadmap',
        ].map((suggestion) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSend(suggestion),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primary.withOpacity(0.08),
              ),
              child: Text(
                suggestion,
                style: AppTextStyles.caption.copyWith(color: AppColors.primaryLight),
              ),
            ),
          ),
        )),
      ],
    ),
  );

  Widget _buildInput(bool isWide) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: isWide ? 80 : AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: msgController,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ask your Career Twin anything...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: AppColors.bgCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onSubmitted: onSend,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.primaryGradient),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => onSend(msgController.text),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            padding: const EdgeInsets.all(14),
          ),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String) onActionTap;
  const _MessageBubble({required this.message, required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final isAI = message.role == 'assistant';
    if (isAI) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Text(
                      message.content,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  if (message.actions.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: message.actions.map((action) {
                        final label = action['label']?.toString() ?? action.toString();
                        return GestureDetector(
                          onTap: () => onActionTap(label),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: AppColors.primaryGradient),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              label,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideX(begin: -0.1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.primaryGradient),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Text(
              message.content,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.primaryGradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .moveY(begin: 0, end: -6, delay: Duration(milliseconds: i * 150))
                    .then()
                    .moveY(begin: -6, end: 0),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
