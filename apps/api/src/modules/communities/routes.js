const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { pageQuery } = require('../../utils/pagination');
const { notify } = require('../notify/service');
const { visibleTo, newestFirst } = require('../posts/lib');

const idParam = z.object({ id: z.coerce.number().int().positive() });
const STAFF = ['owner', 'admin', 'moderator'];
router.use(authenticate);

const membership = (cid, uid) => db('community_members').where({ community_id: cid, user_id: uid }).first();
const recount = async (trx, cid) => trx('communities').where({ id: cid }).update({ members_count: Number((await trx('community_members').where({ community_id: cid, status: 'active' }).count({ c: '*' }).first()).c) });
async function load(id) { const c = await db('communities').where({ id }).first(); if (!c) throw err.notFound('Community not found'); return c; }
async function requireStaff(cid, uid, roles = STAFF) {
  const m = await membership(cid, uid);
  if (!m || m.status !== 'active' || !roles.includes(m.role)) throw err.forbidden('Not allowed');
  return m;
}

router.post('/', validate({ body: z.object({
  kind: z.enum(['group', 'page']), page_type: z.enum(['business', 'community', 'creator']).optional(),
  privacy: z.enum(['public', 'private']).default('public'), name: z.string().trim().min(2).max(100), description: z.string().max(2000).optional(),
}).strict().refine((v) => v.kind === 'group' || v.page_type, { message: 'Pages need page_type', path: ['page_type'] }).refine((v) => v.kind === 'group' || v.privacy === 'public', { message: 'Pages are always public', path: ['privacy'] }) }), asyncHandler(async (req, res) => {
  const id = await db.transaction(async (trx) => {
    const [cid] = await trx('communities').insert({ ...req.body, owner_id: req.user.id });
    await trx('community_members').insert({ community_id: cid, user_id: req.user.id, role: 'owner' });
    await recount(trx, cid);
    return cid;
  });
  res.status(201).json(await db('communities').where({ id }).first());
}));

router.get('/', validate({ query: z.object({ q: z.string().max(100).optional(), kind: z.enum(['group', 'page']).optional() }) }), asyncHandler(async (req, res) => {
  const q = db('communities').where({ privacy: 'public' }).orderBy('members_count', 'desc').limit(30);
  if (req.query.q) q.where('name', 'like', `%${req.query.q.replace(/[%_]/g, '')}%`);
  if (req.query.kind) q.where({ kind: req.query.kind });
  res.json({ data: await q });
}));

router.get('/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const c = await load(req.params.id);
  const m = await membership(c.id, req.user.id);
  if (c.privacy === 'private' && !(m && m.status === 'active')) return res.json({ id: c.id, name: c.name, kind: c.kind, privacy: c.privacy, members_count: c.members_count, my_status: m?.status || null }); // limited preview
  res.json({ ...c, my_role: m?.status === 'active' ? m.role : null, my_status: m?.status || null });
}));

router.post('/:id/join', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const c = await load(req.params.id);
  const m = await membership(c.id, req.user.id);
  if (m?.status === 'banned') throw err.forbidden('You are banned from this community');
  if (m) return res.json({ status: m.status });
  const status = c.privacy === 'public' ? 'active' : 'pending';
  await db.transaction(async (trx) => { await trx('community_members').insert({ community_id: c.id, user_id: req.user.id, status }); await recount(trx, c.id); });
  if (status === 'pending') {
    const me = await db('users').where({ id: req.user.id }).first('display_name');
    const staff = await db('community_members').where({ community_id: c.id, status: 'active' }).whereIn('role', STAFF).select('user_id');
    await Promise.all(staff.map((s) => notify(s.user_id, 'friend_request', { title: c.name, body: `${me.display_name} wants to join`, data: { community_id: c.id, user_id: req.user.id } })));
  }
  res.status(201).json({ status });
}));
router.post('/:id/leave', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const c = await load(req.params.id); const m = await membership(c.id, req.user.id);
  if (m?.role === 'owner') throw err.conflict('Owners must transfer ownership first');
  if (m && m.status !== 'banned') await db.transaction(async (trx) => { await trx('community_members').where({ community_id: c.id, user_id: req.user.id }).del(); await recount(trx, c.id); });
  res.status(204).end();
}));

router.get('/:id/members', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const c = await load(req.params.id);
  const m = await membership(c.id, req.user.id);
  if (c.privacy === 'private' && m?.status !== 'active') throw err.forbidden('Members only');
  const isStaff = m?.status === 'active' && STAFF.includes(m.role);
  const q = db('community_members as cm').join('users as u', 'u.id', 'cm.user_id').where('cm.community_id', c.id).select('u.id', 'u.username', 'u.display_name', 'cm.role', 'cm.status').limit(200);
  isStaff ? q.whereIn('cm.status', ['active', 'pending', 'banned']) : q.where('cm.status', 'active');
  res.json({ data: await q });
}));

// Staff actions: approve/reject, promote (owner/admin), ban (staff over lower roles).
router.patch('/:id/members/:uid', validate({ params: idParam.extend({ uid: z.coerce.number().int().positive() }), body: z.object({ action: z.enum(['approve', 'reject', 'ban', 'unban', 'set_role']), role: z.enum(['admin', 'moderator', 'member']).optional() }).strict() }), asyncHandler(async (req, res) => {
  const c = await load(req.params.id);
  const actor = await requireStaff(c.id, req.user.id);
  const target = await membership(c.id, req.params.uid);
  if (!target) throw err.notFound('Member not found');
  const rank = { owner: 3, admin: 2, moderator: 1, member: 0 };
  if (rank[target.role] >= rank[actor.role]) throw err.forbidden('You cannot manage this member');
  const { action, role } = req.body;
  if (action === 'set_role') {
    if (actor.role !== 'owner' && actor.role !== 'admin') throw err.forbidden('Only owner or admins set roles');
    if (!role) throw err.badRequest('role required');
    if (role === 'admin' && actor.role !== 'owner') throw err.forbidden('Only the owner can appoint admins');
    await db('community_members').where({ community_id: c.id, user_id: target.user_id }).update({ role });
  } else if (action === 'approve') {
    if (target.status !== 'pending') throw err.conflict('Not pending');
    await db('community_members').where({ community_id: c.id, user_id: target.user_id }).update({ status: 'active' });
    await notify(target.user_id, 'reward', { title: c.name, body: 'Your join request was approved', data: { community_id: c.id } });
  } else if (action === 'reject') {
    await db('community_members').where({ community_id: c.id, user_id: target.user_id, status: 'pending' }).del();
  } else if (action === 'ban') {
    await db('community_members').where({ community_id: c.id, user_id: target.user_id }).update({ status: 'banned', role: 'member' });
  } else if (action === 'unban') {
    await db('community_members').where({ community_id: c.id, user_id: target.user_id, status: 'banned' }).del();
  }
  await db.transaction((trx) => recount(trx, c.id));
  res.status(204).end();
}));

router.get('/:id/feed', validate({ params: idParam, query: pageQuery }), asyncHandler(async (req, res) => {
  const c = await load(req.params.id);
  const m = await membership(c.id, req.user.id);
  if (c.privacy === 'private' && m?.status !== 'active') throw err.forbidden('Members only');
  res.json(await newestFirst(db('posts').where({ 'posts.community_id': c.id }).where(visibleTo(req.user.id)), req.query, req.user.id));
}));
module.exports = router;
