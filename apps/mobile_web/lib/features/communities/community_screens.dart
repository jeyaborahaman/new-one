import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../feed/feed_state.dart';
import '../feed/post_card.dart';

/// "Private · 12 members" for groups, "Business · 1.2K followers" for pages.
String communitySubtitle(BuildContext context, Community c) {
  final l = context.l10n;
  return c.isPage
      ? '${l.pageType(c.pageType ?? 'community')} · ${l.followersCount(c.membersCount)}'
      : '${c.isPrivate ? l.groupPrivate : l.groupPublic} · ${l.memberCount(c.membersCount)}';
}

class _CommunityTile extends StatelessWidget {
  const _CommunityTile(this.c, {this.onReturn});
  final Community c;
  /// Called after coming back from the details (membership may have changed there).
  final VoidCallback? onReturn;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: JAvatar(c.initials, size: 44),
        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(c.isPending ? '${communitySubtitle(context, c)} · ${context.l10n.requested}' : communitySubtitle(context, c), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: c.isPrivate ? Icon(Icons.lock_outline, size: 18, color: context.tk.inkMuted) : const Icon(Icons.chevron_right),
        onTap: () async { await context.push('/community/${c.id}'); onReturn?.call(); },
      );
}

/// Groups or pages: yours first, then popular ones; typing searches by name.
class CommunityListScreen extends ConsumerStatefulWidget {
  const CommunityListScreen({super.key, required this.kind});
  final String kind; // group | page
  @override
  ConsumerState<CommunityListScreen> createState() => _ListState();
}
class _ListState extends ConsumerState<CommunityListScreen> {
  final _q = TextEditingController(); Timer? _debounce;
  List<Community>? _mine, _discover, _results; String? _error; String _query = '';
  bool get _page => widget.kind == 'page';

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _debounce?.cancel(); _q.dispose(); super.dispose(); }

  List<Community> _parse(dynamic r) => ((r as Map)['data'] as List).map((j) => Community.fromJson(j as Map<String, dynamic>)).toList();
  Future<void> _load() async {
    try {
      final api = ref.read(apiProvider);
      final mine = _parse(await api.get('/communities/mine', q: {'kind': widget.kind}));
      final all = _parse(await api.get('/communities', q: {'kind': widget.kind}));
      final ids = mine.map((c) => c.id).toSet();
      if (mounted) setState(() { _mine = mine; _discover = all.where((c) => !ids.contains(c.id)).toList(); _error = null; });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }
  /// After visiting a group/page: reload both lists and, when searching, the results.
  void _refresh() { _load(); if (_query.isNotEmpty) _onSearch(_query); }
  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = v.trim();
      setState(() { _query = q; if (q.isEmpty) _results = null; });
      if (q.isEmpty) return;
      try {
        final r = _parse(await ref.read(apiProvider).get('/communities', q: {'q': q, 'kind': widget.kind}));
        if (mounted && q == _query) setState(() => _results = r); // ignore answers for outdated queries
      } catch (e) { if (mounted) toast(context, e.toString()); }
    });
  }

  Future<void> _create() async {
    final id = await showCreateCommunity(context, kind: widget.kind);
    if (id == null || !mounted) return;
    await context.push('/community/$id');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n; final t = context.tk;
    Widget section(String title) => Padding(padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s4, Sp.s4, Sp.s2), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)));
    final mine = _mine, discover = _discover, results = _results;
    return Scaffold(
      appBar: AppBar(title: Text(_page ? l.pages : l.groups), actions: [IconButton(tooltip: _page ? l.createPage : l.createGroup, icon: const Icon(Icons.add), onPressed: _create)]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s2, Sp.s4, 0), child: TextField(controller: _q, onChanged: _onSearch, textInputAction: TextInputAction.search,
            decoration: InputDecoration(hintText: _page ? l.searchPages : l.searchGroups, prefixIcon: const Icon(Icons.search_rounded), isDense: true))),
        Expanded(child: _error != null ? ErrorRetry(message: _error!, onRetry: _load)
            : _query.isNotEmpty ? (results == null ? const Center(child: CircularProgressIndicator())
                : results.isEmpty ? EmptyState(icon: Icons.search_off_rounded, title: _page ? l.noPagesFound : l.noGroupsFound, message: l.nothingFound(_query))
                : ListView(children: [for (final c in results) _CommunityTile(c, onReturn: _refresh)]))
            : mine == null || discover == null ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(onRefresh: _load, child: ListView(children: [
                section(_page ? l.yourPages : l.yourGroups),
                if (mine.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.s4), child: Text(_page ? l.noYourPages : l.noYourGroups, style: TextStyle(color: t.inkMuted))),
                for (final c in mine) _CommunityTile(c, onReturn: _refresh),
                if (discover.isNotEmpty) ...[section(l.discover), for (final c in discover) _CommunityTile(c, onReturn: _refresh)],
              ]))),
      ]),
    );
  }
}

