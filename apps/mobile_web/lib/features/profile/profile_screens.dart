import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(label, style: TextStyle(fontSize: 12, color: context.tk.inkMuted))]);
}

Widget _header(BuildContext context, User u, {List<Widget> actions = const []}) {
  final t = context.tk;
  return Column(children: [
    Container(height: 120, decoration: BoxDecoration(color: t.brandSoft, borderRadius: BorderRadius.circular(Rd.lg))),
    Transform.translate(offset: const Offset(0, -36), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle), child: JAvatar(u.initials, size: 80))),
    Transform.translate(offset: const Offset(0, -28), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(u.displayName, style: Theme.of(context).textTheme.titleLarge), if (u.verified) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.verified, size: 20, color: t.brand, semanticLabel: 'Verified'))]),
      Text('@${u.username}', style: TextStyle(color: t.inkMuted)),
      if (u.bio != null && u.bio!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text(u.bio!, textAlign: TextAlign.center)),
      const SizedBox(height: Sp.s3),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: t.gold, borderRadius: BorderRadius.circular(Rd.pill)), child: Text('Level ${u.level} · ${u.xp} XP', style: TextStyle(color: t.onGold, fontWeight: FontWeight.w700, fontSize: 13))),
      const SizedBox(height: Sp.s4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_Stat(compact(u.followers), 'Followers'), _Stat(compact(u.following), 'Following')]),
      if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Sp.s4), child: Row(children: actions.map((a) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: a))).toList())),
    ])),
  ]);
}

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authProvider).user;
    if (u == null) return const SizedBox.shrink();
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider.notifier).refreshUser(),
        child: ListView(padding: const EdgeInsets.all(Sp.s4), children: [
          _header(context, u, actions: [OutlinedButton(onPressed: () => _editProfile(context, ref, u), child: const Text('Edit profile'))]),
          const Divider(),
          ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: const Text('Wallet and rewards'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/wallet')),
          ListTile(leading: const Icon(Icons.emoji_events_outlined), title: const Text('Leaderboard'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/leaderboard')),
          const _LuckyDrawTile(),
          if (u.referralCode != null) ListTile(leading: const Icon(Icons.card_giftcard_outlined), title: const Text('Invite friends'), subtitle: Text('Your code: ${u.referralCode}'), trailing: IconButton(tooltip: 'Copy code', icon: const Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: u.referralCode!)); toast(context, 'Code copied'); })),
          const Divider(),
          Padding(padding: const EdgeInsets.symmetric(vertical: Sp.s2), child: SegmentedButton<ThemeMode>(
            segments: const [ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto)), ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)), ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined))],
            selected: {mode}, onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          )),
          const SizedBox(height: Sp.s4),
          OutlinedButton.icon(onPressed: () => ref.read(authProvider.notifier).logout(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
        ]),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref, User u) async {
    final name = TextEditingController(text: u.displayName), bio = TextEditingController(text: u.bio ?? '');
    await showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, MediaQuery.of(c).viewInsets.bottom + Sp.s4),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: name, maxLength: 80, decoration: const InputDecoration(labelText: 'Display name')),
        const SizedBox(height: Sp.s2),
        TextField(controller: bio, maxLength: 300, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio')),
        const SizedBox(height: Sp.s3),
        FilledButton(onPressed: () async {
          try { await ref.read(apiProvider).patch('/users/me', body: {'display_name': name.text.trim(), 'bio': bio.text.trim()}); await ref.read(authProvider.notifier).refreshUser(); if (c.mounted) Navigator.pop(c); } catch (e) { if (c.mounted) toast(c, e.toString()); }
        }, child: const Text('Save')),
      ]),
    ));
    name.dispose(); bio.dispose();
  }
}

/// Only shown when the operator has enabled Lucky Draw (the API answers 404 when it is off).
final luckyEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  try { await ref.watch(apiProvider).get('/luckydraw/campaigns'); return true; } catch (_) { return false; }
});
class _LuckyDrawTile extends ConsumerWidget {
  const _LuckyDrawTile();
  @override
  Widget build(BuildContext context, WidgetRef ref) => (ref.watch(luckyEnabledProvider).value ?? false)
      ? ListTile(leading: const Icon(Icons.confirmation_number_outlined), title: const Text('Lucky Draw'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/luckydraw'))
      : const SizedBox.shrink();
}

class UserProfileScreen extends ConsumerStatefulWidget { const UserProfileScreen({super.key, required this.id}); final int id; @override ConsumerState<UserProfileScreen> createState() => _UState(); }
class _UState extends ConsumerState<UserProfileScreen> {
  User? _u; String? _error; bool _busy = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await ref.read(apiProvider).get('/users/${widget.id}'); if (mounted) setState(() { _u = User.fromJson(r); _error = null; }); } catch (e) { if (mounted) setState(() => _error = e.toString()); } }

  Future<void> _toggleFollow() async {
    final u = _u!; setState(() => _busy = true);
    try { u.isFollowing ? await ref.read(apiProvider).delete('/users/${u.id}/follow') : await ref.read(apiProvider).post('/users/${u.id}/follow'); await _load(); } catch (e) { if (mounted) toast(context, e.toString()); } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _message() async {
    try { final c = await ref.read(apiProvider).post('/conversations', body: {'type': 'direct', 'user_id': widget.id}); if (mounted) context.push('/chat/${c['id']}?title=${Uri.encodeComponent(_u!.displayName)}'); } catch (e) { if (mounted) toast(context, e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(),
      body: _error != null ? ErrorRetry(message: _error!, onRetry: _load) : _u == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(Sp.s4), children: [
        _header(context, _u!, actions: me?.id == _u!.id ? [] : [
          FilledButton(onPressed: _busy ? null : _toggleFollow, child: Text(_u!.isFollowing ? 'Following' : 'Follow')),
          OutlinedButton(onPressed: _message, child: const Text('Message')),
        ]),
      ]),
    );
  }
}
