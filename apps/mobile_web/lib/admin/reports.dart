import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/theme/tokens.dart';
import 'admin_session.dart';
import 'users.dart';
import 'widgets.dart';

/// Reports queue: filter by status and by what was reported; open a report for details and actions.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.onChanged});
  /// Called after a report was handled (to refresh the counters).
  final VoidCallback? onChanged;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}
class _ReportsScreenState extends State<ReportsScreen> {
  String _status = 'open';
  String? _type;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s4, Sp.s4, Sp.s2), child: Wrap(spacing: Sp.s3, runSpacing: Sp.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'open', label: Text('Open')), ButtonSegment(value: 'reviewing', label: Text('Under review')),
            ButtonSegment(value: 'actioned', label: Text('Resolved')), ButtonSegment(value: 'dismissed', label: Text('Rejected')), ButtonSegment(value: 'all', label: Text('All')),
          ],
          selected: {_status}, onSelectionChanged: (s) => setState(() => _status = s.first),
        ),
        DropdownButton<String?>(
          value: _type, underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: null, child: Text('All types')), DropdownMenuItem(value: 'post', child: Text('Post reports')),
            DropdownMenuItem(value: 'comment', child: Text('Comment reports')), DropdownMenuItem(value: 'user', child: Text('User reports')),
          ],
          onChanged: (v) => setState(() => _type = v),
        ),
      ])),
      const Divider(height: 1),
      Expanded(child: PagedList(
        key: ValueKey('$_status/$_type'),
        path: '/admin/reports', query: {'status': _status, 'target_type': ?_type},
        emptyText: _status == 'open' ? 'No open reports. The queue is clear.' : 'No reports here.',
        itemBuilder: (c, r, reload) => ReportRow(r, onTap: () async {
          final changed = await openReport(c, r['id'] as int);
          if (changed) { reload(); widget.onChanged?.call(); }
        }),
      )),
    ]);
  }
}

/// Opens report details; true when something was changed there.
Future<bool> openReport(BuildContext context, int id) async =>
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ReportDetailScreen(id: id))) == true;

class ReportRow extends StatelessWidget {
  const ReportRow(this.r, {super.key, this.onTap});
  final Json r; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = r['target'] as Map? ?? const {};
    final type = r['target_type'] as String?;
    final what = t['exists'] == false ? 'Deleted ${label(targetLabels, type).toLowerCase()}'
        : type == 'user' ? '${personName(t['author'])} ${personHandle(t['author'])}' : '${t['excerpt'] ?? ''}';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(backgroundColor: context.tk.surfaceRaised, child: Icon(targetIcon(type), color: context.tk.ink, size: 20)),
      title: Text(what, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        '#${r['id']}', label(reasonLabels, r['reason']),
        if (type != 'user' && t['author'] != null) 'by ${personName(t['author'])}',
        'reported by ${personName(r['reporter'])}', fmtTime(r['created_at']),
      ].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Wrap(spacing: Sp.s2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (t['removed'] == true) Pill(type == 'user' ? 'Restricted' : 'Removed', color: context.tk.danger),
        reportStatusPill(context, r['status']),
      ]),
    );
  }
}

