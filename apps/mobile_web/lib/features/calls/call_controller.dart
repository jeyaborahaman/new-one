import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/socket_service.dart';
import '../../core/providers.dart';
import 'call_engine.dart';

enum CallPhase { outgoing, incoming, connecting, active, ended }
enum CallEndReason { hungUp, remoteHungUp, declined, busy, noAnswer, missed, answeredElsewhere, failed, permissionDenied, notConfigured }

/// The one call this device is in (or ringing for). Null when idle.
class CallState {
  const CallState({required this.callId, required this.conversationId, required this.peerName, required this.video, required this.outgoing, required this.phase,
      this.endReason, this.muted = false, this.cameraOn = true, this.speakerOn = false, this.reconnecting = false, this.minimized = false, this.remoteUid, this.connectedAt, this.channel = ''});
  final String callId, peerName, channel;
  final int conversationId;
  final bool video, outgoing, muted, cameraOn, speakerOn, reconnecting, minimized;
  final CallPhase phase;
  final CallEndReason? endReason;
  final int? remoteUid;
  final DateTime? connectedAt;

  bool get live => phase != CallPhase.ended;
  CallState copyWith({String? callId, String? channel, CallPhase? phase, CallEndReason? endReason, bool? muted, bool? cameraOn, bool? speakerOn, bool? reconnecting, bool? minimized, int? remoteUid, DateTime? connectedAt}) => CallState(
        callId: callId ?? this.callId, conversationId: conversationId, peerName: peerName, video: video, outgoing: outgoing, phase: phase ?? this.phase,
        endReason: endReason ?? this.endReason, muted: muted ?? this.muted, cameraOn: cameraOn ?? this.cameraOn, speakerOn: speakerOn ?? this.speakerOn,
        reconnecting: reconnecting ?? this.reconnecting, minimized: minimized ?? this.minimized, remoteUid: remoteUid ?? this.remoteUid,
        connectedAt: connectedAt ?? this.connectedAt, channel: channel ?? this.channel);
}

final callSignalsProvider = Provider<CallSignals>((ref) => ref.watch(socketProvider));
final callEngineFactoryProvider = Provider<CallEngine Function()>((_) => AgoraCallEngine.new);
final callPermissionsProvider = Provider<CallPermissions>((_) => DeviceCallPermissions());
/// How long an ended call stays on screen ("Call ended", "No answer") before the screen closes.
final callEndLingerProvider = Provider<Duration>((_) => const Duration(seconds: 2));
/// Calls need the native RTC SDK; the web build does not ship it yet.
final callsSupportedProvider = Provider<bool>((_) => !kIsWeb);

/// Signaling (REST + Socket.IO) and media (RTC engine) for one-to-one calls.
/// The server owns call state; this mirrors it and drives the engine.
class CallController extends Notifier<CallState?> {
  CallEngine? _engine;
  StreamSubscription? _engineSub;
  Timer? _ringTimer, _lingerTimer;
  final _subs = <StreamSubscription>[];

  ApiClient get _api => ref.read(apiProvider);
  int? get _me => ref.read(authProvider).user?.id;

  @override
  CallState? build() {
    final signals = ref.watch(callSignalsProvider);
    _subs..add(signals.incomingCalls.listen(_onIncoming))..add(signals.callStates.listen(_onState))..add(signals.connects.listen((_) => _resync()));
    ref.onDispose(() { for (final s in _subs) { s.cancel(); } _subs.clear(); _cleanup(); });
    return null;
  }

  bool get busy => state?.live ?? false;

  // ---------- outgoing ----------
  /// Rings the other member of a direct conversation. Returns false when nothing was started (already in a call,
  /// permission refused); the state says why when a call was attempted.
  Future<bool> startCall({required int conversationId, required String peerName, required bool video}) async {
    if (busy || !ref.read(callsSupportedProvider)) return false;
    if (!await ref.read(callPermissionsProvider).request(video: video)) {
      _set(CallState(callId: '', conversationId: conversationId, peerName: peerName, video: video, outgoing: true, phase: CallPhase.ended, endReason: CallEndReason.permissionDenied));
      _scheduleClear();
      return false;
    }
    _set(CallState(callId: '', conversationId: conversationId, peerName: peerName, video: video, outgoing: true, phase: CallPhase.outgoing, speakerOn: video));
    try {
      final r = await _api.post('/calls', body: {'conversation_id': conversationId, 'kind': video ? 'video' : 'audio'}) as Map;
      if (state?.phase != CallPhase.outgoing) return true; // cancelled while the request was in flight
      _set(state!.copyWith(callId: r['call_id'] as String, channel: r['channel'] as String));
      _armRing(Duration(milliseconds: (r['ring_timeout_ms'] as num?)?.toInt() ?? 45000), () async {
        if (state?.phase == CallPhase.outgoing) { await _post('/calls/${state!.callId}/end'); _finish(CallEndReason.noAnswer); }
      });
      await _join(r, video: video);
      return true;
    } on ApiException catch (e) {
      _finish(e.code == 'CALLS_NOT_CONFIGURED' ? CallEndReason.notConfigured : CallEndReason.failed);
      return true;
    } catch (_) { // the media engine could not start (bad App ID, no audio device...): do not leave the callee ringing
      _endWith(CallEndReason.failed);
      return true;
    }
  }

