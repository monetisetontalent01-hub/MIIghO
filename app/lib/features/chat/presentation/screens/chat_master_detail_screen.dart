import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';

class ChatMasterDetailScreen extends StatefulWidget {
  final String? initialConversationId;

  const ChatMasterDetailScreen({
    super.key,
    this.initialConversationId,
  });

  @override
  State<ChatMasterDetailScreen> createState() => _ChatMasterDetailScreenState();
}

class _ChatMasterDetailScreenState extends State<ChatMasterDetailScreen> {
  late String _activeConversationId;

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.initialConversationId ?? 'conv_0';
  }

  @override
  void didUpdateWidget(covariant ChatMasterDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialConversationId != null && widget.initialConversationId != oldWidget.initialConversationId) {
      setState(() {
        _activeConversationId = widget.initialConversationId!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Row(
            children: [
              // Sidebar conversations (Master)
              SizedBox(
                width: 360,
                child: ConversationsScreen(
                  isEmbedded: true,
                  selectedConversationId: _activeConversationId,
                  onConversationSelected: (id) {
                    setState(() {
                      _activeConversationId = id;
                    });
                  },
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
              ),
              // Chat actif (Detail)
              Expanded(
                child: ChatScreen(
                  key: ValueKey(_activeConversationId),
                  conversationId: _activeConversationId,
                  isEmbedded: true,
                ),
              ),
            ],
          );
        }

        // Sur mobile : si un ID est passé en argument direct
        if (widget.initialConversationId != null) {
          return ChatScreen(
            conversationId: widget.initialConversationId!,
            isEmbedded: false,
          );
        }

        // Sinon liste des conversations classique
        return const ConversationsScreen(isEmbedded: false);
      },
    );
  }
}
