const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { pageQuery, page } = require('../../utils/pagination');
const svc = require('./service');
const realtime = require('../../realtime/bus');

const idParam = z.object({ id: z.coerce.number().int().positive() });
const messageBody = z.object({ client_id: z.string().uuid(), type: z.enum(['text', 'voice', 'image', 'video', 'file', 'sticker']).default('text'), body: z.string().max(4000).optional(), media_id: z.number().int().positive().optional() })
  .refine((m) => m.body || m.media_id, 'body or media_id required');
router.use(authenticate);

router.get('/', asyncHandler(async (req, res) => {
  const rows = await db('conversation_members as m').join('conversations as c', 'c.id', 'm.conversation_id').where('m.user_id', req.user.id)
    .orderByRaw('c.last_message_at is null, c.last_message_at desc').limit(100).select('c.id', 'c.type', 'c.title', 'c.last_message_at', 'm.last_read_message_id');
  res.json({ data: rows });
}));

router.post('/', validate({ body: z.discriminatedUnion('type', [
  z.object({ type: z.literal('direct'), user_id: z.number().int().positive() }).strict(),
  z.object({ type: z.literal('group'), title: z.string().min(1).max(100), member_ids: z.array(z.number().int().positive()).max(1000) }).strict(),
]) }), asyncHandler(async (req, res) => {
  const c = req.body.type === 'direct' ? await svc.openDirect(req.user.id, req.body.user_id) : await svc.createGroup(req.user.id, req.body.title, req.body.member_ids);
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

module.exports = { router, messageBody };
