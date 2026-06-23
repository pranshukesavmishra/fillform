import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class CareerTwinScreen extends StatefulWidget {
  const CareerTwinScreen({super.key});
  @override
  State<CareerTwinScreen> createState() => _CareerTwinScreenState();
}

class _CareerTwinScreenState extends State<CareerTwinScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      isAI: true,
      text: "Namaste Anshu! 👋 I'm your Career Twin. I've analyzed your profile and found 3 urgent opportunities you should apply to this week.\n\nThe NSP Scholarship closes in **3 days** and your success probability is **78%**. Want me to start filling your application?",
      actions: ['Yes, start application', 'Show all opportunities', 'Set a goal'],
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
  ];

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(isAI: false, text: text, timestamp: DateTime.now()));
      _isTyping = true;
      _msgController.clear();
    });

    // Simulate AI response
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          isAI: true,
          text: "Great! I've started pre-filling your NSP Scholarship application. I've auto-filled 8 out of 12 fields using your profile.\n\nI need 2 things from you:\n1. Upload your **Income Certificate** (required)\n2. Confirm your Bank Account number\n\nShall I guide you through these?",
          actions: ['Upload now', 'Confirm bank details'],
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Suggested goals (first time)
            if (_messages.length <= 1) _buildGoalSuggestions(),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 80 : AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) return _TypingIndicator();
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),

            // Input
            _buildInput(isWide),
          ],
        ),
      ),
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
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.history_outlined, color: AppColors.textSecondary),
          onPressed: () {},
          tooltip: 'Conversation history',
        ),
        IconButton(
          icon: const Icon(Icons.auto_fix_high, color: AppColors.accent),
          onPressed: () {},
          tooltip: 'Generate roadmap',
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
            onTap: () => _sendMessage(suggestion),
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
            controller: _msgController,
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
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic_outlined, color: AppColors.textMuted),
                onPressed: () {},
              ),
            ),
            onSubmitted: _sendMessage,
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
            onPressed: () => _sendMessage(_msgController.text),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            padding: const EdgeInsets.all(14),
          ),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isAI) {
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
                      message.text,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  if (message.actions.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: message.actions.map((action) => GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: AppColors.primaryGradient),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            action,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )).toList(),
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
              message.text,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}

class _TypingIndicator extends StatelessWidget {
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

class _ChatMessage {
  final bool isAI;
  final String text;
  final List<String> actions;
  final DateTime timestamp;

  _ChatMessage({
    required this.isAI,
    required this.text,
    this.actions = const [],
    required this.timestamp,
  });
}
