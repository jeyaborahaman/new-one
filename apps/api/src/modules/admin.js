const router = require('express').Router();
const { z } = require('zod');
const db = require('../db/knex');
const validate = require('../middleware/validate');
const { authenticate, requireRole } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');
const { err } = require('../utils/errors');

router.use(authenticate);
const idParam = z.object({ id: z.coerce.number().int().positive() });

const { setUserStatus, audit } = require('./moderation/service');
// Optional { reason } is kept in the audit log.
const reasonBody = z.object({ reason: z.string().trim().max(500).optional() }).strict().default({});
const setStatus = (status, action) => [validate({ params: idParam, body: reasonBody }), asyncHandler(async (req, res) => {
  const u = await setUserStatus(req.params.id, status);
  await audit(req.user.id, action, `user:${u.id}`, req.body.reason ? { reason: req.body.reason } : null);
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

// Analytics: signups per day (last 14d), content volume, open reports, live connections.
router.get('/analytics', requireRole('admin'), asyncHandler(async (_req, res) => {
  const since = new Date(Date.now() - 14 * 864e5);
  const bucket = async (table, col = 'created_at', where = {}) => {
    const days = {}; for (let i = 13; i >= 0; i--) days[new Date(Date.now() - i * 864e5).toISOString().slice(0, 10)] = 0;
    (await db(table).where(where).where(col, '>=', since).select(col)).forEach((r) => { const d = new Date(r[col]).toISOString().slice(0, 10); if (d in days) days[d] += 1; });
    return Object.entries(days).map(([day, count]) => ({ day, count }));
  };
  const n = async (t, w = {}) => Number((await db(t).where(w).count({ c: '*' }).first()).c);
  res.json({
    signups: await bucket('users'), posts: await bucket('posts'), messages: await bucket('messages'),
    totals: { users: await n('users'), banned: await n('users', { status: 'banned' }), open_reports: await n('reports', { status: 'open' }), coins_in_circulation: Number((await db('wallets').sum({ s: 'balance' }).first()).s || 0) },
    live_connections: require('../realtime/bus').onlineCount(),
  });
}));

module.exports = router;
