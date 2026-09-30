const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate, ROLE_RANK } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { pageQuery } = require('../../utils/pagination');
const { grantXp } = require('../wallet/service');
const { notify } = require('../notify/service');
const { assertClean } = require('../moderation/service');
const { requireReadyMedia } = require('../media/routes');
const { visibleTo, hydrate, indexText, newestFirst } = require('./lib');

const idParam = z.object({ id: z.coerce.number().int().positive() });
const KINDS = ['like', 'love', 'wow', 'laugh', 'sad'];
router.use(authenticate);

// Scheduled posts become visible once due (a background job does this too; this keeps reads correct without it).
const publishDue = () => db('posts').where({ status: 'scheduled' }).where('publish_at', '<=', new Date()).update({ status: 'published' });

const createBody = z.object({
  type: z.enum(['text', 'image', 'video', 'poll']).default('text'),
  body: z.string().trim().min(1).max(5000),
  visibility: z.enum(['public', 'followers', 'private']).default('public'),
  publish_at: z.coerce.date().optional(),
  media_id: z.number().int().positive().optional(),
  community_id: z.number().int().positive().optional(),
  poll: z.object({ options: z.array(z.string().trim().min(1).max(120)).min(2).max(6), closes_at: z.coerce.date().optional() }).optional(),
}).strict().superRefine((v, ctx) => {
  if ((v.type === 'image' || v.type === 'video') && !v.media_id) ctx.addIssue({ code: 'custom', path: ['media_id'], message: `${v.type} posts need media_id` });
  if (v.type === 'poll' && !v.poll) ctx.addIssue({ code: 'custom', path: ['poll'], message: 'poll posts need poll options' });
});

router.post('/', validate({ body: createBody }), asyncHandler(async (req, res) => {
  const b = req.body;
  const score = await assertClean(b.body + (b.poll ? ` ${b.poll.options.join(' ')}` : ''));
  if (b.media_id) await requireReadyMedia(b.media_id, req.user.id, [b.type === 'video' ? 'video' : 'image']);
  if (b.community_id) {
    const c = await db('communities').where({ id: b.community_id }).first();
    const m = c && (await db('community_members').where({ community_id: c.id, user_id: req.user.id, status: 'active' }).first());
    if (!m) throw err.forbidden('Join the community to post');
    if (c.kind === 'page' && !['owner', 'admin', 'moderator'].includes(m.role)) throw err.forbidden('Only page staff can post');
  }
  const scheduled = b.publish_at && b.publish_at > new Date();
  const { id, mentions } = await db.transaction(async (trx) => {
    const [pid] = await trx('posts').insert({ author_id: req.user.id, type: b.type, body: b.body, visibility: b.visibility, publish_at: b.publish_at, status: scheduled ? 'scheduled' : 'published', media_id: b.media_id, community_id: b.community_id, moderation_score: score, poll_closes_at: b.poll?.closes_at });
    if (b.poll) await trx('poll_options').insert(b.poll.options.map((label) => ({ post_id: pid, label })));
    return { id: pid, mentions: await indexText(trx, pid, b.body) };
  });
  if (!scheduled) {
    await grantXp(req.user.id, 10, 'post');
    const me = await db('users').where({ id: req.user.id }).first('display_name');
    await Promise.all(mentions.filter((u) => u !== req.user.id).map((u) => notify(u, 'mention', { title: me.display_name, body: 'Mentioned you in a post', data: { post_id: id } })));
  }
  res.status(201).json((await hydrate([await db('posts').where({ id }).first()], req.user.id))[0]);
}));

// Timeline: own + followed + public discovery, newest first.
router.get('/feed', validate({ query: pageQuery }), asyncHandler(async (req, res) => {
  await publishDue();
  res.json(await newestFirst(db('posts').where(visibleTo(req.user.id)), req.query, req.user.id));
}));

router.get('/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const p = await db('posts').where('posts.id', req.params.id).where(visibleTo(req.user.id)).first('posts.*');
  if (!p) throw err.notFound('Post not found');
  res.json((await hydrate([p], req.user.id))[0]);
}));

router.delete('/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const p = await db('posts').where({ id: req.params.id }).first();
  if (!p || p.status === 'removed') throw err.notFound('Post not found');
  let allowed = p.author_id === req.user.id || ROLE_RANK[req.user.role] >= ROLE_RANK.moderator;
  if (!allowed && p.community_id) allowed = !!(await db('community_members').where({ community_id: p.community_id, user_id: req.user.id, status: 'active' }).whereIn('role', ['owner', 'admin', 'moderator']).first());
  if (!allowed) throw err.forbidden();
  await db('posts').where({ id: p.id }).update({ status: 'removed' });
  res.status(204).end();
}));

