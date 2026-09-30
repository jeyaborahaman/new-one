/// The API returns timestamps as ISO strings (MySQL) or epoch ms (SQLite dev); accept both.
DateTime parseTime(dynamic v) {
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
  return DateTime.now();
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day}/${t.month}/${t.year}';
}

String compact(int n) => n >= 1000000 ? '${(n / 1000000).toStringAsFixed(1)}M' : n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';

class User {
  User({required this.id, required this.username, required this.displayName, this.bio, this.verified = false, this.level = 1, this.xp = 0, this.followers = 0, this.following = 0, this.twoFactor = false, this.referralCode, this.isFollowing = false});
  final int id, level, xp, followers, following;
  final String username, displayName;
  final String? bio, referralCode;
  final bool verified, twoFactor, isFollowing;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'], username: j['username'], displayName: j['display_name'] ?? j['username'], bio: j['bio'],
        verified: j['is_verified'] == true, level: j['level'] ?? 1, xp: (j['xp'] ?? 0).toInt(), followers: j['followers_count'] ?? 0,
        following: j['following_count'] ?? 0, twoFactor: j['two_factor_enabled'] == true, referralCode: j['referral_code'], isFollowing: j['following'] == true,
      );
  String get initials => displayName.trim().isEmpty ? '?' : displayName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
}

class Author {
  Author({required this.id, required this.username, required this.displayName, this.verified = false, this.level = 1});
  final int id, level; final String username, displayName; final bool verified;
  factory Author.fromJson(Map<String, dynamic> j) => Author(id: j['id'], username: j['username'], displayName: j['display_name'] ?? j['username'], verified: j['is_verified'] == true, level: j['level'] ?? 1);
  String get initials => displayName.trim().isEmpty ? '?' : displayName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
}

class PollOption { PollOption(this.id, this.label, this.votes); final int id, votes; final String label; }

class Post {
  Post({required this.id, required this.type, required this.body, required this.author, required this.createdAt, this.reactions = 0, this.comments = 0, this.myReaction, this.mediaUrl, this.mediaKind, this.pollOptions = const [], this.myVote, this.videoTitle});
  final int id, reactions, comments;
  final String type, body;
  final Author author;
  final DateTime createdAt;
  final String? myReaction, mediaUrl, mediaKind, videoTitle;
  final List<PollOption> pollOptions;
  final int? myVote;

  int get totalVotes => pollOptions.fold(0, (a, o) => a + o.votes);

  Post copyWith({int? reactions, int? comments, String? myReaction, bool clearReaction = false, List<PollOption>? pollOptions, int? myVote}) => Post(
        id: id, type: type, body: body, author: author, createdAt: createdAt, reactions: reactions ?? this.reactions, comments: comments ?? this.comments,
        myReaction: clearReaction ? null : (myReaction ?? this.myReaction), mediaUrl: mediaUrl, mediaKind: mediaKind, pollOptions: pollOptions ?? this.pollOptions,
        myVote: myVote ?? this.myVote, videoTitle: videoTitle,
      );

  factory Post.fromJson(Map<String, dynamic> j) {
    final poll = j['poll'] as Map<String, dynamic>?;
    final media = j['media'] as Map<String, dynamic>?;
    return Post(
      id: j['id'], type: j['type'] ?? 'text', body: j['body'] ?? '', author: Author.fromJson(j['author']), createdAt: parseTime(j['created_at']),
      reactions: j['reactions_count'] ?? 0, comments: j['comments_count'] ?? 0, myReaction: j['my_reaction'], mediaUrl: media?['url'], mediaKind: media?['kind'],
      pollOptions: (poll?['options'] as List? ?? []).map((o) => PollOption(o['id'], o['label'], o['votes'] ?? 0)).toList(), myVote: poll?['my_vote'],
      videoTitle: (j['video'] as Map?)?['title'],
    );
  }
}

class Comment {
  Comment({required this.id, required this.authorId, required this.authorName, required this.body, required this.createdAt, required this.depth, this.parentId});
  final int id, authorId, depth; final int? parentId; final String body, authorName; final DateTime createdAt;
  factory Comment.fromJson(Map<String, dynamic> j) => Comment(id: j['id'], authorId: j['author_id'], authorName: (j['author'] as Map?)?['display_name'] ?? 'Someone', body: j['body'], createdAt: parseTime(j['created_at']), depth: j['depth'] ?? 0, parentId: j['parent_id']);
}

class Conversation {
  Conversation({required this.id, required this.type, required this.title, this.peerId, this.lastBody, this.lastAt, this.unread = 0, this.lastReadId = 0});
  final int id, unread, lastReadId; final String type, title; final int? peerId; final String? lastBody; final DateTime? lastAt;
  factory Conversation.fromJson(Map<String, dynamic> j) {
    final last = j['last_message'] as Map<String, dynamic>?;
    final t = last?['type'];
    return Conversation(
      id: j['id'], type: j['type'], title: j['title'] ?? 'Chat', peerId: (j['peer'] as Map?)?['id'], unread: j['unread'] ?? 0, lastReadId: j['last_read_message_id'] ?? 0,
      lastBody: last == null ? null : (t == 'text' ? last['body'] : 'Sent a $t'), lastAt: last == null ? null : parseTime(last['created_at']),
    );
  }
}

class Message {
  Message({required this.id, required this.senderId, required this.clientId, required this.body, required this.createdAt, required this.conversationId, this.type = 'text', this.pending = false});
  final int id, senderId, conversationId; final String clientId, body, type; final DateTime createdAt; final bool pending;
  factory Message.fromJson(Map<String, dynamic> j) => Message(id: j['id'], senderId: j['sender_id'], clientId: j['client_id'] ?? '', body: j['body'] ?? '', createdAt: parseTime(j['created_at']), conversationId: j['conversation_id'], type: j['type'] ?? 'text');
}

class StoryGroup {
  StoryGroup({required this.user, required this.stories, required this.allSeen});
  final Author user; final List<StoryItem> stories; final bool allSeen;
  factory StoryGroup.fromJson(Map<String, dynamic> j) => StoryGroup(user: Author.fromJson(j['user']), allSeen: j['all_seen'] == true, stories: (j['stories'] as List).map((s) => StoryItem.fromJson(s)).toList());
}
class StoryItem {
  StoryItem(this.id, this.kind, this.url, this.caption, this.seen);
  final int id; final String kind, url; final String? caption; final bool seen;
  factory StoryItem.fromJson(Map<String, dynamic> j) => StoryItem(j['id'], j['kind'], j['url'], j['caption'], j['seen'] == true);
}
