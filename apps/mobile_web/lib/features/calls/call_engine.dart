import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Media connection states the call UI cares about.
enum EngineConnection { connecting, connected, reconnecting, failed, disconnected }

sealed class EngineEvent {}
class RemoteJoined extends EngineEvent { RemoteJoined(this.uid); final int uid; }
class RemoteLeft extends EngineEvent { RemoteLeft(this.uid); final int uid; }
class ConnectionChanged extends EngineEvent { ConnectionChanged(this.state); final EngineConnection state; }
class TokenWillExpire extends EngineEvent {}
class EngineFailure extends EngineEvent { EngineFailure(this.message); final String message; }

/// The slice of the RTC SDK the call feature uses, so call logic is testable without native code.
abstract class CallEngine {
  Stream<EngineEvent> get events;
  Future<void> join({required String appId, required String token, required String channel, required int uid, required bool video});
  Future<void> renewToken(String token);
  Future<void> setMuted(bool muted);
  Future<void> setCameraOn(bool on);
  Future<void> switchCamera();
  Future<void> setSpeaker(bool on);
  /// Leaves the channel and frees the engine. Safe to call more than once.
  Future<void> leave();
  Widget localView();
  Widget remoteView(int uid, String channel);
}

/// Agora RTC implementation. One engine per call: created on join, released on leave.
class AgoraCallEngine implements CallEngine {
  RtcEngine? _engine;
  // One render controller per stream for the whole call: rebuilding the view (timer ticks, minimize/reopen) must
  // reuse it, or the native renderer is torn down and the video goes black.
  VideoViewController? _localCtl;
  final _remoteCtl = <int, VideoViewController>{};
  final _events = StreamController<EngineEvent>.broadcast();
  @override
  Stream<EngineEvent> get events => _events.stream;

  static EngineConnection _map(ConnectionStateType s) => switch (s) {
        ConnectionStateType.connectionStateConnecting => EngineConnection.connecting,
        ConnectionStateType.connectionStateConnected => EngineConnection.connected,
        ConnectionStateType.connectionStateReconnecting => EngineConnection.reconnecting,
        ConnectionStateType.connectionStateFailed => EngineConnection.failed,
        _ => EngineConnection.disconnected,
      };

  @override
  Future<void> join({required String appId, required String token, required String channel, required int uid, required bool video}) async {
    final e = createAgoraRtcEngine();
    _engine = e;
    await e.initialize(RtcEngineContext(appId: appId, channelProfile: ChannelProfileType.channelProfileCommunication));
    e.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (_, remoteUid, _) => _events.add(RemoteJoined(remoteUid)),
      onUserOffline: (_, remoteUid, _) => _events.add(RemoteLeft(remoteUid)),
      onConnectionStateChanged: (_, state, _) => _events.add(ConnectionChanged(_map(state))),
      onTokenPrivilegeWillExpire: (_, _) => _events.add(TokenWillExpire()),
      onError: (err, msg) { if (err == ErrorCodeType.errInvalidToken || err == ErrorCodeType.errTokenExpired) _events.add(EngineFailure('$err $msg')); },
    ));
    if (video) { await e.enableVideo(); await e.startPreview(); } else { await e.disableVideo(); }
    await e.setDefaultAudioRouteToSpeakerphone(video); // video calls on the speaker, audio calls at the ear
    await e.joinChannel(token: token, channelId: channel, uid: uid, options: ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster, channelProfile: ChannelProfileType.channelProfileCommunication,
      publishMicrophoneTrack: true, publishCameraTrack: video, autoSubscribeAudio: true, autoSubscribeVideo: video,
    ));
  }

  @override
  Future<void> renewToken(String token) async => _engine?.renewToken(token);
  @override
  Future<void> setMuted(bool muted) async => _engine?.muteLocalAudioStream(muted);
  @override
  Future<void> setCameraOn(bool on) async { await _engine?.enableLocalVideo(on); await _engine?.muteLocalVideoStream(!on); }
  @override
  Future<void> switchCamera() async => _engine?.switchCamera();
  @override
  Future<void> setSpeaker(bool on) async => _engine?.setEnableSpeakerphone(on);

  @override
  Future<void> leave() async {
    final e = _engine; _engine = null; _localCtl = null; _remoteCtl.clear();
    if (e == null) return;
    try { await e.leaveChannel(); } catch (_) {}
    try { await e.release(); } catch (_) {}
  }

  @override
  Widget localView() {
    final e = _engine;
    if (e == null) return const SizedBox.shrink();
    final c = _localCtl ??= VideoViewController(rtcEngine: e, canvas: const VideoCanvas(uid: 0));
    return AgoraVideoView(key: const ValueKey('local-video'), controller: c);
  }
  @override
  Widget remoteView(int uid, String channel) {
    final e = _engine;
    if (e == null) return const SizedBox.shrink();
    final c = _remoteCtl.putIfAbsent(uid, () => VideoViewController.remote(rtcEngine: e, canvas: VideoCanvas(uid: uid), connection: RtcConnection(channelId: channel)));
    return AgoraVideoView(key: ValueKey('remote-video-$uid'), controller: c);
  }
}

/// Microphone (and camera for video) access. Android asks at runtime here; iOS shows its own prompt the first
/// time the SDK opens the mic/camera (usage texts are in Info.plist).
abstract class CallPermissions {
  Future<bool> request({required bool video});
  Future<void> openSettings();
}

class DeviceCallPermissions implements CallPermissions {
  @override
  Future<bool> request({required bool video}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    final statuses = await [Permission.microphone, if (video) Permission.camera].request();
    return statuses.values.every((s) => s.isGranted);
  }
  @override
  Future<void> openSettings() => openAppSettings();
}
