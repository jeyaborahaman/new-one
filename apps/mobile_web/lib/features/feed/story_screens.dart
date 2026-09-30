import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../core/media_upload.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import 'feed_state.dart';

/// Pick a photo or video and share it as a 24-hour story.
class StoryComposerScreen extends ConsumerStatefulWidget { const StoryComposerScreen({super.key}); @override ConsumerState<StoryComposerScreen> createState() => _State(); }
class _State extends ConsumerState<StoryComposerScreen> {
  PickedMedia? _m; final _caption = TextEditingController(); double? _progress; bool _busy = false;
  @override
  void dispose() { _caption.dispose(); super.dispose(); }

  Future<void> _pick(String kind, [ImageSource src = ImageSource.gallery]) async {
    try { final m = await PickedMedia.pick(kind, source: src); if (m != null && mounted) setState(() => _m = m); } catch (e) { if (mounted) toast(context, 'Could not open that: $e'); }
  }

  Future<void> _share() async {
    final m = _m; if (m == null) return;
    setState(() { _busy = true; _progress = 0; });
    try {
      final api = ref.read(apiProvider);
      final id = await uploadMedia(api, m, onProgress: (p) { if (mounted) setState(() => _progress = p); });
      await api.post('/stories', body: {'media_id': id, if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim()});
      await ref.read(feedProvider.notifier).refresh();
      if (mounted) { toast(context, 'Story shared for 24 hours'); context.pop(); }
    } catch (e) { if (mounted) toast(context, e.toString()); } finally { if (mounted) setState(() { _busy = false; _progress = null; }); }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk; final m = _m;
    return Scaffold(
      appBar: AppBar(title: const Text('New story'), actions: [if (m != null) Padding(padding: const EdgeInsets.only(right: Sp.s3), child: FilledButton(onPressed: _busy ? null : _share, style: FilledButton.styleFrom(minimumSize: const Size(72, 40)), child: const Text('Share')))]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Padding(padding: const EdgeInsets.all(Sp.s4), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: Container(
          decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(Rd.lg)), clipBehavior: Clip.antiAlias,
          child: m == null
              ? EmptyState(icon: Icons.auto_stories_outlined, title: 'Share a moment', message: 'Stories disappear after 24 hours.', action: Wrap(spacing: Sp.s2, runSpacing: Sp.s2, alignment: WrapAlignment.center, children: [
                  FilledButton.icon(onPressed: () => _pick('image'), icon: const Icon(Icons.photo_outlined), label: const Text('Photo')),
                  OutlinedButton.icon(onPressed: () => _pick('video'), icon: const Icon(Icons.videocam_outlined), label: const Text('Video')),
                ]))
              : m.previewBytes != null ? Image.memory(m.previewBytes!, fit: BoxFit.cover, semanticLabel: 'Story preview') : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.movie_outlined, size: 56, color: t.inkMuted), Text(m.name)])),
        )),
        if (m != null) ...[
          const SizedBox(height: Sp.s3),
          TextField(controller: _caption, maxLength: 200, decoration: const InputDecoration(hintText: 'Add a caption')),
          if (_progress != null) LinearProgressIndicator(value: _progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
          TextButton(onPressed: _busy ? null : () => setState(() => _m = null), child: const Text('Choose a different file')),
        ],
      ])))),
    );
  }
}

/// Full-screen viewer: segmented progress bar, tap right/left to skip, hold to pause, react, and (for your own) see who viewed.
class StoryViewerScreen extends ConsumerStatefulWidget { const StoryViewerScreen({super.key, required this.groups, required this.start}); final List<StoryGroup> groups; final int start; @override ConsumerState<StoryViewerScreen> createState() => _ViewerState(); }
class _ViewerState extends ConsumerState<StoryViewerScreen> with SingleTickerProviderStateMixin {
  late int _g = widget.start; int _i = 0;
  late final AnimationController _bar = AnimationController(vsync: this)..addStatusListener((s) { if (s == AnimationStatus.completed) _next(); });
  VideoPlayerController? _video; bool _paused = false; int? _viewers;

