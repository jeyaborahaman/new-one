import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/core/models.dart';

void main() {
  test('parseTime accepts ISO strings and epoch milliseconds', () {
    expect(parseTime(1790727815000).millisecondsSinceEpoch, 1790727815000);
    expect(parseTime('2026-09-30T10:00:00Z').toUtc().hour, 10);
    expect(parseTime(null).difference(DateTime.now()).inSeconds.abs() < 2, true);
  });

  test('Post.fromJson parses media, poll and reaction', () {
    final p = Post.fromJson({
      'id': 7, 'type': 'poll', 'body': 'Best? #x', 'created_at': 1790727815000, 'reactions_count': 3, 'comments_count': 1, 'my_reaction': 'love',
      'author': {'id': 2, 'username': 'ann', 'display_name': 'Ann Lee', 'is_verified': true, 'level': 4},
      'poll': {'options': [{'id': 1, 'label': 'A', 'votes': 3}, {'id': 2, 'label': 'B', 'votes': 1}], 'my_vote': 1},
      'media': {'kind': 'image', 'url': 'https://cdn/x.jpg'},
    });
    expect(p.author.initials, 'AL'); expect(p.totalVotes, 4); expect(p.myVote, 1); expect(p.mediaUrl, 'https://cdn/x.jpg'); expect(p.myReaction, 'love');
    expect(p.copyWith(clearReaction: true).myReaction, isNull);
  });

  test('Conversation preview for non-text messages', () {
    final c = Conversation.fromJson({'id': 1, 'type': 'direct', 'title': 'Zed', 'unread': 2, 'last_message': {'type': 'voice', 'body': null, 'created_at': 1790727815000}});
    expect(c.lastType, 'voice'); expect(c.lastBody, isNull); expect(c.unread, 2);
  });
}
