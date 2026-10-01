const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { generate } = require('otplib');
const { io: connect } = require('socket.io-client');
const { api, db, setup, teardown, signup, setRole, uploadMedia, app } = require('./helpers');
const { attach } = require('../src/realtime/io');
const sms = require('../src/integrations/sms');

before(setup); after(teardown);
const bearer = (t) => ({ Authorization: `Bearer ${t}` });

async function withSocketServer(fn) {
  const server = http.createServer(app); const io = attach(server);
  await new Promise((r) => server.listen(0, r));
  const url = `http://localhost:${server.address().port}`;
  const open = (token) => new Promise((res, rej) => {
    const s = connect(url, { auth: { token }, reconnection: false });
    s.on('connect', () => setTimeout(() => res(s), 50)); s.on('connect_error', (e) => { s.close(); rej(e); });
  });
  try { await fn(open); } finally { io.close(); server.close(); }
}

test('2FA: a challenge token is not an access token (REST and socket)', async () => {
  const u = await signup();
  const s = await api().post('/v1/auth/2fa/setup').set(u.auth).expect(200);
  await api().post('/v1/auth/2fa/enable').set(u.auth).send({ code: await generate({ secret: s.body.secret }) }).expect(200);
  const l = await api().post('/v1/auth/login').send({ identifier: u.user.username, password: 'password123' }).expect(200);
  assert.equal(l.body.requires_2fa, true);
  await api().get('/v1/users/me').set(bearer(l.body.challenge_token)).expect(401);
  await api().post('/v1/posts').set(bearer(l.body.challenge_token)).send({ body: 'pwned' }).expect(401);
  await withSocketServer(async (open) => {
    await assert.rejects(open(l.body.challenge_token), (e) => e.message === 'unauthorized');
  });
  // Completing the second factor still works and yields a real access token.
  const v = await api().post('/v1/auth/2fa/verify').send({ challenge_token: l.body.challenge_token, code: await generate({ secret: s.body.secret }) }).expect(200);
  await api().get('/v1/users/me').set(bearer(v.body.accessToken)).expect(200);
});

test('tokens without typ=access (or signed for another purpose) are rejected', async () => {
  const u = await signup();
  const legacy = jwt.sign({ sub: String(u.id), role: 'user' }, process.env.JWT_SECRET, { algorithm: 'HS256', expiresIn: '5m' });
  await api().get('/v1/users/me').set(bearer(legacy)).expect(401);
  const forged = jwt.sign({ sub: String(u.id), typ: 'access' }, 'some-other-secret-some-other-secret-1234', { algorithm: 'HS256' });
  await api().get('/v1/users/me').set(bearer(forged)).expect(401);
  await api().get('/v1/users/me').set(u.auth).expect(200);
});

test('socket: banning a user drops their live socket', async () => {
  const admin = await signup(); await setRole(admin.id, 'admin');
  const u = await signup();
  await withSocketServer(async (open) => {
    const s = await open(u.accessToken);
    const dropped = new Promise((res) => s.on('disconnect', res));
    await api().post(`/v1/admin/users/${u.id}/ban`).set(admin.auth).expect(200);
    assert.equal(await dropped, 'io server disconnect');
    s.close();
  });
});

test('chat attachments must be the sender\'s own ready media of a matching kind', async () => {
  const a = await signup(); const b = await signup();
  const { body: conv } = await api().post('/v1/conversations').set(a.auth).send({ type: 'direct', user_id: b.id }).expect(201);
  const send = (u, msg) => api().post(`/v1/conversations/${conv.id}/messages`).set(u.auth).send({ client_id: crypto.randomUUID(), ...msg });
  const aImage = await uploadMedia(a);
  await send(b, { type: 'image', media_id: aImage }).expect(400); // someone else's media
  const pending = await api().post('/v1/media/uploads').set(b.auth).send({ kind: 'image', mime: 'image/jpeg', size: 10 }).expect(201);
  await send(b, { type: 'image', media_id: pending.body.media_id }).expect(400); // not uploaded yet
  const bImage = await uploadMedia(b);
  await send(b, { type: 'video', media_id: bImage }).expect(400); // wrong kind for the type
  await send(b, { type: 'image', body: 'no file' }).expect(400); // image message without media
  const ok = await send(b, { type: 'image', media_id: bImage }).expect(201);
  assert.equal(ok.body.media_id, bImage);
  // The socket path uses the same service, so it is covered too.
  await withSocketServer(async (open) => {
    const s = await open(b.accessToken);
    const ack = await new Promise((res) => s.emit('message:send', { conversation_id: conv.id, message: { client_id: crypto.randomUUID(), type: 'image', media_id: aImage } }, res));
    assert.equal(ack.ok, false);
    s.close();
  });
});

