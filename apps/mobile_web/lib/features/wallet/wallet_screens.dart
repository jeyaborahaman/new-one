import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';

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
    try { final r = await ref.read(apiProvider).post('/rewards/daily/claim'); if (mounted) toast(context, context.l10n.streakReward(r['streak'], r['coins'])); ref.invalidate(walletProvider); }
    catch (e) { if (mounted) toast(context, e.toString()); } finally { if (mounted) setState(() => _claiming = false); }
  }
  Future<void> _challenge(int id, String action) async {
    try { await ref.read(apiProvider).post('/challenges/$id/$action'); ref.invalidate(walletProvider); if (mounted && action == 'claim') toast(context, context.l10n.rewardClaimed); } catch (e) { if (mounted) toast(context, e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk; final w = ref.watch(walletProvider); final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.walletAndRewards)),
      body: w.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(message: e.toString(), onRetry: () => ref.invalidate(walletProvider)),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.refresh(walletProvider.future),
          child: ListView(padding: const EdgeInsets.all(Sp.s4), children: [
            Card(color: t.gold, child: Padding(padding: const EdgeInsets.all(Sp.s6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.coins, style: TextStyle(color: t.onGold, fontWeight: FontWeight.w600)),
              Text(context.number(d['balance']), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: t.onGold, fontSize: 48)),
              const SizedBox(height: Sp.s3),
              FilledButton(onPressed: _claiming ? null : _claim, style: FilledButton.styleFrom(backgroundColor: t.onGold, foregroundColor: t.gold), child: Text(l.claimDaily)),
            ]))),
            const SizedBox(height: Sp.s4),
            Text(l.badges, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Sp.s2),
            (d['badges'] as List).isEmpty ? Text(l.noBadges, style: TextStyle(color: t.inkMuted)) : Wrap(spacing: Sp.s2, runSpacing: Sp.s2, children: [for (final b in d['badges']) Chip(avatar: const Icon(Icons.military_tech, size: 18), label: Text(l.badgeName('${b['code']}', '${b['name']}')))]),
            const SizedBox(height: Sp.s4),
            if ((d['challenges'] as List).isNotEmpty) ...[
              Text(l.challenges, style: Theme.of(context).textTheme.titleLarge),
              for (final c in d['challenges']) Card(child: ListTile(
                title: Text(c['title']), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 6), LinearProgressIndicator(value: (c['progress'] as int) / (c['target'] as int), color: t.brand, backgroundColor: t.surfaceRaised), Text(l.challengeProgress(c['progress'], c['target'], c['reward_coins']), style: TextStyle(fontSize: 12, color: t.inkMuted))]),
                trailing: c['claimed'] == true ? const Icon(Icons.check_circle) : !(c['joined'] as bool) ? TextButton(onPressed: () => _challenge(c['id'], 'join'), child: Text(l.join)) : (c['progress'] as int) >= (c['target'] as int) ? FilledButton(onPressed: () => _challenge(c['id'], 'claim'), child: Text(l.claim)) : null,
              )),
              const SizedBox(height: Sp.s4),
            ],
            Text(l.history, style: Theme.of(context).textTheme.titleLarge),
            if ((d['tx'] as List).isEmpty) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text(l.noTransactions, style: TextStyle(color: t.inkMuted))),
            for (final x in d['tx']) ListTile(contentPadding: EdgeInsets.zero, title: Text(_reasonLabel(l, '${x['reason']}')), subtitle: Text(context.timeAgo(parseTime(x['created_at']))), trailing: Text(context.signedNumber(x['amount']), style: TextStyle(fontWeight: FontWeight.w800, color: x['amount'] > 0 ? t.brand : t.danger))),
          ]),
        ),
      ),
    );
  }
}

/// Known ledger reasons are translated; anything new shows as the raw reason, capitalised.
String _reasonLabel(AppLocalizations l, String reason) {
  final label = l.txReason(reason);
  return label == reason && reason.isNotEmpty ? reason[0].toUpperCase() + reason.substring(1) : label;
}

class LeaderboardScreen extends ConsumerStatefulWidget { const LeaderboardScreen({super.key}); @override ConsumerState<LeaderboardScreen> createState() => _LState(); }
class _LState extends ConsumerState<LeaderboardScreen> {
  String _period = 'week';
  late Future<List> _f = _load();
  Future<List> _load() async => (await ref.read(apiProvider).get('/leaderboards/$_period'))['data'] as List;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
        appBar: AppBar(title: Text(l.leaderboard)),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(Sp.s4), child: SegmentedButton<String>(segments: [ButtonSegment(value: 'week', label: Text(l.thisWeek)), ButtonSegment(value: 'all', label: Text(l.allTime))], selected: {_period}, onSelectionChanged: (s) => setState(() { _period = s.first; _f = _load(); }))),
          Expanded(child: FutureBuilder<List>(future: _f, builder: (c, s) {
            if (s.hasError) return ErrorRetry(message: s.error.toString(), onRetry: () => setState(() => _f = _load()));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final rows = s.data!;
            if (rows.isEmpty) return EmptyState(icon: Icons.emoji_events_outlined, title: l.noActivity);
            return ListView.builder(itemCount: rows.length, itemBuilder: (c, i) => ListTile(
              leading: SizedBox(width: 72, child: Row(children: [SizedBox(width: 28, child: Text(c.number(i + 1), style: const TextStyle(fontWeight: FontWeight.w800))), JAvatar(rows[i]['display_name'].toString().trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join(), size: 36)])),
              title: Text(rows[i]['display_name']), subtitle: Text(l.levelN(rows[i]['level'])), trailing: Text(l.xpCount(num.parse('${rows[i]['xp']}').toInt()), style: const TextStyle(fontWeight: FontWeight.w800)),
            ));
          })),
        ]),
      );
  }
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
  IconData _icon(String t) => switch (t) { 'message' => Icons.chat_bubble_outline, 'follow' => Icons.person_add_alt, 'friend_request' => Icons.group_add_outlined, 'reaction' => Icons.favorite_border, 'comment' => Icons.mode_comment_outlined, 'mention' => Icons.alternate_email, 'story' => Icons.auto_stories_outlined, 'reward' => Icons.stars_outlined, 'luckydraw' => Icons.confirmation_number_outlined, 'call' => Icons.phone_missed_outlined, _ => Icons.notifications_none };
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.notifications)),
        body: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (c, s) {
          if (s.hasError) return ErrorRetry(message: s.error.toString(), onRetry: () => setState(() => _f = _load()));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final items = s.data!['data'] as List;
          if (items.isEmpty) return EmptyState(icon: Icons.notifications_none_rounded, title: context.l10n.allCaughtUp, message: context.l10n.newActivity);
          return ListView.separated(itemCount: items.length, separatorBuilder: (_, _) => const Divider(indent: 72), itemBuilder: (c, i) {
            final n = items[i]; final p = (n['payload'] as Map?) ?? {}; final unread = n['read_at'] == null;
            return ListTile(leading: CircleAvatar(backgroundColor: context.tk.brandSoft, foregroundColor: context.tk.ink, child: Icon(_icon(n['type']))), title: Text(p['title'] ?? '', style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)), subtitle: Text(p['body'] ?? '', textDirection: contentDirection('${p['body'] ?? ''}')), trailing: Text(context.timeAgo(parseTime(n['created_at'])), style: TextStyle(fontSize: 12, color: context.tk.inkMuted)));
          });
        }),
      );
}
