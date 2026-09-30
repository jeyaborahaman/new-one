import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';

class FeedState {
  const FeedState({this.posts = const [], this.cursor, this.loading = false, this.loadingMore = false, this.error, this.stories = const []});
  final List<Post> posts; final int? cursor; final bool loading, loadingMore; final String? error; final List<StoryGroup> stories;
  bool get hasMore => cursor != null;
  FeedState copy({List<Post>? posts, int? cursor, bool clearCursor = false, bool? loading, bool? loadingMore, String? error, bool clearError = false, List<StoryGroup>? stories}) => FeedState(
      posts: posts ?? this.posts, cursor: clearCursor ? null : (cursor ?? this.cursor), loading: loading ?? this.loading, loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error), stories: stories ?? this.stories);
}

class FeedController extends Notifier<FeedState> {
  @override
  FeedState build() => const FeedState(loading: true);
  ApiClient get _api => ref.read(apiProvider);

  Future<void> refresh() async {
    state = state.copy(loading: state.posts.isEmpty, clearError: true);
    try {
      final r = await _api.get('/posts/feed', q: {'limit': 20});
      final s = await _api.get('/stories');
      state = FeedState(
        posts: (r['data'] as List).map((p) => Post.fromJson(p)).toList(), cursor: r['next_cursor'],
        stories: (s['data'] as List).map((g) => StoryGroup.fromJson(g)).toList(),
      );
    } catch (e) { state = state.copy(loading: false, error: e.toString()); }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    state = state.copy(loadingMore: true);
    try {
      final r = await _api.get('/posts/feed', q: {'limit': 20, 'cursor': state.cursor});
      state = state.copy(posts: [...state.posts, ...(r['data'] as List).map((p) => Post.fromJson(p))], cursor: r['next_cursor'], clearCursor: r['next_cursor'] == null, loadingMore: false);
    } catch (_) { state = state.copy(loadingMore: false); }
  }

  void _replace(int id, Post Function(Post) f) => state = state.copy(posts: [for (final p in state.posts) p.id == id ? f(p) : p]);

  /// Optimistic reaction: update instantly, roll back if the server refuses.
  Future<void> react(Post p, String? kind) async {
    final had = p.myReaction != null;
    final delta = kind == null ? -1 : (had ? 0 : 1);
    _replace(p.id, (x) => kind == null ? x.copyWith(reactions: (x.reactions + delta).clamp(0, 1 << 30), clearReaction: true) : x.copyWith(reactions: x.reactions + delta, myReaction: kind));
    try { kind == null ? await _api.delete('/posts/${p.id}/reaction') : await _api.put('/posts/${p.id}/reaction', body: {'kind': kind}); }
    catch (_) { _replace(p.id, (_) => p); }
  }

  Future<void> vote(Post p, int optionId) async {
    final r = await _api.post('/posts/${p.id}/vote', body: {'option_id': optionId});
    _replace(p.id, (x) => x.copyWith(pollOptions: (r['options'] as List).map((o) => PollOption(o['id'], o['label'], o['votes'])).toList(), myVote: r['my_vote']));
  }

  void bumpComments(int id) => _replace(id, (x) => x.copyWith(comments: x.comments + 1));
  void prepend(Post p) => state = state.copy(posts: [p, ...state.posts]);
}
final feedProvider = NotifierProvider<FeedController, FeedState>(FeedController.new);
