import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

class AiChatState {
  final List<ChatMessage> messages;
  final bool sending;

  const AiChatState({
    this.messages = const [],
    this.sending = false,
  });

  AiChatState copyWith({List<ChatMessage>? messages, bool? sending}) =>
      AiChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
      );
}

class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() => const AiChatState();

  void clear() => state = const AiChatState();

  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.sending) return;

    final userMsg = ChatMessage(role: 'user', content: question);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      sending: true,
    );

    // Only clean turns go back to the model — failed sends are local-only.
    final history = state.messages
        .where((m) => !m.isError)
        .map((m) => m.toJson())
        .toList();

    try {
      final res = await apiService.post(
        '/api/ai/chat',
        data: {'messages': history},
        timeout: const Duration(seconds: 120),
      );
      final data = res.data as Map<String, dynamic>;
      final reply = (data['reply'] as String?)?.trim();
      final tools = (data['tools_used'] as List?)?.length ?? 0;
      Sentry.logger.fmt
          .info('AI chat answered using %s tool call(s)', [tools]);

      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            role: 'assistant',
            content: reply?.isNotEmpty == true
                ? reply!
                : 'Пустой ответ от ассистента.',
          ),
        ],
        sending: false,
      );
    } catch (e, st) {
      Sentry.logger.fmt.error('AI chat failed: %s', [e]);
      await Sentry.captureException(e, stackTrace: st);
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            role: 'assistant',
            content: e.toString().replaceFirst('Exception: ', ''),
            isError: true,
          ),
        ],
        sending: false,
      );
    }
  }

  /// Removes the trailing error bubble and re-sends the question above it.
  Future<void> retryLast() async {
    final msgs = [...state.messages];
    if (msgs.isEmpty || !msgs.last.isError) return;
    msgs.removeLast();
    final lastUser = msgs.isNotEmpty && msgs.last.isUser ? msgs.removeLast() : null;
    state = state.copyWith(messages: msgs);
    if (lastUser != null) await send(lastUser.content);
  }
}

final aiChatProvider =
    NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);
