const router = require('express').Router();
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { pageQuery, page } = require('../../utils/pagination');
const { claimDaily } = require('./service');

router.use(authenticate);

router.get('/wallet', asyncHandler(async (req, res) => {
  const w = await db('wallets').where({ user_id: req.user.id }).first();
  res.json({ balance: Number(w?.balance || 0) });
}));

router.get('/wallet/transactions', validate({ query: pageQuery }), asyncHandler(async (req, res) => {
  const { limit, cursor } = req.query;
  const q = db('wallet_transactions').where({ user_id: req.user.id }).orderBy('id', 'desc').limit(limit + 1);
  if (cursor) q.where('id', '<', cursor);
  res.json(page(await q, limit));
}));

router.post('/rewards/daily/claim', asyncHandler(async (req, res) => res.json(await claimDaily(req.user.id))));

module.exports = router;
