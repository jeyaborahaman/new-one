const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { generate } = require('otplib');
const { api, db, setup, teardown, signup } = require('./helpers');
const sms = require('../src/integrations/sms');
const mailer = require('../src/integrations/mailer');
const oauth = require('../src/integrations/oauth');

before(setup); after(teardown);

test('phone OTP: creates account, wrong code fails, code is single-use, resend limit', async () => {
  const phone = '+14155550123';
  await api().post('/v1/auth/otp/request').send({ phone }).expect(204);
  const code = sms.sent.at(-1).text.match(/(\d{6})/)[1];
  await api().post('/v1/auth/otp/verify').send({ phone, code: code === '000000' ? '111111' : '000000' }).expect(401);
  const ok = await api().post('/v1/auth/otp/verify').send({ phone, code }).expect(200);
  assert.ok(ok.body.accessToken);
  await api().post('/v1/auth/otp/verify').send({ phone, code }).expect(401); // consumed
  await api().post('/v1/auth/otp/request').send({ phone }).expect(204);
  await api().post('/v1/auth/otp/request').send({ phone }).expect(204);
  await api().post('/v1/auth/otp/request').send({ phone }).expect(429);
  await api().post('/v1/auth/otp/request').send({ phone: '12345' }).expect(400);
});

test('OTP locks after 5 wrong attempts', async () => {
  const phone = '+14155550999';
  await api().post('/v1/auth/otp/request').send({ phone }).expect(204);
  const code = sms.sent.at(-1).text.match(/(\d{6})/)[1];
  const wrong = code === '123456' ? '654321' : '123456';
  for (let i = 0; i < 5; i++) await api().post('/v1/auth/otp/verify').send({ phone, code: wrong }).expect(401);
  await api().post('/v1/auth/otp/verify').send({ phone, code }).expect(401); // even the right code is now refused
});

test('password reset: no enumeration, code resets password and revokes sessions', async () => {
  const u = await signup({ email: 'reset@x.io' });
  await api().post('/v1/auth/password/forgot').send({ email: 'ghost@x.io' }).expect(204);
  assert.equal(mailer.sent.filter((m) => m.to === 'ghost@x.io').length, 0);
  await api().post('/v1/auth/password/forgot').send({ email: 'reset@x.io' }).expect(204);
  const code = mailer.sent.at(-1).text.match(/(\d{6})/)[1];
  await api().post('/v1/auth/password/reset').send({ email: 'reset@x.io', code: code === '000000' ? '111111' : '000000', new_password: 'newpassword1' }).expect(401);
  await api().post('/v1/auth/password/reset').send({ email: 'reset@x.io', code, new_password: 'newpassword1' }).expect(204);
  await api().post('/v1/auth/refresh').send({ refreshToken: u.refreshToken }).expect(401);
  await api().post('/v1/auth/login').send({ identifier: 'reset@x.io', password: 'password123' }).expect(401);
  await api().post('/v1/auth/login').send({ identifier: 'reset@x.io', password: 'newpassword1' }).expect(200);
});