const canSee = async (id, viewer) => { const p = await db('posts').where('posts.id', id).where(visibleTo(viewer)).first('posts.*'); if (!p) throw err.notFound('Post not found'); return p; };
async function recountReactions(trx, postId) {
  const c = Number((await trx('reactions').where({ target_type: 'post', target_id: postId }).count({ c: '*' }).first()).c);
  await trx('posts').where({ id: postId }).update({ reactions_count: c });
  return c;
}
router.put('/:id/reaction', validate({ params: idParam, body: z.object({ kind: z.enum(KINDS) }).strict() }), asyncHandler(async (req, res) => {
  const post = await canSee(req.params.id, req.user.id);
  const isNew = !(await db('reactions').where({ target_type: 'post', target_id: post.id, user_id: req.user.id }).first());
  const reactions_count = await db.transaction(async (trx) => {
    await trx('reactions').insert({ target_type: 'post', target_id: post.id, user_id: req.user.id, kind: req.body.kind }).onConflict(['target_type', 'target_id', 'user_id']).merge({ kind: req.body.kind });
    return recountReactions(trx, post.id);
  });
  if (isNew) { // XP and notification only for a first reaction, so re-tapping cannot farm rewards
    await grantXp(req.user.id, 1, 'reaction');
    if (post.author_id !== req.user.id) await notify(post.author_id, 'reaction', { title: 'New reaction', body: `Someone reacted ${req.body.kind} to your post`, data: { post_id: post.id } });
  }
  res.json({ kind: req.body.kind, reactions_count });
}));
router.delete('/:id/reaction', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const reactions_count = await db.transaction(async (trx) => {
    await trx('reactions').where({ target_type: 'post', target_id: req.params.id, user_id: req.user.id }).del();
    return recountReactions(trx, req.params.id);
  });
  res.json({ reactions_count });
}));

router.post('/:id/vote', validate({ params: idParam, body: z.object({ option_id: z.number().int().positive() }).strict() }), asyncHandler(async (req, res) => {
  const post = await canSee(req.params.id, req.user.id);
  if (post.type !== 'poll') throw err.badRequest('Not a poll');
  if (post.poll_closes_at && new Date(post.poll_closes_at) < new Date()) throw err.conflict('Poll is closed');
  const opt = await db('poll_options').where({ id: req.body.option_id, post_id: post.id }).first();
  if (!opt) throw err.badRequest('Unknown option');
  await db.transaction(async (trx) => {
    try { await trx('poll_votes').insert({ post_id: post.id, user_id: req.user.id, option_id: opt.id }); } catch { throw err.conflict('You already voted'); }
    await trx('poll_options').where({ id: opt.id }).increment('votes_count', 1);
  });
  res.json((await hydrate([post], req.user.id))[0].poll);
}));

router.post('/:id/comments', validate({ params: idParam, body: z.object({ body: z.string().trim().min(1).max(2000), parent_id: z.number().int().positive().optional(), gif_url: z.string().url().max(500).optional() }).strict() }), asyncHandler(async (req, res) => {
  const post = await canSee(req.params.id, req.user.id);
  await assertClean(req.body.body);
  let depth = 0; let parent;
  if (req.body.parent_id) {
    parent = await db('comments').where({ id: req.body.parent_id, post_id: post.id }).whereNull('deleted_at').first();
    if (!parent) throw err.badRequest('Parent comment not found on this post');
    depth = Math.min(parent.depth + 1, 3);
  }
  const id = await db.transaction(async (trx) => {
    const [cid] = await trx('comments').insert({ post_id: post.id, author_id: req.user.id, depth, ...req.body });
    const c = Number((await trx('comments').where({ post_id: post.id }).whereNull('deleted_at').count({ c: '*' }).first()).c);
    await trx('posts').where({ id: post.id }).update({ comments_count: c });
    return cid;
  });
  await grantXp(req.user.id, 2, 'comment');
  const me = await db('users').where({ id: req.user.id }).first('display_name');
  const targets = new Set([post.author_id, parent?.author_id].filter((u) => u && u !== req.user.id));
  await Promise.all([...targets].map((u) => notify(u, 'comment', { title: me.display_name, body: req.body.body.slice(0, 100), data: { post_id: post.id, comment_id: id } })));
  res.status(201).json(await db('comments').where({ id }).first());
}));

router.get('/:id/comments', validate({ params: idParam, query: pageQuery.extend({ parent_id: z.coerce.number().int().positive().optional() }) }), asyncHandler(async (req, res) => {
  await canSee(req.params.id, req.user.id);
  const { limit, cursor, parent_id } = req.query;
  const q = db('comments').where({ post_id: req.params.id }).whereNull('deleted_at').orderBy('id', 'asc').limit(limit + 1);
  parent_id ? q.where({ parent_id }) : q.whereNull('parent_id');
  if (cursor) q.where('id', '>', cursor);
  const rows = await q;
  const data = rows.slice(0, limit);
  res.json({ data, next_cursor: rows.length > limit ? data[data.length - 1].id : null });
}));

module.exports = router;
