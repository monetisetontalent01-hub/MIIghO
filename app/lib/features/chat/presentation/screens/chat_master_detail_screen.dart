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
  String? _activeConversationId;

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.initialConversationId;
  }

  @override
  void didUpdateWidget(covariant ChatMasterDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialConversationId != null && widget.initialConversationId != oldWidget.initialConversationId) {
      setState(() {
        _activeConversationId = widget.initialConversationId;
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
              // Chat actif (Detail) ou panneau de bienvenue
              Expanded(
                child: _activeConversationId != null
                    ? ChatScreen(
                        key: ValueKey(_activeConversationId),
                        conversationId: _activeConversationId!,
                        isEmbedded: true,
                      )
                    : _buildWelcomePanel(isDark),
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

  Widget _buildWelcomePanel(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: MiighoColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 36,
                  color: MiighoColors.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'MÏÏghO Chat',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sélectionnez une discussion ou démarrez\nune nouvelle conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
