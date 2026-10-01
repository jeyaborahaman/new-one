import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';
import 'safety.dart';

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(label, style: TextStyle(fontSize: 12, color: context.tk.inkMuted))]);
}

Widget _header(BuildContext context, User u, {List<Widget> actions = const []}) {
  final t = context.tk; final l = context.l10n;
  return Column(children: [
    Container(height: 120, decoration: BoxDecoration(color: t.brandSoft, borderRadius: BorderRadius.circular(Rd.lg))),
    Transform.translate(offset: const Offset(0, -36), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle), child: JAvatar(u.initials, size: 80))),
    Transform.translate(offset: const Offset(0, -28), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(u.displayName, style: Theme.of(context).textTheme.titleLarge), if (u.verified) Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: Icon(Icons.verified, size: 20, color: t.brand, semanticLabel: l.verified))]),
      Text(isolate('@${u.username}'), style: TextStyle(color: t.inkMuted)),
      if (u.bio != null && u.bio!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text(u.bio!, textAlign: TextAlign.center, textDirection: contentDirection(u.bio!))),
      const SizedBox(height: Sp.s3),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: t.gold, borderRadius: BorderRadius.circular(Rd.pill)), child: Text(l.levelXp(u.level, u.xp), style: TextStyle(color: t.onGold, fontWeight: FontWeight.w700, fontSize: 13))),
      const SizedBox(height: Sp.s4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_Stat(context.compact(u.followers), l.statFollowers), _Stat(context.compact(u.following), l.statFollowing)]),
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
    final l = context.l10n; final chosen = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.profile)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider.notifier).refreshUser(),
        child: ListView(padding: const EdgeInsets.all(Sp.s4), children: [
          _header(context, u, actions: [OutlinedButton(onPressed: () => _editProfile(context, ref, u), child: Text(l.editProfile))]),
          const Divider(),
          ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: Text(l.walletAndRewards), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/wallet')),
          ListTile(leading: const Icon(Icons.emoji_events_outlined), title: Text(l.leaderboard), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/leaderboard')),
          ListTile(leading: const Icon(Icons.groups_outlined), title: Text(l.groups), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/groups')),
          ListTile(leading: const Icon(Icons.storefront_outlined), title: Text(l.pages), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/pages')),
          const _LuckyDrawTile(),
          if (u.referralCode != null) ListTile(leading: const Icon(Icons.card_giftcard_outlined), title: Text(l.inviteFriends), subtitle: Text(l.yourCode(isolate(u.referralCode!))), trailing: IconButton(tooltip: l.copyCode, icon: const Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: u.referralCode!)); toast(context, l.codeCopied); })),
          ListTile(leading: const Icon(Icons.block), title: Text(l.blockedAccounts), trailing: const Icon(Icons.chevron_right), onTap: () => showBlockedAccounts(context)),
          ListTile(leading: const Icon(Icons.language), title: Text(l.language), subtitle: Text(chosen == null ? l.languageSystem : languageEndonyms[chosen.languageCode]!), trailing: const Icon(Icons.chevron_right), onTap: () => _pickLanguage(context, ref, chosen)),
          const Divider(),
          Padding(padding: const EdgeInsets.symmetric(vertical: Sp.s2), child: SegmentedButton<ThemeMode>(
            segments: [ButtonSegment(value: ThemeMode.system, label: Text(l.themeAuto), icon: const Icon(Icons.brightness_auto)), ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight), icon: const Icon(Icons.light_mode_outlined)), ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark), icon: const Icon(Icons.dark_mode_outlined))],
            selected: {mode}, onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          )),
          const SizedBox(height: Sp.s4),
          OutlinedButton.icon(onPressed: () => ref.read(authProvider.notifier).logout(), icon: const Icon(Icons.logout), label: Text(l.signOut)),
          const SizedBox(height: Sp.s2),
          TextButton(onPressed: () => confirmDeleteAccount(context, ref, u), style: TextButton.styleFrom(foregroundColor: context.tk.danger), child: Text(l.deleteAccount)),
        ]),
      ),
    );
  }

  /// Language picker: device default, then each language in its own script. The choice is saved and sent to the server.
  // Root navigator: the sheet must cover the bottom navigation bar, not open underneath it.
  Future<void> _pickLanguage(BuildContext context, WidgetRef ref, Locale? chosen) => showModalBottomSheet(context: context, useRootNavigator: true, showDragHandle: true, builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final code in [null, ...supportedLanguages]) ListTile(
            title: Text(code == null ? c.l10n.languageSystem : languageEndonyms[code]!),
            trailing: chosen?.languageCode == code ? Icon(Icons.check, color: c.tk.brand) : null,
            selected: chosen?.languageCode == code,
            onTap: () { ref.read(localeProvider.notifier).set(code == null ? null : Locale(code)); Navigator.pop(c); },
          ),
        ]),
      ));

  Future<void> _editProfile(BuildContext context, WidgetRef ref, User u) async {
    final name = TextEditingController(text: u.displayName), bio = TextEditingController(text: u.bio ?? '');
    await showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(Sp.s4, 0, Sp.s4, MediaQuery.of(c).viewInsets.bottom + Sp.s4),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: name, maxLength: 80, decoration: InputDecoration(labelText: c.l10n.displayName)),
        const SizedBox(height: Sp.s2),
        TextField(controller: bio, maxLength: 300, maxLines: 3, decoration: InputDecoration(labelText: c.l10n.bio)),
        const SizedBox(height: Sp.s3),
        FilledButton(onPressed: () async {
          try { await ref.read(apiProvider).patch('/users/me', body: {'display_name': name.text.trim(), 'bio': bio.text.trim()}); await ref.read(authProvider.notifier).refreshUser(); if (c.mounted) Navigator.pop(c); } catch (e) { if (c.mounted) toast(c, e.toString()); }
        }, child: Text(c.l10n.save)),
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
      ? ListTile(leading: const Icon(Icons.confirmation_number_outlined), title: Text(context.l10n.luckyDraw), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/luckydraw'))
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
    try { final c = await ref.read(apiProvider).post('/conversations', body: {'type': 'direct', 'user_id': widget.id}); if (mounted) context.push('/chat/${c['id']}?title=${Uri.encodeComponent(_u!.displayName)}&direct=1'); } catch (e) { if (mounted) toast(context, e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    final u = _u; final l = context.l10n;
    return Scaffold(
      appBar: AppBar(actions: [
        // Store-required safety actions on someone else's profile.
        if (u != null && me?.id != u.id) PopupMenuButton<String>(
          tooltip: l.moreOptions,
          onSelected: (v) async {
            if (v == 'report') { await reportUser(context, ref, userId: u.id, name: u.displayName); return; }
            if (await confirmBlock(context, ref, userId: u.id, name: u.displayName) && context.mounted) {
              Navigator.of(context).canPop() ? Navigator.of(context).pop() : _load(); // their profile is hidden from now on
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'report', child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.flag_outlined), title: Text(l.reportUser))),
            PopupMenuItem(value: 'block', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.block, color: context.tk.danger), title: Text(l.blockUser, style: TextStyle(color: context.tk.danger)))),
          ],
        ),
      ]),
      body: _error != null ? ErrorRetry(message: _error!, onRetry: _load) : _u == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(Sp.s4), children: [
        _header(context, _u!, actions: me?.id == _u!.id ? [] : [
          FilledButton(onPressed: _busy ? null : _toggleFollow, child: Text(_u!.isFollowing ? context.l10n.followingButton : context.l10n.follow)),
          OutlinedButton(onPressed: _message, child: Text(context.l10n.message)),
        ]),
      ]),
    );
  }
}
