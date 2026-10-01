const db = require('../../db/knex');
const ai = require('../../integrations/ai');
const { HttpError, err } = require('../../utils/errors');

/** Throws 422 for clearly violating text; returns the score so callers can store it. */
async function assertClean(text) {
  const r = await ai.moderateText(text);
  if (r.flagged) throw new HttpError(422, 'CONTENT_REJECTED', 'This content violates the community guidelines');
  return r.score;
}
async function removeTarget(type, id) {
  if (type === 'post') await db('posts').where({ id }).update({ status: 'removed' });
  else if (type === 'comment') await db('comments').where({ id }).update({ deleted_at: new Date() });
  else if (type === 'user') {
    const u = await db('users').where({ id }).first('role');
    if (u && u.role !== 'user') throw err.forbidden('Cannot moderate staff accounts');
    await db('users').where({ id }).update({ status: 'suspended' });
    await db('sessions').where({ user_id: id }).whereNull('revoked_at').update({ revoked_at: new Date() });
    require('../../realtime/bus').disconnectUser(id);
  }
}
module.exports = { assertClean, removeTarget };
