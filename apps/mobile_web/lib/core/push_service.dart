import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'firebase_options.dart';
import 'network/api_client.dart';

/// The small slice of Firebase Messaging we use, so the logic can be tested without Firebase.
abstract class PushBackend {
  Future<bool> init();
  Future<bool> requestPermission();
  Future<String?> token();
  Stream<String> get onTokenRefresh;
  Stream<Map<String, String>> get onOpened; // user tapped a notification
  Stream<({String title, String body})> get onForeground;
  Future<Map<String, String>?> initialMessage();
  Future<void> deleteToken();
}

class FirebasePushBackend implements PushBackend {
  FirebaseMessaging get _m => FirebaseMessaging.instance;

  @override
  Future<bool> init() async {
    final options = JeyaboFirebase.current;
    if (options == null) return false;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    return true;
  }
  @override
  Future<bool> requestPermission() async {
    final s = (await _m.requestPermission()).authorizationStatus;
    return s == AuthorizationStatus.authorized || s == AuthorizationStatus.provisional;
  }
  @override
  Future<String?> token() => _m.getToken(vapidKey: kIsWeb && JeyaboFirebase.webVapidKey.isNotEmpty ? JeyaboFirebase.webVapidKey : null);
  @override
  Stream<String> get onTokenRefresh => _m.onTokenRefresh;
  @override
  Stream<Map<String, String>> get onOpened => FirebaseMessaging.onMessageOpenedApp.map((m) => m.data.map((k, v) => MapEntry(k, '$v')));
  @override
  Stream<({String title, String body})> get onForeground => FirebaseMessaging.onMessage.map((m) => (title: m.notification?.title ?? '', body: m.notification?.body ?? ''));
  @override
  Future<Map<String, String>?> initialMessage() async => (await _m.getInitialMessage())?.data.map((k, v) => MapEntry(k, '$v'));
  @override
  Future<void> deleteToken() => _m.deleteToken();
}

/// Registers this device's push token with the API after sign-in, keeps it fresh, removes it on sign-out,
/// and turns a notification tap into an in-app route.
class PushService {
  PushService(this._api, this._backend, {required this.onOpenRoute, this.onForegroundMessage});
  final ApiClient _api;
  final PushBackend _backend;
  final void Function(String route) onOpenRoute;
  final void Function(String title, String body)? onForegroundMessage;
  final _subs = <StreamSubscription>[];
  String? _token;
  bool _started = false;

  String get platform => kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  /// Never throws: push is optional, and the app must work when it is unavailable or denied.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      if (kIsWeb && JeyaboFirebase.webVapidKey.isEmpty) return; // web push needs the VAPID key; do not ask for permission we cannot use
      if (!await _backend.init()) return;
      if (!await _backend.requestPermission()) return;
      final t = await _backend.token();
      if (t != null) await _register(t);
      _subs.add(_backend.onTokenRefresh.listen((t) => _register(t).catchError((_) {})));
      _subs.add(_backend.onOpened.listen(_open));
      _subs.add(_backend.onForeground.listen((m) => onForegroundMessage?.call(m.title, m.body)));
      final initial = await _backend.initialMessage();
      if (initial != null) _open(initial);
    } catch (_) { /* denied, offline or misconfigured: carry on without push */ }
  }

  Future<void> _register(String t) async {
    _token = t;
    await _api.post('/devices', body: {'token': t, 'platform': platform});
  }

  /// Maps a notification payload to a screen.
  static String? routeFor(Map<String, String> data) {
    // Calls: a missed-call notice opens the call log; an incoming call opens the ringing screen (if still ringing).
    if (data['type'] == 'call') {
      if (data['missed'] == '1') return '/calls';
      final call = data['call_id'];
      return call != null && RegExp(r'^[0-9a-f-]{36}$').hasMatch(call) ? '/call/incoming/$call' : null;
    }
    final chat = int.tryParse(data['conversation_id'] ?? '');
    if (chat != null) return '/chat/$chat?title=${Uri.encodeComponent(data['title'] ?? 'Chat')}';
    return switch (data['type']) { 'follow' || 'friend_request' || 'reaction' || 'comment' || 'mention' || 'story' || 'reward' || 'luckydraw' || 'live' => '/notifications', _ => null };
  }
  void _open(Map<String, String> data) { final r = routeFor(data); if (r != null) onOpenRoute(r); }

  /// Call before the access token is cleared so the server stops pushing to this device.
  Future<void> stop() async {
    for (final s in _subs) { await s.cancel(); }
    _subs.clear();
    final t = _token;
    _token = null; _started = false;
    if (t != null) { try { await _api.delete('/devices', body: {'token': t}); } catch (_) {} }
  }
}
