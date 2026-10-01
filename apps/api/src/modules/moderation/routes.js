const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate, requireRole } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { removeTarget } = require('./service');
const TARGETS = ['post', 'comment', 'user'];
router.use(authenticate);

router.post('/reports', validate({ body: z.object({ target_type: z.enum(TARGETS), target_id: z.number().int().positive(), reason: z.enum(['spam', 'harassment', 'hate', 'sexual', 'violence', 'self_harm', 'other']), details: z.string().max(1000).optional() }).strict() }),
  asyncHandler(async (req, res) => {
    const { target_type: type, target_id: targetId } = req.body;
    if (type === 'user' && targetId === req.user.id) throw err.badRequest('You cannot report yourself');
    const exists = type === 'user' ? db('users').where({ id: targetId }).whereNot({ status: 'deleted' })
      : type === 'post' ? db('posts').where({ id: targetId }).whereNot({ status: 'removed' })
      : db('comments').where({ id: targetId }).whereNull('deleted_at');
    if (!(await exists.first('id'))) throw err.notFound(`${type[0].toUpperCase()}${type.slice(1)} not found`);
    const dup = await db('reports').where({ reporter_id: req.user.id, target_type: req.body.target_type, target_id: req.body.target_id }).whereIn('status', ['open', 'reviewing']).first('id');
    if (dup) throw err.conflict('You already reported this');
    const [id] = await db('reports').insert({ reporter_id: req.user.id, ...req.body });
    res.status(201).json({ id });
  }));

// The reports queue, details, review/resolve/reject: see ./admin.js. This older one-step action stays for existing clients.
router.post('/admin/reports/:id/action', requireRole('moderator'), validate({ params: z.object({ id: z.coerce.number().int().positive() }), body: z.object({ action: z.enum(['remove', 'dismiss']) }).strict() }), asyncHandler(async (req, res) => {
  const r = await db('reports').where({ id: req.params.id }).whereIn('status', ['open', 'reviewing']).first();
  if (!r) throw err.notFound('Open report not found');
  if (req.body.action === 'remove') {
    if (r.target_type === 'user' && req.user.role === 'moderator') throw err.forbidden('Only admins can act on users');
    await removeTarget(r.target_type, r.target_id);
  }
  await db('reports').where({ id: r.id }).update({ status: req.body.action === 'remove' ? 'actioned' : 'dismissed', resolution: req.body.action === 'remove' ? (r.target_type === 'user' ? 'user_suspended' : 'content_removed') : 'no_violation', handled_by: req.user.id, handled_at: new Date() });
  await db('audit_logs').insert({ actor_id: req.user.id, action: `report.${req.body.action}`, target: `${r.target_type}:${r.target_id}` });
  res.json({ id: r.id, status: req.body.action === 'remove' ? 'actioned' : 'dismissed' });
}));
module.exports = router;
