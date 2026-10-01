const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { api, db, setup, teardown, signup, setRole } = require('./helpers');

before(setup); after(teardown);

const staff = async (role) => { const u = await signup(); await setRole(u.id, role); return u; };
const report = (u, type, id, reason = 'spam', details) => api().post('/v1/reports').set(u.auth).send({ target_type: type, target_id: id, reason, ...(details ? { details } : {}) }).expect(201).then((r) => r.body.id);
const post = (u, body) => api().post('/v1/posts').set(u.auth).send({ body }).expect(201).then((r) => r.body);

test('panel access: members are refused; moderators and admins get their permissions', async () => {
  const member = await signup(); const mod = await staff('moderator'); const admin = await staff('admin');
  await api().get('/v1/admin/session').set(member.auth).expect(403);
  await api().get('/v1/admin/session').expect(401);
  const m = (await api().get('/v1/admin/session').set(mod.auth).expect(200)).body;
  assert.equal(m.role, 'moderator');
  assert.deepEqual(m.permissions, { reports: true, remove_content: true, user_actions: false, audit_log: false, see_email: false });
  const a = (await api().get('/v1/admin/session').set(admin.auth).expect(200)).body;
  assert.equal(a.permissions.user_actions, true);
  assert.equal(a.permissions.audit_log, true);
  for (const path of ['/v1/admin/reports', '/v1/admin/users', '/v1/admin/moderation/summary']) await api().get(path).set(member.auth).expect(403);
  await api().get('/v1/admin/audit').set(mod.auth).expect(403);
});

test('queue: post, comment and user reports with previews; filters by status and type; details with related reports', async () => {
  const mod = await staff('moderator');
  const author = await signup(); const r1 = await signup(); const r2 = await signup();
  const p = await post(author, 'buy cheap followers now');
  const c = (await api().post(`/v1/posts/${p.id}/comments`).set(author.auth).send({ body: 'nasty comment' }).expect(201)).body;
  const before = (await api().get('/v1/admin/moderation/summary').set(mod.auth).expect(200)).body;
  const rp = await report(r1, 'post', p.id, 'spam', 'link farm');
  const rp2 = await report(r2, 'post', p.id, 'other');
  const rc = await report(r1, 'comment', c.id, 'harassment');
  const ru = await report(r2, 'user', author.id, 'hate');

  const q = (await api().get('/v1/admin/reports').set(mod.auth).expect(200)).body.data;
  const byId = Object.fromEntries(q.map((r) => [r.id, r]));
  assert.equal(byId[rp].target.excerpt, 'buy cheap followers now');
  assert.equal(byId[rp].target.author.id, author.id);
  assert.equal(byId[rp].reporter.id, r1.id);
  assert.equal(byId[rp].details, 'link farm');
  assert.equal(byId[rc].target.excerpt, 'nasty comment');
  assert.equal(byId[rc].target.post_id, p.id);
  assert.equal(byId[ru].target.author.username, author.user.username);
  const onlyComments = (await api().get('/v1/admin/reports?target_type=comment').set(mod.auth)).body.data;
  assert.ok(onlyComments.length >= 1 && onlyComments.every((r) => r.target_type === 'comment'));
  await api().get('/v1/admin/reports?status=bogus').set(mod.auth).expect(400);

  const d = (await api().get(`/v1/admin/reports/${rp}`).set(mod.auth).expect(200)).body;
  assert.equal(d.content.body, 'buy cheap followers now');
  assert.equal(d.content.status, 'published');
  assert.deepEqual(d.related.map((r) => r.id), [rp2]);
  assert.deepEqual(d.history, []);
  const dc = (await api().get(`/v1/admin/reports/${rc}`).set(mod.auth).expect(200)).body;
  assert.equal(dc.content.body, 'nasty comment');
  assert.equal(dc.content.post_excerpt, 'buy cheap followers now');
  const du = (await api().get(`/v1/admin/reports/${ru}`).set(mod.auth).expect(200)).body;
  assert.equal(du.content.status, 'active');
  await api().get('/v1/admin/reports/999999').set(mod.auth).expect(404);

  const s = (await api().get(`/v1/admin/moderation/summary?since_id=${before.latest_id}`).set(mod.auth).expect(200)).body;
  assert.equal(s.new_since, 4); // the new-report indicator
  assert.equal(s.latest_id, ru);
  assert.ok(s.by_type.post >= 2 && s.by_type.comment >= 1 && s.by_type.user >= 1);
  assert.equal((await api().get(`/v1/admin/moderation/summary?since_id=${s.latest_id}`).set(mod.auth)).body.new_since, 0);
});

