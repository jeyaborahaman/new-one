process.env.R2_DRIVER = 'local';
process.env.API_PUBLIC_URL = 'http://localhost:4000';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const { api, setup, teardown, signup } = require('./helpers');
const r2 = require('../src/integrations/r2');

before(setup);
after(async () => { await teardown(); fs.rmSync(r2.UPLOAD_DIR, { recursive: true, force: true }); });

const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
const localPath = (url) => new URL(url).pathname + new URL(url).search;

test('local driver: signed PUT, size/type checks, serves the file, and cannot be forged', async () => {
  const u = await signup();
  const up = await api().post('/v1/media/uploads').set(u.auth).send({ kind: 'image', mime: 'image/png', size: PNG.length }).expect(201);
  const path = localPath(up.body.upload_url);

  await api().put(path.replace(/sig=[0-9a-f]+/, 'sig=' + '0'.repeat(64))).set('Content-Type', 'image/png').send(PNG).expect(403); // forged signature
  await api().put(path).set('Content-Type', 'image/png').send(Buffer.concat([PNG, PNG])).expect(400); // wrong size
  await api().put(path).set('Content-Type', 'image/jpeg').send(PNG).expect(400); // wrong type
  await api().post(`/v1/media/${up.body.media_id}/complete`).set(u.auth).expect(409); // nothing stored yet
  await api().put(path).set('Content-Type', 'image/png').send(PNG).expect(200);
  const done = await api().post(`/v1/media/${up.body.media_id}/complete`).set(u.auth).expect(200);
  assert.equal(done.body.status, 'ready');
  assert.match(done.body.url, /^http:\/\/localhost:4000\/uploads\/u\/\d+\/\d{4}\/[0-9a-f-]{36}\.png$/);

  const served = await api().get(new URL(done.body.url).pathname).expect(200);
  assert.deepEqual(served.body, PNG);
  assert.equal(served.headers['cross-origin-resource-policy'], 'cross-origin');
  await api().get('/uploads/../../package.json').expect(404); // no path traversal
  await api().put(path).set('Content-Type', 'image/png').send(PNG).expect(404); // an upload slot is single-use
});

test('local driver: a signature for one key does not work for another', async () => {
  const a = await signup();
  const one = (await api().post('/v1/media/uploads').set(a.auth).send({ kind: 'image', mime: 'image/png', size: PNG.length })).body;
  const two = (await api().post('/v1/media/uploads').set(a.auth).send({ kind: 'image', mime: 'image/png', size: PNG.length })).body;
  const pOne = new URL(one.upload_url), pTwo = new URL(two.upload_url);
  await api().put(pOne.pathname + pTwo.search).set('Content-Type', 'image/png').send(PNG).expect(403);
});
