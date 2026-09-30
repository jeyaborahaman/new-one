const rateLimit = require('express-rate-limit');
const { RedisStore } = require('rate-limit-redis');
const env = require('../config/env');
const redis = require('../config/redis');

// Redis store when REDIS_URL is set so limits hold across nodes; in-memory otherwise.
const make = (name, windowMs, limit) =>
  rateLimit({
    windowMs, limit, standardHeaders: true, legacyHeaders: false,
    skip: () => env.NODE_ENV === 'test' && !process.env.RATE_LIMIT_IN_TEST,
    ...(redis ? { store: new RedisStore({ prefix: `rl:${name}:`, sendCommand: (...args) => redis.call(...args) }) } : {}),
    handler: (_req, res) => res.status(429).json({ error: { code: 'RATE_LIMITED', message: 'Too many requests' } }),
  });
module.exports = { general: make('general', 60_000, 120), auth: make('auth', 60_000, 10) };
