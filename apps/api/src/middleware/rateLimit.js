const rateLimit = require('express-rate-limit');
const env = require('../config/env');
const make = (windowMs, limit) =>
  rateLimit({
    windowMs, limit, standardHeaders: true, legacyHeaders: false,
    skip: () => env.NODE_ENV === 'test',
    handler: (_req, res) => res.status(429).json({ error: { code: 'RATE_LIMITED', message: 'Too many requests' } }),
  });
// In-memory store: fine for one process. Swap in rate-limit-redis when running several nodes.
module.exports = { general: make(60_000, 120), auth: make(60_000, 10) };
