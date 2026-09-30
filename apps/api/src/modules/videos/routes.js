const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { pageQuery } = require('../../utils/pagination');
const { requireReadyMedia } = require('../media/routes');
const { assertClean } = require('../moderation/service');
const { grantXp } = require('../wallet/service');
const { notify } = require('../notify/service');
const { visibleTo, hydrate, indexText, newestFirst } = require('../posts/lib');

const idParam = z.object({ id: z.coerce.number().int().positive() });
const posInt = z.coerce.number().int().positive();
router.use(authenticate);

const videoPosts = (viewer, isShort) => db('posts').join('videos', 'videos.post_id', 'posts.id').where('videos.is_short', isShort).where(visibleTo(viewer)).where('posts.visibility', 'public');

router.get('/categories', asyncHandler(async (_req, res) => res.json({ data: await db('video_categories').orderBy('name') })));

router.post('/', validate({ body: z.object({
  media_id: z.number().int().positive(), title: z.string().trim().min(1).max(150), body: z.string().max(5000).default(''),
  is_short: z.boolean().default(false), category_id: z.number().int().positive().optional(), effects: z.array(z.string().max(30)).max(10).optional(),
}).strict() }), asyncHandler(async (req, res) => {
  const b = req.body;
  await assertClean(`${b.title} ${b.body}`);
  await requireReadyMedia(b.media_id, req.user.id, ['video']);
  if (b.category_id && !(await db('video_categories').where({ id: b.category_id }).first('id'))) throw err.badRequest('Unknown category');
  const id = await db.transaction(async (trx) => {
    const [pid] = await trx('posts').insert({ author_id: req.user.id, type: b.is_short ? 'reel' : 'long_video', body: b.body || b.title, media_id: b.media_id });
    await trx('videos').insert({ post_id: pid, title: b.title, category_id: b.category_id, is_short: b.is_short, effects: JSON.stringify(b.effects || []) });
    await indexText(trx, pid, `${b.title} ${b.body}`);
    return pid;
  });
  await grantXp(req.user.id, b.is_short ? 15 : 20, 'video');
  const subs = await db('subscriptions').where({ channel_id: req.user.id }).limit(500).select('subscriber_id');
  const me = await db('users').where({ id: req.user.id }).first('display_name');
  await Promise.all(subs.map((s) => notify(s.subscriber_id, 'live', { title: me.display_name, body: `New ${b.is_short ? 'reel' : 'video'}: ${b.title}`, data: { post_id: id } })));
  res.status(201).json((await hydrate([await db('posts').where({ id }).first()], req.user.id))[0]);
}));

// Reels: infinite vertical feed, newest first via keyset cursor.
router.get('/reels', validate({ query: pageQuery }), asyncHandler(async (req, res) => res.json(await newestFirst(videoPosts(req.user.id, true), req.query, req.user.id))));

// Trending: recent (7d) reactions + comments, then views.
router.get('/reels/trending', asyncHandler(async (req, res) => {
  const rows = await videoPosts(req.user.id, true).where('posts.created_at', '>=', new Date(Date.now() - 7 * 864e5))
    .orderByRaw('(posts.reactions_count * 2 + posts.comments_count * 3 + videos.views_count) desc').limit(30).select('posts.*');
  res.json({ data: await hydrate(rows, req.user.id) });
}));

router.get('/', validate({ query: pageQuery.extend({ category: z.string().max(50).optional() }) }), asyncHandler(async (req, res) => {
  const q = videoPosts(req.user.id, false);
  if (req.query.category) q.whereIn('videos.category_id', db('video_categories').where({ slug: req.query.category }).select('id'));
  res.json(await newestFirst(q, req.query, req.user.id));
}));

// Recommendations: categories the viewer reacted to most, excluding own; falls back to trending.
router.get('/recommended', asyncHandler(async (req, res) => {
  const cats = await db('reactions as r').join('videos as v', 'v.post_id', 'r.target_id').where({ 'r.target_type': 'post', 'r.user_id': req.user.id }).whereNotNull('v.category_id')
    .groupBy('v.category_id').orderByRaw('count(*) desc').limit(3).select('v.category_id');
  const q = db('posts').join('videos', 'videos.post_id', 'posts.id').where(visibleTo(req.user.id)).where('posts.visibility', 'public').whereNot('posts.author_id', req.user.id);
  if (cats.length) q.whereIn('videos.category_id', cats.map((c) => c.category_id));
  const rows = await q.orderByRaw('(posts.reactions_count * 2 + videos.views_count) desc').limit(30).select('posts.*');
  res.json({ data: await hydrate(rows, req.user.id) });
}));

