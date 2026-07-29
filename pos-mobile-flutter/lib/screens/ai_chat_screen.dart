import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/chat_message.dart';
import '../providers/ai_chat_provider.dart';
import '../providers/connectivity_provider.dart';

const _suggestions = [
  'Сколько продали сегодня?',
  'Какие товары в минусе?',
  'Топ товаров за неделю',
  'Как сработали кассиры сегодня?',
  'Возвраты за сегодня',
];

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _ctrl.text;
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    _scrollToEnd();
    await ref.read(aiChatProvider.notifier).send(text);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatProvider);
    final isOnline = ref.watch(connectivityProvider);
    final canSend = isOnline && !state.sending;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              hasMessages: state.messages.isNotEmpty,
              onClear: () => ref.read(aiChatProvider.notifier).clear(),
            ),
            Expanded(
              child: state.messages.isEmpty
                  ? _EmptyState(onPick: canSend ? _send : null)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      itemCount: state.messages.length + (state.sending ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= state.messages.length) return const _TypingBubble();
                        final msg = state.messages[i];
                        return _Bubble(
                          message: msg,
                          onRetry: msg.isError && i == state.messages.length - 1
                              ? () => ref.read(aiChatProvider.notifier).retryLast()
                              : null,
                        );
                      },
                    ),
            ),
            _Composer(
              controller: _ctrl,
              enabled: canSend,
              isOnline: isOnline,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool hasMessages;
  final VoidCallback onClear;

  const _Header({required this.hasMessages, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.gradientAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ассистент',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Спросите о продажах, остатках, кассирах',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (hasMessages)
            GestureDetector(
              onTap: onClear,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Icon(Icons.refresh,
                    color: AppColors.textSecondary, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final void Function(String)? onPick;

  const _EmptyState({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_outlined,
              color: AppColors.textMuted, size: 44),
          const SizedBox(height: 12),
          const Text(
            'Задайте вопрос о работе магазина',
            style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ..._suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: onPick == null ? null : () => onPick!(s),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(Icons.north_east,
                          color: AppColors.textMuted, size: 15),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bubbles ─────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _Bubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxWidth = MediaQuery.of(context).size.width * 0.82;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser ? AppColors.gradientHero : null,
          color: isUser
              ? null
              : message.isError
                  ? AppColors.dangerBg
                  : AppColors.bgSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: message.isError
                      ? AppColors.danger.withValues(alpha: 0.4)
                      : AppColors.borderSubtle,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.content,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : message.isError
                        ? AppColors.danger
                        : AppColors.textPrimary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onRetry,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: AppColors.danger, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Повторить',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  color: AppColors.accent1, strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Смотрю данные...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Composer ────────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isOnline;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.isOnline,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSidebar,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 56, maxHeight: 140),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: TextField(
                controller: controller,
                enabled: isOnline,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => enabled ? onSend() : null,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText:
                      isOnline ? 'Спросите что-нибудь...' : 'Офлайн — недоступно',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: enabled ? onSend : null,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: enabled ? AppColors.gradientHero : null,
                color: enabled ? null : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.arrow_upward,
                color: enabled ? Colors.white : AppColors.textMuted,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
