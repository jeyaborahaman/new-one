import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import 'comments_sheet.dart';
import 'feed_state.dart';
import 'inline_video.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../profile/safety.dart';

class PostCard extends ConsumerWidget {
  const PostCard(this.post, {super.key, this.onReact, this.onVote});
  final Post post;
  /// For lists other than the home feed (group/page feeds): the owner of the list applies the change.
  final void Function(Post post, String? kind)? onReact;
  final Future<void> Function(Post post, int optionId)? onVote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk; final l = context.l10n;
    final feed = ref.read(feedProvider.notifier);
    final mine = ref.watch(authProvider).user?.id == post.author.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Sp.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            JAvatar(post.author.initials),
            const SizedBox(width: Sp.s3),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(post.author.displayName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (post.author.verified) Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.verified, size: 16, color: t.brand, semanticLabel: l.verified)),
              ]),
              Text('${isolate('@${post.author.username}')} · ${context.timeAgo(post.createdAt)}', style: TextStyle(fontSize: 12, color: t.inkMuted)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: t.gold, borderRadius: BorderRadius.circular(Rd.pill)), child: Text(l.levelShort(post.author.level), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.onGold))),
            if (!mine) ReportMenuButton(onReport: () => reportPost(context, postId: post.id)), // others' posts only
          ]),
          const SizedBox(height: Sp.s3),
          _RichBody(post.body),
          if (post.mediaUrl != null && post.mediaKind == 'image') Padding(
            padding: const EdgeInsets.only(top: Sp.s3),
            child: ClipRRect(borderRadius: BorderRadius.circular(Rd.md), child: Image.network(post.mediaUrl!, fit: BoxFit.cover, width: double.infinity, height: 260, loadingBuilder: (c, w, p) => p == null ? w : const Skeleton(height: 260), errorBuilder: (c, e, s) => Container(height: 120, color: t.surfaceRaised, alignment: Alignment.center, child: Text(l.imageUnavailable, style: TextStyle(color: t.inkMuted))))),
          ),
          if (post.mediaUrl != null && post.mediaKind == 'video') Padding(padding: const EdgeInsets.only(top: Sp.s3), child: InlineVideo(url: post.mediaUrl!, title: post.videoTitle)),
          if (post.pollOptions.isNotEmpty) _Poll(post: post, onVote: (id) => (onVote?.call(post, id) ?? feed.vote(post, id)).catchError((e) { if (context.mounted) toast(context, e.toString()); })),
          const SizedBox(height: Sp.s3),
          Row(children: [
            _ReactionButton(post: post, onPick: (k) => onReact != null ? onReact!(post, k) : feed.react(post, k)),
            const SizedBox(width: Sp.s2),
            Semantics(container: true, button: true, excludeSemantics: true, label: l.commentsSemantic(post.comments), onTap: () => showCommentsSheet(context, post), child: TextButton.icon(onPressed: () => showCommentsSheet(context, post), icon: const Icon(Icons.mode_comment_outlined, size: 20), label: Text(context.compact(post.comments)), style: TextButton.styleFrom(foregroundColor: t.inkMuted))),
          ]),
        ]),
      ),
    );
  }
}

/// #hashtags in brand colour, @mentions on brand-soft.
class _RichBody extends StatelessWidget {
  const _RichBody(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final spans = <InlineSpan>[];
    final re = RegExp(r'(#[\p{L}\p{N}_]{2,50})|(@[a-zA-Z0-9_]{3,30})', unicode: true);
    var i = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
      final tag = m.group(1) != null;
      spans.add(TextSpan(text: m.group(0), style: tag ? TextStyle(color: t.brand, fontWeight: FontWeight.w700) : TextStyle(backgroundColor: t.brandSoft, fontWeight: FontWeight.w600)));
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    // Posts are written in any language: lay the text out in its own direction, whatever the UI language.
    return Text.rich(TextSpan(children: spans), textDirection: contentDirection(text), style: const TextStyle(fontSize: 15, height: 22 / 15));
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({required this.post, required this.onPick});
  final Post post; final void Function(String?) onPick;
  @override
  Widget build(BuildContext context) {
    final t = context.tk; final l = context.l10n;
    final mine = post.myReaction;
    return MenuAnchor(
      builder: (c, ctrl, _) {
        void toggle() => onPick(mine == null ? 'like' : null);
        // One labelled node (container: true) so it does not merge into the whole card for screen readers.
        return Semantics(
          container: true, button: true, excludeSemantics: true,
          label: mine == null ? l.reactSemantic(post.reactions) : l.yourReactionSemantic(l.reactionName(mine), post.reactions),
          hint: l.reactHint, onTap: toggle, onLongPress: ctrl.open,
          child: GestureDetector(
            onLongPress: ctrl.open,
            child: TextButton.icon(
              onPressed: toggle,
              icon: mine == null ? Icon(Icons.thumb_up_outlined, size: 20, color: t.inkMuted) : Text(reactionEmoji[mine]!, style: const TextStyle(fontSize: 18)),
              label: Text(context.compact(post.reactions), style: TextStyle(color: mine == null ? t.inkMuted : t.brand, fontWeight: mine == null ? FontWeight.w500 : FontWeight.w700)),
            ),
          ),
        );
      },
      menuChildren: [for (final e in reactionEmoji.entries) MenuItemButton(onPressed: () => onPick(e.key), child: Text('${e.value} ${l.reactionName(e.key)}', style: const TextStyle(fontSize: 16)))],
    );
  }
}

class _Poll extends StatelessWidget {
  const _Poll({required this.post, required this.onVote});
  final Post post; final void Function(int) onVote;
  @override
  Widget build(BuildContext context) {
    final t = context.tk; final voted = post.myVote != null; final total = post.totalVotes;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.s3),
      child: Column(children: [
        for (final o in post.pollOptions) Padding(
          padding: const EdgeInsets.only(bottom: Sp.s2),
          child: InkWell(
            borderRadius: BorderRadius.circular(Rd.md), onTap: voted ? null : () => onVote(o.id),
            child: Stack(children: [
              if (voted) Positioned.fill(child: FractionallySizedBox(alignment: AlignmentDirectional.centerStart, widthFactor: total == 0 ? 0 : o.votes / total, child: Container(decoration: BoxDecoration(color: post.myVote == o.id ? t.brandSoft : t.surfaceRaised, borderRadius: BorderRadius.circular(Rd.md))))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Sp.s3, vertical: Sp.s3),
                decoration: BoxDecoration(border: Border.all(color: post.myVote == o.id ? t.brand : t.borderStrong), borderRadius: BorderRadius.circular(Rd.md)),
                child: Row(children: [Expanded(child: Text(o.label)), if (voted) Text(context.percent(total == 0 ? 0 : o.votes / total), style: const TextStyle(fontWeight: FontWeight.w700))]),
              ),
            ]),
          ),
        ),
        Align(alignment: AlignmentDirectional.centerStart, child: Text(context.l10n.pollVotes(total), style: TextStyle(fontSize: 12, color: t.inkMuted))),
      ]),
    );
  }
}
