import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../config.dart';

/// One authenticated Socket.IO connection for chat, notifications and call events.
class SocketService {
  sio.Socket? _s;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<Map<String, dynamic>>.broadcast();
  final _calls = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;
  Stream<Map<String, dynamic>> get typing => _typing.stream;
  Stream<Map<String, dynamic>> get incomingCalls => _calls.stream;
  bool get connected => _s?.connected ?? false;

  void connect(String accessToken) {
    disconnect();
    final s = sio.io(apiUrl, sio.OptionBuilder().setTransports(['websocket']).setAuth({'token': accessToken}).enableReconnection().build());
    Map<String, dynamic> m(dynamic d) => Map<String, dynamic>.from(d as Map);
    s.on('message:new', (d) => _messages.add(m(d)));
    s.on('notification:new', (d) => _notifications.add(m(d)));
    s.on('typing', (d) => _typing.add(m(d)));
    s.on('call:incoming', (d) => _calls.add(m(d)));
    _s = s;
  }

  /// Sends with an ack; [clientId] makes retries idempotent on the server.
  Future<Map<String, dynamic>> sendMessage(int conversationId, String clientId, String body) {
    final c = Completer<Map<String, dynamic>>();
    final s = _s;
    if (s == null || !s.connected) { c.completeError('offline'); return c.future; }
    s.emitWithAck('message:send', {'conversation_id': conversationId, 'message': {'client_id': clientId, 'body': body}}, ack: (r) {
      final res = Map<String, dynamic>.from(r as Map);
      res['ok'] == true ? c.complete(Map<String, dynamic>.from(res['message'] as Map)) : c.completeError(res['error'] ?? 'send failed');
    });
    return c.future.timeout(const Duration(seconds: 10));
  }

  void markRead(int conversationId, int upToId) => _s?.emit('message:read', {'conversation_id': conversationId, 'up_to_id': upToId});
  void typingIn(int conversationId) => _s?.emit('typing', {'conversation_id': conversationId});
  void disconnect() { _s?.dispose(); _s = null; }
}