test('review -> resolve: content removed, related reports closed, everything audited', async () => {
  const mod = await staff('moderator'); const mod2 = await staff('moderator'); const admin = await staff('admin');
  const author = await signup(); const r1 = await signup(); const r2 = await signup();
  const p = await post(author, 'spam spam spam');
  const id = await report(r1, 'post', p.id);
  const other = await report(r2, 'post', p.id);

  assert.equal((await api().post(`/v1/admin/reports/${id}/review`).set(mod.auth).expect(200)).body.status, 'reviewing');
  await api().post(`/v1/admin/reports/${id}/review`).set(mod.auth).expect(200); // idempotent for the same moderator
  await api().post(`/v1/admin/reports/${id}/review`).set(mod2.auth).expect(409);
  await api().post('/v1/reports').set(r1.auth).send({ target_type: 'post', target_id: p.id, reason: 'spam' }).expect(409); // still pending
  assert.ok((await api().get('/v1/admin/reports?status=reviewing').set(mod.auth)).body.data.some((r) => r.id === id));
  assert.ok(!(await api().get('/v1/admin/reports').set(mod.auth)).body.data.some((r) => r.id === id)); // left the open queue
  assert.ok((await api().get('/v1/admin/reports?status=active').set(mod.auth)).body.data.some((r) => r.id === id));

  await api().post(`/v1/admin/reports/${id}/resolve`).set(mod.auth).send({ remove_content: true, user_action: 'suspend' }).expect(403); // moderators: content only
  const res = (await api().post(`/v1/admin/reports/${id}/resolve`).set(mod.auth).send({ remove_content: true, note: 'commercial spam' }).expect(200)).body;
  assert.deepEqual(res, { id, status: 'actioned', resolution: 'content_removed', closed_related: 1 });
  assert.equal((await db('posts').where({ id: p.id }).first()).status, 'removed');
  const closed = await db('reports').where({ id }).first();
  assert.equal(closed.handled_by, mod.id); assert.equal(closed.reviewer_id, mod.id); assert.equal(closed.note, 'commercial spam'); assert.ok(closed.handled_at);
  assert.equal((await db('reports').where({ id: other }).first()).status, 'actioned');
  assert.equal((await db('users').where({ id: author.id }).first()).status, 'active'); // the account is untouched
  await api().post(`/v1/admin/reports/${id}/resolve`).set(mod.auth).send({}).expect(409);
  await api().post(`/v1/admin/reports/${id}/reject`).set(mod.auth).expect(409);

  const d = (await api().get(`/v1/admin/reports/${id}`).set(mod.auth)).body;
  assert.deepEqual(d.history.map((h) => h.action), ['report.resolve', 'content.remove', 'report.review']);
  assert.equal(d.history[0].actor.id, mod.id);
  assert.equal(d.history[0].meta.note, 'commercial spam');
  assert.equal(d.handler.id, mod.id);
  assert.equal(d.target.removed, true);

  const log = (await api().get(`/v1/admin/audit?actor_id=${mod.id}`).set(admin.auth).expect(200)).body.data;
  assert.deepEqual(log.map((h) => h.action), ['report.resolve', 'content.remove', 'report.review']);
  const onlyReports = (await api().get('/v1/admin/audit?action=report.').set(admin.auth)).body.data;
  assert.ok(onlyReports.length >= 2 && onlyReports.every((h) => h.action.startsWith('report.')));
  assert.equal((await api().get(`/v1/admin/audit?target=post:${p.id}`).set(admin.auth)).body.data[0].action, 'content.remove');
  await api().get('/v1/admin/audit?action=DROP%20TABLE').set(admin.auth).expect(400);
});

test('reject: content stays; admin resolves a comment report by suspending the author (sessions end)', async () => {
  const mod = await staff('moderator'); const admin = await staff('admin');
  const author = await signup(); const r = await signup();
  const p = await post(author, 'harmless opinion');
  const rj = await report(r, 'post', p.id);
  const out = (await api().post(`/v1/admin/reports/${rj}/reject`).set(mod.auth).send({ note: 'no violation' }).expect(200)).body;
  assert.deepEqual(out, { id: rj, status: 'dismissed', resolution: 'no_violation' });
  assert.equal((await db('posts').where({ id: p.id }).first()).status, 'published');
  await api().post(`/v1/admin/reports/${rj}/reject`).set(mod.auth).expect(409);

  const c = (await api().post(`/v1/posts/${p.id}/comments`).set(author.auth).send({ body: 'threatening words' }).expect(201)).body;
  const rc = await report(r, 'comment', c.id, 'violence');
  await api().post(`/v1/admin/reports/${rc}/resolve`).set(admin.auth).send({ remove_content: true, user_action: 'suspend', note: 'threats' }).expect(200);
  assert.ok((await db('comments').where({ id: c.id }).first()).deleted_at);
  assert.equal((await db('users').where({ id: author.id }).first()).status, 'suspended');
  await api().get('/v1/users/me').set(author.auth).expect(401); // signed out everywhere
  assert.equal((await db('reports').where({ id: rc }).first()).resolution, 'user_suspended');
  const hist = (await api().get(`/v1/admin/users/${author.id}`).set(admin.auth).expect(200)).body;
  assert.deepEqual(hist.history.map((h) => [h.action, h.meta.report_id, h.meta.reason]), [['user.suspend', rc, 'threats']]);
  assert.deepEqual(hist.reports.map((x) => [x.id, x.status]), [[rc, 'actioned'], [rj, 'dismissed']]);
  assert.equal(hist.stats.upheld_reports, 1);
});