  // ---------- incoming ----------
  void _onIncoming(Map<String, dynamic> d) {
    if (!ref.read(callsSupportedProvider) || d['is_group'] == true) return; // one-to-one calls only
    final id = '${d['call_id']}';
    if (busy) { if (state!.callId != id) _post('/calls/$id/decline', {'reason': 'busy'}); return; } // already on a call: auto-decline
    _lingerTimer?.cancel();
    final from = (d['from'] as Map?) ?? {};
    _set(CallState(callId: id, channel: id, conversationId: (d['conversation_id'] as num).toInt(), peerName: '${from['display_name'] ?? ''}', video: d['kind'] == 'video', outgoing: false, phase: CallPhase.incoming, speakerOn: d['kind'] == 'video'));
    _armRing(const Duration(seconds: 45), () { if (state?.phase == CallPhase.incoming) _finish(CallEndReason.missed); }); // the server marks it missed
  }

  /// A device that opened from a push (or reconnected late) loads the call and rings only if it still rings.
  Future<bool> loadIncoming(String callId) async {
    if (state?.callId == callId && busy) return true;
    try {
      final c = await _api.get('/calls/$callId') as Map<String, dynamic>;
      final caller = (c['initiator'] as Map?) ?? {};
      if (c['status'] != 'ringing' || caller['id'] == _me) return false;
      _onIncoming({'call_id': callId, 'conversation_id': c['conversation_id'], 'kind': c['kind'], 'is_group': c['is_group'], 'from': caller});
      return state?.callId == callId;
    } catch (_) { return false; }
  }

  Future<void> accept() async {
    final s = state; if (s == null || s.phase != CallPhase.incoming) return;
    _ringTimer?.cancel();
    if (!await ref.read(callPermissionsProvider).request(video: s.video)) { await decline(); _finish(CallEndReason.permissionDenied); return; }
    _set(s.copyWith(phase: CallPhase.connecting));
    try {
      final r = await _api.post('/calls/${s.callId}/join') as Map;
      await _join(r, video: s.video);
      if (state?.phase == CallPhase.connecting) _set(state!.copyWith(phase: CallPhase.active, connectedAt: DateTime.now()));
    } on ApiException catch (e) {
      _finish(e.status == 409 ? CallEndReason.remoteHungUp : CallEndReason.failed); // 409: the caller gave up meanwhile
    } catch (_) {
      _endWith(CallEndReason.failed);
    }
  }

  Future<void> decline() async {
    final s = state; if (s == null || s.phase != CallPhase.incoming) return;
    _finish(CallEndReason.declined);
    await _post('/calls/${s.callId}/decline');
  }

  /// Hang up (or cancel an outgoing ring).
  Future<void> hangUp() async {
    final s = state; if (s == null || !s.live) return;
    if (s.phase == CallPhase.incoming) return decline();
    _finish(CallEndReason.hungUp);
    if (s.callId.isNotEmpty) await _post('/calls/${s.callId}/end');
  }

  // ---------- server signals ----------
  void _onState(Map<String, dynamic> d) {
    final s = state;
    if (s == null || !s.live || d['call_id'] != s.callId) return;
    final me = _me;
    switch (d['status']) {
      case 'active':
        if (s.phase == CallPhase.outgoing && d['joined'] != me) { _ringTimer?.cancel(); _set(s.copyWith(phase: CallPhase.active, connectedAt: DateTime.now())); }
        if (s.phase == CallPhase.incoming && d['joined'] == me) _finish(CallEndReason.answeredElsewhere); // picked up on another device
      case 'declined':
        _finish(s.outgoing ? (d['reason'] == 'busy' ? CallEndReason.busy : CallEndReason.declined) : CallEndReason.declined);
      case 'missed':
        _finish(s.outgoing ? CallEndReason.noAnswer : CallEndReason.missed);
      case 'ended':
        _finish(d['by'] == me ? CallEndReason.hungUp : CallEndReason.remoteHungUp);
    }
  }

