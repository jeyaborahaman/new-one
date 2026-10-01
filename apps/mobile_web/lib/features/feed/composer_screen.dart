import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/media_upload.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import 'feed_state.dart';
import '../../core/l10n.dart';

/// Text, poll, photo, video and reel posts.
class ComposerScreen extends ConsumerStatefulWidget { const ComposerScreen({super.key}); @override ConsumerState<ComposerScreen> createState() => _State(); }
class _State extends ConsumerState<ComposerScreen> {
  final _body = TextEditingController();
  final List<TextEditingController> _opts = [TextEditingController(), TextEditingController()];
  bool _poll = false, _posting = false, _reel = true; String _visibility = 'public'; DateTime? _schedule;
  PickedMedia? _media; double? _progress;
  @override
  void dispose() { _body.dispose(); for (final c in _opts) { c.dispose(); } super.dispose(); }

  Future<void> _pick(String kind) async {
    try {
      final m = await PickedMedia.pick(kind);
      if (m != null && mounted) setState(() { _media = m; _poll = false; });
    } catch (e) { if (mounted) toast(context, context.l10n.couldNotOpenGallery('$e')); }
  }

  Future<void> _post() async {
    final text = _body.text.trim();
    final m = _media; final l = context.l10n;
    if (text.isEmpty && m == null) { toast(context, l.composerEmpty); return; }
    final options = _opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (_poll && options.length < 2) { toast(context, l.pollNeedsTwo); return; }
    setState(() { _posting = true; _progress = m == null ? null : 0; });
    try {
      final api = ref.read(apiProvider);
      final mediaId = m == null ? null : await uploadMedia(api, m, onProgress: (p) { if (mounted) setState(() => _progress = p); });
      final at = _schedule?.toUtc().toIso8601String();
      dynamic r;
      if (m != null && m.kind == 'video') {
        // Videos go through /videos so they get a title, reel/long-video flag and subscriber notifications.
        final title = (text.isEmpty ? l.video : text.split('\n').first);
        r = await api.post('/videos', body: {'media_id': mediaId, 'title': title.length > 150 ? title.substring(0, 150) : title, 'body': text, 'is_short': _reel});
      } else {
        r = await api.post('/posts', body: {
          'type': m != null ? 'image' : (_poll ? 'poll' : 'text'), 'body': text.isEmpty ? l.photo : text, 'visibility': _visibility,
          'media_id': ?mediaId, if (_poll) 'poll': {'options': options}, 'publish_at': ?at,
        });
      }
      if (_schedule == null) ref.read(feedProvider.notifier).prepend(Post.fromJson(r));
      if (mounted) { toast(context, _schedule == null ? l.posted : l.scheduled); context.go('/'); }
    } catch (e) { if (mounted) toast(context, e.toString()); } finally { if (mounted) setState(() { _posting = false; _progress = null; }); }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: now);
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (t == null) return;
    final when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (when.isBefore(now)) { if (mounted) toast(context, context.l10n.pickFutureTime); return; }
    setState(() => _schedule = when);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk; final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.newPost), leading: IconButton(tooltip: l.close, icon: const Icon(Icons.close), onPressed: () => context.go('/')), actions: [Padding(padding: const EdgeInsetsDirectional.only(end: Sp.s3), child: FilledButton(onPressed: _posting ? null : _post, style: FilledButton.styleFrom(minimumSize: const Size(72, 40)), child: Text(_schedule == null ? l.post : l.schedule)))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.s4),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _body, autofocus: true, minLines: 4, maxLines: 10, maxLength: 5000, decoration: InputDecoration(hintText: l.composerHint)),
          if (_media != null) ...[
            const SizedBox(height: Sp.s3),
            _MediaPreview(media: _media!, onRemove: _posting ? null : () => setState(() => _media = null)),
            if (_progress != null) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Semantics(label: l.uploading, value: context.percent(_progress!), child: LinearProgressIndicator(value: _progress, minHeight: 6, borderRadius: BorderRadius.circular(3)))),
            if (_media!.kind == 'video') Padding(padding: const EdgeInsets.only(top: Sp.s3), child: SegmentedButton<bool>(segments: [ButtonSegment(value: true, label: Text(l.shortReel), icon: const Icon(Icons.smartphone)), ButtonSegment(value: false, label: Text(l.regularVideo), icon: const Icon(Icons.ondemand_video))], selected: {_reel}, onSelectionChanged: (s) => setState(() => _reel = s.first))),
          ],
          if (_poll) ...[
            const SizedBox(height: Sp.s3),
            for (var i = 0; i < _opts.length; i++) Padding(padding: const EdgeInsets.only(bottom: Sp.s2), child: TextField(controller: _opts[i], maxLength: 120, buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null, decoration: InputDecoration(labelText: l.pollOption(i + 1)))),
            if (_opts.length < 6) TextButton.icon(onPressed: () => setState(() => _opts.add(TextEditingController())), icon: const Icon(Icons.add), label: Text(l.addOption)),
          ],
          const SizedBox(height: Sp.s3),
          Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [
            ActionChip(avatar: const Icon(Icons.photo_outlined, size: 18), label: Text(l.photo), onPressed: _posting ? null : () => _pick('image')),
            ActionChip(avatar: const Icon(Icons.videocam_outlined, size: 18), label: Text(l.video), onPressed: _posting ? null : () => _pick('video')),
            if (_media == null) FilterChip(label: Text(l.poll), avatar: const Icon(Icons.poll_outlined, size: 18), selected: _poll, onSelected: (v) => setState(() => _poll = v)),
            ActionChip(avatar: const Icon(Icons.schedule, size: 18), label: Text(_schedule == null ? l.schedule : l.scheduledAt(context.dayMonthClock(_schedule!))), onPressed: _pickSchedule),
            if (_schedule != null) ActionChip(label: Text(l.clearSchedule), onPressed: () => setState(() => _schedule = null)),
          ]),
          const SizedBox(height: Sp.s4),
          Text(l.whoCanSee, style: TextStyle(color: t.inkMuted, fontSize: 12)),
          const SizedBox(height: Sp.s2),
          SegmentedButton<String>(
            segments: [ButtonSegment(value: 'public', label: Text(l.visibilityPublic), icon: const Icon(Icons.public)), ButtonSegment(value: 'followers', label: Text(l.visibilityFollowers), icon: const Icon(Icons.people_outline)), ButtonSegment(value: 'private', label: Text(l.visibilityPrivate), icon: const Icon(Icons.lock_outline))],
            selected: {_visibility}, onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
        ]))),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.media, this.onRemove});
  final PickedMedia media; final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final t = context.tk; final l = context.l10n;
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Rd.md),
        child: media.previewBytes != null
            ? Image.memory(media.previewBytes!, height: 220, width: double.infinity, fit: BoxFit.cover, semanticLabel: l.selectedPhoto)
            : Container(height: 140, width: double.infinity, color: t.surfaceRaised, alignment: Alignment.center, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.movie_outlined, size: 40, color: t.inkMuted), const SizedBox(height: 6), Text(l.fileSize(media.name, context.decimal1(media.size / 1048576)), style: TextStyle(color: t.inkMuted))])),
      ),
      if (onRemove != null) PositionedDirectional(top: 6, end: 6, child: IconButton.filledTonal(tooltip: l.removeAttachment, onPressed: onRemove, icon: const Icon(Icons.close, size: 18), style: IconButton.styleFrom(backgroundColor: t.scrim, foregroundColor: Colors.white))),
    ]);
  }
}
