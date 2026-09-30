const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { api, db, setup, teardown, signup, setRole, uploadMedia } = require('./helpers');
const r2 = require('../src/integrations/r2');
const fcm = require('../src/integrations/fcm');
const { HANDLERS } = require('../src/jobs/handlers');

before(setup); after(teardown);

test('media: validation, size verification, ownership', async () => {
  const a = await signup(); const b = await signup();
  await api().post('/v1/media/uploads').set(a.auth).send({ kind: 'image', mime: 'application/x-msdownload', size: 10 }).expect(400);
  await api().post('/v1/media/uploads').set(a.auth).send({ kind: 'image', mime: 'image/png', size: 11 * 1024 * 1024 }).expect(400);
  const up = await api().post('/v1/media/uploads').set(a.auth).send({ kind: 'image', mime: 'image/png', size: 100 }).expect(201);
  await api().post(`/v1/media/${up.body.media_id}/complete`).set(a.auth).expect(409); // nothing uploaded yet
  const key = up.body.upload_url.replace('https://fake-r2.test/', '').split('?')[0];
  r2.fakeObjects.set(key, 999); // wrong size
  await api().post(`/v1/media/${up.body.media_id}/complete`).set(a.auth).expect(400);
  const id = await uploadMedia(a);
  await api().get(`/v1/media/${id}`).set(b.auth).expect(404);
  const m = await api().get(`/v1/media/${id}`).set(a.auth).expect(200);
  assert.match(m.body.url, /^https:\/\/cdn\./);
  await api().post('/v1/posts').set(b.auth).send({ type: 'image', body: 'stolen', media_id: id }).expect(400); // not b's media
  const p = await api().post('/v1/posts').set(a.auth).send({ type: 'image', body: 'pic', media_id: id }).expect(201);
  assert.equal(p.body.media.url, m.body.url);
  await api().post('/v1/posts').set(a.auth).send({ type: 'image', body: 'no media' }).expect(400);
});

test('polls, hashtags, mentions, moderation', async () => {
  const a = await signup(); const b = await signup({ username: 'mentionme' });
  const poll = await api().post('/v1/posts').set(a.auth).send({ type: 'poll', body: 'Best fruit? #poll', poll: { options: ['Mango', 'Apple'] } }).expect(201);
  const [o1] = poll.body.poll.options;
  const v = await api().post(`/v1/posts/${poll.body.id}/vote`).set(b.auth).send({ option_id: o1.id }).expect(200);
  assert.equal(v.body.total_votes, 1); assert.equal(v.body.my_vote, o1.id);
  await api().post(`/v1/posts/${poll.body.id}/vote`).set(b.auth).send({ option_id: o1.id }).expect(409);
  await api().post('/v1/posts').set(a.auth).send({ type: 'poll', body: 'x', poll: { options: ['only one'] } }).expect(400);

  await api().post('/v1/posts').set(a.auth).send({ body: 'hi @mentionme #Jeyabo #jeyabo' }).expect(201);
  const notes = await api().get('/v1/notifications').set(b.auth).expect(200);
  assert.ok(notes.body.data.some((n) => n.type === 'mention'));
  assert.ok(notes.body.unread >= 1);
  const tag = await api().get('/v1/hashtags/jeyabo/posts').set(b.auth).expect(200);
  assert.equal(tag.body.data.length, 1);
  const tr = await api().get('/v1/hashtags/trending').set(b.auth).expect(200);
  assert.equal(tr.body.data.find((t) => t.tag === 'jeyabo').uses, 1); // duplicate tag in one post counts once

  await api().post('/v1/posts').set(a.auth).send({ body: 'you should kys' }).expect(422);
  await api().post(`/v1/posts/${poll.body.id}/comments`).set(a.auth).send({ body: 'kill yourself' }).expect(422);
});

