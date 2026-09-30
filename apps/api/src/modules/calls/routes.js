const router = require('express').Router();
const crypto = require('crypto');
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const agora = require('../../integrations/agora');
const bus = require('../../realtime/bus');
const chat = require('../chat/service');
const { push } = require('../notify/service');

const idParam = z.object({ id: z.string().uuid() });
const RING_TIMEOUT_MS = 45_000;
router.use(authenticate);

async function loadCall(id, userId) {
  const call = await db('call_sessions').where({ id }).first();
  if (!call) throw err.notFound('Call not found');
  await chat.assertMember(call.conversation_id, userId);
  return call;
}

router.post('/', validate({ body: z.object({ conversation_id: z.number().int().positive(), kind: z.enum(['audio', 'video']) }).strict() }), asyncHandler(async (req, res) => {
  await chat.assertMember(req.body.conversation_id, req.user.id);
  const members = await chat.memberIds(req.body.conversation_id);
  const conv = await db('conversations').where({ id: req.body.conversation_id }).first();
  const busy = await db('call_sessions').where({ conversation_id: conv.id }).whereIn('status', ['ringing', 'active']).where('created_at', '>', new Date(Date.now() - 4 * 3600_000)).first('id');
  if (busy) throw err.conflict('A call is already in progress in this conversation');
  const id = crypto.randomUUID();
  const token = agora.buildToken(id, req.user.id); // fail before persisting when calls are not configured
  await db('call_sessions').insert({ id, conversation_id: conv.id, initiator_id: req.user.id, kind: req.body.kind, is_group: conv.type === 'group' });
  const me = await db('users').where({ id: req.user.id }).first('display_name');
  for (const uid of members.filter((m) => m !== req.user.id)) {
    bus.emitToUser(uid, 'call:incoming', { call_id: id, conversation_id: conv.id, kind: req.body.kind, from: { id: req.user.id, display_name: me.display_name }, is_group: conv.type === 'group' });
    await push(uid, 'call', { title: me.display_name, body: `Incoming ${req.body.kind} call`, data: { call_id: id, conversation_id: conv.id, kind: req.body.kind } });
  }
  res.status(201).json({ call_id: id, ring_timeout_ms: RING_TIMEOUT_MS, ...token });
}));

router.post('/:id/join', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const call = await loadCall(req.params.id, req.user.id);
  if (['ended', 'missed', 'declined'].includes(call.status)) throw err.conflict(`Call already ${call.status}`);
  if (call.status === 'ringing' && call.initiator_id !== req.user.id) await db('call_sessions').where({ id: call.id }).update({ status: 'active', started_at: new Date() });
  const members = await chat.memberIds(call.conversation_id);
  members.forEach((u) => bus.emitToUser(u, 'call:state', { call_id: call.id, status: 'active', joined: req.user.id }));
  res.json(agora.buildToken(call.id, req.user.id));
}));
router.post('/:id/decline', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const call = await loadCall(req.params.id, req.user.id);
  // Direct call: a decline ends it. Group call: others may still join, so only a ringing 1:1 flips status.
  if (call.status === 'ringing' && !call.is_group) {
    await db('call_sessions').where({ id: call.id }).update({ status: 'declined', ended_at: new Date() });
    bus.emitToUser(call.initiator_id, 'call:state', { call_id: call.id, status: 'declined' });
  }
  res.status(204).end();
}));
router.post('/:id/end', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const call = await loadCall(req.params.id, req.user.id);
  if (call.is_group && call.initiator_id !== req.user.id) return res.status(204).end(); // members leave; only the host ends a group call
  if (!['ended', 'missed', 'declined'].includes(call.status)) {
    await db('call_sessions').where({ id: call.id }).update({ status: call.status === 'ringing' ? 'missed' : 'ended', ended_at: new Date() });
    (await chat.memberIds(call.conversation_id)).forEach((u) => bus.emitToUser(u, 'call:state', { call_id: call.id, status: 'ended' }));
  }
  res.status(204).end();
}));
router.get('/history', asyncHandler(async (req, res) => {
  const rows = await db('call_sessions as c').join('conversation_members as m', 'm.conversation_id', 'c.conversation_id').where('m.user_id', req.user.id).orderBy('c.created_at', 'desc').limit(50).select('c.id', 'c.conversation_id', 'c.initiator_id', 'c.kind', 'c.is_group', 'c.status', 'c.started_at', 'c.ended_at');
  res.json({ data: rows });
}));
module.exports = router;
