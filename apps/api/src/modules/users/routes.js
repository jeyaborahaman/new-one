const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { publicUser } = require('../auth/service');
const { isBlocked, assertNotBlocked } = require('./blocks');
const { deleteAccount } = require('./account');
const { LANGS } = require('../../i18n');

const idParam = z.object({ id: z.coerce.number().int().positive() });
router.use(authenticate);

router.get('/me', asyncHandler(async (req, res) => res.json(publicUser(await db('users').where({ id: req.user.id }).first()))));

router.patch('/me', validate({ body: z.object({ display_name: z.string().min(1).max(80).optional(), bio: z.string().max(300).optional(), locale: z.enum(LANGS).optional() }).strict() }),
  asyncHandler(async (req, res) => {
    if (Object.keys(req.body).length) await db('users').where({ id: req.user.id }).update(req.body);
    res.json(publicUser(await db('users').where({ id: req.user.id }).first()));
  }));

// Account deletion: the password confirms it on password accounts; phone/OAuth-only accounts confirm by typing DELETE.
router.delete('/me', validate({ body: z.object({ confirm: z.literal('DELETE'), password: z.string().min(1).max(128).optional() }).strict() }), asyncHandler(async (req, res) => {
  await deleteAccount(req.user.id, req.body.password);
  res.status(204).end();
}));

router.get('/me/blocks', asyncHandler(async (req, res) => {
  const rows = await db('user_blocks as b').join('users as u', 'u.id', 'b.blocked_id').where('b.blocker_id', req.user.id).orderBy('b.created_at', 'desc').select('u.id', 'u.username', 'u.display_name', 'b.created_at');
  res.json({ data: rows });
}));

router.get('/:id', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const u = await db('users').where({ id: req.params.id, status: 'active' }).first();
  if (!u || (await isBlocked(req.user.id, u.id))) throw err.notFound('User not found');
  const following = !!(await db('follows').where({ follower_id: req.user.id, followee_id: u.id }).first());
  res.json({ ...publicUser(u), following });
}));

router.post('/:id/follow', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const target = req.params.id;
  if (target === req.user.id) throw err.badRequest('Cannot follow yourself');
  if (!(await db('users').where({ id: target, status: 'active' }).first('id'))) throw err.notFound('User not found');
  await assertNotBlocked(req.user.id, target);
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

// Block: also unfollows both ways and drops friend requests/friendship, so no feed, DM or profile contact remains.
router.post('/:id/block', validate({ params: idParam }), asyncHandler(async (req, res) => {
  const target = req.params.id;
  if (target === req.user.id) throw err.badRequest('Cannot block yourself');
  if (!(await db('users').where({ id: target }).whereNot({ status: 'deleted' }).first('id'))) throw err.notFound('User not found');
  await db.transaction(async (trx) => {
    await trx('user_blocks').insert({ blocker_id: req.user.id, blocked_id: target }).onConflict(['blocker_id', 'blocked_id']).ignore();
    await trx('follows').where({ follower_id: req.user.id, followee_id: target }).orWhere({ follower_id: target, followee_id: req.user.id }).del();
    await trx('friendships').where({ requester_id: req.user.id, addressee_id: target }).orWhere({ requester_id: target, addressee_id: req.user.id }).del();
    await syncCounts(trx, req.user.id, target);
    await syncCounts(trx, target, req.user.id);
  });
  res.status(204).end();
}));
router.delete('/:id/block', validate({ params: idParam }), asyncHandler(async (req, res) => {
  await db('user_blocks').where({ blocker_id: req.user.id, blocked_id: req.params.id }).del();
  res.status(204).end();
}));

// Recompute from source of truth: race-safe and idempotent.
async function syncCounts(trx, followerId, followeeId) {
  const cnt = async (col, id) => Number((await trx('follows').where({ [col]: id }).count({ c: '*' }).first()).c);
  await trx('users').where({ id: followerId }).update({ following_count: await cnt('follower_id', followerId) });
  await trx('users').where({ id: followeeId }).update({ followers_count: await cnt('followee_id', followeeId) });
}

module.exports = router;
