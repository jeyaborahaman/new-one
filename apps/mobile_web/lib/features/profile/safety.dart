import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';

/// Store-required safety actions (block, report, delete account), built only from standard dialogs and sheets
/// in the app theme. They call the Phase 2 APIs.

const reportReasons = ['spam', 'harassment', 'hate', 'sexual', 'violence', 'self_harm', 'other'];

/// Asks for confirmation, then blocks. Returns true when the user is now blocked.
Future<bool> confirmBlock(BuildContext context, WidgetRef ref, {required int userId, required String name}) async {
  final l = context.l10n; final t = context.tk;
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: Text(l.blockConfirmTitle(name)),
    content: Text(l.blockConfirmBody),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: t.danger, foregroundColor: t.onDanger), onPressed: () => Navigator.pop(c, true), child: Text(l.blockUser)),
    ],
  ));
  if (ok != true || !context.mounted) return false;
  try {
    await ref.read(apiProvider).post('/users/$userId/block');
    if (context.mounted) toast(context, l.userBlocked(name));
    return true;
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
    return false;
  }
}

/// Reason (required) and optional details, then POST /reports. Returns true when the report was sent.
Future<bool> reportUser(BuildContext context, WidgetRef ref, {required int userId, required String name}) =>
    _report(context, targetType: 'user', targetId: userId, title: context.l10n.reportTitle(name), prompt: context.l10n.reportReasonPrompt);
Future<bool> reportPost(BuildContext context, {required int postId}) =>
    _report(context, targetType: 'post', targetId: postId, title: context.l10n.reportPost, prompt: context.l10n.reportPostPrompt);
Future<bool> reportComment(BuildContext context, {required int commentId}) =>
    _report(context, targetType: 'comment', targetId: commentId, title: context.l10n.reportComment, prompt: context.l10n.reportCommentPrompt);

/// One dialog for every report target the moderation API accepts (user, post, comment).
Future<bool> _report(BuildContext context, {required String targetType, required int targetId, required String title, required String prompt}) async {
  final sent = await showDialog<bool>(context: context, builder: (c) => _ReportDialog(targetType: targetType, targetId: targetId, title: title, prompt: prompt));
  if (sent == true && context.mounted) toast(context, context.l10n.reportSent);
  return sent == true;
}

/// Compact ⋮ with a single "Report" entry, sized to sit in existing header rows without changing them.
class ReportMenuButton extends StatelessWidget {
  const ReportMenuButton({super.key, required this.onReport});
  final VoidCallback onReport;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox.square(dimension: 32, child: PopupMenuButton<String>(
      tooltip: l.moreOptions, padding: EdgeInsets.zero, iconSize: 20, icon: Icon(Icons.more_vert, color: context.tk.inkMuted),
      onSelected: (_) => onReport(),
      itemBuilder: (_) => [PopupMenuItem(value: 'report', child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.flag_outlined), title: Text(l.reportUser)))],
    ));
  }
}

class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog({required this.targetType, required this.targetId, required this.title, required this.prompt});
  final String targetType, title, prompt; final int targetId;
  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}
class _ReportDialogState extends ConsumerState<_ReportDialog> {
  String? _reason; bool _busy = false; String? _error;
  final _details = TextEditingController(); // owned here: it must outlive the dialog's closing animation
  @override
  void dispose() { _details.dispose(); super.dispose(); }

  Future<void> _send() async {
    setState(() { _busy = true; _error = null; });
    try {
      final d = _details.text.trim();
      await ref.read(apiProvider).post('/reports', body: {'target_type': widget.targetType, 'target_id': widget.targetId, 'reason': _reason, if (d.isNotEmpty) 'details': d});
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) setState(() { _busy = false; _error = e.toString(); }); }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n; final t = context.tk;
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(0, Sp.s4, 0, 0),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.s6), child: Text(widget.prompt, style: TextStyle(color: t.inkMuted))),
        const SizedBox(height: Sp.s2),
        for (final r in reportReasons) ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Sp.s6), dense: true,
          title: Text(l.reportReason(r)), selected: _reason == r,
          trailing: _reason == r ? Icon(Icons.check, color: t.brand) : null,
          onTap: _busy ? null : () => setState(() => _reason = r),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(Sp.s6, Sp.s2, Sp.s6, 0), child: TextField(controller: _details, maxLength: 1000, maxLines: 3, minLines: 1, enabled: !_busy, decoration: InputDecoration(hintText: l.reportDetailsHint))),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.s6), child: Text(_error!, style: TextStyle(color: t.danger))),
      ]))),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(onPressed: _reason == null || _busy ? null : _send, child: Text(l.submitReport)),
      ],
    );
  }
}