test('stories: 24h lifetime, tray, views, reactions, expiry job', async () => {
  const a = await signup(); const b = await signup(); const c = await signup();
  await api().post(`/v1/users/${a.id}/follow`).set(b.auth).expect(204);
  const vid = await uploadMedia(a, 'video');
  const s = await api().post('/v1/stories').set(a.auth).send({ media_id: vid, caption: 'hello' }).expect(201);
  const tray = await api().get('/v1/stories').set(b.auth).expect(200);
  assert.equal(tray.body.data.length, 1);
  assert.equal(tray.body.data[0].stories[0].seen, false);
  assert.equal((await api().get('/v1/stories').set(c.auth)).body.data.length, 0); // not following
  await api().post(`/v1/stories/${s.body.id}/view`).set(b.auth).expect(204);
  await api().post(`/v1/stories/${s.body.id}/view`).set(b.auth).expect(204); // idempotent
  await api().put(`/v1/stories/${s.body.id}/reaction`).set(b.auth).send({ kind: 'love' }).expect(204);
  assert.equal((await api().get('/v1/stories').set(b.auth)).body.data[0].all_seen, true);
  await api().get(`/v1/stories/${s.body.id}/viewers`).set(b.auth).expect(403);
  const viewers = await api().get(`/v1/stories/${s.body.id}/viewers`).set(a.auth).expect(200);
  assert.equal(viewers.body.count, 1); assert.equal(viewers.body.data[0].reaction, 'love');
  const notes = await api().get('/v1/notifications').set(b.auth);
  assert.ok(notes.body.data.some((n) => n.type === 'story'));

  await db('stories').where({ id: s.body.id }).update({ expires_at: new Date(Date.now() - 1000) });
  assert.equal((await api().get('/v1/stories').set(b.auth)).body.data.length, 0);
  await api().post(`/v1/stories/${s.body.id}/view`).set(b.auth).expect(404);
  assert.equal(await HANDLERS.expireStories(), 1);
  assert.equal((await db('story_views').count({ c: '*' }).first()).c, 0);
});

test('videos: reels, long videos, categories, subscriptions, playlists, recommendations', async () => {
  const a = await signup(); const b = await signup();
  const cats = (await api().get('/v1/videos/categories').set(a.auth)).body.data;
  assert.ok(cats.length >= 5);
  await api().post('/v1/videos/channels/' + a.id + '/subscribe').set(b.auth).expect(204);
  const reel = await api().post('/v1/videos').set(a.auth).send({ media_id: await uploadMedia(a, 'video'), title: 'Dance #reel', is_short: true, effects: ['sepia'] }).expect(201);
  const long = await api().post('/v1/videos').set(a.auth).send({ media_id: await uploadMedia(a, 'video'), title: 'Tutorial', category_id: cats.find((c) => c.slug === 'education').id }).expect(201);
  await api().post('/v1/videos').set(a.auth).send({ media_id: await uploadMedia(a, 'image'), title: 'bad', is_short: true }).expect(400); // image is not a video
  assert.equal(reel.body.type, 'reel'); assert.equal(long.body.video.is_short, false);

  const reels = await api().get('/v1/videos/reels').set(b.auth).expect(200);
  assert.deepEqual(reels.body.data.map((p) => p.id), [reel.body.id]);
  assert.deepEqual((await api().get('/v1/videos?category=education').set(b.auth)).body.data.map((p) => p.id), [long.body.id]);
  await api().put(`/v1/posts/${reel.body.id}/reaction`).set(b.auth).send({ kind: 'love' }).expect(200);
  await api().post(`/v1/videos/${reel.body.id}/view`).set(b.auth).expect(204);
  assert.equal((await api().get('/v1/videos/reels/trending').set(b.auth)).body.data[0].video.views, 1);
  assert.equal((await api().get('/v1/videos/subscriptions/feed').set(b.auth)).body.data.length, 2);
  assert.ok((await api().get('/v1/notifications').set(b.auth)).body.data.some((n) => n.type === 'live'));
  assert.ok((await api().get('/v1/videos/recommended').set(b.auth)).body.data.length >= 1);

  const pl = await api().post('/v1/videos/playlists').set(b.auth).send({ title: 'Watch later' }).expect(201);
  await api().post(`/v1/videos/playlists/${pl.body.id}/items`).set(b.auth).send({ post_id: long.body.id }).expect(204);
  await api().post(`/v1/videos/playlists/${pl.body.id}/items`).set(a.auth).send({ post_id: long.body.id }).expect(404); // not owner
  assert.equal((await api().get(`/v1/videos/playlists/${pl.body.id}`).set(b.auth)).body.items.length, 1);
});

