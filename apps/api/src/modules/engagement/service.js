const db = require('../../db/knex');
const { err } = require('../../utils/errors');
const { applyCoins } = require('../wallet/service');

const REFERRER_BONUS = 50; const REFEREE_BONUS = 20;
const count = async (q) => Number((await q.count({ c: '*' }).first()).c);

const BADGES = [
  { code: 'first_post', name: 'First Post', description: 'Publish your first post', test: (s) => s.posts >= 1 },
  { code: 'chatterbox', name: 'Chatterbox', description: 'Write 25 comments', test: (s) => s.comments >= 25 },
  { code: 'popular', name: 'Popular', description: 'Reach 10 followers', test: (s) => s.followers >= 10 },
  { code: 'level_5', name: 'Level 5', description: 'Reach level 5', test: (s) => s.level >= 5 },
  { code: 'streak_7', name: 'Week Streak', description: 'Claim daily rewards 7 days in a row', test: (s) => s.streak >= 7 },
  { code: 'connector', name: 'Connector', description: 'Refer 3 friends', test: (s) => s.referrals >= 3 },
];
let seeded = false;
async function ensureBadges() {
  if (seeded) return;
  for (const b of BADGES) await db('badges').insert({ code: b.code, name: b.name, description: b.description }).onConflict('code').ignore();
  seeded = true;
}

async function checkBadges(userId) {
  await ensureBadges();
  const u = await db('users').where({ id: userId }).first('level', 'followers_count');
  const s = {
    level: u.level, followers: u.followers_count,
    posts: await count(db('posts').where({ author_id: userId, status: 'published' })),
    comments: await count(db('comments').where({ author_id: userId }).whereNull('deleted_at')),
    referrals: await count(db('referrals').where({ referrer_id: userId })),
    streak: (await db('daily_rewards').where({ user_id: userId }).max({ m: 'streak' }).first()).m || 0,
  };
  const owned = new Set((await db('user_badges as ub').join('badges as b', 'b.id', 'ub.badge_id').where('ub.user_id', userId).select('b.code')).map((r) => r.code));
  const earned = [];
  for (const b of BADGES) {
    if (owned.has(b.code) || !b.test(s)) continue;
    const row = await db('badges').where({ code: b.code }).first('id');
    const ins = await db('user_badges').insert({ user_id: userId, badge_id: row.id }).onConflict(['user_id', 'badge_id']).ignore();
    if (ins) { earned.push(b); await require('../notify/service').notify(userId, 'reward', { title: 'Badge earned', body: b.name, t: { title: ['badge_title'], body: ['badge', { code: b.code, name: b.name }] }, data: { badge: b.code } }); }
  }
  return earned.map((b) => b.code);
}
const myBadges = (userId) => db('user_badges as ub').join('badges as b', 'b.id', 'ub.badge_id').where('ub.user_id', userId).select('b.code', 'b.name', 'b.description', 'ub.created_at as earned_at');

async function applyReferral(userId, code) {
  const referrer = await db('users').where({ referral_code: String(code).toUpperCase() }).first('id');
  if (!referrer) throw err.badRequest('Unknown referral code');
  if (referrer.id === userId) throw err.badRequest('You cannot refer yourself');
  if (await db('referrals').where({ referred_id: userId }).first()) throw err.conflict('Referral already applied');
  await db.transaction(async (trx) => {
    await trx('referrals').insert({ referrer_id: referrer.id, referred_id: userId, bonus_coins: REFERRER_BONUS });
    await applyCoins(referrer.id, REFERRER_BONUS, 'referral', { trx, refType: 'user', refId: userId, idempotencyKey: `ref:${userId}:referrer` });
    await applyCoins(userId, REFEREE_BONUS, 'referral', { trx, refType: 'user', refId: referrer.id, idempotencyKey: `ref:${userId}:referee` });
  });
  await require('../notify/service').notify(referrer.id, 'reward', { title: 'Referral bonus', body: `You earned ${REFERRER_BONUS} coins`, t: { title: ['referral_title'], body: ['referral_body', { coins: REFERRER_BONUS }] }, data: { coins: REFERRER_BONUS } });
  await checkBadges(referrer.id);
  return { bonus_coins: REFEREE_BONUS };
}
async function myReferrals(userId) {
  const u = await db('users').where({ id: userId }).first('referral_code');
  const rows = await db('referrals as r').join('users as x', 'x.id', 'r.referred_id').where('r.referrer_id', userId).select('x.username', 'r.bonus_coins', 'r.created_at');
  return { code: u.referral_code, total: rows.length, coins_earned: rows.reduce((a, r) => a + r.bonus_coins, 0), data: rows };
}

