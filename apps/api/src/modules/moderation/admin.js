// Admin moderation panel API (mounted at /v1/admin). Moderators handle the reports queue and remove content;
// account actions (suspend/ban), e-mail addresses and the full audit log are for admins.
const router = require('express').Router();
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate, requireRole, ROLE_RANK } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const { pageQuery, page } = require('../../utils/pagination');
const { hydrate } = require('../posts/lib');
const { removeTarget, setUserStatus, audit } = require('./service');

router.use(authenticate);
const idParam = z.object({ id: z.coerce.number().int().positive() });
const isAdmin = (u) => ROLE_RANK[u.role] >= ROLE_RANK.admin;
const ACTIVE = ['open', 'reviewing']; // reports still waiting for an outcome
const PERSON = ['id', 'username', 'display_name', 'role', 'status'];
const people = async (ids) => Object.fromEntries((await db('users').whereIn('id', [...new Set(ids.filter(Boolean))]).select(PERSON)).map((u) => [u.id, u]));
const parseMeta = (m) => { if (!m) return null; try { return typeof m === 'string' ? JSON.parse(m) : m; } catch { return null; } };
const excerpt = (s, n = 280) => (s && s.length > n ? `${s.slice(0, n)}…` : s ?? null);

/** Who is signed in to the panel, and what they may do. */
router.get('/session', requireRole('moderator'), asyncHandler(async (req, res) => {
  const u = await db('users').where({ id: req.user.id }).first(PERSON);
  const admin = isAdmin(u);
  res.json({ ...u, permissions: { reports: true, remove_content: true, user_actions: admin, audit_log: admin, see_email: admin } });
}));

/** Queue counters for the dashboard and the new-report indicator (`since_id` = newest report the moderator has seen). */
router.get('/moderation/summary', requireRole('moderator'), validate({ query: z.object({ since_id: z.coerce.number().int().min(0).default(0) }) }), asyncHandler(async (req, res) => {
  const count = async (q) => Number((await q.count({ c: '*' }).first()).c);
  const byType = {};
  for (const r of await db('reports').whereIn('status', ACTIVE).groupBy('target_type').select('target_type').count({ c: '*' })) byType[r.target_type] = Number(r.c);
  const latest = await db('reports').max({ m: 'id' }).first();
  const dayAgo = new Date(Date.now() - 864e5);
  res.json({
    open: await count(db('reports').where({ status: 'open' })),
    reviewing: await count(db('reports').where({ status: 'reviewing' })),
    by_type: { post: byType.post || 0, comment: byType.comment || 0, user: byType.user || 0 },
    handled_24h: await count(db('reports').whereIn('status', ['actioned', 'dismissed']).where('handled_at', '>=', dayAgo)),
    suspended: await count(db('users').where({ status: 'suspended' })),
    banned: await count(db('users').where({ status: 'banned' })),
    latest_id: Number(latest?.m || 0),
    new_since: await count(db('reports').where('id', '>', req.query.since_id).whereIn('status', ACTIVE)),
  });
}));

/** Short previews of each report's target (body excerpt, author, whether it was already removed). */
async function previews(reports) {
  const ids = (t) => reports.filter((r) => r.target_type === t).map((r) => r.target_id);
  const [posts, comments] = await Promise.all([
    db('posts').whereIn('id', ids('post')).select('id', 'type', 'body', 'status', 'author_id'),
    db('comments').whereIn('id', ids('comment')).select('id', 'post_id', 'body', 'author_id', 'deleted_at'),
  ]);
  const P = Object.fromEntries(posts.map((p) => [p.id, p])); const C = Object.fromEntries(comments.map((c) => [c.id, c]));
  const U = await people([...ids('user'), ...posts.map((p) => p.author_id), ...comments.map((c) => c.author_id), ...reports.map((r) => r.reporter_id)]);
  const target = (r) => {
    if (r.target_type === 'post') { const p = P[r.target_id]; return p ? { exists: true, removed: p.status === 'removed', type: p.type, excerpt: excerpt(p.body), author: U[p.author_id] || null } : { exists: false }; }
    if (r.target_type === 'comment') { const c = C[r.target_id]; return c ? { exists: true, removed: !!c.deleted_at, post_id: c.post_id, excerpt: excerpt(c.body), author: U[c.author_id] || null } : { exists: false }; }
    const u = U[r.target_id]; return u ? { exists: true, removed: u.status !== 'active', author: u } : { exists: false };
  };
  return reports.map((r) => ({ ...r, reporter: U[r.reporter_id] || null, target: target(r) }));
}

