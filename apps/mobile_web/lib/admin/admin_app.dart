import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/l10n.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'admin_session.dart';
import 'reports.dart';
import 'users.dart';
import 'widgets.dart';

/// Jeyabo Admin: the staff moderation panel. A separate web app (entry point lib/admin/main_admin.dart) with its
/// own desktop layout; it shares only the API client and the brand colours with the member app.
class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});
  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}
class _AdminAppState extends ConsumerState<AdminApp> {
  @override
  void initState() { super.initState(); Future.microtask(() => ref.read(adminAuthProvider.notifier).restore()); }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);
    return MaterialApp(
      title: 'Jeyabo Admin', debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light).copyWith(visualDensity: VisualDensity.compact),
      darkTheme: buildTheme(Brightness.dark).copyWith(visualDensity: VisualDensity.compact),
      locale: const Locale('en'), // staff tooling is English; API messages follow Accept-Language
      localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
      home: switch (auth.status) {
        AdminStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
        AdminStatus.signedOut => AdminLoginScreen(message: auth.message),
        AdminStatus.signedIn => AdminShell(key: ValueKey(auth.session!.id), session: auth.session!),
      },
    );
  }
}

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key, this.message});
  final String? message;
  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}
class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _id = TextEditingController(), _pw = TextEditingController(), _code = TextEditingController();
  String? _challenge, _error; bool _busy = false;
  @override
  void dispose() { _id.dispose(); _pw.dispose(); _code.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final auth = ref.read(adminAuthProvider.notifier);
    setState(() { _busy = true; _error = null; });
    try {
      if (_challenge == null) {
        final c = await auth.login(_id.text.trim(), _pw.text);
        if (c != null && mounted) setState(() => _challenge = c);
      } else {
        await auth.verify2fa(_challenge!, _code.text.trim());
      }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final msg = _error ?? widget.message;
    return Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(Sp.s4), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(child: Padding(padding: const EdgeInsets.all(Sp.s6), child: AutofillGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Icon(Icons.shield_outlined, color: t.brand, size: 32), const SizedBox(width: Sp.s2), Text('Jeyabo Admin', style: Theme.of(context).textTheme.titleLarge)]),
        const SizedBox(height: Sp.s1),
        Text('Moderation panel · staff only', style: TextStyle(color: t.inkMuted)),
        const SizedBox(height: Sp.s6),
        if (_challenge == null) ...[
          TextField(controller: _id, enabled: !_busy, autofillHints: const [AutofillHints.username], decoration: const InputDecoration(labelText: 'E-mail or username')),
          const SizedBox(height: Sp.s3),
          TextField(controller: _pw, enabled: !_busy, obscureText: true, autofillHints: const [AutofillHints.password], onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Password')),
        ] else
          TextField(controller: _code, enabled: !_busy, autofocus: true, keyboardType: TextInputType.number, onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Two-factor code', helperText: 'From your authenticator app, or a backup code')),
        if (msg != null) Padding(padding: const EdgeInsets.only(top: Sp.s3), child: Text(msg, style: TextStyle(color: t.danger))),
        const SizedBox(height: Sp.s4),
        FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_challenge == null ? 'Sign in' : 'Verify')),
      ])))),
    ))));
  }
}

enum AdminSection { dashboard, reports, users, audit }

/// Sidebar layout (navigation rail; a drawer on narrow windows) with the new-report indicator in the top bar.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.session});
  final StaffSession session;
  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}
class _AdminShellState extends ConsumerState<AdminShell> {
  static const _seenKey = 'admin_seen_report';
  AdminSection _section = AdminSection.dashboard;
  Json? _summary; String? _summaryError;
  int? _seen; // newest report id the moderator has looked at
  Timer? _poll;
  int _queueVersion = 0;

  List<AdminSection> get _sections => [AdminSection.dashboard, AdminSection.reports, AdminSection.users, if (widget.session.canSeeAudit) AdminSection.audit];
  int get _newCount => (_summary?['new_since'] as int?) ?? 0;

  @override
  void initState() {
    super.initState();
    _start();
  }
  @override
  void dispose() { _poll?.cancel(); super.dispose(); }

  Future<void> _start() async {
    try { _seen = int.tryParse(await ref.read(adminPrefsProvider).read(key: _seenKey) ?? ''); } catch (_) {}
    if (!mounted) return;
    await _refreshSummary();
    if (mounted) _poll = Timer.periodic(ref.read(adminPollIntervalProvider), (_) => _refreshSummary(announce: true));
  }

