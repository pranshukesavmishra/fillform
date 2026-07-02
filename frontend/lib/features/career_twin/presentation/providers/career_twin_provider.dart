import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/ai_service.dart';

class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final List<Map<String, dynamic>> actions;
  final List<Map<String, dynamic>> opportunities;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.actions = const [],
    this.opportunities = const [],
  });
}

class CareerTwinState {
  final List<ChatMessage> messages;
  final bool isThinking;
  final String? conversationId;
  final String? error;

  const CareerTwinState({
    this.messages = const [],
    this.isThinking = false,
    this.conversationId,
    this.error,
  });

  CareerTwinState copyWith({
    List<ChatMessage>? messages,
    bool? isThinking,
    String? conversationId,
    String? error,
  }) {
    return CareerTwinState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      conversationId: conversationId ?? this.conversationId,
      error: error ?? this.error,
    );
  }
}

class CareerTwinNotifier extends StateNotifier<CareerTwinState> {
  final AIService _service;
  final Map<String, dynamic> _careerDna;
  final String _language;

  CareerTwinNotifier(this._service, this._careerDna, this._language)
      : super(const CareerTwinState());

  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
      error: null,
    );

    try {
      final response = await _service.chatWithCareerTwin(
        message: text,
        careerDna: _careerDna,
        conversationId: state.conversationId,
        language: _language,
      );

      final assistantMsg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role: 'assistant',
        content: response['reply'] as String? ?? '',
        timestamp: DateTime.now(),
        actions: (response['actions'] as List?)?.cast<Map<String, dynamic>>() ?? [],
        opportunities: (response['opportunities'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isThinking: false,
        conversationId: response['conversation_id'] as String?,
      );
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        error: 'Failed to get response. Please try again.',
      );
    }
  }

  void clearConversation() {
    state = const CareerTwinState();
  }
}

// Family of providers per career DNA + language
final careerTwinProvider = StateNotifierProvider.family<
    CareerTwinNotifier, CareerTwinState, ({Map<String, dynamic> dna, String lang})>(
  (ref, args) => CareerTwinNotifier(
    ref.watch(aiServiceProvider),
    args.dna,
    args.lang,
  ),
);
