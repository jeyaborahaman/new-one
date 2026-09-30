const http = require('http');
const env = require('./config/env');
const db = require('./db/knex');
const logger = require('./utils/logger');
const { createApp } = require('./app');
const { attach } = require('./realtime/io');

const server = http.createServer(createApp());
attach(server);
const stopJobs = require('./jobs').start();
server.listen(env.PORT, () => logger.info(`Jeyabo API listening on :${env.PORT}`));

const shutdown = (sig) => () => {
  logger.info(`${sig} received, shutting down`);
  server.close(async () => { await (await stopJobs)(); await db.destroy(); process.exit(0); });
  setTimeout(() => process.exit(1), 10_000).unref();
};
process.on('SIGTERM', shutdown('SIGTERM'));
process.on('SIGINT', shutdown('SIGINT'));