/// Create a group (name, description, public/private) or a page (name, description, type). Returns the new id.
Future<int?> showCreateCommunity(BuildContext context, {required String kind}) => showModalBottomSheet<int>(
      context: context, useRootNavigator: true, isScrollControlled: true, showDragHandle: true,
      builder: (_) => _CreateSheet(kind: kind),
    );

class _CreateSheet extends ConsumerStatefulWidget { const _CreateSheet({required this.kind}); final String kind; @override ConsumerState<_CreateSheet> createState() => _CreateState(); }
class _CreateState extends ConsumerState<_CreateSheet> {
  final _name = TextEditingController(), _desc = TextEditingController();
  String _privacy = 'public'; String? _pageType; bool _busy = false; String? _error; bool _touched = false;
  bool get _page => widget.kind == 'page';
  @override
  void dispose() { _name.dispose(); _desc.dispose(); super.dispose(); }

  bool get _nameOk => _name.text.trim().length >= 2;
  bool get _ready => _nameOk && (!_page || _pageType != null);

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      final d = _desc.text.trim();
      final r = await ref.read(apiProvider).post('/communities', body: {
        'kind': widget.kind, 'name': _name.text.trim(), if (d.isNotEmpty) 'description': d,
        if (_page) 'page_type': _pageType else 'privacy': _privacy,
      });
      if (mounted) Navigator.pop(context, (r as Map)['id'] as int);
    } catch (e) { if (mounted) setState(() { _busy = false; _error = e.toString(); }); }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n; final t = context.tk;
    return Padding(
      padding: EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, MediaQuery.of(context).viewInsets.bottom + Sp.s4),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_page ? l.createPage : l.createGroup, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Sp.s3),
        TextField(controller: _name, maxLength: 100, enabled: !_busy, onChanged: (_) => setState(() => _touched = true),
            decoration: InputDecoration(labelText: _page ? l.pageName : l.groupName, errorText: _touched && !_nameOk ? l.nameTooShort : null)),
        const SizedBox(height: Sp.s2),
        TextField(controller: _desc, maxLength: 2000, minLines: 1, maxLines: 4, enabled: !_busy, decoration: InputDecoration(labelText: l.descriptionOptional)),
        const SizedBox(height: Sp.s2),
        if (_page) ...[
          Text(l.pageTypeLabel, style: TextStyle(color: t.inkMuted, fontSize: 12)),
          const SizedBox(height: Sp.s2),
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            segments: [for (final p in const ['business', 'community', 'creator']) ButtonSegment(value: p, label: Text(l.pageType(p)))],
            selected: {?_pageType}, onSelectionChanged: _busy ? null : (s) => setState(() => _pageType = s.isEmpty ? null : s.first),
          ),
        ] else ...[
          SegmentedButton<String>(
            segments: [ButtonSegment(value: 'public', label: Text(l.groupPublic), icon: const Icon(Icons.public)), ButtonSegment(value: 'private', label: Text(l.groupPrivate), icon: const Icon(Icons.lock_outline))],
            selected: {_privacy}, onSelectionChanged: _busy ? null : (s) => setState(() => _privacy = s.first),
          ),
          const SizedBox(height: Sp.s2),
          Text(_privacy == 'public' ? l.groupPublicHint : l.groupPrivateHint, style: TextStyle(color: t.inkMuted, fontSize: 12)),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text(_error!, style: TextStyle(color: t.danger))),
        const SizedBox(height: Sp.s4),
        FilledButton(onPressed: _ready && !_busy ? _submit : null, child: Text(l.create)),
      ])),
    );
  }
}