  /// After a socket reconnect: anything that happened while offline is read back from the server.
  Future<void> _resync() async {
    final s = state; if (s == null || !s.live || s.callId.isEmpty) return;
    try {
      final c = await _api.get('/calls/${s.callId}') as Map<String, dynamic>;
      final status = c['status'];
      if (['ended', 'missed', 'declined'].contains(status)) {
        _onState({'call_id': s.callId, 'status': status});
      } else if (status == 'active' && s.phase == CallPhase.outgoing) {
        _onState({'call_id': s.callId, 'status': 'active', 'joined': -1});
      }
    } catch (_) { /* still offline; the next reconnect tries again */ }
  }

  // ---------- media ----------
  Future<void> _join(Map r, {required bool video}) async {
    final engine = _engine ??= ref.read(callEngineFactoryProvider)();
    _engineSub ??= engine.events.listen(_onEngine);
    await engine.join(appId: '${r['appId']}', token: '${r['token']}', channel: '${r['channel']}', uid: (r['uid'] as num).toInt(), video: video);
  }

  void _onEngine(EngineEvent e) {
    final s = state; if (s == null || !s.live) return;
    switch (e) {
      case RemoteJoined(:final uid):
        _set(s.copyWith(remoteUid: uid));
      case RemoteLeft():
        _endWith(CallEndReason.remoteHungUp); // one-to-one: the other side left, so the call is over
      case ConnectionChanged(:final state):
        if (state == EngineConnection.failed) { _endWith(CallEndReason.failed); }
        else { _set(s.copyWith(reconnecting: state == EngineConnection.reconnecting)); }
      case TokenWillExpire():
        _api.post('/calls/${s.callId}/token').then((r) => _engine?.renewToken('${(r as Map)['token']}')).catchError((_) {});
      case EngineFailure():
        _endWith(CallEndReason.failed);
    }
  }

  /// Ends locally with [reason] and closes the call on the server (idempotent there).
  void _endWith(CallEndReason reason) {
    final id = state?.callId ?? '';
    _finish(reason);
    if (id.isNotEmpty) _post('/calls/$id/end');
  }

  Future<void> toggleMute() async { final s = state; if (s == null) return; _set(s.copyWith(muted: !s.muted)); await _engine?.setMuted(!s.muted); }
  Future<void> toggleCamera() async { final s = state; if (s == null) return; _set(s.copyWith(cameraOn: !s.cameraOn)); await _engine?.setCameraOn(!s.cameraOn); }
  Future<void> toggleSpeaker() async { final s = state; if (s == null) return; _set(s.copyWith(speakerOn: !s.speakerOn)); await _engine?.setSpeaker(!s.speakerOn); }
  Future<void> switchCamera() async => _engine?.switchCamera();
  void setMinimized(bool m) { final s = state; if (s != null) _set(s.copyWith(minimized: m)); }
  CallEngine? get engine => _engine;

  // ---------- helpers ----------
  void _armRing(Duration d, void Function() onTimeout) { _ringTimer?.cancel(); _ringTimer = Timer(d, onTimeout); }

  void _finish(CallEndReason reason) {
    final s = state; if (s == null || !s.live) return;
    _cleanup();
    _set(s.copyWith(phase: CallPhase.ended, endReason: reason, reconnecting: false));
    _scheduleClear();
  }
  void _scheduleClear() { _lingerTimer?.cancel(); _lingerTimer = Timer(ref.read(callEndLingerProvider), () { if (ref.mounted && state?.live == false) state = null; }); }

  void _cleanup() {
    _ringTimer?.cancel();
    _engineSub?.cancel(); _engineSub = null;
    final e = _engine; _engine = null;
    e?.leave();
  }

  void _set(CallState s) { if (ref.mounted) state = s; }
  Future<void> _post(String path, [Object? body]) async { try { await _api.post(path, body: body); } catch (_) { /* best effort: the server expires calls */ } }
}

final callControllerProvider = NotifierProvider<CallController, CallState?>(CallController.new);