/// Bottom sheet listing blocked accounts, each with Unblock.
Future<void> showBlockedAccounts(BuildContext context) => showModalBottomSheet(
      context: context, useRootNavigator: true, showDragHandle: true, isScrollControlled: true,
      builder: (_) => const _BlockedSheet(),
    );

class _BlockedSheet extends ConsumerStatefulWidget { const _BlockedSheet(); @override ConsumerState<_BlockedSheet> createState() => _BlockedSheetState(); }
class _BlockedSheetState extends ConsumerState<_BlockedSheet> {
  List<Map<String, dynamic>>? _rows; String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await ref.read(apiProvider).get('/users/me/blocks'); if (mounted) setState(() { _rows = (r['data'] as List).cast<Map<String, dynamic>>(); _error = null; }); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }
  Future<void> _unblock(Map<String, dynamic> u) async {
    try {
      await ref.read(apiProvider).delete('/users/${u['id']}/block');
      if (!mounted) return;
      setState(() => _rows = _rows!.where((x) => x['id'] != u['id']).toList());
      toast(context, context.l10n.userUnblocked('${u['display_name']}'));
    } catch (e) { if (mounted) toast(context, e.toString()); }
  }
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = _rows;
    return SafeArea(child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.blockedAccounts, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Sp.s2),
        Flexible(child: _error != null ? ErrorRetry(message: _error!, onRetry: _load)
            : rows == null ? const Padding(padding: EdgeInsets.all(Sp.s6), child: CircularProgressIndicator())
            : rows.isEmpty ? Padding(padding: const EdgeInsets.all(Sp.s6), child: Text(l.noBlocked, style: TextStyle(color: context.tk.inkMuted)))
            : ListView(shrinkWrap: true, children: [for (final u in rows) ListTile(
                leading: JAvatar('${u['display_name']}'.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join()),
                title: Text('${u['display_name']}'), subtitle: Text(isolate('@${u['username']}')),
                trailing: OutlinedButton(onPressed: () => _unblock(u), child: Text(l.unblock)),
              )])),
        const SizedBox(height: Sp.s4),
      ]),
    ));
  }
}

/// Explains what deletion does, asks for the password (password accounts only) and for DELETE to be typed,
/// then deletes the account and signs out.
Future<void> confirmDeleteAccount(BuildContext context, WidgetRef ref, User me) => showDialog<void>(context: context, builder: (_) => _DeleteDialog(me: me));

class _DeleteDialog extends ConsumerStatefulWidget { const _DeleteDialog({required this.me}); final User me; @override ConsumerState<_DeleteDialog> createState() => _DeleteDialogState(); }
class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  final _confirm = TextEditingController(), _password = TextEditingController();
  bool _busy = false; String? _error;
  @override
  void dispose() { _confirm.dispose(); _password.dispose(); super.dispose(); }

  bool get _ready => _confirm.text.trim() == 'DELETE' && (!widget.me.hasPassword || _password.text.isNotEmpty);

  Future<void> _delete() async {
    setState(() { _busy = true; _error = null; });
    final messenger = ScaffoldMessenger.of(context); final done = context.l10n.accountDeleted;
    final auth = ref.read(authProvider.notifier);
    try {
      await auth.deleteAccount(password: widget.me.hasPassword ? _password.text : null);
    } catch (e) { if (mounted) setState(() { _busy = false; _error = e.toString(); }); return; }
    // Close the dialog before signing out: sign-out swaps the screens for the login page, and popping after
    // that would pop the login page instead (leaving a blank screen).
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(done))); // the app-level messenger outlives this screen
    await auth.signOutDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n; final t = context.tk;
    return AlertDialog(
      title: Text(l.deleteAccountTitle),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.deleteAccountBody),
        const SizedBox(height: Sp.s4),
        if (widget.me.hasPassword) ...[
          TextField(controller: _password, obscureText: true, enabled: !_busy, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: l.fieldPassword)),
          const SizedBox(height: Sp.s3),
        ],
        TextField(controller: _confirm, enabled: !_busy, textDirection: TextDirection.ltr, autocorrect: false, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: l.deleteTypeToConfirm(isolate('DELETE')))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text(_error!, style: TextStyle(color: t.danger))),
      ])),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: t.danger, foregroundColor: t.onDanger), onPressed: _ready && !_busy ? _delete : null, child: Text(l.deleteForever)),
      ],
    );
  }
}