/// One report: the reported content, who reported it and why, related reports, history, and the actions.
class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}
class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  Json? _r; String? _error; bool _busy = false, _changed = false;

  @override
  void initState() { super.initState(); _load(); }
  ApiClient get _api => ref.read(adminApiProvider);

  Future<void> _load() async {
    try { final r = await _api.get('/admin/reports/${widget.id}'); if (mounted) setState(() { _r = (r as Map).cast<String, dynamic>(); _error = null; }); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }

  Future<void> _run(Future<void> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      await call();
      _changed = true;
      if (mounted) notice(context, done);
      await _load();
    } catch (e) { if (mounted) notice(context, e.toString()); }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _review() => _run(() => _api.post('/admin/reports/${widget.id}/review'), 'Marked as under review');

  Future<void> _reject() async {
    final note = await confirmWithNote(context, title: 'Reject report', message: 'No rule was broken. The content stays up and the report is closed.', action: 'Reject report');
    if (note == null) return;
    await _run(() => _api.post('/admin/reports/${widget.id}/reject', body: {if (note.isNotEmpty) 'note': note}), 'Report rejected');
  }

  Future<void> _resolve() async {
    final session = ref.read(adminAuthProvider).session!;
    final r = _r!;
    final choice = await showDialog<_Resolution>(context: context, builder: (_) => _ResolveDialog(
      targetType: r['target_type'], canActOnUsers: session.canActOnUsers,
      alreadyRemoved: (r['target'] as Map?)?['removed'] == true,
      authorIsStaff: ((r['target'] as Map?)?['author'] as Map?)?['role'] is String && ((r['target'] as Map?)?['author'] as Map?)?['role'] != 'user',
    ));
    if (choice == null) return;
    final what = choice.userAction == 'ban' ? 'Account banned' : choice.userAction == 'suspend' ? 'Account suspended' : choice.remove ? 'Content removed' : 'Report resolved';
    await _run(() => _api.post('/admin/reports/${widget.id}/resolve', body: {
      'remove_content': choice.remove, 'user_action': choice.userAction, if (choice.note.isNotEmpty) 'note': choice.note,
    }), what);
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) Navigator.pop(context, _changed); },
      child: Scaffold(
        appBar: AppBar(title: Text('Report #${widget.id}'), actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh))]),
        body: _error != null && r == null ? ErrorBox(_error!, onRetry: _load)
            : r == null ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(builder: (c, box) {
                final main = [_content(r), _related(r), _history(r)];
                final side = [_summary(r), _actions(r)];
                if (box.maxWidth < 900) return ListView(padding: const EdgeInsets.all(Sp.s4), children: _spaced([...side, ...main]));
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: ListView(padding: const EdgeInsets.all(Sp.s4), children: _spaced(main))),
                  SizedBox(width: 380, child: ListView(padding: const EdgeInsets.fromLTRB(0, Sp.s4, Sp.s4, Sp.s4), children: _spaced(side))),
                ]);
              }),
      ),
    );
  }

  List<Widget> _spaced(List<Widget> w) => [for (final x in w) Padding(padding: const EdgeInsets.only(bottom: Sp.s4), child: x)];

  Widget _summary(Json r) => Section(title: 'Report', trailing: reportStatusPill(context, r['status']), child: Facts([
    ('Type', Text('${label(targetLabels, r['target_type'])} report')),
    ('Reason', Text(label(reasonLabels, r['reason']), style: const TextStyle(fontWeight: FontWeight.w700))),
    if (r['details'] != null) ('Details', Text('${r['details']}')),
    ('Reported by', _personLink(r['reporter'])),
    ('Reported', Text(fmtTime(r['created_at']))),
    if (r['reviewer'] != null) ('Reviewer', Text(personName(r['reviewer']))),
    if (r['resolution'] != null) ('Outcome', Text(label(resolutionLabels, r['resolution']))),
    if (r['note'] != null) ('Note', Text('${r['note']}')),
    if (r['handler'] != null) ('Handled by', Text('${personName(r['handler'])} · ${fmtTime(r['handled_at'])}')),
  ]));

  Widget _personLink(Object? p) => p is Map
      ? InkWell(onTap: () => openUser(context, p['id'] as int), child: Text('${personName(p)} ${personHandle(p)}', style: TextStyle(color: context.tk.brand, fontWeight: FontWeight.w600)))
      : const Text('Unknown user');

  Widget _actions(Json r) {
    final open = r['status'] == 'open' || r['status'] == 'reviewing';
    final me = ref.watch(adminAuthProvider).session;
    final reviewer = r['reviewer'] as Map?;
    return Section(title: 'Actions', child: !open
        ? Text('This report is closed.', style: TextStyle(color: context.tk.inkMuted))
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (r['status'] == 'open') OutlinedButton.icon(onPressed: _busy ? null : _review, icon: const Icon(Icons.visibility_outlined), label: const Text('Mark under review')),
            if (r['status'] == 'reviewing') Padding(padding: const EdgeInsets.only(bottom: Sp.s2), child: Text(
              reviewer?['id'] == me?.id ? 'You are reviewing this report.' : '${personName(reviewer)} is reviewing this report.', style: TextStyle(color: context.tk.inkMuted))),
            const SizedBox(height: Sp.s2),
            FilledButton.icon(onPressed: _busy ? null : _resolve, icon: const Icon(Icons.gavel), label: const Text('Resolve…')),
            const SizedBox(height: Sp.s2),
            OutlinedButton.icon(onPressed: _busy ? null : _reject, icon: const Icon(Icons.block), label: const Text('Reject')),
            const SizedBox(height: Sp.s2),
            Text('Resolve: a rule was broken (you can remove the content${me?.canActOnUsers == true ? ' and suspend or ban the account' : ''}). Reject: no violation.',
                style: TextStyle(color: context.tk.inkMuted, fontSize: 12)),
          ]));
  }

  Widget _content(Json r) {
    final type = r['target_type'];
    final c = r['content'] as Map?;
    final t = r['target'] as Map? ?? const {};
    final author = t['author'] as Map?;
    if (c == null) return Section(title: 'Reported ${label(targetLabels, type).toLowerCase()}', child: Text('This content no longer exists.', style: TextStyle(color: context.tk.inkMuted)));
    final removed = t['removed'] == true;
    return Section(
      title: 'Reported ${label(targetLabels, type).toLowerCase()}',
      trailing: removed ? Pill(type == 'user' ? 'Restricted' : 'Removed', color: context.tk.danger) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (type == 'user') ...[
          Facts([
            ('Name', _personLink(c)), ('Status', Align(alignment: AlignmentDirectional.centerStart, child: accountStatusPill(context, c['status']))),
            ('Role', Text('${c['role']}')), ('Joined', Text(fmtTime(c['created_at']))), ('Followers', Text('${c['followers_count'] ?? 0}')),
            if ((c['bio'] ?? '').toString().isNotEmpty) ('Bio', Text('${c['bio']}')),
          ]),
        ] else ...[
          Facts([('Author', _personLink(author)), ('Posted', Text(fmtTime(c['created_at']))), if (type == 'comment') ('On post', Text('#${c['post_id']} · ${c['post_excerpt'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis))]),
          const SizedBox(height: Sp.s3),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(Sp.s4),
            decoration: BoxDecoration(color: context.tk.surfaceRaised, borderRadius: BorderRadius.circular(Rd.md)),
            child: SelectableText('${c['body'] ?? ''}'.isEmpty ? '(no text)' : '${c['body']}'),
          ),
          if (c['media'] is Map && (c['media'] as Map)['url'] != null) ...[
            const SizedBox(height: Sp.s3),
            (c['media'] as Map)['kind'] == 'image'
                ? ClipRRect(borderRadius: BorderRadius.circular(Rd.md), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 360), child: Image.network('${(c['media'] as Map)['url']}', fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text('Image could not be loaded'))))
                : SelectableText('${(c['media'] as Map)['kind']}: ${(c['media'] as Map)['url']}'),
          ],
          if (c['gif_url'] != null) SelectableText('GIF: ${c['gif_url']}'),
        ],
      ]),
    );
  }

  Widget _related(Json r) {
    final rel = (r['related'] as List? ?? const []).cast<Json>();
    return Section(title: 'Other reports on this ${label(targetLabels, r['target_type']).toLowerCase()} (${rel.length})', child: rel.isEmpty
        ? Text('None.', style: TextStyle(color: context.tk.inkMuted))
        : Column(children: [for (final x in rel) ListTile(
            contentPadding: EdgeInsets.zero, dense: true,
            title: Text('#${x['id']} · ${label(reasonLabels, x['reason'])}'),
            subtitle: Text('${personName(x['reporter'])} · ${fmtTime(x['created_at'])}${x['details'] != null ? '\n${x['details']}' : ''}'),
            trailing: reportStatusPill(context, x['status']),
            onTap: () async { if (await openReport(context, x['id'] as int)) { _changed = true; _load(); } },
          )]));
  }

  Widget _history(Json r) {
    final h = (r['history'] as List? ?? const []).cast<Json>();
    return Section(title: 'Moderation history', child: h.isEmpty ? Text('No actions yet.', style: TextStyle(color: context.tk.inkMuted)) : AuditTimeline(h));
  }
}

