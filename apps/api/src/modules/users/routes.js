const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { publicUser } = require('../auth/service');

const idParam = z.object({ id: z.coerce.number().int().positive() });
router.use(authenticate);

router.get('/me', asyncHandler(async (req, res) => res.json(publicUser(await db('users').where({ id: req.user.id }).first()))));

router.patch('/me', validate({ body: z.object({ display_name: z.string().min(1).max(80).optional(), bio: z.string().max(300).optional() }).strict() }),
  asyncHandler(async (req, res) => {
    if (Object.keys(req.body).length) await db('users').where({ id: req.user.id }).update(req.body);
    res.json(publicUser(await db('users').where({ id: req.user.id }).first()));
  }));

router.get('/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const u = await db('users').where({ id: req.params.id, status: 'active' }).first();
  if (!u) throw err.notFound('User not found');
  const following = !!(await db('follows').where({ follower_id: req.user.id, followee_id: u.id }).first());
  res.json({ ...publicUser(u), following });
}));

router.post('/:id/follow', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const target = req.params.id;
  if (target === req.user.id) throw err.badRequest('Cannot follow yourself');
  if (!(await db('users').where({ id: target, status: 'active' }).first('id'))) throw err.notFound('User not found');
  await db.transaction(async (trx) => {
    await trx('follows').insert({ follower_id: req.user.id, followee_id: target }).onConflict(['follower_id', 'followee_id']).ignore();
    await syncCounts(trx, req.user.id, target);
  });
  res.status(204).end();
}));

router.delete('/:id/follow', validate({ params: idParam }), asyncHandler(async (req, res) => {
  await db.transaction(async (trx) => {
    await trx('follows').where({ follower_id: req.user.id, followee_id: req.params.id }).del();
    await syncCounts(trx, req.user.id, req.params.id);
  });
  res.status(204).end();
}));

// Recompute from source of truth: race-safe and idempotent.
async function syncCounts(trx, followerId, followeeId) {
  const cnt = async (col, id) => Number((await trx('follows').where({ [col]: id }).count({ c: '*' }).first()).c);
  await trx('users').where({ id: followerId }).update({ following_count: await cnt('follower_id', followerId) });
  await trx('users').where({ id: followeeId }).update({ followers_count: await cnt('followee_id', followeeId) });
}

module.exports = router;
