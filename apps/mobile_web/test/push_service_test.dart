import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/core/push_service.dart';
import 'support.dart';

class FakeBackend implements PushBackend {
  bool available = true, allowed = true; String? tok = 'device-token-123456789012345';
  final refresh = StreamController<String>.broadcast(), opened = StreamController<Map<String, String>>.broadcast(), fg = StreamController<({String title, String body})>.broadcast();
  Map<String, String>? initial;
  @override Future<bool> init() async => available;
  @override Future<bool> requestPermission() async => allowed;
  @override Future<String?> token() async => tok;
  @override Stream<String> get onTokenRefresh => refresh.stream;
  @override Stream<Map<String, String>> get onOpened => opened.stream;
  @override Stream<({String title, String body})> get onForeground => fg.stream;
  @override Future<Map<String, String>?> initialMessage() async => initial;
  @override Future<void> deleteToken() async {}
}

void main() {
  late FakeBackend backend; late List<String> calls; late List<Object?> bodies; late List<String> routes; late List<String> banners;
  PushService make() {
    calls = []; bodies = []; routes = []; banners = [];
    final api = fakeApi((o) { calls.add('${o.method} ${o.path}'); bodies.add(o.data); return (status: 204, body: {}); });
    return PushService(api, backend, onOpenRoute: routes.add, onForegroundMessage: (t, b) => banners.add('$t|$b'));
  }
  setUp(() => backend = FakeBackend());
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('registers the device token and re-registers when it rotates', () async {
    final s = make(); await s.start();
    expect(calls, ['POST /devices']); expect((bodies.single as Map)['token'], backend.tok); expect((bodies.single as Map)['platform'], 'android');
    backend.refresh.add('new-token-abcdefghijklmnopqrstu'); await settle();
    expect(calls.length, 2); expect((bodies.last as Map)['token'], 'new-token-abcdefghijklmnopqrstu');
  });

  test('does nothing (and does not crash) when push is unavailable or denied', () async {
    backend.available = false; var s = make(); await s.start(); expect(calls, isEmpty);
    backend = FakeBackend()..allowed = false; s = make(); await s.start(); expect(calls, isEmpty);
    backend = FakeBackend()..tok = null; s = make(); await s.start(); expect(calls, isEmpty);
  });

  test('a failing API call never throws out of start()', () async {
    final api = fakeApi((o) => (status: 500, body: {'error': {'message': 'boom'}}));
    final s = PushService(api, backend, onOpenRoute: (_) {});
    await s.start();
  });

  test('tapping a chat notification opens that chat; other types open notifications', () async {
    final s = make(); await s.start();
    backend.opened.add({'conversation_id': '7', 'title': 'Aisha Khan', 'type': 'message'}); await settle();
    expect(routes.single, '/chat/7?title=Aisha%20Khan');
    backend.opened.add({'type': 'follow'}); await settle();
    expect(routes.last, '/notifications');
    backend.opened.add({'type': 'unknown'}); await settle();
    expect(routes.length, 2);
  });

  test('a notification that launched the app is routed once started', () async {
    backend.initial = {'conversation_id': '3'}; final s = make(); await s.start();
    expect(routes.single, startsWith('/chat/3'));
  });

  test('foreground messages surface as an in-app banner', () async {
    final s = make(); await s.start();
    backend.fg.add((title: 'Omar', body: 'hello')); await settle();
    expect(banners, ['Omar|hello']);
  });

  test('stop() unregisters the token once and stops listening', () async {
    final s = make(); await s.start(); calls.clear(); bodies.clear();
    await s.stop();
    expect(calls, ['DELETE /devices']); expect((bodies.single as Map)['token'], backend.tok);
    backend.opened.add({'conversation_id': '1'}); await settle();
    expect(routes, isEmpty);
    calls.clear(); await s.stop(); expect(calls, isEmpty); // idempotent
  });

  test('routeFor maps payloads defensively', () {
    expect(PushService.routeFor({'conversation_id': 'abc'}), isNull);
    expect(PushService.routeFor({}), isNull);
  });
}
