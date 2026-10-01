import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';

/// TikTok-style vertical feed: one full-screen video per page, only the visible one plays.
class ReelsScreen extends ConsumerStatefulWidget { const ReelsScreen({super.key}); @override ConsumerState<ReelsScreen> createState() => _State(); }
class _State extends ConsumerState<ReelsScreen> {
  final _page = PageController();
  List<Post> _reels = []; int? _cursor; bool _loading = true, _more = false; String? _error; int _current = 0; bool _trending = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _page.dispose(); super.dispose(); }

  Future<void> _load({bool append = false}) async {
    try {
      final api = ref.read(apiProvider);
      final r = _trending ? await api.get('/videos/reels/trending') : await api.get('/videos/reels', q: {'limit': 10, if (append && _cursor != null) 'cursor': _cursor});
      final items = (r['data'] as List).map((p) => Post.fromJson(p)).where((p) => p.mediaUrl != null).toList();
      if (!mounted) return;
      setState(() { _reels = append ? [..._reels, ...items] : items; _cursor = r['next_cursor']; _loading = false; _more = false; _error = null; });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; _more = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (_loading) const Center(child: CircularProgressIndicator())
        else if (_error != null) ErrorRetry(message: _error!, onRetry: () { setState(() => _loading = true); _load(); })
        else if (_reels.isEmpty) EmptyState(icon: Icons.movie_creation_outlined, title: context.l10n.noReels, message: context.l10n.noReelsMessage)
        else PageView.builder(
          controller: _page, scrollDirection: Axis.vertical, itemCount: _reels.length,
          onPageChanged: (i) { setState(() => _current = i); if (i >= _reels.length - 3 && _cursor != null && !_more && !_trending) { _more = true; _load(append: true); } },
          itemBuilder: (c, i) => _ReelPage(post: _reels[i], active: i == _current),
        ),
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(Sp.s3),
          child: Glass(radius: Rd.pill, padding: const EdgeInsets.all(4), child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final e in [(false, context.l10n.forYou), (true, context.l10n.trending)]) GestureDetector(
              onTap: () { if (_trending != e.$1) { setState(() { _trending = e.$1; _loading = true; }); _load(); } },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: Sp.s4, vertical: Sp.s2), decoration: BoxDecoration(color: _trending == e.$1 ? t.brand : Colors.transparent, borderRadius: BorderRadius.circular(Rd.pill)), child: Text(e.$2, style: TextStyle(fontWeight: FontWeight.w700, color: _trending == e.$1 ? t.onBrand : t.ink))),
            ),
          ])),
        )),
      ]),
    );
  }
}

class _ReelPage extends ConsumerStatefulWidget { const _ReelPage({required this.post, required this.active}); final Post post; final bool active; @override ConsumerState<_ReelPage> createState() => _PageState(); }
class _PageState extends ConsumerState<_ReelPage> {
  VideoPlayerController? _c; bool _failed = false; bool _counted = false;
  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.post.mediaUrl!));
      await c.initialize(); await c.setLooping(true);
      if (!mounted) { c.dispose(); return; }
      setState(() => _c = c);
      if (widget.active) _play();
    } catch (_) { if (mounted) setState(() => _failed = true); }
  }
  void _play() { _c?.play(); if (!_counted) { _counted = true; ref.read(apiProvider).post('/videos/${widget.post.id}/view').catchError((_) {}); } }
  @override
  void didUpdateWidget(_ReelPage old) { super.didUpdateWidget(old); widget.active ? _play() : _c?.pause(); }
  @override
  void dispose() { _c?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = context.tk; final p = widget.post;
    return GestureDetector(
      onTap: () => setState(() => (_c?.value.isPlaying ?? false) ? _c?.pause() : _c?.play()),
      child: Stack(fit: StackFit.expand, children: [
        if (_c != null && _c!.value.isInitialized) FittedBox(fit: BoxFit.cover, child: SizedBox(width: _c!.value.size.width, height: _c!.value.size.height, child: VideoPlayer(_c!)))
        else Center(child: _failed ? Text(context.l10n.videoUnavailable, style: const TextStyle(color: Colors.white)) : const CircularProgressIndicator()),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 220, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [t.scrim, Colors.transparent])))),
        PositionedDirectional(start: Sp.s4, end: 80, bottom: Sp.s6, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(isolate('@${p.author.username}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(p.videoTitle ?? p.body, textDirection: contentDirection(p.videoTitle ?? p.body), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ])),
        PositionedDirectional(end: Sp.s3, bottom: Sp.s8, child: Column(children: [
          _Action(icon: p.myReaction != null ? Icons.favorite : Icons.favorite_border, label: context.compact(p.reactions), onTap: () async {
            try { await ref.read(apiProvider).put('/posts/${p.id}/reaction', body: {'kind': 'love'}); if (context.mounted) toast(context, context.l10n.loved); } catch (e) { if (context.mounted) toast(context, e.toString()); }
          }),
          const SizedBox(height: Sp.s4),
          _Action(icon: Icons.mode_comment_outlined, label: context.compact(p.comments), onTap: () {}),
        ])),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(children: [
        IconButton.filledTonal(onPressed: onTap, icon: Icon(icon), tooltip: label, style: IconButton.styleFrom(backgroundColor: Colors.black38, foregroundColor: Colors.white)),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]);
}
