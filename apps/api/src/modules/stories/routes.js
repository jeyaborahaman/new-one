const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const r2 = require('../../integrations/r2');
const { requireReadyMedia } = require('../media/routes');
const { notify } = require('../notify/service');
const { grantXp } = require('../wallet/service');

const idParam = z.object({ id: z.coerce.number().int().positive() });
const STORY_TTL_MS = 24 * 3600_000;
router.use(authenticate);

router.post('/', validate({ body: z.object({ media_id: z.number().int().positive(), caption: z.string().max(200).optional() }).strict() }), asyncHandler(async (req, res) => {
  await requireReadyMedia(req.body.media_id, req.user.id, ['image', 'video']);
  const [id] = await db('stories').insert({ author_id: req.user.id, ...req.body, expires_at: new Date(Date.now() + STORY_TTL_MS) });
  await grantXp(req.user.id, 5, 'story');
  const author = await db('users').where({ id: req.user.id }).first('display_name');
  const followers = await db('follows').where({ followee_id: req.user.id }).limit(500).select('follower_id');
  await Promise.all(followers.map((f) => notify(f.follower_id, 'story', { title: author.display_name, body: 'Posted a new story', t: { body: ['story_new'] }, data: { story_id: id, author_id: req.user.id } })));
  res.status(201).json(await db('stories').where({ id }).first());
}));

// Tray: me + people I follow with unexpired stories; unseen first.
router.get('/', asyncHandler(async (req, res) => {
  const now = new Date();
  const rows = await db('stories as s').join('media as m', 'm.id', 's.media_id')
    .where('s.expires_at', '>', now)
    .andWhere((q) => q.where('s.author_id', req.user.id).orWhereIn('s.author_id', db('follows').where({ follower_id: req.user.id }).select('followee_id')))
    .orderBy('s.id', 'asc').select('s.id', 's.author_id', 's.caption', 's.created_at', 's.expires_at', 'm.r2_key', 'm.kind');
  const seen = new Set((await db('story_views').where({ viewer_id: req.user.id }).whereIn('story_id', rows.map((r) => r.id).length ? rows.map((r) => r.id) : [0]).select('story_id')).map((r) => r.story_id));
  const users = await db('users').whereIn('id', [...new Set(rows.map((r) => r.author_id))]).select('id', 'username', 'display_name');
  const U = Object.fromEntries(users.map((u) => [u.id, u]));
  const groups = new Map();
  for (const r of rows) {
    if (!groups.has(r.author_id)) groups.set(r.author_id, { user: U[r.author_id], stories: [] });
    groups.get(r.author_id).stories.push({ id: r.id, kind: r.kind, url: r2.publicUrl(r.r2_key), caption: r.caption, created_at: r.created_at, expires_at: r.expires_at, seen: seen.has(r.id) });
  }
  const out = [...groups.values()].map((g) => ({ ...g, all_seen: g.stories.every((s) => s.seen) }));
  out.sort((a, b) => Number(a.all_seen) - Number(b.all_seen) || (a.user.id === req.user.id ? -1 : 0));
  res.json({ data: out });
}));

async function liveStory(id) {
  const s = await db('stories').where({ id }).where('expires_at', '>', new Date()).first();
  if (!s) throw err.notFound('Story not found or expired');
  return s;
}
router.post('/:id/view', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const s = await liveStory(req.params.id);
  if (s.author_id !== req.user.id) await db('story_views').insert({ story_id: s.id, viewer_id: req.user.id }).onConflict(['story_id', 'viewer_id']).ignore();
  res.status(204).end();
}));
router.get('/:id/viewers', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const s = await liveStory(req.params.id);
  if (s.author_id !== req.user.id) throw err.forbidden('Only the author can see viewers');
  const rows = await db('story_views as v').join('users as u', 'u.id', 'v.viewer_id').where('v.story_id', s.id).orderBy('v.viewed_at', 'desc').select('u.id', 'u.username', 'u.display_name', 'v.viewed_at');
  const rx = Object.fromEntries((await db('reactions').where({ target_type: 'story', target_id: s.id }).select('user_id', 'kind')).map((r) => [r.user_id, r.kind]));
  res.json({ count: rows.length, data: rows.map((r) => ({ ...r, reaction: rx[r.id] || null })) });
}));
router.put('/:id/reaction', validate({ params: idParam, body: z.object({ kind: z.enum(['like', 'love', 'wow', 'laugh', 'sad']) }).strict() }), asyncHandler(async (req, res) => {
  const s = await liveStory(req.params.id);
  await db('reactions').insert({ target_type: 'story', target_id: s.id, user_id: req.user.id, kind: req.body.kind }).onConflict(['target_type', 'target_id', 'user_id']).merge({ kind: req.body.kind });
  if (s.author_id !== req.user.id) await notify(s.author_id, 'reaction', { title: 'Story reaction', body: `Someone reacted ${req.body.kind}`, t: { title: ['story_reaction_title'], body: ['story_reaction', { reaction: req.body.kind }] }, data: { story_id: s.id } });
  res.status(204).end();
}));
router.delete('/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const n = await db('stories').where({ id: req.params.id, author_id: req.user.id }).del();
  if (!n) throw err.notFound('Story not found');
  res.status(204).end();
}));
module.exports = router;
