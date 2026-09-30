const env = require('../config/env');
const logger = require('../utils/logger');
/** Driver seam: replace `send` with Twilio/Vonage/etc. in production. */
const sent = [];
module.exports = {
  sent,
  async send(to, text) {
    if (env.SMS_DRIVER === 'memory') { sent.push({ to, text }); return; }
    logger.warn({ to }, `SMS (console driver): ${text}`);
  },
};
