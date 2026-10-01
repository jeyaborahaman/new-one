import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import 'feed_state.dart';
import '../../core/l10n.dart';
import '../profile/safety.dart';

void showCommentsSheet(BuildContext context, Post post) => showModalBottomSheet(
      context: context, isScrollControlled: true, showDragHandle: true, useSafeArea: true,
      builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: CommentsSheet(post: post)),
    );

class CommentsSheet extends ConsumerStatefulWidget { const CommentsSheet({super.key, required this.post}); final Post post; @override ConsumerState<CommentsSheet> createState() => _State(); }
class _State extends ConsumerState<CommentsSheet> {
  final _ctl = TextEditingController();
  List<Comment> _items = []; bool _loading = true; String? _error; Comment? _replyTo; bool _sending = false;
  final Map<int, List<Comment>> _replies = {};

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).get('/posts/${widget.post.id}/comments', q: {'limit': 50});
      if (mounted) setState(() { _items = (r['data'] as List).map((c) => Comment.fromJson(c)).toList(); _loading = false; });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _loadReplies(Comment c) async {
    final r = await ref.read(apiProvider).get('/posts/${widget.post.id}/comments', q: {'parent_id': c.id, 'limit': 50});
    if (mounted) setState(() => _replies[c.id] = (r['data'] as List).map((x) => Comment.fromJson(x)).toList());
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final r = await ref.read(apiProvider).post('/posts/${widget.post.id}/comments', body: {'body': text, if (_replyTo != null) 'parent_id': _replyTo!.id});
      final c = Comment.fromJson(r);
      ref.read(feedProvider.notifier).bumpComments(widget.post.id);
      _ctl.clear();
      setState(() { if (_replyTo == null) { _items = [..._items, c]; } else { _replies[_replyTo!.id] = [...(_replies[_replyTo!.id] ?? []), c]; } _replyTo = null; });
    } catch (e) { if (mounted) toast(context, e.toString()); } finally { if (mounted) setState(() => _sending = false); }
  }

  Widget _tile(Comment c, {double indent = 0}) {
    final t = context.tk; final l = context.l10n;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(Sp.s4 + indent, Sp.s2, Sp.s4, Sp.s2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(c.authorName.isEmpty ? l.someone : c.authorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), const SizedBox(width: 8), Text(context.timeAgo(c.createdAt), style: TextStyle(fontSize: 12, color: t.inkMuted)),
          if (c.authorId != ref.read(authProvider).user?.id) ...[const Spacer(), ReportMenuButton(onReport: () => reportComment(context, commentId: c.id))], // others' comments only
        ]),
        SizedBox(width: double.infinity, child: Text(c.body, textDirection: contentDirection(c.body))),
        Row(children: [
          TextButton(onPressed: () => setState(() => _replyTo = c), style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: t.inkMuted), child: Text(l.reply)),
          if (c.depth == 0 && !_replies.containsKey(c.id)) TextButton(onPressed: () => _loadReplies(c), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(l.viewReplies)),
        ]),
        for (final r in _replies[c.id] ?? <Comment>[]) _tile(r, indent: Sp.s6),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk; final l = context.l10n;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.commentsTitle, style: Theme.of(context).textTheme.titleLarge),
        Flexible(child: _loading ? const Padding(padding: EdgeInsets.all(Sp.s6), child: CircularProgressIndicator()) : _error != null ? ErrorRetry(message: _error!, onRetry: () { setState(() { _loading = true; _error = null; }); _load(); }) : _items.isEmpty ? Padding(padding: const EdgeInsets.all(Sp.s6), child: Text(l.noComments)) : ListView(shrinkWrap: true, children: [for (final c in _items) _tile(c)])),
        const Divider(),
        if (_replyTo != null) Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.s4), child: Row(children: [Expanded(child: Text(l.replyingTo(_replyTo!.authorName.isEmpty ? l.someone : _replyTo!.authorName), style: TextStyle(fontSize: 12, color: t.inkMuted))), IconButton(tooltip: l.cancelReply, icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyTo = null))])),
        Padding(
          padding: const EdgeInsets.all(Sp.s3),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctl, decoration: InputDecoration(hintText: l.addComment, isDense: true), onSubmitted: (_) => _send(), maxLength: 2000, buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null)),
            const SizedBox(width: Sp.s2),
            IconButton.filled(tooltip: l.sendComment, onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded)),
          ]),
        ),
      ]),
    );
  }
}
