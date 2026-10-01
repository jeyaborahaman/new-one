const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { err } = require('../../utils/errors');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { pageQuery, page } = require('../../utils/pagination');
const svc = require('./service');
const realtime = require('../../realtime/bus');
const { blockedAmong } = require('../users/blocks');

const idParam = z.object({ id: z.coerce.number().int().positive() });
const messageBody = z.object({ client_id: z.string().uuid(), type: z.enum(['text', 'voice', 'image', 'video', 'file', 'sticker']).default('text'), body: z.string().max(4000).optional(), media_id: z.number().int().positive().optional() })
  .refine((m) => m.body || m.media_id, 'body or media_id required');
router.use(authenticate);

router.get('/', asyncHandler(async (req, res) => {
  const rows = await db('conversation_members as m').join('conversations as c', 'c.id', 'm.conversation_id').where('m.user_id', req.user.id)
    .orderByRaw('c.last_message_at is null, c.last_message_at desc').limit(100).select('c.id', 'c.type', 'c.title', 'c.last_message_at', 'm.last_read_message_id');
  const ids = rows.map((r) => r.id);
  if (!ids.length) return res.json({ data: [] });
  // Peer (for direct chats), last message preview and unread count, in three batched queries.
  const peers = await db('conversation_members as pm').join('users as u', 'u.id', 'pm.user_id').whereIn('pm.conversation_id', ids).whereNot('pm.user_id', req.user.id).select('pm.conversation_id', 'u.id', 'u.username', 'u.display_name');
  const lastIds = await db('messages').whereIn('conversation_id', ids).whereNull('deleted_at').groupBy('conversation_id').select('conversation_id', db.raw('max(id) as id'));
  const lasts = lastIds.length ? await db('messages').whereIn('id', lastIds.map((l) => l.id)).select('id', 'conversation_id', 'sender_id', 'type', 'body', 'created_at') : [];
  const P = {}; peers.forEach((p) => { (P[p.conversation_id] ||= []).push(p); });
  const L = Object.fromEntries(lasts.map((l) => [l.conversation_id, l]));
  const data = await Promise.all(rows.map(async (r) => {
    const unread = Number((await db('messages').where({ conversation_id: r.id }).whereNot({ sender_id: req.user.id }).where('id', '>', r.last_read_message_id).whereNull('deleted_at').count({ c: '*' }).first()).c);
    const peer = r.type === 'direct' ? P[r.id]?.[0] : null;
    return { ...r, title: r.type === 'direct' ? peer?.display_name || 'Unknown' : r.title, peer: peer ? { id: peer.id, username: peer.username, display_name: peer.display_name } : null, last_message: L[r.id] ? { sender_id: L[r.id].sender_id, type: L[r.id].type, body: L[r.id].body, created_at: L[r.id].created_at } : null, unread };
  }));
  res.json({ data });
}));

router.post('/', validate({ body: z.discriminatedUnion('type', [
  z.object({ type: z.literal('direct'), user_id: z.number().int().positive() }).strict(),
  z.object({ type: z.literal('group'), title: z.string().min(1).max(100), member_ids: z.array(z.number().int().positive()).max(1000) }).strict(),
]) }), asyncHandler(async (req, res) => {
  const c = req.body.type === 'direct' ? await svc.openDirect(req.user.id, req.body.user_id) : await svc.createGroup(req.user.id, req.body.title, req.body.member_ids);
  realtime.joinConversation(await svc.memberIds(c.id), c.id); // live sockets start receiving immediately
  res.status(201).json(c);
}));

router.get('/:id/messages', validate({ params: idParam, query: pageQuery }), asyncHandler(async (req, res) => {
  await svc.assertMember(req.params.id, req.user.id);
  const { limit, cursor } = req.query;
  const q = db('messages').where({ conversation_id: req.params.id }).whereNull('deleted_at').orderBy('id', 'desc').limit(limit + 1);
  if (cursor) q.where('id', '<', cursor);
  res.json(page(await q, limit));
}));