  Future<void> _refreshSummary({bool announce = false}) async {
    try {
      final s = ((await ref.read(adminApiProvider).get('/admin/moderation/summary', q: {'since_id': _seen ?? 0})) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final before = _newCount;
      setState(() { _summary = s; _summaryError = null; });
      if (_section == AdminSection.reports) { _markSeen(); return; }
      if (announce && _newCount > before) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
          content: Text(_newCount == 1 ? '1 new report' : '$_newCount new reports'),
          action: SnackBarAction(label: 'View', onPressed: () => _go(AdminSection.reports)),
        ));
      }
    } catch (e) { if (mounted) setState(() => _summaryError = e.toString()); }
  }

  void _markSeen() {
    final latest = _summary?['latest_id'] as int?;
    if (latest == null || (_seen ?? 0) >= latest && _newCount == 0) return;
    _seen = latest;
    setState(() => _summary = {...?_summary, 'new_since': 0});
    unawaited(ref.read(adminPrefsProvider).write(key: _seenKey, value: '$latest').catchError((_) {}));
  }

  void _go(AdminSection s) {
    setState(() { _section = s; if (s == AdminSection.reports) _queueVersion++; });
    if (s == AdminSection.reports) _markSeen();
  }

  static const _meta = {
    AdminSection.dashboard: ('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard),
    AdminSection.reports: ('Reports', Icons.flag_outlined, Icons.flag),
    AdminSection.users: ('Users', Icons.people_outline, Icons.people),
    AdminSection.audit: ('Audit log', Icons.receipt_long_outlined, Icons.receipt_long),
  };

  Widget _navIcon(AdminSection s, bool selected) {
    final icon = Icon(selected ? _meta[s]!.$3 : _meta[s]!.$2);
    return s == AdminSection.reports && _newCount > 0 ? Badge(label: Text('$_newCount'), child: icon) : icon;
  }

  Widget _page() => switch (_section) {
    AdminSection.dashboard => DashboardScreen(summary: _summary, error: _summaryError, onRefresh: _refreshSummary, onOpenQueue: () => _go(AdminSection.reports)),
    AdminSection.reports => ReportsScreen(key: ValueKey(_queueVersion), onChanged: _refreshSummary),
    AdminSection.users => const UsersScreen(),
    AdminSection.audit => const AuditScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final s = widget.session;
    final sections = _sections;
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 900;
      final bar = AppBar(
        title: Text(_meta[_section]!.$1),
        actions: [
          IconButton(
            tooltip: _newCount == 0 ? 'No new reports' : '$_newCount new reports',
            onPressed: () => _go(AdminSection.reports),
            icon: Badge(isLabelVisible: _newCount > 0, label: Text('$_newCount'), child: const Icon(Icons.notifications_outlined)),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.s2), child: Center(child: Text('${s.displayName} · ${s.role}', style: TextStyle(color: t.inkMuted)))),
          IconButton(tooltip: 'Sign out', onPressed: () => ref.read(adminAuthProvider.notifier).logout(), icon: const Icon(Icons.logout)),
          const SizedBox(width: Sp.s2),
        ],
      );
      final body = Material(color: t.bg, child: _page());
      if (!wide) {
        return Scaffold(appBar: bar, drawer: NavigationDrawer(
          selectedIndex: sections.indexOf(_section),
          onDestinationSelected: (i) { Navigator.pop(context); _go(sections[i]); },
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(28, Sp.s4, Sp.s4, Sp.s4), child: Text('Jeyabo Admin', style: Theme.of(context).textTheme.titleLarge)),
            for (final x in sections) NavigationDrawerDestination(icon: _navIcon(x, false), selectedIcon: _navIcon(x, true), label: Text(_meta[x]!.$1)),
          ],
        ), body: body);
      }
      return Scaffold(body: Row(children: [
        NavigationRail(
          extended: box.maxWidth >= 1200, minExtendedWidth: 220, backgroundColor: t.surface,
          leading: Padding(padding: const EdgeInsets.symmetric(vertical: Sp.s4), child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shield_outlined, color: t.brand),
            if (box.maxWidth >= 1200) ...[const SizedBox(width: Sp.s2), Text('Jeyabo Admin', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))],
          ])),
          selectedIndex: sections.indexOf(_section),
          onDestinationSelected: (i) => _go(sections[i]),
          labelType: box.maxWidth >= 1200 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
          destinations: [for (final x in sections) NavigationRailDestination(icon: _navIcon(x, false), selectedIcon: _navIcon(x, true), label: Text(_meta[x]!.$1))],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: Scaffold(appBar: bar, body: body)),
      ]));
    });
  }
}

