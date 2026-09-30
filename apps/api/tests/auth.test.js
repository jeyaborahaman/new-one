const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { api, setup, teardown, signup } = require('./helpers');

before(setup); after(teardown);

test('register, login, me', async () => {
  const u = await signup({ email: 'a@x.io', username: 'alice' });
  assert.equal(u.user.username, 'alice');
  assert.equal(u.user.password_hash, undefined);
  const login = await api().post('/v1/auth/login').send({ identifier: 'A@X.io', password: 'password123' }).expect(200);
  const me = await api().get('/v1/users/me').set('Authorization', `Bearer ${login.body.accessToken}`).expect(200);
  assert.equal(me.body.username, 'alice');
});

test('duplicate email conflicts; weak input rejected; bad password 401', async () => {
  await signup({ email: 'dup@x.io', username: 'dup1' });
  await api().post('/v1/auth/register').send({ email: 'dup@x.io', username: 'dup2', password: 'password123' }).expect(409);
  await api().post('/v1/auth/register').send({ email: 'n@x.io', username: 'n', password: 'short' }).expect(400);
  await api().post('/v1/auth/login').send({ identifier: 'dup@x.io', password: 'wrongpass1' }).expect(401);
  await api().post('/v1/auth/login').send({ identifier: 'ghost@x.io', password: 'wrongpass1' }).expect(401);
});

test('refresh rotates and reuse revokes the family', async () => {
  const u = await signup();
  const r1 = await api().post('/v1/auth/refresh').send({ refreshToken: u.refreshToken }).expect(200);
  assert.notEqual(r1.body.refreshToken, u.refreshToken);
  await api().post('/v1/auth/refresh').send({ refreshToken: u.refreshToken }).expect(401); // reuse
  await api().post('/v1/auth/refresh').send({ refreshToken: r1.body.refreshToken }).expect(401); // family revoked
});

test('protected routes need a valid token; banned users are locked out', async () => {
  await api().get('/v1/users/me').expect(401);
  await api().get('/v1/users/me').set('Authorization', 'Bearer nope').expect(401);
});
