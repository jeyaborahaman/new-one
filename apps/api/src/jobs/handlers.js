const db = require('../db/knex');
const bus = require('../realtime/bus');

const HANDLERS = {
  /** Scheduled posts whose time has come. */
  async publishScheduled() {
    return db('posts').where({ status: 'scheduled' }).where('publish_at', '<=', new Date()).update({ status: 'published' });
  },
  /** Stories past 24h: remove rows and their views/reactions. */
  async expireStories() {
    const ids = (await db('stories').where('expires_at', '<=', new Date()).limit(1000).select('id')).map((r) => r.id);
    if (!ids.length) return 0;
    await db.transaction(async (trx) => {
      await trx('story_views').whereIn('story_id', ids).del();
      await trx('reactions').where({ target_type: 'story' }).whereIn('target_id', ids).del();
      await trx('stories').whereIn('id', ids).del();
    });
    return ids.length;
  },
  /** Ringing calls nobody answered within the ring window. */
  async expireCalls() {
    const stale = await db('call_sessions').where({ status: 'ringing' }).where('created_at', '<=', new Date(Date.now() - 60_000));
    for (const c of stale) {
      await db('call_sessions').where({ id: c.id }).update({ status: 'missed', ended_at: new Date() });
      bus.emitToUser(c.initiator_id, 'call:state', { call_id: c.id, status: 'missed' });
    }
    return stale.length;
  },
  /** Lucky Draw campaigns whose end time passed stop accepting entries. */
  async closeCampaigns() {
    return db('lucky_campaigns').where({ status: 'open' }).where('ends_at', '<=', new Date()).update({ status: 'closed' });
  },
  /** Housekeeping: OTPs after a day, revoked/expired sessions after 30 days. */
  async cleanup() {
    const otp = await db('otp_codes').where('created_at', '<', new Date(Date.now() - 864e5)).del();
    const sessions = await db('sessions').where('expires_at', '<', new Date(Date.now() - 30 * 864e5)).del();
    return otp + sessions;
  },
};
const SCHEDULE_MS = { publishScheduled: 30_000, expireStories: 300_000, expireCalls: 30_000, closeCampaigns: 60_000, cleanup: 3_600_000 };
module.exports = { HANDLERS, SCHEDULE_MS };
