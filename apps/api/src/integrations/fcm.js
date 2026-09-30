const env = require('../config/env');
const logger = require('../utils/logger');
const sent = []; // captured in tests / when unconfigured
let messaging;
function init() {
  if (messaging !== undefined) return messaging;
  if (!env.FCM_SERVICE_ACCOUNT) return (messaging = null);
  const admin = require('firebase-admin');
  const app = admin.initializeApp({ credential: admin.credential.cert(JSON.parse(env.FCM_SERVICE_ACCOUNT)) });
  return (messaging = admin.messaging(app));
}
module.exports = {
  sent,
  /** Returns tokens FCM reports as dead so the caller can delete them. */
  async push(tokens, { title, body, data = {} }) {
    if (!tokens.length) return [];
    const m = init();
    if (!m) { sent.push({ tokens, title, body, data }); logger.info({ title }, 'FCM not configured; push logged'); return []; }
    const res = await m.sendEachForMulticast({ tokens, notification: { title, body }, data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])), android: { priority: 'high' }, apns: { headers: { 'apns-priority': '10' } } });
    return res.responses.map((r, i) => (!r.success && /registration-token-not-registered|invalid-argument/.test(r.error?.code || '') ? tokens[i] : null)).filter(Boolean);
  },
};
