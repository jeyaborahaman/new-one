import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/tokens.dart';
import '../../core/l10n.dart';

/// Video in a feed card. Nothing is downloaded until the user taps play.
class InlineVideo extends StatefulWidget { const InlineVideo({super.key, required this.url, this.title}); final String url; final String? title; @override State<InlineVideo> createState() => _State(); }
class _State extends State<InlineVideo> {
  VideoPlayerController? _c; bool _loading = false, _failed = false;
  @override
  void dispose() { _c?.dispose(); super.dispose(); }

  Future<void> _start() async {
    if (_c != null) { setState(() => _c!.value.isPlaying ? _c!.pause() : _c!.play()); return; }
    setState(() => _loading = true);
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize(); await c.setLooping(true); await c.play();
      if (!mounted) { c.dispose(); return; }
      setState(() { _c = c; _loading = false; });
    } catch (_) { if (mounted) setState(() { _loading = false; _failed = true; }); }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk; final c = _c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Rd.md),
      child: AspectRatio(
        aspectRatio: c != null && c.value.isInitialized ? c.value.aspectRatio : 16 / 9,
        child: GestureDetector(
          onTap: _start,
          child: Stack(fit: StackFit.expand, children: [
            Container(color: Colors.black),
            if (c != null && c.value.isInitialized) VideoPlayer(c),
            Center(child: _loading ? const CircularProgressIndicator() : _failed ? Text(context.l10n.videoUnavailable, style: const TextStyle(color: Colors.white)) : (c == null || !c.value.isPlaying) ? Semantics(button: true, label: context.l10n.playVideo(widget.title ?? ''), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: t.scrim, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36))) : const SizedBox.shrink()),
            if (widget.title != null) PositionedDirectional(start: Sp.s3, bottom: Sp.s2, end: Sp.s3, child: Text(widget.title!, textDirection: contentDirection(widget.title!), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 6)]))),
          ]),
        ),
      ),
    );
  }
}
