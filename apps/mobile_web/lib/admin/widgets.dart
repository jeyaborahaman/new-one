import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme/tokens.dart';
import 'admin_session.dart';

/// Building blocks shared by the admin panel screens.

typedef Json = Map<String, dynamic>;

/// API times arrive as epoch ms (SQLite) or ISO strings (MySQL).
DateTime? parseTime(Object? v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : v is String ? DateTime.tryParse(v)?.toLocal() : null;
String fmtTime(Object? v) { final d = parseTime(v); return d == null ? '—' : DateFormat('d MMM y, HH:mm').format(d); }

String personName(Object? p) => p is Map ? '${p['display_name'] ?? p['username']}' : 'Unknown user';
String personHandle(Object? p) => p is Map ? '@${p['username']}' : '';

const reasonLabels = {'spam': 'Spam', 'harassment': 'Harassment or bullying', 'hate': 'Hate speech', 'sexual': 'Sexual content', 'violence': 'Violence or threats', 'self_harm': 'Self-harm', 'other': 'Other'};
const reportStatusLabels = {'open': 'Open', 'reviewing': 'Under review', 'actioned': 'Resolved', 'dismissed': 'Rejected'};
const resolutionLabels = {'content_removed': 'Content removed', 'user_suspended': 'User suspended', 'user_banned': 'User banned', 'resolved': 'Resolved', 'no_violation': 'No violation'};
const targetLabels = {'post': 'Post', 'comment': 'Comment', 'user': 'User'};
const auditLabels = {
  'report.review': 'Took a report for review', 'report.resolve': 'Resolved a report', 'report.reject': 'Rejected a report',
  'report.remove': 'Removed reported content', 'report.dismiss': 'Dismissed a report', 'content.remove': 'Removed content',
  'user.suspend': 'Suspended an account', 'user.ban': 'Banned an account', 'user.reinstate': 'Reinstated an account',
  'user.verify': 'Verified an account', 'user.delete_self': 'Deleted their own account', 'flag.set': 'Changed a feature flag',
  'luckydraw.publish': 'Published a lucky draw', 'luckydraw.draw': 'Ran a lucky draw',
};
String label(Map<String, String> m, Object? k) => m['$k'] ?? '$k';

IconData targetIcon(String? type) => switch (type) { 'post' => Icons.article_outlined, 'comment' => Icons.mode_comment_outlined, _ => Icons.person_outline };

/// Small coloured label for statuses (report status, account status, role).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color});
  final String text; final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tk.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Rd.pill), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Text(text, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

Color reportStatusColor(BuildContext c, String? s) => switch (s) { 'open' => c.tk.accent, 'reviewing' => c.tk.gold, 'actioned' => c.tk.brand, _ => c.tk.inkMuted };
Color accountStatusColor(BuildContext c, String? s) => switch (s) { 'active' => c.tk.brand, 'suspended' => c.tk.gold, 'banned' => c.tk.danger, _ => c.tk.inkMuted };
Widget reportStatusPill(BuildContext c, String? s) => Pill(label(reportStatusLabels, s), color: reportStatusColor(c, s));
Widget accountStatusPill(BuildContext c, String? s) => Pill(s == null ? '—' : '${s[0].toUpperCase()}${s.substring(1)}', color: accountStatusColor(c, s));

/// Titled card section.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child, this.trailing});
  final String title; final Widget child; final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(Sp.s4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))), ?trailing]),
      const SizedBox(height: Sp.s3),
      child,
    ]),
  ));
}

/// Label/value rows for detail screens.
class Facts extends StatelessWidget {
  const Facts(this.rows, {super.key});
  final List<(String, Widget)> rows;
  @override
  Widget build(BuildContext context) => Column(children: [
    for (final (k, v) in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text(k, style: TextStyle(color: context.tk.inkMuted))),
      Expanded(child: v),
    ])),
  ]);
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(Sp.s6), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.error_outline, color: context.tk.danger, size: 36),
    const SizedBox(height: Sp.s2),
    Text(message, textAlign: TextAlign.center),
    const SizedBox(height: Sp.s3),
    OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
  ])));
}

void notice(BuildContext context, String message) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));

/// Confirmation with an optional note (kept in the audit log). Returns the note ('' if none) or null if cancelled.
Future<String?> confirmWithNote(BuildContext context, {required String title, required String message, required String action, bool danger = false, String noteLabel = 'Note for the audit log (optional)'}) {
  final note = TextEditingController();
  return showDialog<String>(context: context, builder: (c) => AlertDialog(
    title: Text(title),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(message),
      const SizedBox(height: Sp.s4),
      TextField(controller: note, maxLength: 500, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: noteLabel)),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
      FilledButton(
        style: danger ? FilledButton.styleFrom(backgroundColor: c.tk.danger, foregroundColor: c.tk.onDanger) : null,
        onPressed: () => Navigator.pop(c, note.text.trim()), child: Text(action)),
    ],
  )).whenComplete(() => WidgetsBinding.instance.addPostFrameCallback((_) => note.dispose()));
}

/// A keyset-paginated list from the API (`{data, next_cursor}`), with loading, error, empty and "Load more".
class PagedList extends ConsumerStatefulWidget {
  const PagedList({super.key, required this.path, this.query = const {}, required this.itemBuilder, required this.emptyText});
  final String path;
  final Map<String, dynamic> query;
  final Widget Function(BuildContext context, Json row, VoidCallback reload) itemBuilder;
  final String emptyText;
  @override
  ConsumerState<PagedList> createState() => _PagedListState();
}
class _PagedListState extends ConsumerState<PagedList> {
  List<Json>? _rows; Object? _next; bool _busy = false; String? _error;
  @override
  void initState() { super.initState(); _load(reset: true); }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() { _busy = true; if (reset) _error = null; });
    try {
      final r = await ref.read(adminApiProvider).get(widget.path, q: {...widget.query, if (!reset && _next != null) 'cursor': _next});
      if (!mounted) return;
      final data = (r['data'] as List).cast<Json>();
      setState(() { _rows = reset ? data : [...?_rows, ...data]; _next = r['next_cursor']; _busy = false; });
    } catch (e) { if (mounted) setState(() { _busy = false; _error = e.toString(); }); }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (_error != null && rows == null) return ErrorBox(_error!, onRetry: () => _load(reset: true));
    if (rows == null) return const Center(child: CircularProgressIndicator());
    if (rows.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(Sp.s8), child: Text(widget.emptyText, style: TextStyle(color: context.tk.inkMuted))));
    return RefreshIndicator(onRefresh: () => _load(reset: true), child: ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: Sp.s2),
      itemCount: rows.length + (_next != null ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (c, i) => i < rows.length ? widget.itemBuilder(c, rows[i], () => _load(reset: true))
          : Padding(padding: const EdgeInsets.all(Sp.s4), child: Center(child: _busy ? const CircularProgressIndicator() : OutlinedButton(onPressed: _load, child: const Text('Load more')))),
    ));
  }
}
