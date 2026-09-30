const router = require('express').Router();
const { z } = require('zod');
const crypto = require('crypto');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate, requireRole } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const svc = require('./service');

const idParam = z.object({ id: z.coerce.number().int().positive() });

// Feature gate: a disabled feature is indistinguishable from a missing route.
const gate = asyncHandler(async (_req, _res, next) => ((await svc.isEnabled()) ? next() : next(err.notFound('Route not found'))));

const user = require('express').Router();
user.use(authenticate, gate);
user.get('/campaigns', asyncHandler(async (req, res) => {
  const rows = await db('lucky_campaigns').whereIn('status', ['open', 'closed', 'published']).orderBy('id', 'desc').limit(50);
  res.json({ data: rows.filter((c) => svc.regionAllowed(c, req.user.country)).map(svc.publicCampaign) });
}));
user.get('/campaigns/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const c = await db('lucky_campaigns').where({ id: req.params.id }).whereNot({ status: 'draft' }).first();
  if (!c || !svc.regionAllowed(c, req.user.country)) throw err.notFound('Campaign not found');
  const entries = Number((await db('lucky_entries').where({ campaign_id: c.id, user_id: req.user.id }).count({ c: '*' }).first()).c);
  res.json({ ...svc.publicCampaign(c), my_entries: entries });
}));
user.post('/campaigns/:id/join', validate({ params: idParam }), asyncHandler(async (req, res) => res.status(201).json(await svc.join(req.params.id, req.user))));
user.get('/me/entries', asyncHandler(async (req, res) => res.json({ data: await db('lucky_entries').where({ user_id: req.user.id }).orderBy('id', 'desc').limit(100) })));
user.get('/campaigns/:id/results', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const c = await db('lucky_campaigns').where({ id: req.params.id, status: 'published' }).first();
  if (!c) throw err.notFound('Results not published');
  const data = await db('lucky_results').where({ campaign_id: c.id }).orderBy('rank_no').select('rank_no', 'user_id', 'entry_id');
  res.json({ data, seed: c.seed_secret, seed_hash: c.seed_hash, verify: 'seed_hash = sha256(seed); rank entries by HMAC-SHA256(seed, entry_id) ascending, one win per user' });
}));

const admin = require('express').Router();
admin.use(authenticate, requireRole('admin'), gate);
admin.post('/campaigns', validate({ body: z.object({
  title: z.string().min(1).max(150), description: z.string().max(5000).optional(), coins_per_entry: z.number().int().min(0).default(0),
  max_entries_per_user: z.number().int().min(1).max(1000).default(1), allowed_countries: z.array(z.string().length(2)).default([]),
  disclaimer: z.string().max(2000).optional(), winners_count: z.number().int().min(1).max(1000).default(1),
  starts_at: z.coerce.date().optional(), ends_at: z.coerce.date().optional(),
}).strict() }), asyncHandler(async (req, res) => {
  const [id] = await db('lucky_campaigns').insert({ ...req.body, allowed_countries: JSON.stringify(req.body.allowed_countries.map((s) => s.toUpperCase())), created_by: req.user.id });
  res.status(201).json(svc.publicCampaign(await db('lucky_campaigns').where({ id }).first()));
}));
// Opening commits the seed: its hash becomes public, the secret stays hidden until results are published.
admin.post('/campaigns/:id/open', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const c = await db('lucky_campaigns').where({ id: req.params.id }).first();
  if (!c) throw err.notFound('Campaign not found');
  if (c.status !== 'draft') throw err.conflict('Only drafts can be opened');
  const secret = crypto.randomBytes(32).toString('hex');
  await db('lucky_campaigns').where({ id: c.id }).update({ status: 'open', seed_secret: secret, seed_hash: svc.sha(secret) });
  res.json(svc.publicCampaign(await db('lucky_campaigns').where({ id: c.id }).first()));
}));
admin.get('/campaigns/:id/entries', validate({ params: idParam }), asyncHandler(async (req, res) => res.json({ data: await db('lucky_entries').where({ campaign_id: req.params.id }).orderBy('id') })));
admin.post('/campaigns/:id/draw', validate({ params: idParam }), asyncHandler(async (req, res) => res.json(await svc.draw(req.params.id, req.user.id))));
admin.post('/campaigns/:id/publish', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const c = await db('lucky_campaigns').where({ id: req.params.id }).first();
  if (!c) throw err.notFound('Campaign not found');
  if (c.status !== 'closed' || !(await db('lucky_results').where({ campaign_id: c.id }).first())) throw err.conflict('Draw first');
  await db('lucky_results').where({ campaign_id: c.id }).update({ published_at: new Date() });
  await db('lucky_campaigns').where({ id: c.id }).update({ status: 'published' });
  await db('audit_logs').insert({ actor_id: req.user.id, action: 'luckydraw.publish', target: `campaign:${c.id}` });
  res.json({ status: 'published' });
}));
admin.get('/campaigns/:id/analytics', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const r = await db('lucky_entries').where({ campaign_id: req.params.id }).select(db.raw('count(*) as entries'), db.raw('count(distinct user_id) as participants')).first();
  res.json({ entries: Number(r.entries), participants: Number(r.participants) });
}));

module.exports = { user, admin };
