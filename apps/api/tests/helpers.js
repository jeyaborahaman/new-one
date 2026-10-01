process.env.NODE_ENV = 'test';
process.env.DB_CLIENT = 'better-sqlite3';
process.env.SMS_DRIVER = 'memory';
process.env.MAIL_DRIVER = 'memory';
process.env.R2_DRIVER ||= 'fake';
process.env.AGORA_APP_ID = 'a'.repeat(32);
process.env.AGORA_CERT = 'b'.repeat(32);
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

const r2 = require('../src/integrations/r2');
/** Full upload flow against the fake R2 driver -> ready media id. */
async function uploadMedia(u, kind = 'image', mime = kind === 'video' ? 'video/mp4' : 'image/jpeg', size = 1234) {
  const r = await api().post('/v1/media/uploads').set(u.auth).send({ kind, mime, size }).expect(201);
  const key = r.body.upload_url.replace('https://fake-r2.test/', '').split('?')[0];
  r2.fakeObjects.set(key, size);
  await api().post(`/v1/media/${r.body.media_id}/complete`).set(u.auth).expect(200);
  return r.body.media_id;
}

module.exports = { uploadMedia, api, db, setup, teardown, signup, setRole, app };