router.get('/reports', requireRole('moderator'), validate({ query: pageQuery.extend({
  status: z.enum(['open', 'reviewing', 'active', 'actioned', 'dismissed', 'all']).default('open'),
  target_type: z.enum(['post', 'comment', 'user']).optional(),
}) }), asyncHandler(async (req, res) => {
  const { limit, cursor, status, target_type: type } = req.query;
  const q = db('reports').orderBy('id', 'desc').limit(limit + 1);
  if (status === 'active') q.whereIn('status', ACTIVE); else if (status !== 'all') q.where({ status });
  if (type) q.where({ target_type: type });
  if (cursor) q.where('id', '<', cursor);
  const p = page(await q, limit);
  res.json({ ...p, data: await previews(p.data) });
}));

const reportOr404 = async (id) => { const r = await db('reports').where({ id }).first(); if (!r) throw err.notFound('Report not found'); return r; };

/** Full report: the reported content, its author, other reports on the same target and the moderation history. */
router.get('/reports/:id', requireRole('moderator'), validate({ params: idParam }), asyncHandler(async (req, res) => {
  const r = await reportOr404(req.params.id);
  const [withPreview] = await previews([r]);
  let content = null;
  if (r.target_type === 'post') {
    const row = await db('posts').where({ id: r.target_id }).first();
    if (row) content = { ...(await hydrate([row], req.user.id))[0], status: row.status };
  } else if (r.target_type === 'comment') {
    const c = await db('comments').where({ id: r.target_id }).first('id', 'post_id', 'body', 'gif_url', 'author_id', 'deleted_at', 'created_at');
    if (c) content = { ...c, post_excerpt: excerpt((await db('posts').where({ id: c.post_id }).first('body'))?.body, 140) };
  } else {
    content = await db('users').where({ id: r.target_id }).first('id', 'username', 'display_name', 'bio', 'role', 'status', 'created_at', 'followers_count');
  }
  const related = await db('reports').where({ target_type: r.target_type, target_id: r.target_id }).whereNot({ id: r.id }).orderBy('id', 'desc').limit(50);
  const history = await db('audit_logs').whereIn('target', [`report:${r.id}`, `${r.target_type}:${r.target_id}`]).orderBy('id', 'desc').limit(50);
  const actors = await people([...history.map((h) => h.actor_id), r.handled_by, r.reviewer_id]);
  res.json({
    ...withPreview, content, reviewer: actors[r.reviewer_id] || null, handler: actors[r.handled_by] || null,
    related: await previews(related).then((rows) => rows.map(({ target, ...x }) => x)),
    history: history.map((h) => ({ ...h, meta: parseMeta(h.meta), actor: actors[h.actor_id] || null })),
  });
}));

const note = z.string().trim().max(1000).optional();

/** Claims a report: open -> reviewing, so other moderators see it is taken. */
router.post('/reports/:id/review', requireRole('moderator'), validate({ params: idParam }), asyncHandler(async (req, res) => {
  const r = await reportOr404(req.params.id);
  if (r.status === 'reviewing' && r.reviewer_id === req.user.id) return res.json({ id: r.id, status: 'reviewing' });
  if (r.status === 'reviewing') throw err.conflict('Another moderator is reviewing this report');
  if (r.status !== 'open') throw err.conflict('This report is already closed');
  // Conditional update: two moderators claiming at once -> only one wins.
  const n = await db('reports').where({ id: r.id, status: 'open' }).update({ status: 'reviewing', reviewer_id: req.user.id });
  if (!n) throw err.conflict('Another moderator is reviewing this report');
  await audit(req.user.id, 'report.review', `report:${r.id}`, { target: `${r.target_type}:${r.target_id}` });
  res.json({ id: r.id, status: 'reviewing' });
}));

