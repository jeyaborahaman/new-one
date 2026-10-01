import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../feed/post_card.dart';
import '../../core/l10n.dart';

/// Search for people and posts. With [pickUser] it is the "new chat" picker.
class SearchScreen extends ConsumerStatefulWidget { const SearchScreen({super.key, this.pickUser = false}); final bool pickUser; @override ConsumerState<SearchScreen> createState() => _State(); }
class _State extends ConsumerState<SearchScreen> {
  final _ctl = TextEditingController(); Timer? _debounce;
  List<Map<String, dynamic>> _users = []; List<Post> _posts = []; List<dynamic> _tags = []; bool _loading = false; String? _error; String _q = '';
  List<Map<String, dynamic>> _suggested = [];

  @override
  void initState() { super.initState(); ref.read(apiProvider).get('/recommendations/friends').then((r) { if (mounted) setState(() => _suggested = (r['data'] as List).cast<Map<String, dynamic>>()); }).catchError((_) {}); }
  @override
  void dispose() { _debounce?.cancel(); _ctl.dispose(); super.dispose(); }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v.trim()));
  }
  Future<void> _search(String q) async {
    if (q.isEmpty) { setState(() { _q = ''; _users = []; _posts = []; _tags = []; _error = null; }); return; }
    setState(() { _loading = true; _q = q; });
    try {
      final r = await ref.read(apiProvider).get('/search', q: {'q': q, 'type': widget.pickUser ? 'users' : 'all'});
      if (!mounted || q != _q) return; // ignore a slow answer for an outdated query
      setState(() { _users = (r['users'] as List? ?? []).cast<Map<String, dynamic>>(); _posts = (r['posts'] as List? ?? []).map((p) => Post.fromJson(p)).toList(); _tags = r['hashtags'] as List? ?? []; _loading = false; _error = null; });
    } catch (e) { if (mounted) setState(() { _loading = false; _error = e.toString(); }); }
  }

  Future<void> _open(Map<String, dynamic> u) async {
    if (widget.pickUser) {
      try { final c = await ref.read(apiProvider).post('/conversations', body: {'type': 'direct', 'user_id': u['id']}); if (mounted) context.pushReplacement('/chat/${c['id']}?title=${Uri.encodeComponent(u['display_name'])}&direct=1'); } catch (e) { if (mounted) toast(context, e.toString()); }
    } else { context.push('/user/${u['id']}'); }
  }

  Widget _userTile(Map<String, dynamic> u, {String? sub}) => ListTile(
        leading: JAvatar((u['display_name'] as String).trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()),
        title: Row(children: [Flexible(child: Text(u['display_name'], overflow: TextOverflow.ellipsis)), if (u['is_verified'] == true) Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.verified, size: 16, color: context.tk.brand, semanticLabel: context.l10n.verified))]),
        subtitle: Text('${isolate('@${u['username']}')}${sub != null ? ' · $sub' : ''}'), onTap: () => _open(u),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
        appBar: AppBar(title: TextField(controller: _ctl, autofocus: true, onChanged: _onChanged, decoration: InputDecoration(hintText: widget.pickUser ? l.findSomeone : l.searchHint, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, fillColor: Colors.transparent))),
        body: _error != null ? ErrorRetry(message: _error!, onRetry: () => _search(_q))
            : _q.isEmpty ? ListView(children: [
                if (_suggested.isNotEmpty) Padding(padding: const EdgeInsets.all(Sp.s4), child: Text(l.peopleYouMayKnow, style: const TextStyle(fontWeight: FontWeight.w700))),
                for (final u in _suggested) _userTile(u, sub: (u['mutual_follows'] ?? 0) > 0 ? l.mutualCount(u['mutual_follows']) : null),
              ])
            : _loading && _users.isEmpty && _posts.isEmpty ? const Center(child: CircularProgressIndicator())
            : (_users.isEmpty && _posts.isEmpty && _tags.isEmpty) ? EmptyState(icon: Icons.search_off_rounded, title: l.noResults, message: l.nothingFound(_q))
            : ListView(children: [
                for (final u in _users) _userTile(u, sub: l.followersCount(u['followers_count'] ?? 0)),
                for (final h in _tags) ListTile(leading: const Icon(Icons.tag), title: Text(isolate('#${h['tag']}')), subtitle: Text(l.hashtagPosts(h['uses']))),
                if (_posts.isNotEmpty) Padding(padding: const EdgeInsets.all(Sp.s4), child: Text(l.postsHeader, style: const TextStyle(fontWeight: FontWeight.w700))),
                for (final p in _posts) Padding(padding: const EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, Sp.s3), child: PostCard(p)),
              ]),
      );
  }
}
