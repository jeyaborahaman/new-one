process.env.NODE_ENV = 'test';
process.env.DB_CLIENT = 'better-sqlite3';
process.env.JWT_SECRET = 'test-secret-test-secret-test-secret-123';
const request = require('supertest');
const db = require('../src/db/knex');
const { createApp } = require('../src/app');

const app = createApp();
let n = 0;
const api = () => request(app);

async function setup() { await db.migrate.latest(); }
async function teardown() { await db.destroy(); }

async function signup(over = {}) {
  n += 1;
  const body = { email: `u${n}@test.dev`, username: `user${n}`, password: 'password123', ...over };
  const r = await api().post('/v1/auth/register').send(body).expect(201);
  return { ...r.body, auth: { Authorization: `Bearer ${r.body.accessToken}` }, id: r.body.user.id };
}
const setRole = (id, role) => db('users').where({ id }).update({ role });

module.exports = { api, db, setup, teardown, signup, setRole, app };
