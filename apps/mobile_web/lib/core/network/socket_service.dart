import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../config.dart';

/// Call signaling from the server: an incoming ring, state changes of a call, and (re)connections, after which
/// anything missed while offline must be re-read.
abstract class CallSignals {
  Stream<Map<String, dynamic>> get incomingCalls;
  Stream<Map<String, dynamic>> get callStates;
  Stream<void> get connects;
}

/// One authenticated Socket.IO connection for chat, notifications and call events.
class SocketService implements CallSignals {
  sio.Socket? _s;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<Map<String, dynamic>>.broadcast();
  final _calls = StreamController<Map<String, dynamic>>.broadcast();
  final _callStates = StreamController<Map<String, dynamic>>.broadcast();
  final _connects = StreamController<void>.broadcast();
  String? Function() _token = () => null;
  Future<bool> Function()? _refresh;
  bool _retriedAuth = false;

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;
  Stream<Map<String, dynamic>> get typing => _typing.stream;
  @override
  Stream<Map<String, dynamic>> get incomingCalls => _calls.stream;
  @override
  Stream<Map<String, dynamic>> get callStates => _callStates.stream;
  @override
  Stream<void> get connects => _connects.stream;
  bool get connected => _s?.connected ?? false;

  /// [token] is read on every (re)connect, so reconnects use the latest access token rather than the one from
  /// sign-in. When the server rejects the handshake, [refresh] renews the tokens and the socket retries once.
  void connect(String? Function() token, {Future<bool> Function()? refresh}) {
    disconnect();
    _token = token; _refresh = refresh; _retriedAuth = false;
    final s = sio.io(apiUrl, sio.OptionBuilder().setTransports(['websocket']).setAuthFn((cb) => cb(authPayload())).enableReconnection().enableForceNew().build());
    Map<String, dynamic> m(dynamic d) => Map<String, dynamic>.from(d as Map);
    s.on('message:new', (d) => _messages.add(m(d)));
    s.on('notification:new', (d) => _notifications.add(m(d)));
    s.on('typing', (d) => _typing.add(m(d)));
    s.on('call:incoming', (d) => _calls.add(m(d)));
    s.on('call:state', (d) => _callStates.add(m(d)));
    s.onConnect((_) { _retriedAuth = false; _connects.add(null); });
    s.onConnectError((e) => handleConnectError(e, reconnect: () => s.connect()));
    _s = s;
  }

  /// Handshake payload; the token is looked up at connect time.
  @visibleForTesting
  Map<String, dynamic> authPayload() => {'token': _token() ?? ''};

  /// An "unauthorized" rejection means the access token expired: refresh once, then reconnect.
  /// Other errors are network problems, which the client's own reconnection handles.
  @visibleForTesting
  Future<void> handleConnectError(dynamic e, {required void Function() reconnect}) async {
    final msg = e is Map ? e['message']?.toString() : e?.toString();
    if (msg != 'unauthorized' || _retriedAuth || _refresh == null) return;
    _retriedAuth = true;
    if (await _refresh!()) reconnect();
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
