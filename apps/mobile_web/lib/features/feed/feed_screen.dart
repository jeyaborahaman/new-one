import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import 'feed_state.dart';
import 'post_card.dart';

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
          IconButton(tooltip: 'Search', icon: const Icon(Icons.search_rounded), onPressed: () => context.push('/search')),
          IconButton(tooltip: 'Notifications', icon: const Icon(Icons.notifications_none_rounded), onPressed: () => context.push('/notifications')),
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
                          if (i == s.posts.length + 1) return s.loadingMore ? const Center(child: Padding(padding: EdgeInsets.all(Sp.s4), child: CircularProgressIndicator())) : (s.posts.isEmpty ? const EmptyState(icon: Icons.dynamic_feed_rounded, title: 'Your feed is quiet', message: 'Follow people or create your first post.') : const SizedBox(height: 80));
                          return PostCard(s.posts[i - 1]);
                        },
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _StoryTray extends StatelessWidget {
  const _StoryTray(this.groups);
  final List<StoryGroup> groups;
  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: groups.length, separatorBuilder: (_, _) => const SizedBox(width: Sp.s3),
        itemBuilder: (c, i) {
          final g = groups[i];
          return SizedBox(width: 68, child: Column(children: [StoryRing(initials: g.user.initials, seen: g.allSeen, label: g.user.displayName), const SizedBox(height: 4), Text(g.user.displayName.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))]));
        },
      ),
    );
  }
}
