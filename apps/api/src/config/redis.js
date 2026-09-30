const Redis = require('ioredis');
const env = require('./env');
/** Optional: without REDIS_URL everything falls back to single-process behaviour. */
const redis = env.REDIS_URL ? new Redis(env.REDIS_URL, { maxRetriesPerRequest: null }) : null;
module.exports = redis;