test('2FA: setup, enable, login challenge, backup code single-use, disable', async () => {
  const u = await signup({ email: 'tfa@x.io' });
  const setup2 = await api().post('/v1/auth/2fa/setup').set(u.auth).expect(200);
  assert.match(setup2.body.otpauth_url, /^otpauth:\/\/totp\//);
  const stored = await db('users').where({ id: u.id }).first();
  assert.ok(!stored.two_factor_secret.includes(setup2.body.secret)); // encrypted at rest
  await api().post('/v1/auth/2fa/enable').set(u.auth).send({ code: '000000' }).expect(401);
  const en = await api().post('/v1/auth/2fa/enable').set(u.auth).send({ code: await generate({ secret: setup2.body.secret }) }).expect(200);
  assert.equal(en.body.backup_codes.length, 10);

  const l = await api().post('/v1/auth/login').send({ identifier: 'tfa@x.io', password: 'password123' }).expect(200);
  assert.equal(l.body.requires_2fa, true);
  assert.equal(l.body.accessToken, undefined);
  await api().post('/v1/auth/2fa/verify').send({ challenge_token: l.body.challenge_token, code: '000000' }).expect(401);
  const done = await api().post('/v1/auth/2fa/verify').send({ challenge_token: l.body.challenge_token, code: await generate({ secret: setup2.body.secret }) }).expect(200);
  assert.ok(done.body.accessToken);
  // an access token is not a valid challenge
  await api().post('/v1/auth/2fa/verify').send({ challenge_token: done.body.accessToken, code: '123456' }).expect(401);

  const bc = en.body.backup_codes[0];
  const l2 = await api().post('/v1/auth/login').send({ identifier: 'tfa@x.io', password: 'password123' });
  await api().post('/v1/auth/2fa/verify').send({ challenge_token: l2.body.challenge_token, code: bc }).expect(200);
  const l3 = await api().post('/v1/auth/login').send({ identifier: 'tfa@x.io', password: 'password123' });
  await api().post('/v1/auth/2fa/verify').send({ challenge_token: l3.body.challenge_token, code: bc }).expect(401); // used

  await api().post('/v1/auth/2fa/disable').set(u.auth).send({ password: 'wrong', code: en.body.backup_codes[1] }).expect(401);
  await api().post('/v1/auth/2fa/disable').set(u.auth).send({ password: 'password123', code: en.body.backup_codes[1] }).expect(204);
  await api().post('/v1/auth/login').send({ identifier: 'tfa@x.io', password: 'password123' }).expect(200).then((r) => assert.ok(r.body.accessToken));
});

test('Google/Apple login: links only verified emails, 2FA still enforced, unconfigured is a 400', async () => {
  await api().post('/v1/auth/oauth/google').send({ id_token: 'x'.repeat(30) }).expect(400); // GOOGLE_CLIENT_ID unset
  const orig = { g: oauth.google, a: oauth.apple };
  try {
    oauth.google = async () => ({ uid: 'g-1', email: 'gg@x.io', emailVerified: true, name: 'Gee Gee' });
    const r1 = await api().post('/v1/auth/oauth/google').send({ id_token: 'x'.repeat(30) }).expect(200);
    const r2 = await api().post('/v1/auth/oauth/google').send({ id_token: 'x'.repeat(30) }).expect(200);
    assert.equal(r1.body.user.id, r2.body.user.id);
    // existing password account with same verified email gets linked
    const existing = await signup({ email: 'link@x.io' });
    oauth.apple = async () => ({ uid: 'a-1', email: 'link@x.io', emailVerified: true });
    assert.equal((await api().post('/v1/auth/oauth/apple').send({ id_token: 'x'.repeat(30) }).expect(200)).body.user.id, existing.id);
    // unverified email must NOT take over the account
    oauth.apple = async () => ({ uid: 'a-2', email: 'link@x.io', emailVerified: false });
    assert.notEqual((await api().post('/v1/auth/oauth/apple').send({ id_token: 'x'.repeat(30) }).expect(200)).body.user.id, existing.id);
    // 2FA users cannot skip the second factor through OAuth
    await db('users').where({ id: existing.id }).update({ two_factor_enabled: true, two_factor_secret: 'x' });
    oauth.apple = async () => ({ uid: 'a-1', email: 'link@x.io', emailVerified: true });
    assert.equal((await api().post('/v1/auth/oauth/apple').send({ id_token: 'x'.repeat(30) }).expect(200)).body.requires_2fa, true);
  } finally { oauth.google = orig.g; oauth.apple = orig.a; }
});

test('sessions list and revoke', async () => {
  const u = await signup();
  const list = await api().get('/v1/auth/sessions').set(u.auth).expect(200);
  assert.equal(list.body.data.length, 1);
  await api().delete(`/v1/auth/sessions/${list.body.data[0].id}`).set(u.auth).expect(204);
  await api().post('/v1/auth/refresh').send({ refreshToken: u.refreshToken }).expect(401);
});