const closable = async (id) => {
  const r = await reportOr404(id);
  if (!ACTIVE.includes(r.status)) throw err.conflict('This report is already closed');
  return r;
};
const close = (r, actorId, status, resolution, noteText) =>
  db('reports').where({ id: r.id }).whereIn('status', ACTIVE).update({ status, resolution, note: noteText ?? null, handled_by: actorId, handled_at: new Date(), reviewer_id: r.reviewer_id ?? actorId });

/** Resolves a report as a violation. Optionally removes the content and/or suspends or bans the account behind it
 * (account actions: admins only). Other pending reports on the same target are closed with the same outcome. */
router.post('/reports/:id/resolve', requireRole('moderator'), validate({ params: idParam, body: z.object({
  remove_content: z.boolean().default(false), user_action: z.enum(['none', 'suspend', 'ban']).default('none'), note,
}).strict() }), asyncHandler(async (req, res) => {
  const r = await closable(req.params.id);
  const { remove_content: remove, user_action: userAction } = req.body;
  if (remove && r.target_type === 'user') throw err.badRequest('To act on an account, suspend or ban it');
  if (userAction !== 'none' && !isAdmin(req.user)) throw err.forbidden('Only admins can act on users');
  let authorId = r.target_type === 'user' ? r.target_id : null;
  if (r.target_type !== 'user') authorId = (await db(r.target_type === 'post' ? 'posts' : 'comments').where({ id: r.target_id }).first('author_id'))?.author_id ?? null;
  if (userAction !== 'none' && !authorId) throw err.notFound('User not found');
  // Account action first: it is the step that can be refused (staff), and then nothing else should change.
  if (userAction !== 'none') {
    await setUserStatus(authorId, userAction === 'ban' ? 'banned' : 'suspended');
    await audit(req.user.id, userAction === 'ban' ? 'user.ban' : 'user.suspend', `user:${authorId}`, { report_id: r.id, reason: req.body.note });
  }
  if (remove) {
    await removeTarget(r.target_type, r.target_id);
    await audit(req.user.id, 'content.remove', `${r.target_type}:${r.target_id}`, { report_id: r.id, author_id: authorId });
  }
  const resolution = userAction === 'ban' ? 'user_banned' : userAction === 'suspend' ? 'user_suspended' : remove ? 'content_removed' : 'resolved';
  await close(r, req.user.id, 'actioned', resolution, req.body.note);
  let closedRelated = 0;
  if (remove || userAction !== 'none') {
    closedRelated = await db('reports').where({ target_type: r.target_type, target_id: r.target_id }).whereIn('status', ACTIVE)
      .update({ status: 'actioned', resolution, handled_by: req.user.id, handled_at: new Date(), note: `Closed with report #${r.id}` });
  }
  await audit(req.user.id, 'report.resolve', `report:${r.id}`, { target: `${r.target_type}:${r.target_id}`, resolution, note: req.body.note, closed_related: closedRelated });
  res.json({ id: r.id, status: 'actioned', resolution, closed_related: closedRelated });
}));

/** Rejects a report: no violation found. The content stays. */
router.post('/reports/:id/reject', requireRole('moderator'), validate({ params: idParam, body: z.object({ note }).strict().default({}) }), asyncHandler(async (req, res) => {
  const r = await closable(req.params.id);
  await close(r, req.user.id, 'dismissed', 'no_violation', req.body.note);
  await audit(req.user.id, 'report.reject', `report:${r.id}`, { target: `${r.target_type}:${r.target_id}`, note: req.body.note });
  res.json({ id: r.id, status: 'dismissed', resolution: 'no_violation' });
}));

