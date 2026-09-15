import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miigho/features/chat/presentation/widgets/chat_input.dart';
import 'package:miigho/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('Check ChatInput intrinsic min width and layout at 320, 360, 375, 390 px', (tester) async {
    for (final width in [320.0, 360.0, 375.0, 390.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              onSendMessage: (text, {replyToId}) {},
            ),
          ),
        ),
      );

      final inputFinder = find.byType(ChatInput);
      expect(inputFinder, findsOneWidget);
      final size = tester.getSize(inputFinder);
      print('ChatInput size at width $width: $size');
      expect(size.width, equals(width));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Check MessageBubble layout at 320, 360, 375, 390 px', (tester) async {
    for (final width in [320.0, 360.0, 375.0, 390.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                MessageBubble(
                  id: '1',
                  content: 'Incoming message from someone else',
                  isMe: false,
                  timestamp: DateTime.now(),
                ),
                MessageBubble(
                  id: '2',
                  content: 'Outgoing message from me that is quite long and should wrap properly within the bubble constraints',
                  isMe: true,
                  timestamp: DateTime.now(),
                ),
                MessageBubble(
                  id: '3',
                  content: 'https://mi-igh-o.vercel.app/conversations/00000000-0000-0000-0000-000000000000/very/very/long/unbroken/url/path',
                  isMe: false,
                  timestamp: DateTime.now(),
                ),
              ],
            ),
          ),
        ),
      );

      final listFinder = find.byType(ListView);
      final size = tester.getSize(listFinder);
      print('ListView size at width $width: $size');
      expect(size.width, equals(width));
      expect(tester.takeException(), isNull);
    }
  });
}