test('communities: public/private, approvals, roles, page posting rules, private feed isolation', async () => {
  const owner = await signup(); const m1 = await signup(); const m2 = await signup(); const out = await signup();
  const g = (await api().post('/v1/communities').set(owner.auth).send({ kind: 'group', privacy: 'private', name: 'Secret club' }).expect(201)).body;
  await api().post('/v1/communities').set(owner.auth).send({ kind: 'page', name: 'No type' }).expect(400);
  assert.equal((await api().post(`/v1/communities/${g.id}/join`).set(m1.auth).expect(201)).body.status, 'pending');
  await api().post(`/v1/posts`).set(m1.auth).send({ body: 'sneak', community_id: g.id }).expect(403);
  await api().patch(`/v1/communities/${g.id}/members/${m1.id}`).set(m2.auth).send({ action: 'approve' }).expect(403);
  await api().patch(`/v1/communities/${g.id}/members/${m1.id}`).set(owner.auth).send({ action: 'approve' }).expect(204);
  const post = await api().post('/v1/posts').set(m1.auth).send({ body: 'club talk', community_id: g.id }).expect(201);
  assert.equal((await api().get(`/v1/communities/${g.id}/feed`).set(m1.auth).expect(200)).body.data.length, 1);
  await api().get(`/v1/communities/${g.id}/feed`).set(out.auth).expect(403);
  await api().get(`/v1/posts/${post.body.id}`).set(out.auth).expect(404);
  assert.ok(!(await api().get('/v1/posts/feed').set(out.auth)).body.data.some((p) => p.id === post.body.id)); // private posts never leak into global feed
  assert.equal((await api().get(`/v1/communities/${g.id}`).set(out.auth)).body.description, undefined); // limited preview

  await api().patch(`/v1/communities/${g.id}/members/${m1.id}`).set(owner.auth).send({ action: 'set_role', role: 'moderator' }).expect(204);
  await api().patch(`/v1/communities/${g.id}/members/${owner.id}`).set(m1.auth).send({ action: 'ban' }).expect(403); // cannot touch owner
  await api().delete(`/v1/posts/${post.body.id}`).set(m1.auth).expect(204); // moderator removes content
  await api().patch(`/v1/communities/${g.id}/members/${m1.id}`).set(owner.auth).send({ action: 'ban' }).expect(204);
  await api().post(`/v1/communities/${g.id}/join`).set(m1.auth).expect(403);
  await api().post(`/v1/communities/${g.id}/leave`).set(owner.auth).expect(409);

  const page = (await api().post('/v1/communities').set(owner.auth).send({ kind: 'page', page_type: 'creator', name: 'Creator page' }).expect(201)).body;
  await api().post(`/v1/communities/${page.id}/join`).set(m2.auth).expect(201);
  await api().post('/v1/posts').set(m2.auth).send({ body: 'fan post', community_id: page.id }).expect(403); // only staff post on pages
  await api().post('/v1/posts').set(owner.auth).send({ body: 'official', community_id: page.id }).expect(201);
  assert.equal((await api().get('/v1/communities?q=Creator').set(out.auth)).body.data.length, 1);
});

