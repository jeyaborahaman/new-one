const pino = require('pino');
const env = require('../config/env');
module.exports = pino({ level: env.NODE_ENV === 'test' ? 'silent' : 'info', redact: ['req.headers.authorization', '*.password', '*.refreshToken'] });