router.get('/subscriptions/feed', validate({ query: pageQuery }), asyncHandler(async (req, res) => {
  const q = db('posts').join('videos', 'videos.post_id', 'posts.id').where(visibleTo(req.user.id)).whereIn('posts.author_id', db('subscriptions').where({ subscriber_id: req.user.id }).select('channel_id'));
  res.json(await newestFirst(q, req.query, req.user.id));
}));

router.get('/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const p = await db('posts').join('videos', 'videos.post_id', 'posts.id').where('posts.id', req.params.id).where(visibleTo(req.user.id)).first('posts.*');
  if (!p) throw err.notFound('Video not found');
  res.json((await hydrate([p], req.user.id))[0]);
}));
router.post('/:id/view', validate({ params: idParam }), asyncHandler(async (req, res) => {
  await db('videos').where({ post_id: req.params.id }).increment('views_count', 1);
  res.status(204).end();
}));

// Channels
router.post('/channels/:id/subscribe', validate({ params: idParam }), asyncHandler(async (req, res) => {
  if (req.params.id === req.user.id) throw err.badRequest('Cannot subscribe to yourself');
  if (!(await db('users').where({ id: req.params.id, status: 'active' }).first('id'))) throw err.notFound('Channel not found');
  await db('subscriptions').insert({ subscriber_id: req.user.id, channel_id: req.params.id }).onConflict(['subscriber_id', 'channel_id']).ignore();
  res.status(204).end();
}));
router.delete('/channels/:id/subscribe', validate({ params: idParam }), asyncHandler(async (req, res) => { await db('subscriptions').where({ subscriber_id: req.user.id, channel_id: req.params.id }).del(); res.status(204).end(); }));

// Playlists
router.get('/playlists/mine', asyncHandler(async (req, res) => res.json({ data: await db('playlists').where({ owner_id: req.user.id }).orderBy('id', 'desc') })));
router.post('/playlists', validate({ body: z.object({ title: z.string().trim().min(1).max(100), is_public: z.boolean().default(true) }).strict() }), asyncHandler(async (req, res) => {
  const [id] = await db('playlists').insert({ owner_id: req.user.id, ...req.body });
  res.status(201).json(await db('playlists').where({ id }).first());
}));
router.post('/playlists/:id/items', validate({ params: idParam, body: z.object({ post_id: z.number().int().positive() }).strict() }), asyncHandler(async (req, res) => {
  const pl = await db('playlists').where({ id: req.params.id, owner_id: req.user.id }).first();
  if (!pl) throw err.notFound('Playlist not found');
  if (!(await db('posts').join('videos', 'videos.post_id', 'posts.id').where('posts.id', req.body.post_id).where(visibleTo(req.user.id)).first('posts.id'))) throw err.badRequest('Video not found');
  const pos = Number((await db('playlist_items').where({ playlist_id: pl.id }).max({ m: 'position' }).first()).m ?? -1) + 1;
  await db('playlist_items').insert({ playlist_id: pl.id, post_id: req.body.post_id, position: pos }).onConflict(['playlist_id', 'post_id']).ignore();
  res.status(204).end();
}));
router.get('/playlists/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const pl = await db('playlists').where({ id: req.params.id }).first();
  if (!pl || (!pl.is_public && pl.owner_id !== req.user.id)) throw err.notFound('Playlist not found');
  const items = await db('playlist_items').where({ playlist_id: pl.id }).orderBy('position').select('post_id');
  const posts = await db('posts').whereIn('posts.id', items.map((i) => i.post_id).length ? items.map((i) => i.post_id) : [0]).where(visibleTo(req.user.id));
  const order = new Map(items.map((i, n) => [i.post_id, n]));
  posts.sort((a, b) => order.get(a.id) - order.get(b.id));
  res.json({ ...pl, is_public: !!pl.is_public, items: await hydrate(posts, req.user.id) });
}));
module.exports = router;