// REST fallback for sending (offline queue flush); live delivery still goes through the socket bus.
router.post('/:id/messages', validate({ params: idParam, body: messageBody }), asyncHandler(async (req, res) => {
  const { message, created } = await svc.sendMessage({ conversationId: req.params.id, senderId: req.user.id, clientId: req.body.client_id, type: req.body.type, body: req.body.body, mediaId: req.body.media_id });
  if (created) await realtime.publishMessage(message);
  res.status(created ? 201 : 200).json(message);
}));

router.post('/:id/read', validate({ params: idParam, body: z.object({ up_to_id: z.number().int().positive() }).strict() }), asyncHandler(async (req, res) => {
  await svc.markRead(req.params.id, req.user.id, req.body.up_to_id);
  res.status(204).end();
}));

// Group admin controls: rename, add, remove, promote/demote. Owners and admins only; owner is untouchable.
const groupAdmin = async (req) => {
  const c = await db('conversations').where({ id: req.params.id, type: 'group' }).first();
  if (!c) throw err.notFound('Group not found');
  const m = await svc.assertMember(c.id, req.user.id);
  if (!['owner', 'admin'].includes(m.role)) throw err.forbidden('Group admins only');
  return { c, m };
};
router.patch('/:id', validate({ params: idParam, body: z.object({ title: z.string().trim().min(1).max(100) }).strict() }), asyncHandler(async (req, res) => {
  await groupAdmin(req); await db('conversations').where({ id: req.params.id }).update({ title: req.body.title }); res.status(204).end();
}));
router.post('/:id/members', validate({ params: idParam, body: z.object({ user_ids: z.array(z.number().int().positive()).min(1).max(200) }).strict() }), asyncHandler(async (req, res) => {
  await groupAdmin(req);
  const users = await db('users').whereIn('id', req.body.user_ids).where({ status: 'active' }).select('id');
  if ((await blockedAmong(req.user.id, users.map((u) => u.id))).length) throw err.forbidden('You cannot add a user you blocked or who blocked you');
  await db('conversation_members').insert(users.map((u) => ({ conversation_id: req.params.id, user_id: u.id }))).onConflict(['conversation_id', 'user_id']).ignore();
  realtime.joinConversation(users.map((u) => u.id), req.params.id);
  res.status(204).end();
}));
router.patch('/:id/members/:uid', validate({ params: idParam.extend({ uid: z.coerce.number().int().positive() }), body: z.object({ role: z.enum(['admin', 'member']) }).strict() }), asyncHandler(async (req, res) => {
  const { m } = await groupAdmin(req);
  if (m.role !== 'owner') throw err.forbidden('Only the owner changes roles');
  const t = await svc.assertMember(req.params.id, req.params.uid).catch(() => null);
  if (!t || t.role === 'owner') throw err.badRequest('Invalid member');
  await db('conversation_members').where({ conversation_id: req.params.id, user_id: req.params.uid }).update({ role: req.body.role }); res.status(204).end();
}));
router.delete('/:id/members/:uid', validate({ params: idParam.extend({ uid: z.coerce.number().int().positive() }) }), asyncHandler(async (req, res) => {
  const c = await db('conversations').where({ id: req.params.id, type: 'group' }).first();
  if (!c) throw err.notFound('Group not found');
  const me = await svc.assertMember(c.id, req.user.id);
  const target = await db('conversation_members').where({ conversation_id: c.id, user_id: req.params.uid }).first();
  if (!target) throw err.notFound('Member not found');
  const leaving = req.params.uid === req.user.id;
  if (!leaving && (!['owner', 'admin'].includes(me.role) || target.role === 'owner' || (target.role === 'admin' && me.role !== 'owner'))) throw err.forbidden('Not allowed');
  if (leaving && target.role === 'owner') throw err.conflict('Owner cannot leave; delete or transfer the group');
  await db('conversation_members').where({ conversation_id: c.id, user_id: req.params.uid }).del();
  realtime.leaveConversation(req.params.uid, c.id);
  res.status(204).end();
}));

module.exports = { router, messageBody };