async function leaderboard(period) {
  if (period === 'all') return db('users').where({ status: 'active' }).orderBy('xp', 'desc').limit(50).select('id', 'username', 'display_name', 'level', 'xp');
  const since = new Date(Date.now() - 7 * 864e5);
  return db('xp_events as e').join('users as u', 'u.id', 'e.user_id').where('e.created_at', '>=', since).andWhere('u.status', 'active')
    .groupBy('u.id', 'u.username', 'u.display_name', 'u.level').orderBy('xp', 'desc').limit(50)
    .select('u.id', 'u.username', 'u.display_name', 'u.level', db.raw('sum(e.xp) as xp'));
}

// ---- challenges ----
const METRIC_ACTION = { post: 'post', comment: 'comment', reaction: 'reaction' };
async function progressOf(ch, userId, joinedAt) {
  const from = new Date(Math.max(new Date(ch.starts_at), new Date(joinedAt)));
  const q = db('xp_events').where({ user_id: userId }).where('created_at', '>=', from).where('created_at', '<=', ch.ends_at);
  if (ch.metric === 'xp') return Number((await q.sum({ s: 'xp' }).first()).s || 0);
  return count(q.where({ action: METRIC_ACTION[ch.metric] }));
}
async function listChallenges(userId) {
  const now = new Date();
  const rows = await db('challenges').where('ends_at', '>=', now).orderBy('ends_at');
  const mine = Object.fromEntries((await db('challenge_progress').where({ user_id: userId })).map((r) => [r.challenge_id, r]));
  return Promise.all(rows.map(async (c) => {
    const m = mine[c.id];
    return { ...c, joined: !!m, claimed: !!m?.claimed_at, progress: m ? Math.min(await progressOf(c, userId, m.joined_at), c.target) : 0 };
  }));
}
async function joinChallenge(userId, id) {
  const c = await db('challenges').where({ id }).first();
  if (!c || new Date(c.ends_at) < new Date()) throw err.notFound('Challenge not found');
  await db('challenge_progress').insert({ challenge_id: id, user_id: userId }).onConflict(['challenge_id', 'user_id']).ignore();
}
async function claimChallenge(userId, id) {
  const c = await db('challenges').where({ id }).first();
  const m = await db('challenge_progress').where({ challenge_id: id, user_id: userId }).first();
  if (!c || !m) throw err.notFound('Join the challenge first');
  if (m.claimed_at) throw err.conflict('Already claimed');
  if ((await progressOf(c, userId, m.joined_at)) < c.target) throw err.badRequest('Challenge not complete');
  const marked = await db('challenge_progress').where({ challenge_id: id, user_id: userId }).whereNull('claimed_at').update({ claimed_at: new Date() });
  if (!marked) throw err.conflict('Already claimed');
  const tx = await applyCoins(userId, c.reward_coins, 'challenge', { refType: 'challenge', refId: id, idempotencyKey: `challenge:${id}:${userId}` });
  return { coins: c.reward_coins, balance: tx.balance_after };
}

module.exports = { checkBadges, myBadges, applyReferral, myReferrals, leaderboard, listChallenges, joinChallenge, claimChallenge };
