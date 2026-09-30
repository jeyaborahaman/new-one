const env = require('../config/env');
const path = require('path');

const base = { migrations: { directory: path.join(__dirname, 'migrations') } };

module.exports =
  env.DB_CLIENT === 'better-sqlite3'
    ? { ...base, client: 'better-sqlite3', connection: { filename: env.NODE_ENV === 'test' ? ':memory:' : 'dev.sqlite' }, useNullAsDefault: true }
    : {
        ...base,
        client: 'mysql2',
        connection: { host: env.DB_HOST, port: env.DB_PORT, user: env.DB_USER, password: env.DB_PASSWORD, database: env.DB_NAME, charset: 'utf8mb4' },
        pool: { min: 2, max: 20 },
      };
