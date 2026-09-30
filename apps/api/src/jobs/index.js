const { Queue, Worker } = require('bullmq');
const redis = require('../config/redis');
const logger = require('../utils/logger');
const { HANDLERS, SCHEDULE_MS } = require('./handlers');

/** With Redis: BullMQ repeatable jobs (exactly one worker runs each tick across all nodes).
 *  Without Redis: in-process timers (single node only). Returns a stop() function. */
async function start() {
  const run = async (name) => { try { const n = await HANDLERS[name](); if (n) logger.info({ job: name, affected: n }, 'job done'); } catch (e) { logger.error({ err: e, job: name }, 'job failed'); } };
  if (!redis) {
    const timers = Object.entries(SCHEDULE_MS).map(([name, ms]) => setInterval(() => run(name), ms).unref());
    return async () => timers.forEach(clearInterval);
  }
  const connection = redis.duplicate();
  const queue = new Queue('jeyabo-jobs', { connection });
  for (const [name, ms] of Object.entries(SCHEDULE_MS)) await queue.upsertJobScheduler(name, { every: ms }, { name });
  const worker = new Worker('jeyabo-jobs', (job) => run(job.name), { connection: redis.duplicate(), concurrency: 2 });
  return async () => { await worker.close(); await queue.close(); connection.disconnect(); };
}
module.exports = { start };
