import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/core/l10n.dart';
import 'package:jeyabo/core/models.dart';
import 'package:jeyabo/core/network/socket_service.dart';
import 'package:jeyabo/core/providers.dart';
import 'package:jeyabo/core/push_service.dart';
import 'package:jeyabo/core/theme/theme.dart';
import 'package:jeyabo/features/calls/call_controller.dart';
import 'package:jeyabo/features/calls/call_engine.dart';
import 'package:jeyabo/features/calls/call_screens.dart';
import 'support.dart';

const _me = 1, _peer = 2;
const _callId = '11111111-2222-3333-4444-555555555555';

class FakeSignals implements CallSignals {
  final incoming = StreamController<Map<String, dynamic>>.broadcast(), states = StreamController<Map<String, dynamic>>.broadcast(), connected = StreamController<void>.broadcast();
  @override Stream<Map<String, dynamic>> get incomingCalls => incoming.stream;
  @override Stream<Map<String, dynamic>> get callStates => states.stream;
  @override Stream<void> get connects => connected.stream;
}

class FakeEngine implements CallEngine {
  final events0 = StreamController<EngineEvent>.broadcast();
  Map<String, Object>? joined; bool left = false, muted = false, failJoin = false; String? renewed;
  @override Stream<EngineEvent> get events => events0.stream;
  @override Future<void> join({required String appId, required String token, required String channel, required int uid, required bool video}) async => failJoin ? throw Exception('engine') : joined = {'appId': appId, 'token': token, 'channel': channel, 'uid': uid, 'video': video};
  @override Future<void> renewToken(String token) async => renewed = token;
  @override Future<void> setMuted(bool m) async => muted = m;
  @override Future<void> setCameraOn(bool on) async {}
  @override Future<void> switchCamera() async {}
  @override Future<void> setSpeaker(bool on) async {}
  @override Future<void> leave() async => left = true;
  @override Widget localView() => const SizedBox();
  @override Widget remoteView(int uid, String channel) => const SizedBox();
}

class FakePermissions implements CallPermissions {
  FakePermissions(this.grant); final bool grant; int asked = 0;
  @override Future<bool> request({required bool video}) async { asked++; return grant; }
  @override Future<void> openSettings() async {}
}

class SignedIn extends AuthController {
  @override
  AuthState build() => AuthState(AuthStatus.signedIn, User(id: _me, username: 'me', displayName: 'Me'));
}

typedef Reply = ({int status, Object body});

/// A container wired with fakes; [routes] answers API calls by "METHOD /path".
class Rig {
  Rig({bool grant = true, Map<String, Reply Function(RequestOptions)> routes = const {}, Duration linger = const Duration(milliseconds: 20)}) : perms = FakePermissions(grant) {
    final api = fakeApi((o) {
      calls.add('${o.method} ${o.path}${o.data is Map && (o.data as Map).isNotEmpty ? ' ${o.data}' : ''}');
      final h = routes['${o.method} ${o.path}'];
      if (h != null) return h(o);
      if (o.method == 'POST' && o.path == '/calls') return (status: 201, body: {'call_id': _callId, 'ring_timeout_ms': 45000, 'appId': 'app', 'token': 'tok-a', 'uid': _me, 'channel': _callId});
      if (o.method == 'POST' && o.path.endsWith('/join')) return (status: 200, body: {'appId': 'app', 'token': 'tok-b', 'uid': _me, 'channel': _callId});
      return (status: 204, body: {});
    });
    c = ProviderContainer(overrides: [
      apiProvider.overrideWithValue(api), authProvider.overrideWith(SignedIn.new), callSignalsProvider.overrideWithValue(signals),
      callEngineFactoryProvider.overrideWithValue(() => engine), callPermissionsProvider.overrideWithValue(perms),
      callEndLingerProvider.overrideWithValue(linger), callsSupportedProvider.overrideWithValue(true),
    ]);
    c.listen(callControllerProvider, (_, _) {}); // keep the controller alive and listening, as the app does
  }
  final signals = FakeSignals(); final engine = FakeEngine(); final FakePermissions perms; final calls = <String>[];
  late final ProviderContainer c;
  CallController get ctrl => c.read(callControllerProvider.notifier);
  CallState? get s => c.read(callControllerProvider);
  void ring({String kind = 'audio', String id = _callId}) => signals.incoming.add({'call_id': id, 'conversation_id': 9, 'kind': kind, 'from': {'id': _peer, 'display_name': 'Ann Lee'}, 'is_group': false});
}