test('engagement: badges, referrals, challenges, leaderboard, xp', async () => {
  const a = await signup(); const b = await signup(); const admin = await signup(); await setRole(admin.id, 'admin');
  await api().post('/v1/posts').set(a.auth).send({ body: 'first!' }).expect(201);
  const badges = await api().get('/v1/me/badges').set(a.auth).expect(200);
  assert.ok(badges.body.data.some((x) => x.code === 'first_post'));
  assert.ok((await api().get('/v1/notifications').set(a.auth)).body.data.some((n) => n.type === 'reward'));
  const xp = (await api().get('/v1/me/xp').set(a.auth)).body; assert.equal(xp.xp, 10);

  const code = (await api().get('/v1/referrals/me').set(a.auth)).body.code;
  await api().post('/v1/referrals/apply').set(a.auth).send({ code }).expect(400); // self
  await api().post('/v1/referrals/apply').set(b.auth).send({ code: 'NOPE1234' }).expect(400);
  assert.equal((await api().post('/v1/referrals/apply').set(b.auth).send({ code }).expect(200)).body.bonus_coins, 20);
  await api().post('/v1/referrals/apply').set(b.auth).send({ code }).expect(409);
  assert.equal((await api().get('/v1/wallet').set(a.auth)).body.balance, 50);
  assert.equal((await api().get('/v1/wallet').set(b.auth)).body.balance, 20);
  const viaReg = await signup({ referral_code: code });
  assert.equal((await api().get('/v1/wallet').set(viaReg.auth)).body.balance, 20); // referral code at signup
  assert.equal((await api().get('/v1/referrals/me').set(a.auth)).body.total, 2);

  const ch = (await api().post('/v1/admin/challenges').set(admin.auth).send({ title: 'Post 2x', metric: 'post', target: 2, reward_coins: 30, starts_at: new Date(Date.now() - 1000), ends_at: new Date(Date.now() + 864e5) }).expect(201)).body;
  await api().post(`/v1/admin/challenges`).set(a.auth).send({}).expect(403);
  await api().post(`/v1/challenges/${ch.id}/claim`).set(b.auth).expect(404); // not joined
  await api().post(`/v1/challenges/${ch.id}/join`).set(b.auth).expect(204);
  await api().post('/v1/posts').set(b.auth).send({ body: 'one' }).expect(201);
  await api().post(`/v1/challenges/${ch.id}/claim`).set(b.auth).expect(400);
  await api().post('/v1/posts').set(b.auth).send({ body: 'two' }).expect(201);
  assert.equal((await api().get('/v1/challenges').set(b.auth)).body.data[0].progress, 2);
  assert.equal((await api().post(`/v1/challenges/${ch.id}/claim`).set(b.auth).expect(200)).body.coins, 30);
  await api().post(`/v1/challenges/${ch.id}/claim`).set(b.auth).expect(409);

  const lb = (await api().get('/v1/leaderboards/week').set(a.auth)).body.data;
  assert.ok(lb.length >= 2); assert.ok(Number(lb[0].xp) >= Number(lb.at(-1).xp));
  await api().get('/v1/leaderboards/decade').set(a.auth).expect(400);
});

test('notifications: devices, push, prefs, offline message push', async () => {
  const a = await signup(); const b = await signup();
  const token = 't'.repeat(40);
  await api().post('/v1/devices').set(b.auth).send({ token, platform: 'android' }).expect(204);
  fcm.sent.length = 0;
  const conv = (await api().post('/v1/conversations').set(a.auth).send({ type: 'direct', user_id: b.id })).body;
  await api().post(`/v1/conversations/${conv.id}/messages`).set(a.auth).send({ client_id: require('crypto').randomUUID(), body: 'ping' }).expect(201);
  assert.equal(fcm.sent.length, 1); // b has no live socket => push
  assert.deepEqual(fcm.sent[0].tokens, [token]); assert.equal(fcm.sent[0].body, 'ping');
  await api().put('/v1/notifications/prefs').set(b.auth).send({ message: false }).expect(204);
  await api().post(`/v1/conversations/${conv.id}/messages`).set(a.auth).send({ client_id: require('crypto').randomUUID(), body: 'again' }).expect(201);
  assert.equal(fcm.sent.length, 1); // muted
  assert.equal((await api().get('/v1/notifications/prefs').set(b.auth)).body.message, false);
  await api().put('/v1/notifications/prefs').set(b.auth).send({ nonsense: true }).expect(400);
});

