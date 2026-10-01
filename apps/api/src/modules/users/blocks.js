const db = require('../../db/knex');
const { err } = require('../../utils/errors');

/** Query fragment: `col` is not someone the viewer blocked, nor someone who blocked the viewer. */
const notBlocked = (col, viewerId) => function () {
  this.whereNotIn(col, db('user_blocks').where('blocker_id', viewerId).select('blocked_id'))
    .whereNotIn(col, db('user_blocks').where('blocked_id', viewerId).select('blocker_id'));
};
/** True when either user has blocked the other. */
async function isBlocked(a, b) {
  return !!(await db('user_blocks').where({ blocker_id: a, blocked_id: b }).orWhere({ blocker_id: b, blocked_id: a }).first('blocker_id'));
}
async function assertNotBlocked(a, b) {
  if (await isBlocked(a, b)) throw err.forbidden('You cannot interact with this user');
}
/** Ids among `ids` with a block in either direction with `userId`. */
async function blockedAmong(userId, ids) {
  if (!ids.length) return [];
  const rows = await db('user_blocks').where((w) => w.where('blocker_id', userId).whereIn('blocked_id', ids)).orWhere((w) => w.where('blocked_id', userId).whereIn('blocker_id', ids)).select('blocker_id', 'blocked_id');
  return [...new Set(rows.map((r) => (r.blocker_id === userId ? r.blocked_id : r.blocker_id)))];
}
module.exports = { notBlocked, isBlocked, assertNotBlocked, blockedAmong };
