const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const { io: connect } = require('socket.io-client');
const { api, db, setup, teardown, signup, app } = require('./helpers');
const { attach } = require('../src/realtime/io');
const { HANDLERS } = require('../src/jobs/handlers');

before(setup); after(teardown);

async function withSockets(fn) {
  const server = http.createServer(app); const io = attach(server);
  await new Promise((r) => server.listen(0, r));
  const url = `http://localhost:${server.address().port}`;
  const opened = [];
  const open = (u) => new Promise((res) => { const s = connect(url, { auth: { token: u.accessToken }, reconnection: false }); opened.push(s); s.on('connect', () => setTimeout(() => res(s), 50)); });
  try { await fn(open); } finally { opened.forEach((s) => s.close()); io.close(); server.close(); }
}
const next = (s, event) => new Promise((res) => s.once(event, res));
const pair = async () => {
  const a = await signup(); const b = await signup();
  const { body: conv } = await api().post('/v1/conversations').set(a.auth).send({ type: 'direct', user_id: b.id }).expect(201);
  return { a, b, conv };
};
const ring = (u, conv, kind = 'audio') => api().post('/v1/calls').set(u.auth).send({ conversation_id: conv.id, kind });

test('a device that learns late can load the call; outsiders cannot', async () => {
  const { a, b, conv } = await pair(); const outsider = await signup();
  const call = (await ring(a, conv, 'video').expect(201)).body;
  const got = (await api().get(`/v1/calls/${call.call_id}`).set(b.auth).expect(200)).body;
  assert.deepEqual([got.status, got.kind, got.initiator.id, got.initiator.display_name, got.ring_timeout_ms], ['ringing', 'video', a.id, a.user.display_name, 45000]);
  await api().get(`/v1/calls/${call.call_id}`).set(outsider.auth).expect(403);
  await api().get('/v1/calls/not-a-uuid').set(b.auth).expect(400);
});

test('blocked users cannot call each other', async () => {
  const { a, b, conv } = await pair();
  await api().post(`/v1/users/${a.id}/block`).set(b.auth).expect(204);
  await ring(a, conv).expect(403);
  await api().delete(`/v1/users/${a.id}/block`).set(b.auth).expect(204);
  await ring(a, conv).expect(201);
});

test('decline stops every device and tells the caller why (busy)', async () => {
  const { a, b, conv } = await pair();
  await withSockets(async (open) => {
    const caller = await open(a); const phone = await open(b); const tablet = await open(b);
    const incoming = next(phone, 'call:incoming');
    const call = (await ring(a, conv).expect(201)).body;
    assert.equal((await incoming).call_id, call.call_id);
    const [toCaller, toTablet] = [next(caller, 'call:state'), next(tablet, 'call:state')];
    await api().post(`/v1/calls/${call.call_id}/decline`).set(b.auth).send({ reason: 'busy' }).expect(204);
    assert.deepEqual(await toCaller, { call_id: call.call_id, status: 'declined', by: b.id, reason: 'busy' });
    assert.equal((await toTablet).status, 'declined'); // the other device stops ringing too
  });
  const plain = (await ring(a, conv).expect(201)).body;
  await api().post(`/v1/calls/${plain.call_id}/decline`).set(b.auth).expect(204); // no body is fine
  await api().post(`/v1/calls/${plain.call_id}/decline`).set(b.auth).send({ reason: 'bored' }).expect(400);
});

test('hanging up while ringing is a missed call: everyone is told, the callee gets a notification in their language', async () => {
  const { a, b, conv } = await pair();
  await api().patch('/v1/users/me').set(b.auth).send({ locale: 'ar' }).expect(200);
  await withSockets(async (open) => {
    const callee = await open(b);
    const call = (await ring(a, conv, 'video').expect(201)).body;
    const state = next(callee, 'call:state');
    await api().post(`/v1/calls/${call.call_id}/end`).set(a.auth).expect(204);
    assert.equal((await state).status, 'missed');
    assert.equal((await db('call_sessions').where({ id: call.call_id }).first()).status, 'missed');
    const n = (await api().get('/v1/notifications').set(b.auth)).body.data[0];
    assert.equal(n.type, 'call');
    assert.deepEqual([n.payload.title, n.payload.body, n.payload.missed], [a.user.display_name, 'مكالمة فيديو فائتة', 1]);
    await api().post(`/v1/calls/${call.call_id}/end`).set(a.auth).expect(204); // idempotent: no second notification
    assert.equal((await api().get('/v1/notifications').set(b.auth)).body.data.filter((x) => x.type === 'call').length, 1);
  });
});

test('an unanswered call times out on the server too, and both sides hear about it', async () => {
  const { a, b, conv } = await pair();
  await withSockets(async (open) => {
    const caller = await open(a); const callee = await open(b);
    const call = (await ring(a, conv).expect(201)).body;
    await db('call_sessions').where({ id: call.call_id }).update({ created_at: new Date(Date.now() - 61_000) });
    const [s1, s2] = [next(caller, 'call:state'), next(callee, 'call:state')];
    assert.equal(await HANDLERS.expireCalls(), 1);
    assert.equal((await s1).status, 'missed'); assert.equal((await s2).status, 'missed');
    assert.equal(await HANDLERS.expireCalls(), 0);
  });
});

test('answering, token renewal, hang-up and the call log', async () => {
  const { a, b, conv } = await pair();
  const call = (await ring(a, conv, 'video').expect(201)).body;
  await api().post(`/v1/calls/${call.call_id}/join`).set(b.auth).expect(200);
  const renewed = (await api().post(`/v1/calls/${call.call_id}/token`).set(a.auth).expect(200)).body;
  assert.equal(renewed.channel, call.call_id); assert.ok(renewed.token.length > 50);
  await db('call_sessions').where({ id: call.call_id }).update({ created_at: new Date(Date.now() - 100_000), started_at: new Date(Date.now() - 95_000) });
  await api().post(`/v1/calls/${call.call_id}/end`).set(b.auth).expect(204);
  await api().post(`/v1/calls/${call.call_id}/token`).set(a.auth).expect(409); // over: no new tokens
  const missed = (await ring(b, conv).expect(201)).body;
  await api().post(`/v1/calls/${missed.call_id}/end`).set(b.auth).expect(204);

  const log = (await api().get('/v1/calls/history').set(a.auth).expect(200)).body.data;
  assert.equal(log.length, 2);
  const [latest, first] = log;
  assert.deepEqual([latest.direction, latest.status, latest.peer.id, latest.duration_s], ['incoming', 'missed', b.id, 0]);
  assert.deepEqual([first.direction, first.status, first.kind, first.peer.display_name], ['outgoing', 'ended', 'video', b.user.display_name]);
  assert.ok(first.duration_s >= 94 && first.duration_s <= 97, `duration ${first.duration_s}`);
  const theirs = (await api().get('/v1/calls/history').set(b.auth)).body.data;
  assert.equal(theirs[1].direction, 'incoming'); assert.equal(theirs[1].peer.id, a.id);
});