test('calls: token, ring, join, decline, end, group rules', async () => {
  const a = await signup(); const b = await signup(); const c = await signup(); const out = await signup();
  const conv = (await api().post('/v1/conversations').set(a.auth).send({ type: 'direct', user_id: b.id })).body;
  await api().post('/v1/calls').set(out.auth).send({ conversation_id: conv.id, kind: 'audio' }).expect(403);
  const call = (await api().post('/v1/calls').set(a.auth).send({ conversation_id: conv.id, kind: 'video' }).expect(201)).body;
  assert.ok(call.token.length > 50); assert.equal(call.channel, call.call_id);
  await api().post('/v1/calls').set(a.auth).send({ conversation_id: conv.id, kind: 'audio' }).expect(409); // already ringing
  await api().post(`/v1/calls/${call.call_id}/join`).set(out.auth).expect(403);
  const j = (await api().post(`/v1/calls/${call.call_id}/join`).set(b.auth).expect(200)).body;
  assert.equal(j.uid, b.id);
  assert.equal((await db('call_sessions').where({ id: call.call_id }).first()).status, 'active');
  await api().post(`/v1/calls/${call.call_id}/end`).set(a.auth).expect(204);
  await api().post(`/v1/calls/${call.call_id}/join`).set(b.auth).expect(409);
  const call2 = (await api().post('/v1/calls').set(a.auth).send({ conversation_id: conv.id, kind: 'audio' }).expect(201)).body;
  await api().post(`/v1/calls/${call2.call_id}/decline`).set(b.auth).expect(204);
  assert.equal((await db('call_sessions').where({ id: call2.call_id }).first()).status, 'declined');

  const grp = (await api().post('/v1/conversations').set(a.auth).send({ type: 'group', title: 'G', member_ids: [b.id, c.id] })).body;
  const gc = (await api().post('/v1/calls').set(a.auth).send({ conversation_id: grp.id, kind: 'video' }).expect(201)).body;
  await api().post(`/v1/calls/${gc.call_id}/decline`).set(b.auth).expect(204);
  await api().post(`/v1/calls/${gc.call_id}/join`).set(c.auth).expect(200); // one decline does not kill a group call
  await api().post(`/v1/calls/${gc.call_id}/end`).set(c.auth).expect(204);   // members leaving does not end it
  assert.equal((await db('call_sessions').where({ id: gc.call_id }).first()).status, 'active');
  await api().post(`/v1/calls/${gc.call_id}/end`).set(a.auth).expect(204);
  assert.equal((await api().get('/v1/calls/history').set(a.auth)).body.data.length, 3);

  const d = (await api().post('/v1/calls').set(b.auth).send({ conversation_id: conv.id, kind: 'audio' })).body;
  await db('call_sessions').where({ id: d.call_id }).update({ created_at: new Date(Date.now() - 120_000) });
  assert.equal(await HANDLERS.expireCalls(), 1);
});

test('group admin controls', async () => {
  const o = await signup(); const m = await signup(); const n = await signup();
  const g = (await api().post('/v1/conversations').set(o.auth).send({ type: 'group', title: 'Team', member_ids: [m.id] })).body;
  await api().patch(`/v1/conversations/${g.id}`).set(m.auth).send({ title: 'Hax' }).expect(403);
  await api().patch(`/v1/conversations/${g.id}`).set(o.auth).send({ title: 'Renamed' }).expect(204);
  await api().post(`/v1/conversations/${g.id}/members`).set(o.auth).send({ user_ids: [n.id] }).expect(204);
  await api().patch(`/v1/conversations/${g.id}/members/${n.id}`).set(o.auth).send({ role: 'admin' }).expect(204);
  await api().delete(`/v1/conversations/${g.id}/members/${m.id}`).set(n.auth).expect(204); // admin removes member
  await api().delete(`/v1/conversations/${g.id}/members/${o.id}`).set(n.auth).expect(403);  // never the owner
  await api().get(`/v1/conversations/${g.id}/messages`).set(m.auth).expect(403);
  await api().delete(`/v1/conversations/${g.id}/members/${n.id}`).set(n.auth).expect(204); // leave
});

