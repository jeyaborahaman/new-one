const env = require('../config/env');
const logger = require('../utils/logger');
/** Driver seam: replace `send` with Twilio/Vonage/etc. in production. */
const sent = [];
const mask = (phone) => String(phone).replace(/.(?=.{4})/g, '*');
module.exports = {
  sent,
  mask,
  async send(to, text) {
    if (env.SMS_DRIVER === 'memory') { sent.push({ to, text }); return; }
    // The text carries one-time codes: print it only in development, never into production logs.
    if (env.NODE_ENV === 'production') { logger.error({ to: mask(to) }, 'SMS not sent: no SMS provider configured'); return; }
    logger.warn({ to }, `SMS (console driver): ${text}`);
  },
};