/// Audit entries as a compact timeline (who, what, when, note).
class AuditTimeline extends StatelessWidget {
  const AuditTimeline(this.entries, {super.key});
  final List<Json> entries;
  @override
  Widget build(BuildContext context) => Column(children: [for (final e in entries) ListTile(
    contentPadding: EdgeInsets.zero, dense: true,
    leading: Icon(Icons.history, color: context.tk.inkMuted),
    title: Text(label(auditLabels, e['action'])),
    subtitle: Text([
      '${personName(e['actor'])} · ${fmtTime(e['created_at'])}',
      if (e['meta'] is Map && (e['meta']['note'] ?? e['meta']['reason']) != null) '“${e['meta']['note'] ?? e['meta']['reason']}”',
    ].join('\n')),
  )]);
}

class _Resolution { _Resolution(this.remove, this.userAction, this.note); final bool remove; final String userAction, note; }

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.targetType, required this.canActOnUsers, required this.alreadyRemoved, required this.authorIsStaff});
  final String targetType; final bool canActOnUsers, alreadyRemoved, authorIsStaff;
  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}
class _ResolveDialogState extends State<_ResolveDialog> {
  late bool _remove = widget.targetType != 'user' && !widget.alreadyRemoved;
  String _userAction = 'none';
  final _note = TextEditingController();
  @override
  void dispose() { _note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.targetType == 'user';
    final accountActions = widget.canActOnUsers && !widget.authorIsStaff;
    return AlertDialog(
      title: const Text('Resolve report'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Confirm a rule was broken and choose what happens.'),
        const SizedBox(height: Sp.s3),
        if (!isUser) CheckboxListTile(
          contentPadding: EdgeInsets.zero, value: _remove, onChanged: widget.alreadyRemoved ? null : (v) => setState(() => _remove = v ?? false),
          title: Text('Remove this ${widget.targetType}'), subtitle: widget.alreadyRemoved ? const Text('Already removed') : const Text('Hidden from everyone'),
        ),
        if (accountActions) ...[
          Text(isUser ? 'Account action' : "Author's account", style: const TextStyle(fontWeight: FontWeight.w700)),
          RadioGroup<String>(groupValue: _userAction, onChanged: (v) => setState(() => _userAction = v ?? 'none'), child: const Column(children: [
            RadioListTile(contentPadding: EdgeInsets.zero, value: 'none', title: Text('No account action')),
            RadioListTile(contentPadding: EdgeInsets.zero, value: 'suspend', title: Text('Suspend'), subtitle: Text('Signs them out; they cannot sign in until reinstated')),
            RadioListTile(contentPadding: EdgeInsets.zero, value: 'ban', title: Text('Ban'), subtitle: Text('Permanent; signs them out everywhere')),
          ])),
        ] else if (widget.authorIsStaff)
          Text('The account belongs to staff and cannot be suspended or banned here.', style: TextStyle(color: context.tk.inkMuted))
        else if (isUser)
          Text('Only admins can suspend or ban accounts. Resolving records the violation.', style: TextStyle(color: context.tk.inkMuted)),
        const SizedBox(height: Sp.s2),
        TextField(controller: _note, maxLength: 500, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Note for the audit log (optional)')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _Resolution(_remove, _userAction, _note.text.trim())), child: const Text('Resolve')),
      ],
    );
  }
}