/// A group or page: header with join/follow, members, and its posts (the home feed's PostCard).
class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<CommunityDetailScreen> createState() => _DetailState();
}
class _DetailState extends ConsumerState<CommunityDetailScreen> {
  final _scroll = ScrollController();
  Community? _c; String? _error; bool _busy = false;
  List<Post> _posts = []; int? _cursor; bool _postsLoaded = false, _loadingMore = false, _locked = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() { if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _more(); });
  }
  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final c = Community.fromJson(await ref.read(apiProvider).get('/communities/${widget.id}') as Map<String, dynamic>);
      if (!mounted) return;
      setState(() { _c = c; _error = null; _locked = c.isPrivate && !c.isMember; });
      if (_locked) { setState(() { _posts = []; _postsLoaded = true; }); return; } // never ask for a private feed we cannot see
      final r = await ref.read(apiProvider).get('/communities/${widget.id}/feed', q: {'limit': 20}) as Map;
      if (mounted) setState(() { _posts = (r['data'] as List).map((p) => Post.fromJson(p)).toList(); _cursor = r['next_cursor']; _postsLoaded = true; });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }
  Future<void> _more() async {
    if (_cursor == null || _loadingMore) return;
    _loadingMore = true;
    try {
      final r = await ref.read(apiProvider).get('/communities/${widget.id}/feed', q: {'limit': 20, 'cursor': _cursor}) as Map;
      if (mounted) setState(() { _posts = [..._posts, ...(r['data'] as List).map((p) => Post.fromJson(p))]; _cursor = r['next_cursor']; });
    } catch (_) {} finally { _loadingMore = false; }
  }

  void _replace(Post p) => setState(() => _posts = [for (final x in _posts) x.id == p.id ? p : x]);
  void _react(Post p, String? kind) {
    _replace(withReaction(p, kind, had: p.myReaction != null));
    sendReaction(ref.read(apiProvider), p, kind).catchError((_) { if (mounted) _replace(p); });
  }
  Future<void> _vote(Post p, int optionId) async => _replace(await sendVote(ref.read(apiProvider), p, optionId));

  Future<void> _membership(bool join) async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      if (join) {
        final r = await api.post('/communities/${widget.id}/join') as Map;
        if (r['status'] == 'pending' && mounted) toast(context, context.l10n.requestSent);
      } else {
        await api.post('/communities/${widget.id}/leave');
      }
      await _load();
    } catch (e) { if (mounted) toast(context, e.toString()); } finally { if (mounted) setState(() => _busy = false); }
  }

  Widget _action(Community c) {
    final l = context.l10n;
    if (c.isOwner) return OutlinedButton(onPressed: null, child: Text(l.roleName('owner')));
    if (c.isPage) {
      return c.isMember
          ? OutlinedButton(onPressed: _busy ? null : () => _membership(false), child: Text(l.unfollow))
          : FilledButton(onPressed: _busy ? null : () => _membership(true), child: Text(l.follow));
    }
    if (c.isPending) return OutlinedButton(onPressed: null, child: Text(l.requested));
    return c.isMember
        ? OutlinedButton(onPressed: _busy ? null : () => _membership(false), child: Text(l.leave))
        : FilledButton(onPressed: _busy || c.myStatus == 'banned' ? null : () => _membership(true), child: Text(l.join));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n; final t = context.tk; final c = _c;
    return Scaffold(
      appBar: AppBar(title: Text(c?.name ?? '')),
      body: _error != null ? ErrorRetry(message: _error!, onRetry: _load) : c == null ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: ListView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(Sp.s4), children: [
          Card(child: Padding(padding: const EdgeInsets.all(Sp.s4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              JAvatar(c.initials, size: 56),
              const SizedBox(width: Sp.s3),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: Theme.of(context).textTheme.titleLarge),
                Text(communitySubtitle(context, c), style: TextStyle(color: t.inkMuted)),
              ])),
            ]),
            if ((c.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: Sp.s3), child: Text(c.description!, textDirection: contentDirection(c.description!))),
            const SizedBox(height: Sp.s4),
            Row(children: [
              Expanded(child: _action(c)),
              const SizedBox(width: Sp.s2),
              Expanded(child: OutlinedButton.icon(onPressed: _locked ? null : () => showCommunityMembers(context, c), icon: const Icon(Icons.people_outline), label: Text(c.isPage ? l.statFollowers : l.members))),
            ]),
          ]))),
          const SizedBox(height: Sp.s3),
          if (_locked) EmptyState(icon: Icons.lock_outline, title: l.privateGroupTitle, message: l.privateGroupMessage)
          else if (!_postsLoaded) const Padding(padding: EdgeInsets.all(Sp.s6), child: Center(child: CircularProgressIndicator()))
          else if (_posts.isEmpty) EmptyState(icon: Icons.dynamic_feed_rounded, title: l.noCommunityPosts)
          else for (final p in _posts) Padding(padding: const EdgeInsets.only(bottom: Sp.s3), child: PostCard(p, onReact: _react, onVote: _vote)),
        ]))),
      ),
    );
  }
}

