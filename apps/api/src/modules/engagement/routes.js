const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate, requireRole } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const svc = require('./service');
const idParam = z.object({ id: z.coerce.number().int().positive() });
router.use(authenticate);

router.get('/me/badges', asyncHandler(async (req, res) => res.json({ data: await svc.myBadges(req.user.id) })));
router.get('/me/xp', asyncHandler(async (req, res) => {
  const u = await db('users').where({ id: req.user.id }).first('xp', 'level');
  const next = (u.level) ** 2 * 100;
  res.json({ xp: Number(u.xp), level: u.level, next_level_at: next });
}));
router.get('/leaderboards/:period', validate({ params: z.object({ period: z.enum(['week', 'all']) }) }), asyncHandler(async (req, res) => res.json({ data: await svc.leaderboard(req.params.period) })));
router.get('/referrals/me', asyncHandler(async (req, res) => res.json(await svc.myReferrals(req.user.id))));
router.post('/referrals/apply', validate({ body: z.object({ code: z.string().min(4).max(12) }).strict() }), asyncHandler(async (req, res) => res.json(await svc.applyReferral(req.user.id, req.body.code))));

router.get('/challenges', asyncHandler(async (req, res) => res.json({ data: await svc.listChallenges(req.user.id) })));
router.post('/challenges/:id/join', validate({ params: idParam }), asyncHandler(async (req, res) => { await svc.joinChallenge(req.user.id, req.params.id); res.status(204).end(); }));
router.post('/challenges/:id/claim', validate({ params: idParam }), asyncHandler(async (req, res) => res.json(await svc.claimChallenge(req.user.id, req.params.id))));
router.post('/admin/challenges', requireRole('admin'), validate({ body: z.object({ scope: z.enum(['weekly', 'community']).default('weekly'), title: z.string().min(1).max(120), metric: z.enum(['post', 'comment', 'reaction', 'xp']), target: z.number().int().min(1), reward_coins: z.number().int().min(1).max(10000), starts_at: z.coerce.date(), ends_at: z.coerce.date() }).strict() }),
  asyncHandler(async (req, res) => { const [id] = await db('challenges').insert(req.body); res.status(201).json(await db('challenges').where({ id }).first()); }));

module.exports = router;
