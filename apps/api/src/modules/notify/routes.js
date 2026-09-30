const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { pageQuery, page } = require('../../utils/pagination');
const { TYPES } = require('./service');
router.use(authenticate);

router.post('/devices', validate({ body: z.object({ token: z.string().min(20).max(400), platform: z.enum(['android', 'ios', 'web']) }).strict() }), asyncHandler(async (req, res) => {
  await db('devices').insert({ user_id: req.user.id, ...req.body }).onConflict('token').merge({ user_id: req.user.id, platform: req.body.platform });
  res.status(204).end();
}));
router.delete('/devices', validate({ body: z.object({ token: z.string().min(20).max(400) }).strict() }), asyncHandler(async (req, res) => {
  await db('devices').where({ user_id: req.user.id, token: req.body.token }).del(); res.status(204).end();
}));

router.get('/notifications', validate({ query: pageQuery }), asyncHandler(async (req, res) => {
  const { limit, cursor } = req.query;
  const q = db('notifications').where({ user_id: req.user.id }).orderBy('id', 'desc').limit(limit + 1);
  if (cursor) q.where('id', '<', cursor);
  const out = page(await q, limit);
  const unread = Number((await db('notifications').where({ user_id: req.user.id }).whereNull('read_at').count({ c: '*' }).first()).c);
  res.json({ ...out, data: out.data.map((n) => ({ ...n, payload: JSON.parse(n.payload || '{}') })), unread });
}));
router.post('/notifications/read', validate({ body: z.object({ up_to_id: z.number().int().positive() }).strict() }), asyncHandler(async (req, res) => {
  await db('notifications').where({ user_id: req.user.id }).where('id', '<=', req.body.up_to_id).whereNull('read_at').update({ read_at: new Date() });
  res.status(204).end();
}));
router.get('/notifications/prefs', asyncHandler(async (req, res) => {
  const rows = await db('notification_prefs').where({ user_id: req.user.id });
  const m = Object.fromEntries(rows.map((r) => [r.type, !!r.push]));
  res.json(Object.fromEntries(TYPES.map((t) => [t, m[t] ?? true])));
}));
router.put('/notifications/prefs', validate({ body: z.partialRecord(z.enum(TYPES), z.boolean()) }), asyncHandler(async (req, res) => {
  for (const [type, on] of Object.entries(req.body)) await db('notification_prefs').insert({ user_id: req.user.id, type, push: on }).onConflict(['user_id', 'type']).merge({ push: on });
  res.status(204).end();
}));
module.exports = router;
