const router = require('express').Router();
const { z } = require('zod');
const db = require('../db/knex');
const validate = require('../middleware/validate');
const { authenticate, requireRole } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');
const { err } = require('../utils/errors');

router.use(authenticate);
const idParam = z.object({ id: z.coerce.number().int().positive() });

const setStatus = (status, action) => [validate({ params: idParam }), asyncHandler(async (req, res) => {
  const u = await db('users').where({ id: req.params.id }).first();
  if (!u) throw err.notFound('User not found');
  if (u.role !== 'user') throw err.forbidden('Cannot moderate staff accounts');
  await db('users').where({ id: u.id }).update({ status });
  if (status !== 'active') await db('sessions').where({ user_id: u.id }).whereNull('revoked_at').update({ revoked_at: new Date() });
  await db('audit_logs').insert({ actor_id: req.user.id, action, target: `user:${u.id}` });
  res.json({ id: u.id, status });
})];

router.post('/users/:id/ban', requireRole('admin'), ...setStatus('banned', 'user.ban'));
router.post('/users/:id/suspend', requireRole('admin'), ...setStatus('suspended', 'user.suspend'));
router.post('/users/:id/reinstate', requireRole('admin'), ...setStatus('active', 'user.reinstate'));
router.post('/users/:id/verify', requireRole('admin'), validate({ params: idParam }), asyncHandler(async (req, res) => {
  await db('users').where({ id: req.params.id }).update({ is_verified: true });
  await db('audit_logs').insert({ actor_id: req.user.id, action: 'user.verify', target: `user:${req.params.id}` });
  res.json({ id: req.params.id, is_verified: true });
}));
router.put('/flags/:key', requireRole('superadmin'), validate({ params: z.object({ key: z.enum(['LUCKY_DRAW_ENABLED']) }), body: z.object({ enabled: z.boolean() }).strict() }),
  asyncHandler(async (req, res) => {
    await db('feature_flags').insert({ k: req.params.key, enabled: req.body.enabled }).onConflict('k').merge();
    await db('audit_logs').insert({ actor_id: req.user.id, action: 'flag.set', target: req.params.key, meta: JSON.stringify(req.body) });
    res.json({ key: req.params.key, enabled: req.body.enabled });
  }));
router.get('/stats', requireRole('admin'), asyncHandler(async (_req, res) => {
  const n = async (t, w = {}) => Number((await db(t).where(w).count({ c: '*' }).first()).c);
  res.json({ users: await n('users'), posts: await n('posts', { status: 'published' }), messages: await n('messages') });
}));

module.exports = router;
