import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';

final walletProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiProvider);
  final w = await api.get('/wallet'); final tx = await api.get('/wallet/transactions', q: {'limit': 30}); final b = await api.get('/me/badges'); final c = await api.get('/challenges');
  return {'balance': w['balance'], 'tx': tx['data'], 'badges': b['data'], 'challenges': c['data']};
});

class WalletScreen extends ConsumerStatefulWidget { const WalletScreen({super.key}); @override ConsumerState<WalletScreen> createState() => _State(); }
class _State extends ConsumerState<WalletScreen> {
  bool _claiming = false;
  Future<void> _claim() async {
    setState(() => _claiming = true);
    try { final r = await ref.read(apiProvider).post('/rewards/daily/claim'); if (mounted) toast(context, 'Day ${r['streak']} streak: +${r['coins']} coins'); ref.invalidate(walletProvider); }
    catch (e) { if (mounted) toast(context, e.toString()); } finally { if (mounted) setState(() => _claiming = false); }
  }
  Future<void> _challenge(int id, String action) async {
    try { await ref.read(apiProvider).post('/challenges/$id/$action'); ref.invalidate(walletProvider); if (mounted && action == 'claim') toast(context, 'Reward claimed'); } catch (e) { if (mounted) toast(context, e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk; final w = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet and rewards')),
      body: w.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(message: e.toString(), onRetry: () => ref.invalidate(walletProvider)),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.refresh(walletProvider.future),
          child: ListView(padding: const EdgeInsets.all(Sp.s4), children: [
            Card(color: t.gold, child: Padding(padding: const EdgeInsets.all(Sp.s6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Coins', style: TextStyle(color: t.onGold, fontWeight: FontWeight.w600)),
              Text('${d['balance']}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: t.onGold, fontSize: 48)),
              const SizedBox(height: Sp.s3),
              FilledButton(onPressed: _claiming ? null : _claim, style: FilledButton.styleFrom(backgroundColor: t.onGold, foregroundColor: t.gold), child: const Text('Claim daily reward')),
            ]))),
            const SizedBox(height: Sp.s4),
            Text('Badges', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Sp.s2),
            (d['badges'] as List).isEmpty ? Text('No badges yet. Post, comment and invite friends to earn them.', style: TextStyle(color: t.inkMuted)) : Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [for (final b in d['badges']) Chip(avatar: const Icon(Icons.military_tech, size: 18), label: Text(b['name']))]),
            const SizedBox(height: Sp.s4),
            if ((d['challenges'] as List).isNotEmpty) ...[
              Text('Challenges', style: Theme.of(context).textTheme.titleLarge),
              for (final c in d['challenges']) Card(child: ListTile(
                title: Text(c['title']), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 6), LinearProgressIndicator(value: (c['progress'] as int) / (c['target'] as int), color: t.brand, backgroundColor: t.surfaceRaised), Text('${c['progress']}/${c['target']} · +${c['reward_coins']} coins', style: TextStyle(fontSize: 12, color: t.inkMuted))]),
                trailing: c['claimed'] == true ? const Icon(Icons.check_circle) : !(c['joined'] as bool) ? TextButton(onPressed: () => _challenge(c['id'], 'join'), child: const Text('Join')) : (c['progress'] as int) >= (c['target'] as int) ? FilledButton(onPressed: () => _challenge(c['id'], 'claim'), child: const Text('Claim')) : null,
              )),
              const SizedBox(height: Sp.s4),
            ],
            Text('History', style: Theme.of(context).textTheme.titleLarge),
            if ((d['tx'] as List).isEmpty) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text('No transactions yet.', style: TextStyle(color: t.inkMuted))),
            for (final x in d['tx']) ListTile(contentPadding: EdgeInsets.zero, title: Text(x['reason'].toString().replaceFirst(x['reason'][0], x['reason'][0].toUpperCase())), subtitle: Text(timeAgo(parseTime(x['created_at']))), trailing: Text('${x['amount'] > 0 ? '+' : ''}${x['amount']}', style: TextStyle(fontWeight: FontWeight.w800, color: x['amount'] > 0 ? t.brand : t.danger))),
          ]),
        ),
      ),
    );
  }
}

