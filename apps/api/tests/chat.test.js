const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const { io: connect } = require('socket.io-client');
const { api, setup, teardown, signup, app } = require('./helpers');
const { attach } = require('../src/realtime/io');
const crypto = require('crypto');

before(setup); after(teardown);

test('direct chat is unique, membership enforced, sends are idempotent', async () => {
  const a = await signup(); const b = await signup(); const c = await signup();
  const c1 = await api().post('/v1/conversations').set(a.auth).send({ type: 'direct', user_id: b.id }).expect(201);
  const c2 = await api().post('/v1/conversations').set(b.auth).send({ type: 'direct', user_id: a.id }).expect(201);
  assert.equal(c1.body.id, c2.body.id);
  const cid = c1.body.id; const client_id = crypto.randomUUID();
  const m1 = await api().post(`/v1/conversations/${cid}/messages`).set(a.auth).send({ client_id, body: 'hi' }).expect(201);
  const m2 = await api().post(`/v1/conversations/${cid}/messages`).set(a.auth).send({ client_id, body: 'hi' }).expect(200);
  assert.equal(m1.body.id, m2.body.id);
  await api().get(`/v1/conversations/${cid}/messages`).set(c.auth).expect(403);
  await api().post(`/v1/conversations/${cid}/read`).set(b.auth).send({ up_to_id: m1.body.id }).expect(204);
  const list = await api().get('/v1/conversations').set(b.auth).expect(200);
  assert.equal(list.body.data[0].last_read_message_id, m1.body.id);
  const g = await api().post('/v1/conversations').set(a.auth).send({ type: 'group', title: 'Crew', member_ids: [b.id, c.id] }).expect(201);
  await api().post(`/v1/conversations/${g.body.id}/messages`).set(c.auth).send({ client_id: crypto.randomUUID(), body: 'yo' }).expect(201);
});

test('socket: auth required, live delivery to members only', async () => {
  const server = http.createServer(app); const io = attach(server);
  await new Promise((r) => server.listen(0, r));
  const url = `http://localhost:${server.address().port}`;
  const a = await signup(); const b = await signup(); const outsider = await signup();
  const { body: conv } = await api().post('/v1/conversations').set(a.auth).send({ type: 'direct', user_id: b.id });

  const bad = connect(url, { auth: { token: 'x' }, reconnection: false });
  await new Promise((res) => bad.on('connect_error', (e) => { assert.equal(e.message, 'unauthorized'); res(); }));

  const open = (u) => new Promise((res) => { const s = connect(url, { auth: { token: u.accessToken }, reconnection: false }); s.on('connect', () => setTimeout(() => res(s), 100)); });
  const [sa, sb, so] = await Promise.all([open(a), open(b), open(outsider)]);
  let leaked = false; so.on('message:new', () => { leaked = true; });
  const got = new Promise((res) => sb.on('message:new', res));
  const ack = await new Promise((res) => sa.emit('message:send', { conversation_id: conv.id, message: { client_id: crypto.randomUUID(), body: 'live!' } }, res));
  assert.equal(ack.ok, true);
  assert.equal((await got).body, 'live!');
  const denied = await new Promise((res) => so.emit('message:send', { conversation_id: conv.id, message: { client_id: crypto.randomUUID(), body: 'x' } }, res));
  assert.equal(denied.ok, false);
  assert.equal(leaked, false);
  [sa, sb, so, bad].forEach((s) => s.close()); io.close(); server.close();
});