test('block: hides profiles and posts, stops follows, friend requests, DMs and group adds; unblock restores', async () => {
  const a = await signup(); const b = await signup({ username: 'blockee' }); const c = await signup();
  await api().post(`/v1/users/${b.id}/follow`).set(a.auth).expect(204);
  await api().post(`/v1/users/${a.id}/follow`).set(b.auth).expect(204);
  const { body: dm } = await api().post('/v1/conversations').set(a.auth).send({ type: 'direct', user_id: b.id }).expect(201);
  const bPost = await api().post('/v1/posts').set(b.auth).send({ body: 'from b' }).expect(201);
  const aPost = await api().post('/v1/posts').set(a.auth).send({ body: 'from a' }).expect(201);

  await api().post(`/v1/users/${a.id}/block`).set(a.auth).expect(400); // not yourself
  await api().post(`/v1/users/${b.id}/block`).set(a.auth).expect(204);
  await api().post(`/v1/users/${b.id}/block`).set(a.auth).expect(204); // idempotent
  const me = await api().get('/v1/users/me').set(a.auth).expect(200);
  assert.equal(me.body.followers_count, 0); assert.equal(me.body.following_count, 0); // follows removed both ways
  assert.deepEqual((await api().get('/v1/users/me/blocks').set(a.auth)).body.data.map((u) => u.id), [b.id]);

  for (const [x, y] of [[a, b], [b, a]]) { // both directions
    await api().get(`/v1/users/${y.id}`).set(x.auth).expect(404);
    await api().post(`/v1/users/${y.id}/follow`).set(x.auth).expect(403);
    await api().post('/v1/friends/requests').set(x.auth).send({ user_id: y.id }).expect(403);
    await api().post('/v1/conversations').set(x.auth).send({ type: 'direct', user_id: y.id }).expect(403);
    await api().post(`/v1/conversations/${dm.id}/messages`).set(x.auth).send({ client_id: crypto.randomUUID(), body: 'hi' }).expect(403);
  }
  const feedA = (await api().get('/v1/posts/feed').set(a.auth)).body.data.map((p) => p.id);
  assert.ok(!feedA.includes(bPost.body.id));
  const feedB = (await api().get('/v1/posts/feed').set(b.auth)).body.data.map((p) => p.id);
  assert.ok(!feedB.includes(aPost.body.id));
  await api().get(`/v1/posts/${bPost.body.id}`).set(a.auth).expect(404);
  const found = await api().get('/v1/search').query({ q: 'blockee', type: 'users' }).set(a.auth).expect(200);
  assert.equal(found.body.users.length, 0);
  await api().post('/v1/conversations').set(a.auth).send({ type: 'group', title: 'G', member_ids: [b.id, c.id] }).expect(403);
  const { body: g } = await api().post('/v1/conversations').set(c.auth).send({ type: 'group', title: 'G2', member_ids: [a.id] }).expect(201);
  await api().patch(`/v1/conversations/${g.id}/members/${a.id}`).set(c.auth).send({ role: 'admin' }).expect(204);
  await api().post(`/v1/conversations/${g.id}/members`).set(a.auth).send({ user_ids: [b.id] }).expect(403);

  await api().delete(`/v1/users/${b.id}/block`).set(a.auth).expect(204);
  await api().get(`/v1/users/${b.id}`).set(a.auth).expect(200);
  await api().post(`/v1/conversations/${dm.id}/messages`).set(b.auth).send({ client_id: crypto.randomUUID(), body: 'back' }).expect(201);
});