test('user reports: admin bans; staff accounts are protected and the report stays open', async () => {
  const admin = await staff('admin'); const mod = await staff('moderator');
  const bad = await signup(); const r = await signup();
  const ru = await report(r, 'user', bad.id, 'harassment');
  await api().post(`/v1/admin/reports/${ru}/resolve`).set(admin.auth).send({ remove_content: true }).expect(400); // accounts: suspend/ban
  assert.equal((await api().post(`/v1/admin/reports/${ru}/resolve`).set(admin.auth).send({ user_action: 'ban' }).expect(200)).body.resolution, 'user_banned');
  assert.equal((await db('users').where({ id: bad.id }).first()).status, 'banned');

  const rs = await report(r, 'user', mod.id, 'other');
  await api().post(`/v1/admin/reports/${rs}/resolve`).set(admin.auth).send({ user_action: 'ban' }).expect(403);
  assert.equal((await db('reports').where({ id: rs }).first()).status, 'open');
  assert.equal((await db('users').where({ id: mod.id }).first()).status, 'active');
  await api().post(`/v1/admin/reports/${rs}/resolve`).set(mod.auth).send({ user_action: 'none' }).expect(200); // closed without an account action
});

test('user search includes suspended/banned accounts; e-mail only for admins; suspend/ban/reinstate keep a reason', async () => {
  const mod = await staff('moderator'); const admin = await staff('admin');
  const target = await signup({ username: 'zed_target', display_name: 'Zed Target' });
  await api().post(`/v1/admin/users/${target.id}/suspend`).set(mod.auth).send({ reason: 'x' }).expect(403); // admins only
  await api().post(`/v1/admin/users/${target.id}/suspend`).set(admin.auth).send({ reason: 'cooling off' }).expect(200);
  await api().post(`/v1/admin/users/${target.id}/ban`).set(admin.auth).expect(200); // the reason is optional
  await api().post(`/v1/admin/users/${target.id}/ban`).set(admin.auth).send({ reason: 'r', extra: 1 }).expect(400);

  const asMod = (await api().get('/v1/admin/users?q=zed_tar').set(mod.auth).expect(200)).body.data;
  assert.deepEqual(asMod.map((u) => [u.id, u.status]), [[target.id, 'banned']]);
  assert.equal(asMod[0].email, undefined);
  const asAdmin = (await api().get(`/v1/admin/users?q=${encodeURIComponent(target.user.username)}`).set(admin.auth)).body.data;
  assert.equal(asAdmin[0].email, (await db('users').where({ id: target.id }).first()).email);
  assert.deepEqual((await api().get(`/v1/admin/users?q=${target.id}`).set(mod.auth)).body.data.map((u) => u.id), [target.id]);
  assert.ok((await api().get('/v1/admin/users?status=banned').set(mod.auth)).body.data.every((u) => u.status === 'banned'));
  assert.ok((await api().get('/v1/admin/users?role=admin').set(mod.auth)).body.data.some((u) => u.id === admin.id));
  assert.equal((await api().get('/v1/admin/users?q=%25').set(mod.auth)).body.data.length, 0); // wildcards match literally
  assert.equal((await api().get('/v1/admin/users?q=zed%25').set(mod.auth)).body.data.length, 0);

  await api().post(`/v1/admin/users/${target.id}/reinstate`).set(admin.auth).send({ reason: 'appeal accepted' }).expect(200);
  const u = (await api().get(`/v1/admin/users/${target.id}`).set(mod.auth).expect(200)).body;
  assert.equal(u.status, 'active');
  assert.equal(u.email, undefined);
  assert.deepEqual(u.history.map((h) => [h.action, h.meta?.reason ?? null, h.actor.id]), [['user.reinstate', 'appeal accepted', admin.id], ['user.ban', null, admin.id], ['user.suspend', 'cooling off', admin.id]]);
  await api().get('/v1/admin/users/999999').set(mod.auth).expect(404);
});

test('legacy one-step action still works and also handles reports under review', async () => {
  const mod = await staff('moderator');
  const author = await signup(); const r = await signup();
  const p = await post(author, 'old client');
  const id = await report(r, 'post', p.id);
  await api().post(`/v1/admin/reports/${id}/review`).set(mod.auth).expect(200);
  await api().post(`/v1/admin/reports/${id}/action`).set(mod.auth).send({ action: 'remove' }).expect(200);
  const row = await db('reports').where({ id }).first();
  assert.equal(row.status, 'actioned'); assert.equal(row.resolution, 'content_removed');
});

test('errors are translated for Arabic moderators', async () => {
  const mod = await staff('moderator');
  const r = await api().get('/v1/admin/reports/999999').set(mod.auth).set('Accept-Language', 'ar').expect(404);
  assert.equal(r.body.error.message, 'البلاغ غير موجود');
});
