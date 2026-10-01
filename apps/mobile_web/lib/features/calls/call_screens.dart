import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../../core/l10n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import 'call_controller.dart';

String _initials(String name) => name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

/// "4:07" / "1:02:33" with the language's digits.
String callDuration(BuildContext context, Duration d) {
  final f = intl.NumberFormat('00', Localizations.localeOf(context).toLanguageTag());
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '${context.number(h)}:${f.format(m)}:${f.format(s)}' : '${context.number(m)}:${f.format(s)}';
}

String callStatusText(BuildContext context, CallState s) {
  final l = context.l10n;
  return switch (s.phase) {
    CallPhase.outgoing => l.callCalling,
    CallPhase.incoming => s.video ? l.callIncomingVideo : l.callIncomingAudio,
    CallPhase.connecting => l.callConnecting,
    CallPhase.active => s.reconnecting ? l.callReconnecting : callDuration(context, DateTime.now().difference(s.connectedAt ?? DateTime.now())),
    CallPhase.ended => l.callEndReason(s.endReason?.name ?? 'hungUp'),
  };
}

/// Rebuilds once a second while a call is connected (for the timer).
mixin _Ticker<T extends StatefulWidget> on State<T> {
  Timer? _tick;
  @override
  void initState() { super.initState(); _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { _tick?.cancel(); super.dispose(); }
}

/// Full-screen call: incoming (accept/decline), outgoing ringing, connected (audio or video) and the ended notice.
class CallScreen extends ConsumerStatefulWidget { const CallScreen({super.key}); @override ConsumerState<CallScreen> createState() => _CallScreenState(); }
class _CallScreenState extends ConsumerState<CallScreen> with _Ticker {
  bool _closed = false;
  /// Pops this screen exactly once (the state listener and the post-frame check can both ask), and only while it is
  /// on top, so the screen underneath is never popped by mistake.
  void _close() {
    if (_closed || !mounted || ModalRoute.of(context)?.isCurrent != true || !Navigator.of(context).canPop()) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  void _minimize() { ref.read(callControllerProvider.notifier).setMinimized(true); _close(); }

  @override
  Widget build(BuildContext context) {
    // The screen goes away on its own once the call is over and its closing notice has been shown.
    ref.listen(callControllerProvider, (_, next) { if (next == null) _close(); });
    final s = ref.watch(callControllerProvider);
    final t = context.tk; final l = context.l10n;
    if (s == null) { WidgetsBinding.instance.addPostFrameCallback((_) => _close()); return Scaffold(backgroundColor: t.bg); }
    final ctrl = ref.read(callControllerProvider.notifier);
    final engine = ctrl.engine;
    final showRemote = s.video && s.phase == CallPhase.active && s.remoteUid != null && engine != null;
    final showLocal = s.video && s.cameraOn && s.live && s.phase != CallPhase.incoming && engine != null;
    final onMedia = showRemote; // text sits on video: white with a scrim, as in reels
    final ink = onMedia ? Colors.white : t.ink, muted = onMedia ? Colors.white70 : t.inkMuted;
    final canMinimize = s.live && s.phase != CallPhase.incoming;

    return PopScope(
      canPop: !s.live || s.phase == CallPhase.incoming,
      onPopInvokedWithResult: (didPop, _) { if (!didPop && canMinimize) _minimize(); }, // system back minimizes a live call
      child: Scaffold(
        backgroundColor: onMedia ? Colors.black : t.bg,
        body: Stack(fit: StackFit.expand, children: [
          if (showRemote) engine.remoteView(s.remoteUid!, s.channel),
          if (showRemote) Positioned(left: 0, right: 0, top: 0, child: Container(height: 180, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.scrim, Colors.transparent])))),
          SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.s2), child: Row(children: [
              if (canMinimize) IconButton(tooltip: l.minimize, icon: Icon(Icons.keyboard_arrow_down_rounded, color: ink, size: 32), onPressed: _minimize),
            ])),
            if (showRemote) ...[
              Text(s.peerName, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: ink)),
              Text(callStatusText(context, s), style: TextStyle(color: muted)),
            ] else Expanded(child: Center(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              JAvatar(_initials(s.peerName), size: 112),
              const SizedBox(height: Sp.s4),
              Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.s6), child: Text(s.peerName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium)),
              const SizedBox(height: Sp.s2),
              Semantics(liveRegion: true, child: Text(callStatusText(context, s), textAlign: TextAlign.center, style: TextStyle(color: s.phase == CallPhase.ended ? t.danger : t.inkMuted, fontSize: 16))),
              if (s.endReason == CallEndReason.permissionDenied) Padding(padding: const EdgeInsets.only(top: Sp.s4), child: OutlinedButton(onPressed: () => ref.read(callPermissionsProvider).openSettings(), child: Text(l.openSettings))),
            ])))),
            if (showRemote) const Spacer(),
            Padding(padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s4, Sp.s4, Sp.s8), child: _Controls(s: s, onMedia: onMedia)),
          ])),
          if (showLocal) PositionedDirectional(top: MediaQuery.of(context).padding.top + 64, end: Sp.s4, width: 108, height: 152,
              child: ClipRRect(borderRadius: BorderRadius.circular(Rd.md), child: engine.localView())),
        ]),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.s, required this.onMedia});
  final CallState s; final bool onMedia;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk; final l = context.l10n; final c = ref.read(callControllerProvider.notifier);
    if (s.phase == CallPhase.ended) return const SizedBox(height: 96);
    if (s.phase == CallPhase.incoming) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _RoundButton(icon: Icons.call_end_rounded, label: l.declineCall, bg: t.danger, fg: t.onDanger, onTap: c.decline, onMedia: onMedia),
        _RoundButton(icon: s.video ? Icons.videocam_rounded : Icons.call_rounded, label: l.acceptCall, bg: t.brand, fg: t.onBrand, onTap: c.accept, onMedia: onMedia),
      ]);
    }
    Widget toggle(IconData on, IconData off, bool active, String label, VoidCallback tap, [String? caption]) =>
        _RoundButton(icon: active ? on : off, label: label, caption: caption, bg: active ? t.ink : t.surfaceRaised, fg: active ? t.bg : t.ink, onTap: tap, onMedia: onMedia, size: 56, selected: active);
    final row = Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      toggle(Icons.mic_off_rounded, Icons.mic_none_rounded, s.muted, s.muted ? l.unmute : l.mute, c.toggleMute),
      if (s.video) toggle(Icons.videocam_off_rounded, Icons.videocam_outlined, !s.cameraOn, s.cameraOn ? l.cameraOff : l.cameraOn, c.toggleCamera, l.cameraShort),
      if (s.video) _RoundButton(icon: Icons.cameraswitch_outlined, label: l.switchCamera, caption: l.flipShort, bg: t.surfaceRaised, fg: t.ink, onTap: c.switchCamera, onMedia: onMedia, size: 56),
      toggle(Icons.volume_up_rounded, Icons.volume_down_outlined, s.speakerOn, l.speaker, c.toggleSpeaker),
      _RoundButton(icon: Icons.call_end_rounded, label: l.endCall, bg: t.danger, fg: t.onDanger, onTap: c.hangUp, onMedia: onMedia, size: 56),
    ]);
    return onMedia ? Glass(radius: Rd.lg, padding: const EdgeInsets.symmetric(vertical: Sp.s3), child: row) : row;
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.bg, required this.fg, required this.onTap, this.caption, this.onMedia = false, this.size = 72, this.selected});
  /// [label] is the full action (tooltip, screen readers); [caption] a short visible word when the label is long.
  final IconData icon; final String label; final String? caption; final Color bg, fg; final VoidCallback onTap; final bool onMedia; final double size; final bool? selected;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true, toggled: selected, label: label, excludeSemantics: true, onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton.filled(onPressed: onTap, tooltip: label, icon: Icon(icon, size: size * 0.42), style: IconButton.styleFrom(backgroundColor: bg, foregroundColor: fg, fixedSize: Size.square(size))),
          const SizedBox(height: Sp.s1),
          // Over video the controls sit on a Glass panel that follows the theme, so captions use the theme ink.
          SizedBox(width: size + 16, child: Text(caption ?? label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: onMedia ? context.tk.ink : context.tk.inkMuted))),
        ]),
      );
}

