import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';

final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) async {
  // Refresh the list whenever a message arrives so previews and unread counts stay live.
  final sub = ref.watch(socketProvider).messages.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  final r = await ref.watch(apiProvider).get('/conversations');
  return (r['data'] as List).map((c) => Conversation.fromJson(c)).toList();
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final list = ref.watch(conversationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chats'), actions: [IconButton(tooltip: 'New chat', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/search?pick=1'))]),
      body: list.when(
        loading: () => ListView(children: List.generate(6, (_) => const ListTile(leading: Skeleton(height: 44, width: 44, radius: 22), title: Skeleton(height: 14), subtitle: Skeleton(height: 12)))),
        error: (e, _) => ErrorRetry(message: e.toString(), onRetry: () => ref.invalidate(conversationsProvider)),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'No conversations yet', message: 'Find a friend and say hello.', action: FilledButton(onPressed: () => context.push('/search?pick=1'), child: const Text('Start a chat')))
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(conversationsProvider.future),
                child: ListView.separated(
                  itemCount: items.length, separatorBuilder: (_, _) => const Divider(indent: 72),
                  itemBuilder: (c, i) {
                    final v = items[i];
                    return ListTile(
                      leading: JAvatar(v.title.isEmpty ? '?' : v.title.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join(), size: 44),
                      title: Text(v.title, style: TextStyle(fontWeight: v.unread > 0 ? FontWeight.w800 : FontWeight.w600)),
                      subtitle: Text(v.lastBody ?? 'No messages yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: v.unread > 0 ? t.ink : t.inkMuted)),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (v.lastAt != null) Text(timeAgo(v.lastAt!), style: TextStyle(fontSize: 12, color: t.inkMuted)),
                        if (v.unread > 0) Semantics(label: '${v.unread} unread', child: Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(Rd.pill)), child: Text('${v.unread}', style: TextStyle(color: t.onBrand, fontSize: 12, fontWeight: FontWeight.w700)))),
                      ]),
                      onTap: () => context.push('/chat/${v.id}?title=${Uri.encodeComponent(v.title)}'),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class ChatThreadScreen extends ConsumerStatefulWidget { const ChatThreadScreen({super.key, required this.id, required this.title}); final int id; final String title; @override ConsumerState<ChatThreadScreen> createState() => _ThreadState(); }
class _ThreadState extends ConsumerState<ChatThreadScreen> {
  final _ctl = TextEditingController(); final _scroll = ScrollController();
  List<Message> _msgs = []; bool _loading = true; String? _error; StreamSubscription? _sub, _typingSub; bool _peerTyping = false; Timer? _typingTimer; DateTime _lastTypingSent = DateTime(0);
  int get _me => ref.read(authProvider).user!.id;

  @override
  void initState() {
    super.initState();
    _load();
    final sock = ref.read(socketProvider);
    _sub = sock.messages.listen((m) {
      if (m['conversation_id'] != widget.id) return;
      final msg = Message.fromJson(m);
      if (_msgs.any((x) => x.id == msg.id || (x.clientId.isNotEmpty && x.clientId == msg.clientId))) { _replaceByClient(msg); return; }
      setState(() => _msgs = [msg, ..._msgs]);
      if (msg.senderId != _me) sock.markRead(widget.id, msg.id);
    });
    _typingSub = sock.typing.listen((t) {
      if (t['conversation_id'] != widget.id || t['user_id'] == _me) return;
      setState(() => _peerTyping = true); _typingTimer?.cancel(); _typingTimer = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _peerTyping = false); });
    });
  }
  @override
  void dispose() { _sub?.cancel(); _typingSub?.cancel(); _typingTimer?.cancel(); _ctl.dispose(); _scroll.dispose(); super.dispose(); }

  void _replaceByClient(Message m) => setState(() => _msgs = [for (final x in _msgs) (x.clientId == m.clientId && x.pending) ? m : x]);

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).get('/conversations/${widget.id}/messages', q: {'limit': 50});
      final list = (r['data'] as List).map((m) => Message.fromJson(m)).toList(); // newest first
      if (mounted) setState(() { _msgs = list; _loading = false; });
      if (list.isNotEmpty) { ref.read(socketProvider).markRead(widget.id, list.first.id); ref.read(apiProvider).post('/conversations/${widget.id}/read', body: {'up_to_id': list.first.id}).catchError((_) {}); }
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  String _uuid() { final r = DateTime.now().microsecondsSinceEpoch; final h = (r * 2654435761).toRadixString(16).padLeft(32, '0'); final s = (h + h).substring(0, 32); return '${s.substring(0, 8)}-${s.substring(8, 12)}-4${s.substring(13, 16)}-a${s.substring(17, 20)}-${s.substring(20, 32)}'; }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    final cid = _uuid(); _ctl.clear();
    final temp = Message(id: -DateTime.now().millisecondsSinceEpoch, senderId: _me, clientId: cid, body: text, createdAt: DateTime.now(), conversationId: widget.id, pending: true);
    setState(() => _msgs = [temp, ..._msgs]);
    try {
      final sent = await ref.read(socketProvider).sendMessage(widget.id, cid, text);
      _replaceByClient(Message.fromJson(sent));
    } catch (_) {
      // Socket down: fall back to REST (same client_id, so a retry can never duplicate).
      try { final r = await ref.read(apiProvider).post('/conversations/${widget.id}/messages', body: {'client_id': cid, 'body': text}); _replaceByClient(Message.fromJson(r)); }
      catch (e) { if (mounted) { setState(() => _msgs = _msgs.where((m) => m.clientId != cid).toList()); toast(context, 'Message not sent: $e'); _ctl.text = text; } }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), if (_peerTyping) Text('typing…', style: TextStyle(fontSize: 12, color: t.brand))])),
      body: Column(children: [
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? ErrorRetry(message: _error!, onRetry: () { setState(() { _loading = true; _error = null; }); _load(); }) : _msgs.isEmpty ? const EmptyState(icon: Icons.waving_hand_outlined, title: 'Say hello') : ListView.builder(
          controller: _scroll, reverse: true, padding: const EdgeInsets.all(Sp.s3), itemCount: _msgs.length,
          itemBuilder: (c, i) => _Bubble(_msgs[i], mine: _msgs[i].senderId == _me),
        )),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.all(Sp.s2),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctl, minLines: 1, maxLines: 5, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Message', isDense: true),
              onChanged: (_) { if (DateTime.now().difference(_lastTypingSent) > const Duration(seconds: 2)) { _lastTypingSent = DateTime.now(); ref.read(socketProvider).typingIn(widget.id); } })),
            const SizedBox(width: Sp.s2),
            IconButton.filled(tooltip: 'Send', onPressed: _send, icon: const Icon(Icons.send_rounded)),
          ]),
        )),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m, {required this.mine});
  final Message m; final bool mine;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final r = BorderRadius.only(topLeft: const Radius.circular(Rd.md), topRight: const Radius.circular(Rd.md), bottomLeft: Radius.circular(mine ? Rd.md : 4), bottomRight: Radius.circular(mine ? 4 : Rd.md));
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3), padding: const EdgeInsets.all(Sp.s3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(color: mine ? t.brand : t.surfaceRaised, borderRadius: r),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(m.body, style: TextStyle(color: mine ? t.onBrand : t.ink, fontSize: 15)),
          const SizedBox(height: 2),
          Text(m.pending ? 'Sending…' : '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 11, color: (mine ? t.onBrand : t.inkMuted).withValues(alpha: 0.85))),
        ]),
      ),
    );
  }
}
