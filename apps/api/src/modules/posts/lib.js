const db = require('../../db/knex');
const r2 = require('../../integrations/r2');
const { notBlocked } = require('../users/blocks');

/** Query-builder fragment: posts the viewer may see (status, visibility, community privacy, blocks). */
const visibleTo = (viewerId) => function () {
  this.where('posts.status', 'published')
    .andWhere(notBlocked('posts.author_id', viewerId))
    .andWhere(function () {
      this.where('posts.visibility', 'public').orWhere('posts.author_id', viewerId)
        .orWhere(function () { this.where('posts.visibility', 'followers').whereIn('posts.author_id', db('follows').where('follower_id', viewerId).select('followee_id')); });
    })
    .andWhere(function () {
      this.whereNull('posts.community_id')
        .orWhereIn('posts.community_id', db('communities').where('privacy', 'public').select('id'))
        .orWhereIn('posts.community_id', db('community_members').where({ user_id: viewerId, status: 'active' }).select('community_id'));
    });
};

async function hydrate(rows, viewerId) {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const [authors, mine, media, options, votes, videos] = await Promise.all([
    db('users').whereIn('id', [...new Set(rows.map((r) => r.author_id))]).select('id', 'username', 'display_name', 'is_verified', 'level'),
    db('reactions').where({ target_type: 'post', user_id: viewerId }).whereIn('target_id', ids).select('target_id', 'kind'),
    db('media').whereIn('id', rows.map((r) => r.media_id).filter(Boolean)).select('id', 'kind', 'r2_key'),
    db('poll_options').whereIn('post_id', ids).orderBy('id'),
    db('poll_votes').where({ user_id: viewerId }).whereIn('post_id', ids),
    db('videos').whereIn('post_id', ids),
  ]);
  const A = Object.fromEntries(authors.map((a) => [a.id, { ...a, is_verified: !!a.is_verified }]));
  const M = Object.fromEntries(mine.map((m) => [m.target_id, m.kind]));
  const MD = Object.fromEntries(media.map((m) => [m.id, { kind: m.kind, url: r2.publicUrl(m.r2_key) }]));
  const V = Object.fromEntries(votes.map((v) => [v.post_id, v.option_id]));
  const VID = Object.fromEntries(videos.map((v) => [v.post_id, v]));
  return rows.map((r) => {
    const opts = options.filter((o) => o.post_id === r.id);
    return {
      id: r.id, type: r.type, body: r.body, visibility: r.visibility, community_id: r.community_id, created_at: r.created_at,
      reactions_count: r.reactions_count, comments_count: r.comments_count, author: A[r.author_id], my_reaction: M[r.id] || null,
      media: r.media_id ? MD[r.media_id] || null : null,
      poll: opts.length ? { options: opts.map((o) => ({ id: o.id, label: o.label, votes: o.votes_count })), my_vote: V[r.id] || null, closes_at: r.poll_closes_at, total_votes: opts.reduce((a, o) => a + o.votes_count, 0) } : undefined,
      video: VID[r.id] ? { title: VID[r.id].title, category_id: VID[r.id].category_id, is_short: !!VID[r.id].is_short, views: Number(VID[r.id].views_count) } : undefined,
    };
  });
}

/** #hashtags and @mentions -> link rows; returns mentioned user ids. */
async function indexText(trx, postId, text) {
  const tags = [...new Set([...text.matchAll(/(?:^|\s)#([\p{L}\p{N}_]{2,50})/gu)].map((m) => m[1].toLowerCase()))].slice(0, 20);
  for (const tag of tags) {
    await trx('hashtags').insert({ tag, uses: 0 }).onConflict('tag').ignore();
    const h = await trx('hashtags').where({ tag }).first('id');
    await trx('post_hashtags').insert({ post_id: postId, hashtag_id: h.id }).onConflict(['hashtag_id', 'post_id']).ignore();
    await trx('hashtags').where({ id: h.id }).increment('uses', 1);
  }
  const names = [...new Set([...text.matchAll(/(?:^|\s)@([a-zA-Z0-9_]{3,30})/g)].map((m) => m[1].toLowerCase()))].slice(0, 10);
  return names.length ? (await trx('users').whereIn('username', names).where({ status: 'active' }).select('id')).map((u) => u.id) : [];
}

const newestFirst = async (baseQuery, { limit, cursor }, viewerId) => {
  const q = baseQuery.orderBy('posts.id', 'desc').limit(limit + 1).select('posts.*');
  if (cursor) q.where('posts.id', '<', cursor);
  const rows = await q;
  const data = rows.slice(0, limit);
  return { data: await hydrate(data, viewerId), next_cursor: rows.length > limit ? data[data.length - 1].id : null };
};

module.exports = { visibleTo, hydrate, indexText, newestFirst };
