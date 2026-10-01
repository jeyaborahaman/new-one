import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/tokens.dart';
import 'admin_session.dart';
import 'reports.dart';
import 'widgets.dart';

/// Member search for staff (name, @username, id; e-mail for admins), including suspended and banned accounts.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}
class _UsersScreenState extends State<UsersScreen> {
  final _q = TextEditingController();
  String _query = ''; String? _status;
  Timer? _debounce;
  @override
  void dispose() { _debounce?.cancel(); _q.dispose(); super.dispose(); }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () { if (mounted) setState(() => _query = v.trim()); });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s4, Sp.s4, Sp.s2), child: Row(children: [
      Expanded(child: TextField(
        controller: _q, onChanged: _changed, onSubmitted: (v) { _debounce?.cancel(); setState(() => _query = v.trim()); },
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name, @username, e-mail or user ID'),
      )),
      const SizedBox(width: Sp.s3),
      DropdownButton<String?>(
        value: _status, underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: null, child: Text('Any status')), DropdownMenuItem(value: 'active', child: Text('Active')),
          DropdownMenuItem(value: 'suspended', child: Text('Suspended')), DropdownMenuItem(value: 'banned', child: Text('Banned')),
          DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
        ],
        onChanged: (v) => setState(() => _status = v),
      ),
    ])),
    const Divider(height: 1),
    Expanded(child: PagedList(
      key: ValueKey('$_query/$_status'),
      path: '/admin/users', query: {if (_query.isNotEmpty) 'q': _query, 'status': ?_status},
      emptyText: 'No members match.',
      itemBuilder: (c, u, reload) => ListTile(
        onTap: () async { if (await openUser(c, u['id'] as int)) reload(); },
        leading: CircleAvatar(backgroundColor: c.tk.brandSoft, child: Text(personName(u).isEmpty ? '?' : personName(u)[0].toUpperCase(), style: TextStyle(color: c.tk.ink))),
        title: Text('${personName(u)}  ${personHandle(u)}', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(['#${u['id']}', ?u['email'] as String?, 'joined ${fmtTime(u['created_at'])}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Wrap(spacing: Sp.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if ((u['open_reports'] ?? 0) > 0) Pill(u['open_reports'] == 1 ? '1 open report' : '${u['open_reports']} open reports', color: c.tk.accent),
          if (u['role'] != 'user') Pill('${u['role']}', color: c.tk.brand),
          accountStatusPill(c, u['status']),
        ]),
      ),
    )),
  ]);
}

/// Opens a member's moderation page; true when their account was changed there.
Future<bool> openUser(BuildContext context, int id) async =>
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => UserDetailScreen(id: id))) == true;

/// A member: profile, account status and actions (admins), reports against them and their content, and staff history.
class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}
class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  Json? _u; String? _error; bool _busy = false, _changed = false;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final u = await ref.read(adminApiProvider).get('/admin/users/${widget.id}'); if (mounted) setState(() { _u = (u as Map).cast<String, dynamic>(); _error = null; }); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }

  static const _actions = {
    'suspend': ('Suspend account', 'They are signed out everywhere and cannot sign in until reinstated.', 'Account suspended'),
    'ban': ('Ban account', 'Permanent. They are signed out everywhere and cannot sign in.', 'Account banned'),
    'reinstate': ('Reinstate account', 'They can sign in and use Jeyabo again.', 'Account reinstated'),
  };

  Future<void> _act(String action) async {
    final (title, message, done) = _actions[action]!;
    final reason = await confirmWithNote(context, title: title, message: message, action: title, danger: action != 'reinstate', noteLabel: 'Reason (kept in the audit log)');
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminApiProvider).post('/admin/users/${widget.id}/$action', body: {if (reason.isNotEmpty) 'reason': reason});
      _changed = true;
      if (mounted) notice(context, done);
      await _load();
    } catch (e) { if (mounted) notice(context, e.toString()); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = _u;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) Navigator.pop(context, _changed); },
      child: Scaffold(
        appBar: AppBar(title: Text(u == null ? 'Member #${widget.id}' : '${personName(u)}  ${personHandle(u)}')),
        body: _error != null && u == null ? ErrorBox(_error!, onRetry: _load)
            : u == null ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(Sp.s4), children: [
                _profile(u), const SizedBox(height: Sp.s4),
                Section(title: 'Reports against this member and their content (${(u['reports'] as List).length})', child: (u['reports'] as List).isEmpty
                    ? Text('None.', style: TextStyle(color: context.tk.inkMuted))
                    : Column(children: [for (final r in (u['reports'] as List).cast<Json>()) ReportRow(r, onTap: () async { if (await openReport(context, r['id'] as int)) { _changed = true; _load(); } })])),
                const SizedBox(height: Sp.s4),
                Section(title: 'Moderation history', child: (u['history'] as List).isEmpty
                    ? Text('No staff actions on this account.', style: TextStyle(color: context.tk.inkMuted))
                    : AuditTimeline((u['history'] as List).cast<Json>())),
              ]),
      ),
    );
  }

  Widget _profile(Json u) {
    final session = ref.watch(adminAuthProvider).session;
    final stats = u['stats'] as Map? ?? const {};
    final canAct = session?.canActOnUsers == true && u['role'] == 'user' && u['status'] != 'deleted';
    return Section(title: 'Account', trailing: accountStatusPill(context, u['status']), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Facts([
        ('User ID', SelectableText('#${u['id']}')),
        ('Username', SelectableText(personHandle(u))),
        if (u['email'] != null) ('E-mail', SelectableText('${u['email']}')),
        if (u['phone'] != null) ('Phone', SelectableText('${u['phone']}')),
        ('Role', Text('${u['role']}')),
        ('Joined', Text(fmtTime(u['created_at']))),
        ('Posts', Text('${stats['posts'] ?? 0} (${stats['removed_posts'] ?? 0} removed)')),
        ('Reports', Text('${stats['reports'] ?? 0} received · ${stats['upheld_reports'] ?? 0} upheld')),
        if ((u['bio'] ?? '').toString().isNotEmpty) ('Bio', Text('${u['bio']}')),
      ]),
      if (canAct) ...[
        const SizedBox(height: Sp.s3),
        Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [
          if (u['status'] != 'active') FilledButton.icon(onPressed: _busy ? null : () => _act('reinstate'), icon: const Icon(Icons.restore), label: const Text('Reinstate')),
          if (u['status'] == 'active') OutlinedButton.icon(onPressed: _busy ? null : () => _act('suspend'), icon: const Icon(Icons.pause_circle_outline), label: const Text('Suspend')),
          if (u['status'] != 'banned') FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: context.tk.danger, foregroundColor: context.tk.onDanger),
            onPressed: _busy ? null : () => _act('ban'), icon: const Icon(Icons.gpp_bad_outlined), label: const Text('Ban')),
        ]),
      ] else if (u['role'] != 'user')
        Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text('Staff account: it cannot be suspended or banned here.', style: TextStyle(color: context.tk.inkMuted))),
    ]));
  }
}
