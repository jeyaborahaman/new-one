const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { api, setup, teardown, signup } = require('./helpers');

before(setup); after(teardown);

test('my groups and pages: joined, followed and pending, with my role; nothing else', async () => {
  const owner = await signup(); const me = await signup();
  const mk = (body) => api().post('/v1/communities').set(owner.auth).send(body).expect(201).then((r) => r.body);
  const open = await mk({ kind: 'group', name: 'Runners' });
  const closed = await mk({ kind: 'group', privacy: 'private', name: 'Book club' });
  const page = await mk({ kind: 'page', page_type: 'business', name: 'Cafe Noor' });
  await mk({ kind: 'group', name: 'Not mine' });
  await api().post(`/v1/communities/${open.id}/join`).set(me.auth).expect(201);
  await api().post(`/v1/communities/${closed.id}/join`).set(me.auth).expect(201); // pending
  await api().post(`/v1/communities/${page.id}/join`).set(me.auth).expect(201); // follow

  const groups = (await api().get('/v1/communities/mine?kind=group').set(me.auth).expect(200)).body.data;
  assert.deepEqual(groups.map((g) => [g.name, g.my_status, g.my_role]), [['Book club', 'pending', 'member'], ['Runners', 'active', 'member']]);
  const pages = (await api().get('/v1/communities/mine?kind=page').set(me.auth).expect(200)).body.data;
  assert.deepEqual(pages.map((p) => p.name), ['Cafe Noor']);
  const ownerGroups = (await api().get('/v1/communities/mine?kind=group').set(owner.auth)).body.data;
  assert.ok(ownerGroups.every((g) => g.my_role === 'owner'));
  await api().get('/v1/communities/mine?kind=event').set(me.auth).expect(400);

  await api().post(`/v1/communities/${page.id}/leave`).set(me.auth).expect(204); // unfollow
  assert.equal((await api().get('/v1/communities/mine?kind=page').set(me.auth)).body.data.length, 0);
});

test('search finds private groups as a preview only, and says whether I already belong', async () => {
  const owner = await signup(); const stranger = await signup();
  const secret = (await api().post('/v1/communities').set(owner.auth).send({ kind: 'group', privacy: 'private', name: 'Quiet Garden', description: 'members only talk' }).expect(201)).body;
  await api().post('/v1/communities').set(owner.auth).send({ kind: 'group', name: 'Quiet Readers', description: 'open to all' }).expect(201);
  await api().post('/v1/posts').set(owner.auth).send({ body: 'garden secrets', community_id: secret.id }).expect(201);

  const found = (await api().get('/v1/communities?q=Quiet&kind=group').set(stranger.auth).expect(200)).body.data;
  const priv = found.find((c) => c.name === 'Quiet Garden'); const pub = found.find((c) => c.name === 'Quiet Readers');
  assert.equal(priv.privacy, 'private');
  assert.equal(priv.description, null); // no description for non-members
  assert.equal(pub.description, 'open to all');
  assert.equal(priv.my_status, null);
  await api().get(`/v1/communities/${secret.id}/feed`).set(stranger.auth).expect(403); // content stays members-only
  const mine = (await api().get('/v1/communities?q=Quiet').set(owner.auth)).body.data;
  assert.ok(mine.every((c) => c.my_role === 'owner'));
  // A query of only wildcards is stripped (never passed to LIKE): same as browsing without a query.
  const all = (await api().get('/v1/communities').set(stranger.auth)).body.data.length;
  assert.equal((await api().get('/v1/communities?q=%25').set(stranger.auth).expect(200)).body.data.length, all);
});
