import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miigho/features/chat/models/chat_models.dart';
import 'package:miigho/shared/widgets/conversation_tile.dart' show MessageDeliveryStatus;
import 'package:miigho/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:miigho/features/chat/presentation/screens/chat_screen.dart';
import 'package:miigho/features/chat/presentation/widgets/chat_input.dart';

class MockChatBloc extends Fake implements ChatBloc {
  final ChatState _state;
  MockChatBloc(this._state);

  @override
  ChatState get state => _state;

  @override
  Stream<ChatState> get stream => const Stream.empty();

  @override
  void add(ChatEvent event) {}
}

void main() {
  testWidgets('ChatScreen layout test on mobile viewports (320, 360, 375, 390, 414)', (tester) async {
    final messages = [
      MiighoMessageItem(
        id: 'msg-1',
        conversationId: '00000000-0000-0000-0000-000000000001',
        content: 'Hello, how are you?',
        isMe: false,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now(),
      ),
      MiighoMessageItem(
        id: 'msg-2',
        conversationId: '00000000-0000-0000-0000-000000000001',
        content: 'I am doing great! Here is a longer message that should test text wrapping properly.',
        isMe: true,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now(),
      ),
      MiighoMessageItem(
        id: 'msg-3',
        conversationId: '00000000-0000-0000-0000-000000000001',
        content: 'https://example.com/very/long/unbroken/url/that/could/overflow/if/not/handled/properly',
        isMe: false,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now(),
      ),
    ];

    final conv = MiighoConversation(
      id: '00000000-0000-0000-0000-000000000001',
      title: 'Contact Test Name Very Long Title For Conversation',
      subtitle: 'Hello',
      updatedAt: DateTime.now(),
      unreadCount: 0,
    );

    final mockBloc = MockChatBloc(
      ConversationsLoaded(
        [conv],
        activeConversationId: conv.id,
        messages: messages,
        activeConversation: conv,
      ),
    );

    for (final width in [320.0, 360.0, 375.0, 390.0, 414.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        BlocProvider<ChatBloc>.value(
          value: mockBloc,
          child: const MaterialApp(
            home: ChatScreen(
              conversationId: '00000000-0000-0000-0000-000000000001',
              isEmbedded: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no overflow errors
      expect(tester.takeException(), isNull, reason: 'Overflow exception at width $width');

      // Check sizes of key components
      final chatScreenFinder = find.byType(ChatScreen);
      expect(chatScreenFinder, findsOneWidget);
      final chatSize = tester.getSize(chatScreenFinder);
      print('Width $width -> ChatScreen size: $chatSize');
      expect(chatSize.width, equals(width));

      final inputFinder = find.byType(ChatInput);
      expect(inputFinder, findsOneWidget);
      final inputSize = tester.getSize(inputFinder);
      print('Width $width -> ChatInput size: $inputSize');
      expect(inputSize.width, lessThanOrEqualTo(width));

      // Check all RenderBoxes to see if any exceeds width
      final renderObjects = tester.allRenderObjects.whereType<RenderBox>();
      for (final ro in renderObjects) {
        if (ro.hasSize && ro.size.width > width + 0.5) {
          print('WARNING: RenderBox wider than viewport ($width): ${ro.runtimeType}, size: ${ro.size}');
        }
      }
    }
  });
}
