const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { pageQuery } = require('../../utils/pagination');
const ai = require('../../integrations/ai');
const { visibleTo, hydrate, newestFirst } = require('../posts/lib');
const { notBlocked } = require('../users/blocks');
router.use(authenticate);

const like = (s) => `%${s.replace(/[\\%_]/g, '')}%`;

// Smart search: handles @user, #tag and free text; ranks exact/prefix matches above substrings.
router.get('/search', validate({ query: z.object({ q: z.string().trim().min(1).max(100), type: z.enum(['all', 'users', 'posts', 'videos', 'communities', 'hashtags']).default('all') }) }), asyncHandler(async (req, res) => {
  let { q } = req.query; const { type } = req.query;
  const want = (t) => type === 'all' || type === t;
  const out = {};
  const term = q.replace(/^[@#]/, '');
  if (!term) throw err.badRequest('Empty query');
  if (!term.replace(/[\\%_]/g, '').trim()) return res.json({ users: [], posts: [], communities: [], hashtags: [] }); // only wildcards
  if (want('users') && !q.startsWith('#')) {
    out.users = await db('users').where({ status: 'active' }).where(notBlocked('id', req.user.id)).andWhere((w) => w.where('username', 'like', like(term)).orWhere('display_name', 'like', like(term)))
      .orderByRaw('case when username = ? then 0 when username like ? then 1 else 2 end, followers_count desc', [term.toLowerCase(), `${term.toLowerCase()}%`]).limit(15).select('id', 'username', 'display_name', 'is_verified', 'followers_count');
  }
  if (want('hashtags') || q.startsWith('#')) out.hashtags = await db('hashtags').where('tag', 'like', like(term.toLowerCase())).orderBy('uses', 'desc').limit(15);
  if ((want('posts') || want('videos')) && !q.startsWith('@')) {
    const pq = db('posts').where(visibleTo(req.user.id)).where('posts.visibility', 'public').where('posts.body', 'like', like(term)).orderBy('posts.id', 'desc').limit(20).select('posts.*');
    if (type === 'videos') pq.whereIn('posts.type', ['reel', 'long_video']);
    out.posts = await hydrate(await pq, req.user.id);
  }
  if (want('communities') && !q.startsWith('#') && !q.startsWith('@')) out.communities = await db('communities').where({ privacy: 'public' }).where('name', 'like', like(term)).orderBy('members_count', 'desc').limit(10);
  res.json(out);
}));

router.get('/hashtags/trending', asyncHandler(async (_req, res) => {
  const since = new Date(Date.now() - 3 * 864e5);
  const rows = await db('post_hashtags as ph').join('hashtags as h', 'h.id', 'ph.hashtag_id').join('posts as p', 'p.id', 'ph.post_id').where('p.created_at', '>=', since).where('p.status', 'published')
    .groupBy('h.id', 'h.tag').orderBy('uses', 'desc').limit(20).select('h.tag', db.raw('count(*) as uses'));
  res.json({ data: rows.map((r) => ({ tag: r.tag, uses: Number(r.uses) })) });
}));
router.get('/hashtags/:tag/posts', validate({ params: z.object({ tag: z.string().min(1).max(60) }), query: pageQuery }), asyncHandler(async (req, res) => {
  const q = db('posts').join('post_hashtags as ph', 'ph.post_id', 'posts.id').join('hashtags as h', 'h.id', 'ph.hashtag_id').where('h.tag', req.params.tag.toLowerCase()).where(visibleTo(req.user.id)).where('posts.visibility', 'public');
  res.json(await newestFirst(q, req.query, req.user.id));
}));

// Friend suggestions: people followed by the people I follow (mutual-graph score), then popular users.
router.get('/recommendations/friends', asyncHandler(async (req, res) => {
  const me = req.user.id;
  const followed = db('follows').where({ follower_id: me }).select('followee_id');
  const graph = await db('follows as f').whereIn('f.follower_id', followed).whereNot('f.followee_id', me).whereNotIn('f.followee_id', followed)
    .groupBy('f.followee_id').orderByRaw('count(*) desc').limit(20).select('f.followee_id as id', db.raw('count(*) as mutual'));
  const ids = graph.map((g) => g.id);
  let users = ids.length ? await db('users').whereIn('id', ids).where({ status: 'active' }).where(notBlocked('id', me)).select('id', 'username', 'display_name', 'is_verified') : [];
  const mutual = Object.fromEntries(graph.map((g) => [g.id, Number(g.mutual)]));
  users = users.map((u) => ({ ...u, mutual_follows: mutual[u.id] })).sort((a, b) => b.mutual_follows - a.mutual_follows);
  if (users.length < 10) {
    const fill = await db('users').where({ status: 'active' }).where(notBlocked('id', me)).whereNot('id', me).whereNotIn('id', followed).whereNotIn('id', ids.length ? ids : [0]).orderBy('followers_count', 'desc').limit(10 - users.length).select('id', 'username', 'display_name', 'is_verified');
    users = users.concat(fill.map((u) => ({ ...u, mutual_follows: 0 })));
  }
  res.json({ data: users });
}));

router.post('/ai/translate', validate({ body: z.object({ text: z.string().min(1).max(4000), target: z.string().min(2).max(30) }).strict() }), asyncHandler(async (req, res) => {
  res.json({ text: await ai.translate(req.body.text, req.body.target) });
}));
module.exports = router;
