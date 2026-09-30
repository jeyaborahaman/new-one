import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import 'feed_state.dart';

/// Text and poll posts. Photo/video posts need the media upload flow (presigned R2), which is wired once storage keys exist.
class ComposerScreen extends ConsumerStatefulWidget { const ComposerScreen({super.key}); @override ConsumerState<ComposerScreen> createState() => _State(); }
class _State extends ConsumerState<ComposerScreen> {
  final _body = TextEditingController();
  final List<TextEditingController> _opts = [TextEditingController(), TextEditingController()];
  bool _poll = false, _posting = false; String _visibility = 'public'; DateTime? _schedule;
  @override
  void dispose() { _body.dispose(); for (final c in _opts) { c.dispose(); } super.dispose(); }

  Future<void> _post() async {
    final text = _body.text.trim();
    if (text.isEmpty) { toast(context, 'Write something first'); return; }
    final options = _opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (_poll && options.length < 2) { toast(context, 'A poll needs at least 2 options'); return; }
    setState(() => _posting = true);
    try {
      final r = await ref.read(apiProvider).post('/posts', body: {
        'type': _poll ? 'poll' : 'text', 'body': text, 'visibility': _visibility,
        if (_poll) 'poll': {'options': options}, if (_schedule != null) 'publish_at': _schedule!.toUtc().toIso8601String(),
      });
      if (_schedule == null) ref.read(feedProvider.notifier).prepend(Post.fromJson(r));
      if (mounted) { toast(context, _schedule == null ? 'Posted' : 'Scheduled'); context.go('/'); }
    } catch (e) { if (mounted) toast(context, e.toString()); } finally { if (mounted) setState(() => _posting = false); }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: now);
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (t == null) return;
    final when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (when.isBefore(now)) { if (mounted) toast(context, 'Pick a time in the future'); return; }
    setState(() => _schedule = when);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      appBar: AppBar(title: const Text('New post'), leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => context.go('/')), actions: [Padding(padding: const EdgeInsets.only(right: Sp.s3), child: FilledButton(onPressed: _posting ? null : _post, style: FilledButton.styleFrom(minimumSize: const Size(72, 40)), child: Text(_schedule == null ? 'Post' : 'Schedule')))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.s4),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _body, autofocus: true, minLines: 4, maxLines: 10, maxLength: 5000, decoration: const InputDecoration(hintText: "What's on your mind? Use #hashtags and @mentions")),
          if (_poll) ...[
            const SizedBox(height: Sp.s3),
            for (var i = 0; i < _opts.length; i++) Padding(padding: const EdgeInsets.only(bottom: Sp.s2), child: TextField(controller: _opts[i], maxLength: 120, buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null, decoration: InputDecoration(labelText: 'Option ${i + 1}'))),
            if (_opts.length < 6) TextButton.icon(onPressed: () => setState(() => _opts.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('Add option')),
          ],
          const SizedBox(height: Sp.s3),
          Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [
            FilterChip(label: const Text('Poll'), avatar: const Icon(Icons.poll_outlined, size: 18), selected: _poll, onSelected: (v) => setState(() => _poll = v)),
            ActionChip(avatar: const Icon(Icons.schedule, size: 18), label: Text(_schedule == null ? 'Schedule' : 'At ${_schedule!.day}/${_schedule!.month} ${_schedule!.hour.toString().padLeft(2, '0')}:${_schedule!.minute.toString().padLeft(2, '0')}'), onPressed: _pickSchedule),
            if (_schedule != null) ActionChip(label: const Text('Clear schedule'), onPressed: () => setState(() => _schedule = null)),
          ]),
          const SizedBox(height: Sp.s4),
          Text('Who can see this', style: TextStyle(color: t.inkMuted, fontSize: 12)),
          const SizedBox(height: Sp.s2),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'public', label: Text('Public'), icon: Icon(Icons.public)), ButtonSegment(value: 'followers', label: Text('Followers'), icon: Icon(Icons.people_outline)), ButtonSegment(value: 'private', label: Text('Only me'), icon: Icon(Icons.lock_outline))],
            selected: {_visibility}, onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
        ]))),
      ),
    );
  }
}
