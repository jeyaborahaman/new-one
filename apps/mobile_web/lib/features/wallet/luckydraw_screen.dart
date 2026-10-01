import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/l10n.dart';

final campaignsProvider = FutureProvider.autoDispose<List>((ref) async => (await ref.watch(apiProvider).get('/luckydraw/campaigns'))['data'] as List);

class LuckyDrawScreen extends ConsumerWidget {
  const LuckyDrawScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk; final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.luckyDraw)),
      body: ref.watch(campaignsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.block, title: l.notAvailable, message: l.luckyRegion),
        data: (items) => items.isEmpty ? EmptyState(icon: Icons.confirmation_number_outlined, title: l.noCampaigns) : ListView.separated(
          padding: const EdgeInsets.all(Sp.s4), itemCount: items.length, separatorBuilder: (_, _) => const SizedBox(height: Sp.s3),
          itemBuilder: (c, i) {
            final k = items[i]; final open = k['status'] == 'open';
            return Card(child: Padding(padding: const EdgeInsets.all(Sp.s4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: t.gold, borderRadius: BorderRadius.circular(Rd.pill)), child: Text(l.luckyDraw, style: TextStyle(color: t.onGold, fontWeight: FontWeight.w700, fontSize: 12))),
                const Spacer(), Text(l.campaignStatus('${k['status']}'), style: TextStyle(color: t.inkMuted, fontSize: 12)),
              ]),
              const SizedBox(height: Sp.s3),
              Text(k['title'], style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
              const SizedBox(height: Sp.s2),
              Text(l.entryTerms(k['coins_per_entry'] == 0 ? l.freeEntry : l.coinsPerEntry(k['coins_per_entry']), k['max_entries_per_user']), style: TextStyle(color: t.inkMuted)),
              if (k['disclaimer'] != null) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text(k['disclaimer'], style: TextStyle(fontSize: 12, color: t.inkMuted))),
              const SizedBox(height: Sp.s3),
              if (open) FilledButton(style: FilledButton.styleFrom(backgroundColor: t.gold, foregroundColor: t.onGold), onPressed: () async {
                try { final r = await ref.read(apiProvider).post('/luckydraw/campaigns/${k['id']}/join'); if (context.mounted) toast(context, l.entered(r['entries'], r['max_entries'])); } catch (e) { if (context.mounted) toast(context, e.toString()); }
              }, child: Text(l.getEntry)),
            ])));
          },
        ),
      ),
    );
  }
}
