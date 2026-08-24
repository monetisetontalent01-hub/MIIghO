import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_bloc.dart';
import '../../models/chat_models.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ChatLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          List<MiighoConversation> conversations = [];
          if (state is ConversationsLoaded) {
            conversations = state.conversations;
          } else {
            // Fallback default list
            conversations = [
              MiighoConversation(
                id: 'conv_0',
                title: 'Amina Diallo',
                subtitle: 'Parfait, on valide les maquettes !',
                updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
                unreadCount: 3,
                isPinned: true,
                isOnline: true,
                isVerified: true,
              ),
              MiighoConversation(
                id: 'conv_1',
                title: 'Équipe MÏÏghO Core',
                subtitle: 'Réunion de cadrage technique à 10h',
                updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
                isGroup: true,
              ),
              MiighoConversation(
                id: 'conv_2',
                title: 'Kofi Mensah',
                subtitle: 'Message vocal reçu',
                updatedAt: DateTime.now().subtract(const Duration(minutes: 38)),
                unreadCount: 1,
                isMuted: true,
              ),
            ];
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ChatBloc>().add(LoadConversations());
            },
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 82,
                endIndent: 16,
                color: Color(0x1A000000),
              ),
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return ConversationTile(
                  id: conv.id,
                  title: conv.title,
                  subtitle: conv.subtitle,
                  avatarUrl: conv.avatarUrl,
                  updatedAt: conv.updatedAt,
                  unreadCount: conv.unreadCount,
                  isPinned: conv.isPinned,
                  isMuted: conv.isMuted,
                  isGroup: conv.isGroup,
                  isOnline: conv.isOnline,
                  isTyping: conv.isTyping,
                  typingUserName: conv.typingUserName,
                  isLastMessageFromMe: conv.isLastMessageFromMe,
                  lastMessageStatus: conv.lastMessageStatus,
                  messageType: conv.messageType,
                  isVerified: conv.isVerified,
                  onTap: () => context.push('/conversations/${conv.id}'),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: MiighoColors.primary,
        onPressed: () {},
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: MiighoColors.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_rounded), label: 'Discussions'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Paramètres'),
        ],
        onTap: (index) {
          if (index == 1) context.go('/contacts');
          if (index == 2) context.go('/settings');
        },
      ),
    );
  }
}