class LeaderboardScreen extends ConsumerStatefulWidget { const LeaderboardScreen({super.key}); @override ConsumerState<LeaderboardScreen> createState() => _LState(); }
class _LState extends ConsumerState<LeaderboardScreen> {
  String _period = 'week';
  late Future<List> _f = _load();
  Future<List> _load() async => (await ref.read(apiProvider).get('/leaderboards/$_period'))['data'] as List;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Leaderboard')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(Sp.s4), child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'week', label: Text('This week')), ButtonSegment(value: 'all', label: Text('All time'))], selected: {_period}, onSelectionChanged: (s) => setState(() { _period = s.first; _f = _load(); }))),
          Expanded(child: FutureBuilder<List>(future: _f, builder: (c, s) {
            if (s.hasError) return ErrorRetry(message: s.error.toString(), onRetry: () => setState(() => _f = _load()));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final rows = s.data!;
            if (rows.isEmpty) return const EmptyState(icon: Icons.emoji_events_outlined, title: 'No activity yet');
            return ListView.builder(itemCount: rows.length, itemBuilder: (c, i) => ListTile(
              leading: SizedBox(width: 72, child: Row(children: [SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))), JAvatar(rows[i]['display_name'].toString().trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join(), size: 36)])),
              title: Text(rows[i]['display_name']), subtitle: Text('Level ${rows[i]['level']}'), trailing: Text('${rows[i]['xp']} XP', style: const TextStyle(fontWeight: FontWeight.w800)),
            ));
          })),
        ]),
      );
}

class NotificationsScreen extends ConsumerStatefulWidget { const NotificationsScreen({super.key}); @override ConsumerState<NotificationsScreen> createState() => _NState(); }
class _NState extends ConsumerState<NotificationsScreen> {
  late Future<Map<String, dynamic>> _f = _load();
  Future<Map<String, dynamic>> _load() async {
    final r = await ref.read(apiProvider).get('/notifications', q: {'limit': 50}) as Map<String, dynamic>;
    final list = r['data'] as List;
    if (list.isNotEmpty) ref.read(apiProvider).post('/notifications/read', body: {'up_to_id': list.first['id']}).catchError((_) {});
    return r;
  }
  IconData _icon(String t) => switch (t) { 'message' => Icons.chat_bubble_outline, 'follow' => Icons.person_add_alt, 'friend_request' => Icons.group_add_outlined, 'reaction' => Icons.favorite_border, 'comment' => Icons.mode_comment_outlined, 'mention' => Icons.alternate_email, 'story' => Icons.auto_stories_outlined, 'reward' => Icons.stars_outlined, 'luckydraw' => Icons.confirmation_number_outlined, _ => Icons.notifications_none };
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (c, s) {
          if (s.hasError) return ErrorRetry(message: s.error.toString(), onRetry: () => setState(() => _f = _load()));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final items = s.data!['data'] as List;
          if (items.isEmpty) return const EmptyState(icon: Icons.notifications_none_rounded, title: 'All caught up', message: 'New activity will show up here.');
          return ListView.separated(itemCount: items.length, separatorBuilder: (_, _) => const Divider(indent: 72), itemBuilder: (c, i) {
            final n = items[i]; final p = (n['payload'] as Map?) ?? {}; final unread = n['read_at'] == null;
            return ListTile(leading: CircleAvatar(backgroundColor: context.tk.brandSoft, foregroundColor: context.tk.ink, child: Icon(_icon(n['type']))), title: Text(p['title'] ?? '', style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)), subtitle: Text(p['body'] ?? ''), trailing: Text(timeAgo(parseTime(n['created_at'])), style: TextStyle(fontSize: 12, color: context.tk.inkMuted)));
          });
        }),
      );
}