/// Queue counters and account restrictions at a glance.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.summary, this.error, required this.onRefresh, required this.onOpenQueue});
  final Json? summary; final String? error;
  final Future<void> Function() onRefresh; final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) return error != null ? ErrorBox(error!, onRetry: onRefresh) : const Center(child: CircularProgressIndicator());
    final t = context.tk;
    final byType = s['by_type'] as Map? ?? const {};
    Widget tile(String label, Object? n, IconData icon, Color c) => SizedBox(width: 220, child: Card(child: Padding(padding: const EdgeInsets.all(Sp.s4), child: Row(children: [
      CircleAvatar(backgroundColor: c.withValues(alpha: 0.15), child: Icon(icon, color: c)),
      const SizedBox(width: Sp.s3),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${n ?? 0}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: t.inkMuted)),
      ])),
    ]))));
    return RefreshIndicator(onRefresh: onRefresh, child: ListView(padding: const EdgeInsets.all(Sp.s4), children: [
      if ((s['new_since'] ?? 0) > 0) Padding(padding: const EdgeInsets.only(bottom: Sp.s4), child: MaterialBanner(
        backgroundColor: t.brandSoft, leading: Icon(Icons.notifications_active, color: t.brand),
        content: Text('${s['new_since']} new ${s['new_since'] == 1 ? 'report' : 'reports'} since you last opened the queue.'),
        actions: [TextButton(onPressed: onOpenQueue, child: const Text('Open queue'))],
      )),
      Text('Reports queue', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: Sp.s2),
      Wrap(spacing: Sp.s3, runSpacing: Sp.s3, children: [
        tile('Open reports', s['open'], Icons.flag_outlined, t.accent),
        tile('Under review', s['reviewing'], Icons.visibility_outlined, t.gold),
        tile('Handled (24 h)', s['handled_24h'], Icons.task_alt, t.brand),
      ]),
      const SizedBox(height: Sp.s4),
      Text('Waiting, by type', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: Sp.s2),
      Wrap(spacing: Sp.s3, runSpacing: Sp.s3, children: [
        tile('Post reports', byType['post'], Icons.article_outlined, t.ink),
        tile('Comment reports', byType['comment'], Icons.mode_comment_outlined, t.ink),
        tile('User reports', byType['user'], Icons.person_outline, t.ink),
      ]),
      const SizedBox(height: Sp.s4),
      Text('Restricted accounts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: Sp.s2),
      Wrap(spacing: Sp.s3, runSpacing: Sp.s3, children: [
        tile('Suspended', s['suspended'], Icons.pause_circle_outline, t.gold),
        tile('Banned', s['banned'], Icons.gpp_bad_outlined, t.danger),
      ]),
      const SizedBox(height: Sp.s6),
      Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: onOpenQueue, icon: const Icon(Icons.flag), label: const Text('Go to reports queue'))),
    ]));
  }
}

/// Moderator audit log (admins): every staff action, newest first, filterable by kind.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}
class _AuditScreenState extends State<AuditScreen> {
  String? _action;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.fromLTRB(Sp.s4, Sp.s4, Sp.s4, Sp.s2), child: Wrap(spacing: Sp.s2, children: [
      for (final (v, l) in const [(null, 'All actions'), ('report.', 'Reports'), ('content.', 'Content'), ('user.', 'Accounts')])
        ChoiceChip(label: Text(l), selected: _action == v, onSelected: (_) => setState(() => _action = v)),
    ])),
    const Divider(height: 1),
    Expanded(child: PagedList(
      key: ValueKey(_action), path: '/admin/audit', query: {'action': ?_action, 'limit': 50}, emptyText: 'No entries.',
      itemBuilder: (c, e, _) {
        final target = '${e['target'] ?? ''}';
        final m = RegExp(r'^(user|report):(\d+)$').firstMatch(target);
        final meta = e['meta'] is Map ? e['meta'] as Map : const {};
        final note = meta['note'] ?? meta['reason'];
        return ListTile(
          leading: Icon(Icons.history, color: c.tk.inkMuted),
          title: Text('${personName(e['actor'])} — ${label(auditLabels, e['action'])}'),
          subtitle: Text([target, if (meta['resolution'] != null) label(resolutionLabels, meta['resolution']), if (note != null) '“$note”', fmtTime(e['created_at'])].join(' · ')),
          trailing: m == null ? null : const Icon(Icons.chevron_right),
          onTap: m == null ? null : () => m.group(1) == 'user' ? openUser(c, int.parse(m.group(2)!)) : openReport(c, int.parse(m.group(2)!)),
        );
      },
    )),
  ]);
}
