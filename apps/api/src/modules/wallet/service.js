const db = require('../../db/knex');
const { err } = require('../../utils/errors');

const levelFor = (xp) => Math.floor(Math.sqrt(Number(xp) / 100)) + 1;

/** Atomically move coins. amount>0 credits, amount<0 spends (fails if balance would go negative).
 *  A repeated idempotencyKey returns the original transaction and changes nothing. */
async function applyCoins(userId, amount, reason, { refType, refId, idempotencyKey, trx: outer } = {}) {
  const run = async (trx) => {
    if (idempotencyKey) {
      const prior = await trx('wallet_transactions').where({ idempotency_key: idempotencyKey }).first();
      if (prior) return { ...prior, replayed: true };
    }
    await trx('wallets').insert({ user_id: userId, balance: 0 }).onConflict('user_id').ignore();
    const q = trx('wallets').where({ user_id: userId });
    if (amount < 0) q.andWhere('balance', '>=', -amount);
    const changed = await q.update({ balance: trx.raw('balance + ?', [amount]) });
    if (!changed) throw err.badRequest('Insufficient coins');
    const { balance } = await trx('wallets').where({ user_id: userId }).first('balance');
    const [id] = await trx('wallet_transactions').insert({ user_id: userId, amount, balance_after: balance, reason, ref_type: refType, ref_id: refId, idempotency_key: idempotencyKey });
    return { id, amount, balance_after: Number(balance), reason, replayed: false };
  };
  return outer ? run(outer) : db.transaction(run);
}

async function grantXp(userId, xp) {
  await db('users').where({ id: userId }).update({ xp: db.raw('xp + ?', [xp]) });
  const u = await db('users').where({ id: userId }).first('xp', 'level');
  const level = levelFor(u.xp);
  if (level !== u.level) await db('users').where({ id: userId }).update({ level });
}

const utcDay = (d = new Date()) => d.toISOString().slice(0, 10);

async function claimDaily(userId) {
  const today = utcDay();
  const yesterday = utcDay(new Date(Date.now() - 864e5));
  return db.transaction(async (trx) => {
    if (await trx('daily_rewards').where({ user_id: userId, day: today }).first()) throw err.conflict('Already claimed today');
    const prev = await trx('daily_rewards').where({ user_id: userId, day: yesterday }).first('streak');
    const streak = (prev?.streak || 0) + 1;
    const coins = Math.min(10 + 5 * (streak - 1), 50);
    await trx('daily_rewards').insert({ user_id: userId, day: today, streak, coins });
    const tx = await applyCoins(userId, coins, 'daily', { trx, idempotencyKey: `daily:${userId}:${today}` });
    return { streak, coins, balance: tx.balance_after };
  });
}

module.exports = { applyCoins, grantXp, claimDaily, levelFor };
