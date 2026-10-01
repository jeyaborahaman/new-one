const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { notify } = require('../notify/service');
const { assertNotBlocked } = require('./blocks');
router.use(authenticate);
const uidParam = z.object({ uid: z.coerce.number().int().positive() });

async function syncFollowCounts(trx, ids) {
  for (const id of ids) {
    const n = async (col) => Number((await trx('follows').where({ [col]: id }).count({ c: '*' }).first()).c);
    await trx('users').where({ id }).update({ followers_count: await n('followee_id'), following_count: await n('follower_id') });
  }
}

router.post('/requests', validate({ body: z.object({ user_id: z.number().int().positive() }).strict() }), asyncHandler(async (req, res) => {
  const to = req.body.user_id;
  if (to === req.user.id) throw err.badRequest('Cannot befriend yourself');
  if (!(await db('users').where({ id: to, status: 'active' }).first('id'))) throw err.notFound('User not found');
  await assertNotBlocked(req.user.id, to);
  const existing = await db('friendships').where((w) => w.where({ requester_id: req.user.id, addressee_id: to }).orWhere({ requester_id: to, addressee_id: req.user.id })).first();
  if (existing) throw err.conflict(existing.status === 'accepted' ? 'Already friends' : 'Request already exists');
  await db('friendships').insert({ requester_id: req.user.id, addressee_id: to });
  const me = await db('users').where({ id: req.user.id }).first('display_name');
  await notify(to, 'friend_request', { title: me.display_name, body: 'Sent you a friend request', t: { body: ['friend_request'] }, data: { user_id: req.user.id } });
  res.status(201).json({ status: 'pending' });
}));
router.post('/requests/:uid/accept', validate({ params: uidParam }), asyncHandler(async (req, res) => {
  const n = await db('friendships').where({ requester_id: req.params.uid, addressee_id: req.user.id, status: 'pending' }).update({ status: 'accepted' });
  if (!n) throw err.notFound('No pending request');
  await db.transaction(async (trx) => { // friends follow each other
    await trx('follows').insert([{ follower_id: req.user.id, followee_id: req.params.uid }, { follower_id: req.params.uid, followee_id: req.user.id }]).onConflict(['follower_id', 'followee_id']).ignore();
    await syncFollowCounts(trx, [req.user.id, req.params.uid]);
  });
  res.status(204).end();
}));
router.delete('/requests/:uid', validate({ params: uidParam }), asyncHandler(async (req, res) => {
  await db('friendships').where({ status: 'pending' }).where((w) => w.where({ requester_id: req.params.uid, addressee_id: req.user.id }).orWhere({ requester_id: req.user.id, addressee_id: req.params.uid })).del();
  res.status(204).end();
}));
router.get('/requests', asyncHandler(async (req, res) => {
  const rows = await db('friendships as f').join('users as u', 'u.id', 'f.requester_id').where({ 'f.addressee_id': req.user.id, 'f.status': 'pending' }).select('u.id', 'u.username', 'u.display_name', 'f.created_at');
  res.json({ data: rows });
}));
router.get('/', asyncHandler(async (req, res) => {
  const rows = await db('friendships as f').join('users as u', (j) => j.on('u.id', db.raw('case when f.requester_id = ? then f.addressee_id else f.requester_id end', [req.user.id]))).where('f.status', 'accepted')
    .where((w) => w.where('f.requester_id', req.user.id).orWhere('f.addressee_id', req.user.id)).select('u.id', 'u.username', 'u.display_name');
  res.json({ data: rows });
}));
module.exports = router;
