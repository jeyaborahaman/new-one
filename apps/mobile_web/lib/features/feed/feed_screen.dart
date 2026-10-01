import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/providers.dart';
import 'feed_state.dart';
import 'post_card.dart';
import '../../core/l10n.dart';

class FeedScreen extends ConsumerStatefulWidget { const FeedScreen({super.key}); @override ConsumerState<FeedScreen> createState() => _State(); }
class _State extends ConsumerState<FeedScreen> {
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(feedProvider.notifier).refresh());
    _scroll.addListener(() { if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) ref.read(feedProvider.notifier).loadMore(); });
  }
  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(feedProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Jeyabo', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: context.tk.brand, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: context.l10n.search, icon: const Icon(Icons.search_rounded), onPressed: () => context.push('/search')),
          IconButton(tooltip: context.l10n.notifications, icon: const Icon(Icons.notifications_none_rounded), onPressed: () => context.push('/notifications')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ref.read(feedProvider.notifier).refresh,
        child: s.loading
            ? ListView(padding: const EdgeInsets.all(Sp.s4), children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: Sp.s4), child: Skeleton(height: 180, radius: Rd.lg))))
            : s.error != null && s.posts.isEmpty
                ? ListView(children: [SizedBox(height: 400, child: ErrorRetry(message: s.error!, onRetry: ref.read(feedProvider.notifier).refresh))])
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView.separated(
                        controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(Sp.s4),
                        itemCount: s.posts.length + 2, separatorBuilder: (_, _) => const SizedBox(height: Sp.s3),
                        itemBuilder: (c, i) {
                          if (i == 0) return _StoryTray(s.stories);
                          if (i == s.posts.length + 1) return s.loadingMore ? const Center(child: Padding(padding: EdgeInsets.all(Sp.s4), child: CircularProgressIndicator())) : (s.posts.isEmpty ? EmptyState(icon: Icons.dynamic_feed_rounded, title: context.l10n.feedEmptyTitle, message: context.l10n.feedEmptyMessage) : const SizedBox(height: 80));
                          return PostCard(s.posts[i - 1]);
                        },
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _StoryTray extends ConsumerWidget {
  const _StoryTray(this.groups);
  final List<StoryGroup> groups;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    final hasMine = groups.any((g) => g.user.id == me?.id);
    final l = context.l10n;
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (!hasMine) _tile(context, label: l.yourStory, child: Stack(clipBehavior: Clip.none, children: [
            JAvatar(me?.initials ?? '?', size: 60),
            PositionedDirectional(end: -2, bottom: -2, child: Container(decoration: BoxDecoration(color: context.tk.brand, shape: BoxShape.circle, border: Border.all(color: context.tk.bg, width: 2)), child: Icon(Icons.add, size: 18, color: context.tk.onBrand))),
          ]), onTap: () => context.push('/story/new'), semantic: l.addToYourStory),
          for (var i = 0; i < groups.length; i++) _tile(context, label: groups[i].user.id == me?.id ? l.yourStory : groups[i].user.displayName.split(' ').first, child: StoryRing(initials: groups[i].user.initials, seen: groups[i].allSeen, label: groups[i].user.displayName), onTap: () => context.push('/story/view', extra: (groups, i)), semantic: l.userStorySemantic(groups[i].user.displayName)),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, {required String label, required Widget child, required VoidCallback onTap, required String semantic}) => Padding(
        padding: const EdgeInsetsDirectional.only(end: Sp.s3),
        child: Semantics(button: true, label: semantic, excludeSemantics: true, onTap: onTap, child: InkWell(borderRadius: BorderRadius.circular(Rd.md), onTap: onTap, child: SizedBox(width: 68, child: Column(children: [child, const SizedBox(height: 4), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))])))),
      );
}
