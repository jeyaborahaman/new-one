const crypto = require('crypto');
const env = require('../../config/env');
const db = require('../../db/knex');
const { err } = require('../../utils/errors');
const { applyCoins } = require('../wallet/service');

/** DB flag (set by superadmin) overrides the env default, so operators can switch it off instantly. */
async function isEnabled() {
  const row = await db('feature_flags').where({ k: 'LUCKY_DRAW_ENABLED' }).first();
  return row ? !!row.enabled : env.LUCKY_DRAW_ENABLED;
}

const regionsOf = (c) => { try { return JSON.parse(c.allowed_countries || '[]'); } catch { return []; } };
function regionAllowed(campaign, country) {
  const list = regionsOf(campaign);
  const global = env.LUCKY_DRAW_REGIONS;
  const c = (country || '').toUpperCase();
  if (global.length && !global.includes(c)) return false;
  return !list.length || list.includes(c);
}

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
const publicCampaign = (c) => ({ id: c.id, title: c.title, description: c.description, status: c.status, coins_per_entry: c.coins_per_entry, max_entries_per_user: c.max_entries_per_user, disclaimer: c.disclaimer, winners_count: c.winners_count, starts_at: c.starts_at, ends_at: c.ends_at, seed_hash: c.seed_hash });

async function join(campaignId, user) {
  return db.transaction(async (trx) => {
    const c = await trx('lucky_campaigns').where({ id: campaignId }).first();
    if (!c) throw err.notFound('Campaign not found');
    if (!regionAllowed(c, user.country)) throw err.notFound('Campaign not found'); // do not reveal region-gated campaigns
    const now = new Date();
    if (c.status !== 'open' || (c.starts_at && new Date(c.starts_at) > now) || (c.ends_at && new Date(c.ends_at) < now)) throw err.badRequest('Campaign is not open');
    const mine = Number((await trx('lucky_entries').where({ campaign_id: c.id, user_id: user.id }).count({ c: '*' }).first()).c);
    if (mine >= c.max_entries_per_user) throw err.conflict('Entry limit reached');
    if (c.coins_per_entry > 0) await applyCoins(user.id, -c.coins_per_entry, 'luckydraw', { trx, refType: 'campaign', refId: c.id, idempotencyKey: `lucky:${c.id}:${user.id}:${mine + 1}` });
    const [id] = await trx('lucky_entries').insert({ campaign_id: c.id, user_id: user.id, source: c.coins_per_entry > 0 ? 'coins' : 'free' });
    return { entry_id: id, entries: mine + 1, max_entries: c.max_entries_per_user };
  });
}

/** Deterministic, auditable draw: rank entries by HMAC(secret, entryId); one win per user. */
async function draw(campaignId, actorId) {
  return db.transaction(async (trx) => {
    const c = await trx('lucky_campaigns').where({ id: campaignId }).first();
    if (!c) throw err.notFound('Campaign not found');
    if (c.status !== 'open' && c.status !== 'closed') throw err.conflict(`Cannot draw a ${c.status} campaign`);
    if (await trx('lucky_results').where({ campaign_id: c.id }).first()) throw err.conflict('Already drawn');
    const entries = await trx('lucky_entries').where({ campaign_id: c.id });
    const ranked = entries.map((e) => ({ ...e, score: crypto.createHmac('sha256', c.seed_secret).update(String(e.id)).digest('hex') })).sort((a, b) => (a.score < b.score ? -1 : 1));
    const seen = new Set(); const winners = [];
    for (const e of ranked) { if (!seen.has(e.user_id) && winners.length < c.winners_count) { seen.add(e.user_id); winners.push(e); } }
    for (const [i, w] of winners.entries()) await trx('lucky_results').insert({ campaign_id: c.id, rank_no: i + 1, entry_id: w.id, user_id: w.user_id, seed: c.seed_secret });
    await trx('lucky_campaigns').where({ id: c.id }).update({ status: 'closed' });
    await trx('audit_logs').insert({ actor_id: actorId, action: 'luckydraw.draw', target: `campaign:${c.id}`, meta: JSON.stringify({ entries: entries.length, winners: winners.length }) });
    return { winners: winners.length, entries: entries.length };
  });
}

module.exports = { isEnabled, regionAllowed, publicCampaign, join, draw, sha };