test('search, suggestions, friends, reports, admin analytics, jobs', async () => {
  const a = await signup({ username: 'zaralee' }); const b = await signup(); const c = await signup(); const mod = await signup(); await setRole(mod.id, 'moderator');
  const admin = await signup(); await setRole(admin.id, 'admin');
  await api().post('/v1/posts').set(a.auth).send({ body: 'Learning rust today' }).expect(201);
  const s = (await api().get('/v1/search?q=rust').set(b.auth).expect(200)).body;
  assert.equal(s.posts.length, 1);
  assert.equal((await api().get('/v1/search?q=@zara&type=users').set(b.auth)).body.users[0].username, 'zaralee');
  await api().get('/v1/search').set(b.auth).expect(400);
  assert.equal((await api().get('/v1/search?q=%25').set(b.auth).expect(200)).body.posts.length, 0); // wildcard is escaped

  await api().post(`/v1/users/${b.id}/follow`).set(a.auth); await api().post(`/v1/users/${c.id}/follow`).set(b.auth);
  const sug = (await api().get('/v1/recommendations/friends').set(a.auth).expect(200)).body.data;
  assert.equal(sug[0].id, c.id); assert.equal(sug[0].mutual_follows, 1); assert.ok(!sug.some((u) => u.id === a.id || u.id === b.id));

  await api().post('/v1/friends/requests').set(a.auth).send({ user_id: c.id }).expect(201);
  await api().post('/v1/friends/requests').set(a.auth).send({ user_id: c.id }).expect(409);
  await api().post(`/v1/friends/requests/${a.id}/accept`).set(b.auth).expect(404);
  await api().post(`/v1/friends/requests/${a.id}/accept`).set(c.auth).expect(204);
  assert.equal((await api().get('/v1/friends').set(a.auth)).body.data[0].id, c.id);
  assert.equal((await api().get(`/v1/users/${a.id}`).set(b.auth)).body.following_count, 2);

  const post = (await api().post('/v1/posts').set(a.auth).send({ body: 'spammy link' })).body;
  const rep = (await api().post('/v1/reports').set(b.auth).send({ target_type: 'post', target_id: post.id, reason: 'spam' }).expect(201)).body;
  await api().post('/v1/reports').set(b.auth).send({ target_type: 'post', target_id: post.id, reason: 'spam' }).expect(409);
  await api().get('/v1/admin/reports').set(b.auth).expect(403);
  assert.equal((await api().get('/v1/admin/reports').set(mod.auth).expect(200)).body.data.length, 1);
  await api().post(`/v1/admin/reports/${rep.id}/action`).set(mod.auth).send({ action: 'remove' }).expect(200);
  await api().get(`/v1/posts/${post.id}`).set(b.auth).expect(404);

  const an = (await api().get('/v1/admin/analytics').set(admin.auth).expect(200)).body;
  assert.equal(an.signups.length, 14); assert.ok(an.totals.users >= 5);
  await api().get('/v1/admin/analytics').set(mod.auth).expect(403);

  const later = await api().post('/v1/posts').set(a.auth).send({ body: 'sched', publish_at: new Date(Date.now() + 5000) }).expect(201);
  await db('posts').where({ id: later.body.id }).update({ publish_at: new Date(Date.now() - 1000) });
  assert.equal(await HANDLERS.publishScheduled(), 1);
  await api().get(`/v1/posts/${later.body.id}`).set(b.auth).expect(200);
  await api().post('/v1/ai/translate').set(b.auth).send({ text: 'hi', target: 'French' }).expect(501); // AI not configured
});
