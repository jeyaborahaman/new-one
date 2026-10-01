const db = require('../../db/knex');
const ai = require('../../integrations/ai');
const { HttpError, err } = require('../../utils/errors');

/** Throws 422 for clearly violating text; returns the score so callers can store it. */
async function assertClean(text) {
  const r = await ai.moderateText(text);
  if (r.flagged) throw new HttpError(422, 'CONTENT_REJECTED', 'This content violates the community guidelines');
  return r.score;
}
/** Sets a member's account status; suspended/banned also ends their sessions and live sockets. Staff are protected. */
async function setUserStatus(id, status) {
  const u = await db('users').where({ id }).first('id', 'role', 'status');
  if (!u || u.status === 'deleted') throw err.notFound('User not found');
  if (u.role !== 'user') throw err.forbidden('Cannot moderate staff accounts');
  await db('users').where({ id }).update({ status });
  if (status !== 'active') {
    await db('sessions').where({ user_id: id }).whereNull('revoked_at').update({ revoked_at: new Date() });
    require('../../realtime/bus').disconnectUser(id);
  }
  return u;
}
async function removeTarget(type, id) {
  if (type === 'post') await db('posts').where({ id }).update({ status: 'removed' });
  else if (type === 'comment') await db('comments').where({ id }).update({ deleted_at: new Date() });
  else if (type === 'user') await setUserStatus(id, 'suspended');
}
/** Writes one moderator audit entry. */
const audit = (actorId, action, target, meta) => db('audit_logs').insert({ actor_id: actorId, action, target, meta: meta ? JSON.stringify(meta) : null });
module.exports = { assertClean, removeTarget, setUserStatus, audit };
