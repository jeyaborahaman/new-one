const env = require('../config/env');
const logger = require('../utils/logger');
const sent = [];
const mask = (email) => String(email).replace(/^(.).*(@.*)$/, '$1***$2');
module.exports = {
  sent,
  mask,
  async send(to, subject, text) {
    if (env.MAIL_DRIVER === 'memory') { sent.push({ to, subject, text }); return; }
    // The body carries reset codes: print it only in development, never into production logs.
    if (env.NODE_ENV === 'production') { logger.error({ to: mask(to), subject }, 'Mail not sent: no email provider configured'); return; }
    logger.warn({ to, subject }, `Mail (console driver): ${text}`);
  },
};