/// Members (or followers) with their role. Staff also see join requests and can approve or decline them.
Future<void> showCommunityMembers(BuildContext context, Community c) => showModalBottomSheet(
      context: context, useRootNavigator: true, isScrollControlled: true, showDragHandle: true,
      builder: (_) => _MembersSheet(c: c),
    );

class _MembersSheet extends ConsumerStatefulWidget { const _MembersSheet({required this.c}); final Community c; @override ConsumerState<_MembersSheet> createState() => _MembersState(); }
class _MembersState extends ConsumerState<_MembersSheet> {
  List<Map<String, dynamic>>? _rows; String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await ref.read(apiProvider).get('/communities/${widget.c.id}/members') as Map; if (mounted) setState(() { _rows = (r['data'] as List).cast<Map<String, dynamic>>(); _error = null; }); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }
  Future<void> _decide(Map<String, dynamic> m, String action) async {
    try { await ref.read(apiProvider).patch('/communities/${widget.c.id}/members/${m['id']}', body: {'action': action}); await _load(); }
    catch (e) { if (mounted) toast(context, e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n; final t = context.tk; final rows = _rows;
    final visible = rows?.where((m) => m['status'] != 'banned').toList();
    return SafeArea(child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.c.isPage ? l.statFollowers : l.members, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Sp.s2),
        Flexible(child: _error != null ? ErrorRetry(message: _error!, onRetry: _load)
            : visible == null ? const Padding(padding: EdgeInsets.all(Sp.s6), child: CircularProgressIndicator())
            : ListView(shrinkWrap: true, children: [for (final m in visible) ListTile(
                leading: JAvatar('${m['display_name']}'.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join()),
                title: Text('${m['display_name']}'),
                subtitle: Text(m['status'] == 'pending' ? l.wantsToJoin : '${isolate('@${m['username']}')} · ${l.roleName('${m['role']}')}', style: TextStyle(color: m['status'] == 'pending' ? t.brand : t.inkMuted)),
                trailing: m['status'] == 'pending' && widget.c.isStaff ? Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(onPressed: () => _decide(m, 'reject'), child: Text(l.declineRequest)),
                  FilledButton(onPressed: () => _decide(m, 'approve'), child: Text(l.approve)),
                ]) : null,
                onTap: () { Navigator.pop(context); context.push('/user/${m['id']}'); },
              )])),
        const SizedBox(height: Sp.s4),
      ]),
    ));
  }
}
