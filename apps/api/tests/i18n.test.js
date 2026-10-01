const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { api, setup, teardown, signup, uploadMedia } = require('./helpers');
const { pickLanguage, translateError, notificationText } = require('../src/i18n');
const fcm = require('../src/integrations/fcm');

before(setup); after(teardown);

test('Accept-Language picks the best supported language, English otherwise', () => {
  assert.equal(pickLanguage('ar-SA,ar;q=0.9,en;q=0.8'), 'ar');
  assert.equal(pickLanguage('fr-FR, ur;q=0.7, en;q=0.5'), 'ur');
  assert.equal(pickLanguage('en;q=0.4, ar;q=0.9'), 'ar');
  assert.equal(pickLanguage('de, fr'), 'en');
  assert.equal(pickLanguage(undefined), 'en');
  assert.equal(pickLanguage('ar;q=0'), 'en');
  assert.equal(translateError('ar', 'File too large (max 10 MB)'), 'الملف كبير جدًا (الحد الأقصى 10 م.ب)');
  assert.equal(translateError('ur', 'Some brand-new message'), 'Some brand-new message'); // untranslated stays English
  assert.equal(notificationText('en', 'reaction_post', { reaction: 'love' }), 'Someone reacted love to your post'); // English wording unchanged
  assert.equal(notificationText('ar', 'reaction_post', { reaction: 'love' }), 'تفاعل أحدهم بـحب مع منشورك');
});

test('API error messages follow Accept-Language; codes stay stable', async () => {
  const u = await signup();
  const bad = { identifier: u.user.username, password: 'wrong-password' };
  const ar = await api().post('/v1/auth/login').set('Accept-Language', 'ar').send(bad).expect(401);
  assert.deepEqual([ar.body.error.code, ar.body.error.message], ['UNAUTHORIZED', 'بيانات الدخول غير صحيحة']);
  const ur = await api().post('/v1/auth/login').set('Accept-Language', 'ur-PK').send(bad).expect(401);
  assert.equal(ur.body.error.message, 'غلط لاگ ان معلومات');
  const fr = await api().post('/v1/auth/login').set('Accept-Language', 'fr').send(bad).expect(401);
  assert.equal(fr.body.error.message, 'Invalid credentials');
  const v = await api().post('/v1/auth/register').set('Accept-Language', 'ur').send({ email: 'nope' }).expect(400);
  assert.equal(v.body.error.message, 'کچھ فیلڈز درست نہیں'); // validation
  assert.ok(v.body.error.fields); // field details are still returned for the client
  const nf = await api().get('/nowhere').set('Accept-Language', 'ar').expect(404);
  assert.equal(nf.body.error.message, 'المسار غير موجود');
});

test('the account language is saved and validated', async () => {
  const u = await signup();
  assert.equal((await api().get('/v1/users/me').set(u.auth)).body.locale, 'en'); // default
  const r = await api().patch('/v1/users/me').set(u.auth).send({ locale: 'ur' }).expect(200);
  assert.equal(r.body.locale, 'ur');
  await api().patch('/v1/users/me').set(u.auth).send({ locale: 'fr' }).expect(400);
});

test('notifications and pushes use the recipient\'s language, not the sender\'s', async () => {
  const a = await signup(); const b = await signup(); const c = await signup();
  await api().patch('/v1/users/me').set(b.auth).send({ locale: 'ur' }).expect(200);
  await api().patch('/v1/users/me').set(c.auth).send({ locale: 'ar' }).expect(200);
  await api().post('/v1/devices').set(b.auth).send({ token: `tok-b-${'x'.repeat(24)}`, platform: 'android' }).expect(204);
  await api().post('/v1/devices').set(c.auth).send({ token: `tok-c-${'x'.repeat(24)}`, platform: 'ios' }).expect(204);

  fcm.sent.length = 0;
  await api().post('/v1/friends/requests').set(a.auth).set('Accept-Language', 'ar').send({ user_id: b.id }).expect(201);
  const inbox = (await api().get('/v1/notifications').set(b.auth)).body.data[0];
  assert.equal(inbox.payload.body, 'آپ کو دوستی کی درخواست بھیجی'); // Urdu inbox text
  assert.equal(inbox.payload.title, a.user.display_name); // names are never translated
  assert.equal(fcm.sent.at(-1).body, 'آپ کو دوستی کی درخواست بھیجی'); // and the push

  const post = await api().post('/v1/posts').set(c.auth).send({ body: 'hello' }).expect(201);
  await api().put(`/v1/posts/${post.body.id}/reaction`).set(a.auth).send({ kind: 'like' }).expect(200);
  const n = (await api().get('/v1/notifications').set(c.auth)).body.data[0].payload;
  assert.deepEqual([n.title, n.body], ['تفاعل جديد', 'تفاعل أحدهم بـإعجاب مع منشورك']);

  // An English user still gets the original English wording.
  const aPost = await api().post('/v1/posts').set(a.auth).send({ body: 'hi' }).expect(201);
  await api().put(`/v1/posts/${aPost.body.id}/reaction`).set(b.auth).send({ kind: 'love' }).expect(200);
  const en = (await api().get('/v1/notifications').set(a.auth)).body.data[0].payload;
  assert.deepEqual([en.title, en.body], ['New reaction', 'Someone reacted love to your post']);

  // Offline chat push for a photo: localized "sent a photo".
  const { body: dm } = await api().post('/v1/conversations').set(a.auth).send({ type: 'direct', user_id: c.id }).expect(201);
  fcm.sent.length = 0;
  await api().post(`/v1/conversations/${dm.id}/messages`).set(a.auth).send({ client_id: crypto.randomUUID(), type: 'image', media_id: await uploadMedia(a) }).expect(201);
  assert.equal(fcm.sent.at(-1).body, 'أرسل صورة');
  assert.equal(fcm.sent.at(-1).title, a.user.display_name);
});