/// Floating "return to call" pill shown over the app while a call is minimized.
class MinimizedCallBar extends ConsumerStatefulWidget { const MinimizedCallBar({super.key, required this.onOpen}); final VoidCallback onOpen; @override ConsumerState<MinimizedCallBar> createState() => _BarState(); }
class _BarState extends ConsumerState<MinimizedCallBar> with _Ticker {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(callControllerProvider);
    if (s == null || !s.live || !s.minimized) return const SizedBox.shrink();
    final t = context.tk;
    // Just below the app bar, so it never covers a screen's title or actions.
    return SafeArea(child: Align(alignment: Alignment.topCenter, child: Padding(
      padding: const EdgeInsets.only(top: kToolbarHeight + Sp.s1),
      child: Material(type: MaterialType.transparency, child: Semantics(
        button: true, label: '${s.peerName}, ${callStatusText(context, s)}. ${context.l10n.returnToCall}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(Rd.pill),
          onTap: () { ref.read(callControllerProvider.notifier).setMinimized(false); widget.onOpen(); },
          child: Glass(radius: Rd.pill, padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s2), child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(s.video ? Icons.videocam_rounded : Icons.call_rounded, size: 18, color: t.brand),
            const SizedBox(width: Sp.s2),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: Text(s.peerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: t.ink))),
            const SizedBox(width: Sp.s2),
            Text(callStatusText(context, s), style: TextStyle(color: t.inkMuted, fontFeatures: const [FontFeature.tabularFigures()])),
          ])),
        ),
      )),
    )));
  }
}