Future<void> settle([int ms = 5]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('outgoing: rings, connects when the callee joins, media controls, hang up, then clears', () async {
    final r = Rig();
    await r.ctrl.startCall(conversationId: 9, peerName: 'Ann Lee', video: true);
    expect(r.calls.first, 'POST /calls {conversation_id: 9, kind: video}');
    expect(r.s!.phase, CallPhase.outgoing);
    expect(r.engine.joined, {'appId': 'app', 'token': 'tok-a', 'channel': _callId, 'uid': _me, 'video': true});
    r.signals.states.add({'call_id': _callId, 'status': 'active', 'joined': _peer});
    await settle();
    expect(r.s!.phase, CallPhase.active); expect(r.s!.connectedAt, isNotNull);
    r.engine.events0.add(RemoteJoined(_peer)); await settle();
    expect(r.s!.remoteUid, _peer);
    await r.ctrl.toggleMute();
    expect(r.s!.muted, isTrue); expect(r.engine.muted, isTrue);
    await r.ctrl.hangUp();
    expect(r.calls.last, 'POST /calls/$_callId/end');
    expect([r.s!.phase, r.s!.endReason, r.engine.left], [CallPhase.ended, CallEndReason.hungUp, true]);
    await settle(40);
    expect(r.s, isNull); // the ended notice goes away by itself
  });

  test('outgoing: no answer within the ring window ends the call on the server', () async {
    final r = Rig(linger: const Duration(seconds: 1), routes: {'POST /calls': (_) => (status: 201, body: {'call_id': _callId, 'ring_timeout_ms': 30, 'appId': 'a', 'token': 't', 'uid': _me, 'channel': _callId})});
    await r.ctrl.startCall(conversationId: 9, peerName: 'Ann', video: false);
    await settle(60);
    expect(r.calls, contains('POST /calls/$_callId/end'));
    expect(r.s?.endReason, CallEndReason.noAnswer);
    expect(r.engine.left, isTrue);
  });

  test('outgoing: busy and declined are told apart; a remote hang-up ends it', () async {
    for (final (reason, expected) in [('busy', CallEndReason.busy), ('declined', CallEndReason.declined)]) {
      final r = Rig();
      await r.ctrl.startCall(conversationId: 9, peerName: 'Ann', video: false);
      r.signals.states.add({'call_id': _callId, 'status': 'declined', 'reason': reason});
      await settle();
      expect(r.s!.endReason, expected);
    }
    final r = Rig();
    await r.ctrl.startCall(conversationId: 9, peerName: 'Ann', video: false);
    r.signals.states.add({'call_id': 'some-other-call', 'status': 'ended'}); await settle();
    expect(r.s!.phase, CallPhase.outgoing); // signals for other calls are ignored
    r.signals.states.add({'call_id': _callId, 'status': 'ended', 'by': _peer}); await settle();
    expect(r.s!.endReason, CallEndReason.remoteHungUp);
  });

  test('incoming: accept joins with a fresh token; the other side leaving ends the call', () async {
    final r = Rig();
    r.ring(kind: 'video'); await settle();
    expect([r.s!.phase, r.s!.peerName, r.s!.video, r.s!.outgoing], [CallPhase.incoming, 'Ann Lee', true, false]);
    expect(r.engine.joined, isNull); // nothing is captured until the user answers
    await r.ctrl.accept();
    expect(r.perms.asked, 1);
    expect(r.calls, contains('POST /calls/$_callId/join'));
    expect(r.engine.joined!['token'], 'tok-b');
    expect(r.s!.phase, CallPhase.active);
    r.engine.events0.add(RemoteLeft(_peer)); await settle();
    expect(r.s!.endReason, CallEndReason.remoteHungUp);
    expect(r.calls.last, 'POST /calls/$_callId/end');
  });

  test('incoming: decline, caller gives up, answered on another device', () async {
    final a = Rig(); a.ring(); await settle();
    await a.ctrl.decline();
    expect(a.calls.last, 'POST /calls/$_callId/decline'); expect(a.s!.endReason, CallEndReason.declined);

    final b = Rig(); b.ring(); await settle();
    b.signals.states.add({'call_id': _callId, 'status': 'missed'}); await settle();
    expect(b.s!.endReason, CallEndReason.missed);

    final c = Rig(); c.ring(); await settle();
    c.signals.states.add({'call_id': _callId, 'status': 'active', 'joined': _me}); await settle();
    expect(c.s!.endReason, CallEndReason.answeredElsewhere);
    expect(c.calls, isEmpty); // this device sends nothing
  });

  test('a second call while busy is declined as busy and does not disturb the current one', () async {
    final r = Rig();
    await r.ctrl.startCall(conversationId: 9, peerName: 'Ann', video: false);
    r.ring(id: '99999999-2222-3333-4444-555555555555'); await settle();
    expect(r.calls.last, 'POST /calls/99999999-2222-3333-4444-555555555555/decline {reason: busy}');
    expect(r.s!.callId, _callId); expect(r.s!.phase, CallPhase.outgoing);
    expect(await r.ctrl.startCall(conversationId: 10, peerName: 'Bo', video: false), isFalse); // one call at a time
  });

  test('permission refused or calling not configured: nothing rings and the reason is shown', () async {
    final denied = Rig(grant: false);
    expect(await denied.ctrl.startCall(conversationId: 9, peerName: 'Ann', video: true), isFalse);
    expect(denied.s!.endReason, CallEndReason.permissionDenied);
    expect(denied.calls, isEmpty);

    final off = Rig(routes: {'POST /calls': (_) => (status: 503, body: {'error': {'code': 'CALLS_NOT_CONFIGURED', 'message': 'Calling is not configured'}})});
    await off.ctrl.startCall(conversationId: 9, peerName: 'Ann', video: false);
    expect(off.s!.endReason, CallEndReason.notConfigured);
    expect(off.engine.joined, isNull);
  });

  test('network: media reconnecting is shown; after a socket reconnect the call is re-read from the server', () async {
    var status = 'ringing';
    final r = Rig(routes: {'GET /calls/$_callId': (_) => (status: 200, body: {'id': _callId, 'status': status})});
    await r.ctrl.startCall(conversationId: 9, peerName: 'Ann', video: false);
    r.engine.events0.add(ConnectionChanged(EngineConnection.reconnecting)); await settle();
    expect(r.s!.reconnecting, isTrue);
    r.engine.events0.add(ConnectionChanged(EngineConnection.connected)); await settle();
    expect(r.s!.reconnecting, isFalse);
    r.signals.connected.add(null); await settle();
    expect(r.s!.phase, CallPhase.outgoing); // still ringing
    status = 'missed'; // the callee never answered while we were offline
    r.signals.connected.add(null); await settle();
    expect(r.s!.endReason, CallEndReason.noAnswer);
  });

  test('a media engine that cannot start ends the call on the server instead of leaving the callee ringing', () async {
    final r = Rig(linger: const Duration(seconds: 1)); r.engine.failJoin = true;
    await r.ctrl.startCall(conversationId: 9, peerName: 'Ann', video: false);
    await settle();
    expect(r.s!.endReason, CallEndReason.failed);
    expect(r.calls.last, 'POST /calls/$_callId/end');
  });

  test('long calls renew their token before it expires', () async {
    final r = Rig(routes: {'POST /calls/$_callId/token': (_) => (status: 200, body: {'token': 'tok-new'})});
    await r.ctrl.startCall(conversationId: 9, peerName: 'Ann', video: false);
    r.engine.events0.add(TokenWillExpire()); await settle();
    expect(r.engine.renewed, 'tok-new');
  });

  test('opening a call push rings only if the call is still ringing', () async {
    var status = 'ringing';
    final r = Rig(routes: {'GET /calls/$_callId': (_) => (status: 200, body: {'id': _callId, 'status': status, 'kind': 'audio', 'conversation_id': 9, 'is_group': false, 'initiator': {'id': _peer, 'display_name': 'Ann Lee'}})});
    expect(await r.ctrl.loadIncoming(_callId), isTrue);
    expect(r.s!.phase, CallPhase.incoming);
    await r.ctrl.decline(); await settle(40);
    status = 'missed';
    expect(await r.ctrl.loadIncoming(_callId), isFalse);
    expect(r.s, isNull);
  });

  test('push taps route to the call, the call log, or nowhere', () {
    expect(PushService.routeFor({'type': 'call', 'call_id': _callId, 'conversation_id': '9'}), '/call/incoming/$_callId');
    expect(PushService.routeFor({'type': 'call', 'call_id': _callId, 'missed': '1'}), '/calls');
    expect(PushService.routeFor({'type': 'call', 'call_id': '../x'}), isNull);
    expect(PushService.routeFor({'conversation_id': '9', 'title': 'Ann'}), '/chat/9?title=Ann'); // chats unchanged
  });

  testWidgets('when a call ends, only the call screen closes (the screen underneath stays)', (t) async {
    final r = Rig();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(UncontrolledProviderScope(container: r.c, child: MaterialApp(navigatorKey: nav, theme: buildTheme(Brightness.light), home: const Scaffold(body: Text('chat thread')),
        localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales)));
    r.ring(); await t.pump();
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const CallScreen()));
    await t.pumpAndSettle();
    expect(find.text('Incoming audio call'), findsOneWidget);
    await t.tap(find.byTooltip('Decline'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50)); // linger passes, state clears
    await t.pumpAndSettle();
    expect(find.byType(CallScreen), findsNothing);
    expect(find.text('chat thread'), findsOneWidget);
  });

  testWidgets('a minimized live call shows the return-to-call bar; tapping it reopens the call', (t) async {
    final r = Rig();
    var opened = 0;
    await t.pumpWidget(UncontrolledProviderScope(container: r.c, child: MaterialApp(theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Stack(children: [const Text('feed'), MinimizedCallBar(onOpen: () => opened++)])))));
    await t.runAsync(() => r.ctrl.startCall(conversationId: 9, peerName: 'Ann Lee', video: false));
    await t.pump();
    expect(find.text('Ann Lee'), findsNothing); // not minimized yet: the full call screen is in charge
    r.ctrl.setMinimized(true);
    await t.pump();
    expect(find.text('Ann Lee'), findsOneWidget);
    expect(find.text('Calling…'), findsOneWidget);
    await t.tap(find.text('Ann Lee'));
    await t.pump();
    expect(opened, 1);
    expect(r.s!.minimized, isFalse);
    expect(find.text('Ann Lee'), findsNothing);
    await t.runAsync(() => r.ctrl.hangUp());
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('incoming call screen in Arabic: right-to-left, translated, decline works', (t) async {
    final r = Rig();
    await t.pumpWidget(UncontrolledProviderScope(container: r.c, child: MaterialApp(
      theme: buildTheme(Brightness.light, language: 'ar'), locale: const Locale('ar'), home: const CallScreen(),
      localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
    )));
    r.ring(kind: 'video');
    await t.pump(); await t.pump();
    expect(find.text('Ann Lee'), findsOneWidget);
    expect(find.text('مكالمة فيديو واردة'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(CallScreen))), TextDirection.rtl);
    await t.tap(find.byTooltip('رفض'));
    await t.pump(); await t.pump();
    expect(find.text('تم رفض المكالمة'), findsOneWidget);
    expect(r.s!.endReason, CallEndReason.declined); // the request itself is covered by the controller tests above
    expect(t.takeException(), isNull);
    await t.pump(const Duration(milliseconds: 50)); // let the linger timer finish
  });
}
