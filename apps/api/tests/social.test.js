const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { api, setup, teardown, signup, setRole } = require('./helpers');

before(setup); after(teardown);

test('post, feed pagination, reactions and nested comments', async () => {
  const a = await signup(); const b = await signup();
  for (let i = 0; i < 3; i++) await api().post('/v1/posts').set(a.auth).send({ body: `hello ${i} #tag` }).expect(201);
  const p1 = await api().get('/v1/posts/feed?limit=2').set(b.auth).expect(200);
  assert.equal(p1.body.data.length, 2);
  assert.ok(p1.body.next_cursor);
  const p2 = await api().get(`/v1/posts/feed?limit=2&cursor=${p1.body.next_cursor}`).set(b.auth).expect(200);
  assert.ok(p2.body.data.length >= 1);
  const post = p1.body.data[0];

  await api().put(`/v1/posts/${post.id}/reaction`).set(b.auth).send({ kind: 'love' }).expect(200);
  const changed = await api().put(`/v1/posts/${post.id}/reaction`).set(b.auth).send({ kind: 'wow' }).expect(200);
  assert.equal(changed.body.reactions_count, 1); // one reaction per user, replaced
  await api().put(`/v1/posts/${post.id}/reaction`).set(b.auth).send({ kind: 'nope' }).expect(400);

  const c1 = await api().post(`/v1/posts/${post.id}/comments`).set(b.auth).send({ body: 'first' }).expect(201);
  const c2 = await api().post(`/v1/posts/${post.id}/comments`).set(a.auth).send({ body: 'reply', parent_id: c1.body.id }).expect(201);
  assert.equal(c2.body.depth, 1);
  assert.equal(c2.body.author.id, a.id); // comments carry their author
  const top = await api().get(`/v1/posts/${post.id}/comments`).set(b.auth).expect(200);
  assert.equal(top.body.data.length, 1);
  const replies = await api().get(`/v1/posts/${post.id}/comments?parent_id=${c1.body.id}`).set(b.auth).expect(200);
  assert.equal(replies.body.data[0].body, 'reply');
});

test('visibility: private and follower-only posts, scheduled posts, delete rules', async () => {
  const a = await signup(); const b = await signup(); const mod = await signup();
  const priv = await api().post('/v1/posts').set(a.auth).send({ body: 'secret', visibility: 'private' }).expect(201);
  const fol = await api().post('/v1/posts').set(a.auth).send({ body: 'friends', visibility: 'followers' }).expect(201);
  await api().get(`/v1/posts/${priv.body.id}`).set(b.auth).expect(404);
  await api().get(`/v1/posts/${fol.body.id}`).set(b.auth).expect(404);
  await api().post(`/v1/users/${a.id}/follow`).set(b.auth).expect(204);
  await api().post(`/v1/users/${a.id}/follow`).set(b.auth).expect(204); // idempotent
  await api().get(`/v1/posts/${fol.body.id}`).set(b.auth).expect(200);
  assert.equal((await api().get(`/v1/users/${a.id}`).set(b.auth)).body.followers_count, 1);

  const later = new Date(Date.now() + 3600e3).toISOString();
  const sch = await api().post('/v1/posts').set(a.auth).send({ body: 'later', publish_at: later }).expect(201);
  await api().get(`/v1/posts/${sch.body.id}`).set(b.auth).expect(404);

  await api().delete(`/v1/posts/${fol.body.id}`).set(b.auth).expect(403);
  await setRole(mod.id, 'moderator');
  await api().delete(`/v1/posts/${fol.body.id}`).set(mod.auth).expect(204);
  await api().get(`/v1/posts/${fol.body.id}`).set(a.auth).expect(404);
  await api().delete(`/v1/users/${a.id}/follow`).set(b.auth).expect(204);
  assert.equal((await api().get(`/v1/users/${a.id}`).set(b.auth)).body.followers_count, 0);
});

test('admin ban revokes access; role checks', async () => {
  const admin = await signup(); const victim = await signup();
  await api().post(`/v1/admin/users/${victim.id}/ban`).set(admin.auth).expect(403);
  await setRole(admin.id, 'admin');
  await api().post(`/v1/admin/users/${victim.id}/ban`).set(admin.auth).expect(200);
  await api().get('/v1/users/me').set(victim.auth).expect(401);
  await api().post('/v1/auth/refresh').send({ refreshToken: victim.refreshToken }).expect(401);
});