/// Opened from a call push: rings if the call is still ringing, otherwise says it has ended.
class IncomingCallLoader extends ConsumerStatefulWidget { const IncomingCallLoader({super.key, required this.callId}); final String callId; @override ConsumerState<IncomingCallLoader> createState() => _LoaderState(); }
class _LoaderState extends ConsumerState<IncomingCallLoader> {
  bool _gone = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final ringing = await ref.read(callControllerProvider.notifier).loadIncoming(widget.callId);
      if (!mounted) return;
      ringing ? context.pushReplacement('/call') : setState(() => _gone = true);
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: _gone ? EmptyState(icon: Icons.phone_missed_outlined, title: context.l10n.callNotRinging, action: FilledButton(onPressed: () => context.go('/calls'), child: Text(context.l10n.callHistory))) : const Center(child: CircularProgressIndicator()),
      );
}

/// Call log: most recent first, missed calls marked, tap the icon to call back.
final callHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async => ((await ref.watch(apiProvider).get('/calls/history'))['data'] as List).cast<Map<String, dynamic>>());

class CallLogScreen extends ConsumerWidget {
  const CallLogScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk; final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.callsTitle)),
      body: ref.watch(callHistoryProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(message: e.toString(), onRetry: () => ref.invalidate(callHistoryProvider)),
        data: (rows) => rows.isEmpty ? EmptyState(icon: Icons.call_outlined, title: l.noCalls, message: l.noCallsMessage) : RefreshIndicator(
          onRefresh: () async => ref.refresh(callHistoryProvider.future),
          child: ListView.separated(itemCount: rows.length, separatorBuilder: (_, _) => const Divider(indent: 72), itemBuilder: (c, i) {
            final r = rows[i];
            final video = r['kind'] == 'video'; final outgoing = r['direction'] == 'outgoing';
            final missed = !outgoing && r['status'] == 'missed';
            final name = '${(r['peer'] as Map?)?['display_name'] ?? ''}';
            final secs = (r['duration_s'] as num?)?.toInt() ?? 0;
            final parts = [
              outgoing ? l.callOutgoing : l.callIncoming,
              if (missed) l.callMissedLabel else if (r['status'] == 'declined') l.callDeclinedLabel,
              c.timeAgo(parseTime(r['created_at'])),
              if (secs > 0) callDuration(c, Duration(seconds: secs)),
            ];
            final peerId = (r['peer'] as Map?)?['id'];
            return ListTile(
              leading: JAvatar(_initials(name), size: 44),
              title: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: missed ? t.danger : t.ink)),
              subtitle: Row(children: [
                Icon(outgoing ? Icons.call_made_rounded : (missed ? Icons.call_missed_rounded : Icons.call_received_rounded), size: 16, color: missed ? t.danger : t.inkMuted),
                const SizedBox(width: Sp.s1),
                Expanded(child: Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.inkMuted))),
              ]),
              trailing: peerId == null || !ref.watch(callsSupportedProvider) ? null : IconButton(
                tooltip: '${l.callBack}: ${video ? l.callVideo : l.callAudio}', icon: Icon(video ? Icons.videocam_outlined : Icons.call_outlined),
                onPressed: () => startCallFrom(c, ref, conversationId: (r['conversation_id'] as num).toInt(), peerName: name, video: video),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Starts a call and opens the call screen (which also shows why a call could not start, e.g. missing permission).
Future<void> startCallFrom(BuildContext context, WidgetRef ref, {required int conversationId, required String peerName, required bool video}) async {
  if (!ref.read(callsSupportedProvider)) { toast(context, context.l10n.callsUnavailable); return; }
  final ctrl = ref.read(callControllerProvider.notifier);
  if (ctrl.busy) { ctrl.setMinimized(false); context.push('/call'); return; }
  // Open the call screen as soon as there is a call to show (after the permission prompt), not when ringing ends.
  final shown = Completer<void>();
  final sub = ref.listenManual(callControllerProvider, (_, next) { if (next != null && !shown.isCompleted) shown.complete(); });
  final started = ctrl.startCall(conversationId: conversationId, peerName: peerName, video: video);
  await Future.any([shown.future, started]);
  sub.close();
  if (context.mounted && ref.read(callControllerProvider) != null) context.push('/call');
  await started;
}
