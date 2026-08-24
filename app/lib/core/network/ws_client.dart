import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

class WsClient {
  final String wsUrl;
  WebSocketChannel? _channel;
  final _uuid = const Uuid();
  
  final _messageController = StreamController<dynamic>.broadcast();
  final _stateController = StreamController<String>.broadcast();
  
  Stream<dynamic> get messages => _messageController.stream;
  Stream<String> get connectionState => _stateController.stream;

  WsClient(this.wsUrl);

  void connect() {
    _stateController.add('connecting');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _stateController.add('connected');
      
      _channel!.stream.listen(
        (message) {
          _messageController.add(message);
        },
        onDone: () {
          _stateController.add('disconnected');
          _reconnect();
        },
        onError: (error) {
          _stateController.add('disconnected');
          _reconnect();
        },
      );
    } catch (e) {
      _stateController.add('disconnected');
      _reconnect();
    }
  }

  void _reconnect() {
    _stateController.add('reconnecting');
    Future.delayed(const Duration(seconds: 5), connect);
  }

  void sendMessage(Map<String, dynamic> payload) {
    if (_channel != null) {
      final messageId = _uuid.v7();
      payload['id'] = messageId;
      // Convert to protobuf or json in real app
      // _channel!.sink.add(jsonEncode(payload));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _stateController.add('disconnected');
  }
}
