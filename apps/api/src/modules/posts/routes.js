const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate, ROLE_RANK } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { pageQuery, page } = require('../../utils/pagination');
const { grantXp } = require('../wallet/service');

const idParam = z.object({ id: z.coerce.number().int().positive() });
const KINDS = ['like', 'love', 'wow', 'laugh', 'sad'];
router.use(authenticate);

const hydrate = async (rows, viewerId) => {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const authors = await db('users').whereIn('id', [...new Set(rows.map((r) => r.author_id))]).select('id', 'username', 'display_name', 'is_verified', 'level');
  const mine = await db('reactions').where({ target_type: 'post', user_id: viewerId }).whereIn('target_id', ids).select('target_id', 'kind');
  const A = Object.fromEntries(authors.map((a) => [a.id, { ...a, is_verified: !!a.is_verified }]));
  const M = Object.fromEntries(mine.map((m) => [m.target_id, m.kind]));
  return rows.map((r) => ({ id: r.id, type: r.type, body: r.body, visibility: r.visibility, created_at: r.created_at, reactions_count: r.reactions_count, comments_count: r.comments_count, author: A[r.author_id], my_reaction: M[r.id] || null }));
};

const visibleTo = (viewerId) => function () {
  this.where('posts.status', 'published').andWhere(function () {
    this.where('posts.visibility', 'public').orWhere('posts.author_id', viewerId)
      .orWhere(function () { this.where('posts.visibility', 'followers').whereIn('posts.author_id', db('follows').where('follower_id', viewerId).select('followee_id')); });
  });
};

// Promote due scheduled posts (called lazily here; a cron/BullMQ job does it in production).
const publishDue = () => db('posts').where({ status: 'scheduled' }).where('publish_at', '<=', new Date()).update({ status: 'published' });

router.post('/', validate({ body: z.object({
  type: z.enum(['text', 'image', 'video', 'poll']).default('text'),
  body: z.string().trim().min(1).max(5000),
  visibility: z.enum(['public', 'followers', 'private']).default('public'),
  publish_at: z.coerce.date().optional(),
}).strict() }), asyncHandler(async (req, res) => {
  const scheduled = req.body.publish_at && req.body.publish_at > new Date();
  const [id] = await db('posts').insert({ author_id: req.user.id, ...req.body, publish_at: req.body.publish_at, status: scheduled ? 'scheduled' : 'published' });
  if (!scheduled) await grantXp(req.user.id, 10, 'post', id);
  res.status(201).json((await hydrate([await db('posts').where({ id }).first()], req.user.id))[0]);
}));

// Timeline: own + followed authors + public discovery, newest first.
router.get('/feed', validate({ query: pageQuery }), asyncHandler(async (req, res) => {
  await publishDue();
  const { limit, cursor } = req.query;
  const q = db('posts').where(visibleTo(req.user.id)).orderBy('posts.id', 'desc').limit(limit + 1).select('posts.*');
  if (cursor) q.where('posts.id', '<', cursor);
  const out = page(await q, limit);
  res.json({ ...out, data: await hydrate(out.data, req.user.id) });
}));

router.get('/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const p = await db('posts').where('posts.id', req.params.id).where(visibleTo(req.user.id)).first('posts.*');
  if (!p) throw err.notFound('Post not found');
  res.json((await hydrate([p], req.user.id))[0]);
}));

router.delete('/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const p = await db('posts').where({ id: req.params.id }).first();
  if (!p || p.status === 'removed') throw err.notFound('Post not found');
  if (p.author_id !== req.user.id && ROLE_RANK[req.user.role] < ROLE_RANK.moderator) throw err.forbidden();
  await db('posts').where({ id: p.id }).update({ status: 'removed' });
  res.status(204).end();
}));

async function recountReactions(trx, postId) {
  const c = Number((await trx('reactions').where({ target_type: 'post', target_id: postId }).count({ c: '*' }).first()).c);
  await trx('posts').where({ id: postId }).update({ reactions_count: c });
  return c;
}

router.put('/:id/reaction', validate({ params: idParam, body: z.object({ kind: z.enum(KINDS) }).strict() }), asyncHandler(async (req, res) => {
  if (!(await db('posts').where('posts.id', req.params.id).where(visibleTo(req.user.id)).first('id'))) throw err.notFound('Post not found');
  const reactions_count = await db.transaction(async (trx) => {
    await trx('reactions').insert({ target_type: 'post', target_id: req.params.id, user_id: req.user.id, kind: req.body.kind })
      .onConflict(['target_type', 'target_id', 'user_id']).merge({ kind: req.body.kind });
    return recountReactions(trx, req.params.id);
  });
  res.json({ kind: req.body.kind, reactions_count });
}));

router.delete('/:id/reaction', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const reactions_count = await db.transaction(async (trx) => {
    await trx('reactions').where({ target_type: 'post', target_id: req.params.id, user_id: req.user.id }).del();
    return recountReactions(trx, req.params.id);
  });
  res.json({ reactions_count });
}));

// Comments with nested replies (depth-limited to 3 to keep threads readable).
router.post('/:id/comments', validate({ params: idParam, body: z.object({
  body: z.string().trim().min(1).max(2000), parent_id: z.number().int().positive().optional(), gif_url: z.string().url().max(500).optional(),
}).strict() }), asyncHandler(async (req, res) => {
  if (!(await db('posts').where('posts.id', req.params.id).where(visibleTo(req.user.id)).first('id'))) throw err.notFound('Post not found');
  let depth = 0;
  if (req.body.parent_id) {
    const parent = await db('comments').where({ id: req.body.parent_id, post_id: req.params.id }).whereNull('deleted_at').first();
    if (!parent) throw err.badRequest('Parent comment not found on this post');
    depth = Math.min(parent.depth + 1, 3);
  }
  const id = await db.transaction(async (trx) => {
    const [cid] = await trx('comments').insert({ post_id: req.params.id, author_id: req.user.id, depth, ...req.body });
    const c = Number((await trx('comments').where({ post_id: req.params.id }).whereNull('deleted_at').count({ c: '*' }).first()).c);
    await trx('posts').where({ id: req.params.id }).update({ comments_count: c });
    return cid;
  });
  await grantXp(req.user.id, 2, 'comment', id);
  res.status(201).json(await db('comments').where({ id }).first());
}));

router.get('/:id/comments', validate({ params: idParam, query: pageQuery.extend({ parent_id: z.coerce.number().int().positive().optional() }) }), asyncHandler(async (req, res) => {
  const { limit, cursor, parent_id } = req.query;
  const q = db('comments').where({ post_id: req.params.id }).whereNull('deleted_at').orderBy('id', 'asc').limit(limit + 1);
  parent_id ? q.where({ parent_id }) : q.whereNull('parent_id');
  if (cursor) q.where('id', '>', cursor);
  const rows = await q;
  const data = rows.slice(0, limit);
  res.json({ data, next_cursor: rows.length > limit ? data[data.length - 1].id : null });
}));

module.exports = router;