test('report user: validates the target, no duplicates; acting suspends and revokes; staff are protected', async () => {
  const mod = await signup(); await setRole(mod.id, 'admin');
  const r = await signup(); const bad = await signup(); const staff = await signup(); await setRole(staff.id, 'moderator');
  await api().post('/v1/reports').set(r.auth).send({ target_type: 'user', target_id: r.id, reason: 'spam' }).expect(400);
  await api().post('/v1/reports').set(r.auth).send({ target_type: 'user', target_id: 999999, reason: 'spam' }).expect(404);
  await api().post('/v1/reports').set(r.auth).send({ target_type: 'post', target_id: 999999, reason: 'spam' }).expect(404);
  const rep = await api().post('/v1/reports').set(r.auth).send({ target_type: 'user', target_id: bad.id, reason: 'harassment', details: 'abusive DMs' }).expect(201);
  await api().post('/v1/reports').set(r.auth).send({ target_type: 'user', target_id: bad.id, reason: 'spam' }).expect(409);
  await api().post(`/v1/admin/reports/${rep.body.id}/action`).set(mod.auth).send({ action: 'remove' }).expect(200);
  assert.equal((await db('users').where({ id: bad.id }).first()).status, 'suspended');
  await api().get('/v1/users/me').set(bad.auth).expect(401);
  await api().post('/v1/auth/refresh').send({ refreshToken: bad.refreshToken }).expect(401);
  const rs = await api().post('/v1/reports').set(r.auth).send({ target_type: 'user', target_id: staff.id, reason: 'other' }).expect(201);
  await api().post(`/v1/admin/reports/${rs.body.id}/action`).set(mod.auth).send({ action: 'remove' }).expect(403);
  assert.equal((await db('users').where({ id: staff.id }).first()).status, 'active');
});

test('account deletion: confirms, anonymises, revokes, takes content down, frees the username', async () => {
  const u = await signup({ username: 'leaving', email: 'leaving@x.io' }); const friend = await signup();
  await api().post(`/v1/users/${friend.id}/follow`).set(u.auth).expect(204);
  await api().post(`/v1/users/${u.id}/follow`).set(friend.auth).expect(204);
  const post = await api().post('/v1/posts').set(u.auth).send({ body: 'bye' }).expect(201);
  const fPost = await api().post('/v1/posts').set(friend.auth).send({ body: 'hello' }).expect(201);
  await api().put(`/v1/posts/${fPost.body.id}/reaction`).set(u.auth).send({ kind: 'love' }).expect(200);
  await api().post(`/v1/posts/${fPost.body.id}/comments`).set(u.auth).send({ body: 'nice' }).expect(201);
  await api().post('/v1/devices').set(u.auth).send({ token: 'x'.repeat(30), platform: 'android' }).expect(204);

  assert.equal((await api().get('/v1/users/me').set(u.auth)).body.has_password, true);
  await api().delete('/v1/users/me').set(u.auth).send({ password: 'password123' }).expect(400); // must type DELETE
  await api().delete('/v1/users/me').set(u.auth).send({ confirm: 'DELETE', password: 'wrong-password' }).expect(401);
  await api().delete('/v1/users/me').set(u.auth).send({ confirm: 'DELETE' }).expect(401); // password accounts need it
  await api().delete('/v1/users/me').set(u.auth).send({ confirm: 'DELETE', password: 'password123' }).expect(204);

  await api().get('/v1/users/me').set(u.auth).expect(401);
  await api().post('/v1/auth/refresh').send({ refreshToken: u.refreshToken }).expect(401);
  await api().post('/v1/auth/login').send({ identifier: 'leaving@x.io', password: 'password123' }).expect(401);
  await api().get(`/v1/users/${u.id}`).set(friend.auth).expect(404);
  await api().get(`/v1/posts/${post.body.id}`).set(friend.auth).expect(404);
  const row = await db('users').where({ id: u.id }).first();
  assert.equal(row.status, 'deleted'); assert.equal(row.email, null); assert.equal(row.password_hash, null); assert.equal(row.display_name, 'Deleted user');
  assert.equal((await db('devices').where({ user_id: u.id })).length, 0);
  const f = (await api().get('/v1/users/me').set(friend.auth)).body;
  assert.equal(f.followers_count, 0); assert.equal(f.following_count, 0);
  const fp = (await api().get(`/v1/posts/${fPost.body.id}`).set(friend.auth)).body;
  assert.equal(fp.reactions_count, 0); assert.equal(fp.comments_count, 0);
  await signup({ username: 'leaving', email: 'leaving@x.io' }); // username and email are free again

  // Phone (OTP) accounts have no password: typing DELETE is the confirmation.
  const phone = '+14155550777';
  await api().post('/v1/auth/otp/request').send({ phone }).expect(204);
  const code = sms.sent.at(-1).text.match(/(\d{6})/)[1];
  const p = await api().post('/v1/auth/otp/verify').send({ phone, code }).expect(200);
  assert.equal(p.body.user.has_password, false); // the app then asks only for the DELETE confirmation
  await api().delete('/v1/users/me').set(bearer(p.body.accessToken)).send({ confirm: 'DELETE' }).expect(204);
  assert.equal((await db('users').where({ id: p.body.user.id }).first()).phone, null);
});
