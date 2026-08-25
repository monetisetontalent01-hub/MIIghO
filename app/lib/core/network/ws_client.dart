import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

class WsClient {
  final String wsUrl;
  WebSocketChannel? _channel;
  final _uuid = const Uuid();
  Timer? _reconnectTimer;
  int _reconnectDelaySeconds = 1;
  static const int _maxReconnectDelay = 10;
  bool _isExplicitlyDisconnected = false;
  
  final _messageController = StreamController<dynamic>.broadcast();
  final _stateController = StreamController<String>.broadcast();
  
  Stream<dynamic> get messages => _messageController.stream;
  Stream<String> get connectionState => _stateController.stream;

  WsClient(this.wsUrl);

  void connect() {
    _isExplicitlyDisconnected = false;
    _reconnectTimer?.cancel();
    _stateController.add('connecting');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _stateController.add('connected');
      _reconnectDelaySeconds = 1; // Reset backoff on successful connect
      
      _channel!.stream.listen(
        (rawMessage) {
          try {
            if (rawMessage is String) {
              final decoded = jsonDecode(rawMessage);
              _messageController.add(decoded);
            } else {
              _messageController.add(rawMessage);
            }
          } catch (_) {
            _messageController.add(rawMessage);
          }
        },
        onDone: () {
          _stateController.add('disconnected');
          if (!_isExplicitlyDisconnected) {
            _scheduleReconnect();
          }
        },
        onError: (error) {
          _stateController.add('disconnected');
          if (!_isExplicitlyDisconnected) {
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      _stateController.add('disconnected');
      if (!_isExplicitlyDisconnected) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    _stateController.add('reconnecting');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySeconds), () {
      if (!_isExplicitlyDisconnected) {
        _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(1, _maxReconnectDelay);
        connect();
      }
    });
  }

  void sendMessage(Map<String, dynamic> payload) {
    if (_channel != null) {
      payload.putIfAbsent('id', () => _uuid.v7());
      payload.putIfAbsent('timestamp', () => DateTime.now().toIso8601String());
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void sendTyping(String conversationId, bool isTyping) {
    sendMessage({
      'type': 'typing',
      'conversation_id': conversationId,
      'data': isTyping,
    });
  }

  void sendPing() {
    sendMessage({'type': 'ping'});
  }

  void disconnect() {
    _isExplicitlyDisconnected = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _stateController.add('disconnected');
  }
}