/** Member search for staff: includes suspended and banned accounts (normal search hides them). */
router.get('/users', requireRole('moderator'), validate({ query: pageQuery.extend({
  q: z.string().trim().max(100).optional(), status: z.enum(['active', 'suspended', 'banned', 'deleted']).optional(), role: z.enum(['user', 'moderator', 'admin', 'superadmin']).optional(),
}) }), asyncHandler(async (req, res) => {
  const { limit, cursor, status, role } = req.query;
  const term = (req.query.q || '').replace(/^@/, '');
  // LIKE with escaped wildcards: '_' is common in usernames, '%' must not match everything.
  const like = (col, v) => [`${col} like ? escape '!'`, [`%${v.replace(/[!%_]/g, '!$&')}%`]];
  const admin = isAdmin(req.user);
  const q = db('users').orderBy('id', 'desc').limit(limit + 1).select([...PERSON, 'is_verified', 'created_at', ...(admin ? ['email', 'phone'] : [])]);
  if (term) {
    q.where((w) => {
      w.whereRaw(...like('username', term.toLowerCase())).orWhereRaw(...like('display_name', term));
      if (admin) w.orWhereRaw(...like('email', term.toLowerCase()));
      if (/^\d+$/.test(term)) w.orWhere('id', Number(term));
    });
  }
  if (status) q.where({ status });
  if (role) q.where({ role });
  if (cursor) q.where('id', '<', cursor);
  const p = page(await q, limit);
  const ids = p.data.map((u) => u.id);
  const open = Object.fromEntries((await db('reports').where({ target_type: 'user' }).whereIn('target_id', ids).whereIn('status', ACTIVE).groupBy('target_id').select('target_id').count({ c: '*' })).map((x) => [x.target_id, Number(x.c)]));
  res.json({ ...p, data: p.data.map((u) => ({ ...u, is_verified: !!u.is_verified, open_reports: open[u.id] || 0 })) });
}));

/** A member's moderation history: reports against them or their content, and every staff action on the account. */
router.get('/users/:id', requireRole('moderator'), validate({ params: idParam }), asyncHandler(async (req, res) => {
  const admin = isAdmin(req.user);
  const u = await db('users').where({ id: req.params.id }).first([...PERSON, 'bio', 'is_verified', 'level', 'followers_count', 'following_count', 'created_at', 'deleted_at', ...(admin ? ['email', 'phone'] : [])]);
  if (!u) throw err.notFound('User not found');
  const reports = await db('reports').where((w) => {
    w.where({ target_type: 'user', target_id: u.id })
      .orWhere((x) => x.where({ target_type: 'post' }).whereIn('target_id', db('posts').where({ author_id: u.id }).select('id')))
      .orWhere((x) => x.where({ target_type: 'comment' }).whereIn('target_id', db('comments').where({ author_id: u.id }).select('id')));
  }).orderBy('id', 'desc').limit(100);
  const history = await db('audit_logs').where({ target: `user:${u.id}` }).orderBy('id', 'desc').limit(100);
  const actors = await people(history.map((h) => h.actor_id));
  const count = async (t, w) => Number((await db(t).where(w).count({ c: '*' }).first()).c);
  res.json({
    ...u, is_verified: !!u.is_verified,
    stats: { posts: await count('posts', { author_id: u.id }), removed_posts: await count('posts', { author_id: u.id, status: 'removed' }), reports: reports.length, upheld_reports: reports.filter((r) => r.status === 'actioned').length },
    reports: await previews(reports),
    history: history.map((h) => ({ ...h, meta: parseMeta(h.meta), actor: actors[h.actor_id] || null })),
  });
}));

/** Moderator audit log (admins): who did what, newest first. Filter by actor, action (prefix such as `report.`) or target. */
router.get('/audit', requireRole('admin'), validate({ query: pageQuery.extend({
  actor_id: z.coerce.number().int().positive().optional(),
  action: z.string().regex(/^[a-z_.]{1,60}$/).optional(),
  target: z.string().regex(/^[a-z_]+:\d+$/).optional(),
}) }), asyncHandler(async (req, res) => {
  const { limit, cursor, actor_id: actorId, action, target } = req.query;
  const q = db('audit_logs').orderBy('id', 'desc').limit(limit + 1);
  if (actorId) q.where({ actor_id: actorId });
  if (action) action.endsWith('.') ? q.where('action', 'like', `${action}%`) : q.where({ action });
  if (target) q.where({ target });
  if (cursor) q.where('id', '<', cursor);
  const p = page(await q, limit);
  const actors = await people(p.data.map((h) => h.actor_id));
  res.json({ ...p, data: p.data.map((h) => ({ ...h, meta: parseMeta(h.meta), actor: actors[h.actor_id] || null })) });
}));

module.exports = router;
