const db = require('../../db/knex');
const fcm = require('../../integrations/fcm');
const bus = require('../../realtime/bus');

const TYPES = ['message', 'friend_request', 'follow', 'reaction', 'comment', 'mention', 'story', 'live', 'luckydraw', 'reward', 'call'];

async function pushEnabled(userId, type) {
  const p = await db('notification_prefs').where({ user_id: userId, type }).first();
  return p ? !!p.push : true;
}
/** FCM push only (no inbox row): used for chat messages and calls. */
async function push(userId, type, { title, body, data = {} }) {
  if (!(await pushEnabled(userId, type))) return;
  const tokens = (await db('devices').where({ user_id: userId }).select('token')).map((d) => d.token);
  const dead = await fcm.push(tokens, { title, body, data: { type, title, ...data } });
  if (dead.length) await db('devices').whereIn('token', dead).del();
}
/** Inbox row + live socket event + push. */
async function notify(userId, type, { title, body, data = {} }) {
  const [id] = await db('notifications').insert({ user_id: userId, type, payload: JSON.stringify({ title, body, ...data }) });
  bus.emitToUser(userId, 'notification:new', { id, type, title, body, ...data });
  await push(userId, type, { title, body, data });
  return id;
}
module.exports = { TYPES, push, notify };