  StoryGroup get _group => widget.groups[_g];
  StoryItem get _item => _group.stories[_i];
  bool get _mine => _group.user.id == ref.read(authProvider).user?.id;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _bar.dispose(); _video?.dispose(); super.dispose(); }

  Future<void> _load() async {
    _bar.stop(); _bar.value = 0; _viewers = null;
    await _video?.dispose(); _video = null;
    final item = _item;
    if (_mine) {
      ref.read(apiProvider).get('/stories/${item.id}/viewers').then((r) { if (mounted) setState(() => _viewers = r['count']); }).catchError((_) {});
    } else {
      ref.read(apiProvider).post('/stories/${item.id}/view').catchError((_) {});
    }
    if (item.kind == 'video') {
      try {
        final c = VideoPlayerController.networkUrl(Uri.parse(item.url));
        await c.initialize(); if (!mounted) { c.dispose(); return; }
        _video = c; _bar.duration = c.value.duration; await c.play(); _bar.forward(); setState(() {});
      } catch (_) { _bar.duration = const Duration(seconds: 3); _bar.forward(); }
    } else { _bar.duration = const Duration(seconds: 5); _bar.forward(); setState(() {}); }
  }

  void _next() { if (!mounted) return; if (_i < _group.stories.length - 1) { setState(() => _i++); _load(); } else if (_g < widget.groups.length - 1) { setState(() { _g++; _i = 0; }); _load(); } else { context.pop(); } }
  void _prev() { if (_i > 0) { setState(() => _i--); _load(); } else if (_g > 0) { setState(() { _g--; _i = 0; }); _load(); } else { _load(); } }
  void _hold(bool h) { setState(() => _paused = h); if (h) { _bar.stop(); _video?.pause(); } else { _bar.forward(); _video?.play(); } }

  Future<void> _react(String kind) async {
    try { await ref.read(apiProvider).put('/stories/${_item.id}/reaction', body: {'kind': kind}); if (mounted) toast(context, 'Sent ${reactionEmoji[kind]}'); } catch (e) { if (mounted) toast(context, e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item; final t = context.tk; final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _hold(true), onLongPressEnd: (_) => _hold(false),
        onTapUp: (d) => d.localPosition.dx < size.width / 3 ? _prev() : _next(),
        child: Stack(fit: StackFit.expand, children: [
          if (item.kind == 'image') Image.network(item.url, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Center(child: Text('Story unavailable', style: TextStyle(color: Colors.white))))
          else if (_video != null && _video!.value.isInitialized) Center(child: AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!)))
          else const Center(child: CircularProgressIndicator()),
          Positioned(left: 0, right: 0, top: 0, child: Container(height: 140, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.scrim, Colors.transparent])))),
          SafeArea(child: Padding(padding: const EdgeInsets.all(Sp.s3), child: Column(children: [
            Row(children: [for (var k = 0; k < _group.stories.length; k++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: ClipRRect(borderRadius: BorderRadius.circular(2), child: AnimatedBuilder(animation: _bar, builder: (_, _) => LinearProgressIndicator(minHeight: 3, value: k < _i ? 1 : k == _i ? _bar.value : 0, backgroundColor: Colors.white30, color: Colors.white)))))]),
            const SizedBox(height: Sp.s3),
            Row(children: [
              JAvatar(_group.user.initials, size: 36), const SizedBox(width: Sp.s2),
              Expanded(child: Text(_group.user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              if (_paused) const Icon(Icons.pause_circle_outline, color: Colors.white),
              IconButton(tooltip: 'Close', icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop()),
            ]),
          ]))),
          Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(child: Padding(padding: const EdgeInsets.all(Sp.s4), child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (item.caption != null) Padding(padding: const EdgeInsets.only(bottom: Sp.s3), child: Text(item.caption!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 8)]))),
            if (_mine) Glass(radius: Rd.pill, padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s2), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.visibility_outlined, size: 18), const SizedBox(width: 6), Text(_viewers == null ? '…' : '$_viewers views')]))
            else Glass(radius: Rd.pill, padding: const EdgeInsets.symmetric(horizontal: Sp.s2), child: Row(mainAxisSize: MainAxisSize.min, children: [for (final e in reactionEmoji.entries) IconButton(tooltip: 'React ${e.key}', onPressed: () => _react(e.key), icon: Text(e.value, style: const TextStyle(fontSize: 22)))])),
          ])))),
        ]),
      ),
    );
  }
}
