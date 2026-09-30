const env = require('../config/env');
const logger = require('../utils/logger');
const sent = [];
module.exports = {
  sent,
  async send(to, subject, text) {
    if (env.SMS_DRIVER === 'memory') { sent.push({ to, subject, text }); return; }
    logger.warn({ to, subject }, `Mail (console driver): ${text}`);
  },
};
