const db = require('../../db/knex');
const fcm = require('../../integrations/fcm');
const bus = require('../../realtime/bus');
const { notificationText } = require('../../i18n');

const localeOf = async (userId) => (await db('users').where({ id: userId }).first('locale'))?.locale || 'en';
/** `t` = { title?: [key, params], body?: [key, params] }: texts rendered in the recipient's language; title/body are the English fallback. */
function localize(lang, { title, body, t }) {
  if (!t) return { title, body };
  const pick = (spec, fallback) => (spec ? notificationText(lang, spec[0], spec[1]) ?? fallback : fallback);
  return { title: pick(t.title, title), body: pick(t.body, body) };
}

const TYPES = ['message', 'friend_request', 'follow', 'reaction', 'comment', 'mention', 'story', 'live', 'luckydraw', 'reward', 'call'];

async function pushEnabled(userId, type) {
  const p = await db('notification_prefs').where({ user_id: userId, type }).first();
  return p ? !!p.push : true;
}
/** FCM push only (no inbox row): used for chat messages and calls. */
async function push(userId, type, { title, body, t, data = {} }) {
  if (!(await pushEnabled(userId, type))) return;
  const tokens = (await db('devices').where({ user_id: userId }).select('token')).map((d) => d.token);
  if (!tokens.length) return;
  ({ title, body } = localize(await localeOf(userId), { title, body, t }));
  const dead = await fcm.push(tokens, { title, body, data: { type, title, ...data } });
  if (dead.length) await db('devices').whereIn('token', dead).del();
}
/** Inbox row + live socket event + push. */
async function notify(userId, type, { title, body, t, data = {} }) {
  ({ title, body } = localize(await localeOf(userId), { title, body, t })); // inbox, live event and push share the recipient's language
  const [id] = await db('notifications').insert({ user_id: userId, type, payload: JSON.stringify({ title, body, ...data }) });
  bus.emitToUser(userId, 'notification:new', { id, type, title, body, ...data });
  await push(userId, type, { title, body, data });
  return id;
}
module.exports = { TYPES, push, notify };
