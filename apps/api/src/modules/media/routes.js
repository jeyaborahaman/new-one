const router = require('express').Router();
const crypto = require('crypto');
const { z } = require('zod');
const db = require('../../db/knex');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const asyncHandler = require('../../utils/asyncHandler');
const { err } = require('../../utils/errors');
const r2 = require('../../integrations/r2');

const MB = 1024 * 1024;
const RULES = {
  image: { max: 10 * MB, mimes: { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' } },
  video: { max: 500 * MB, mimes: { 'video/mp4': 'mp4', 'video/quicktime': 'mov', 'video/webm': 'webm' } },
  audio: { max: 25 * MB, mimes: { 'audio/mpeg': 'mp3', 'audio/mp4': 'm4a', 'audio/ogg': 'ogg', 'audio/webm': 'weba' } },
  file: { max: 50 * MB, mimes: { 'application/pdf': 'pdf', 'application/zip': 'zip', 'text/plain': 'txt' } },
};
const mediaView = (m) => ({ id: m.id, kind: m.kind, mime: m.mime, size_bytes: Number(m.size_bytes), status: m.status, url: m.status === 'ready' ? r2.publicUrl(m.r2_key) : null });
router.use(authenticate);

router.post('/uploads', validate({ body: z.object({ kind: z.enum(Object.keys(RULES)), mime: z.string().max(100), size: z.number().int().positive() }).strict() }), asyncHandler(async (req, res) => {
  const { kind, mime, size } = req.body;
  const rule = RULES[kind];
  const ext = rule.mimes[mime];
  if (!ext) throw err.badRequest(`Unsupported ${kind} type`);
  if (size > rule.max) throw err.badRequest(`File too large (max ${rule.max / MB} MB)`);
  const key = `u/${req.user.id}/${new Date().getUTCFullYear()}/${crypto.randomUUID()}.${ext}`;
  const upload_url = await r2.presignPut({ key, contentType: mime, size });
  const [id] = await db('media').insert({ owner_id: req.user.id, kind, r2_key: key, mime, size_bytes: size });
  res.status(201).json({ media_id: id, upload_url, headers: { 'Content-Type': mime }, expires_in: 600 });
}));

router.post('/:id/complete', validate({ params: z.object({ id: z.coerce.number().int().positive() }) }), asyncHandler(async (req, res) => {
  const m = await db('media').where({ id: req.params.id, owner_id: req.user.id }).first();
  if (!m) throw err.notFound('Media not found');
  if (m.status === 'ready') return res.json(mediaView(m));
  const head = await r2.head(m.r2_key);
  if (!head) throw err.conflict('Upload not found. Upload the file first.');
  if (Number(head.size) !== Number(m.size_bytes)) {
    await db('media').where({ id: m.id }).update({ status: 'rejected' });
    await r2.remove(m.r2_key).catch(() => {});
    throw err.badRequest('Uploaded size does not match the declared size');
  }
  await db('media').where({ id: m.id }).update({ status: 'ready' });
  res.json(mediaView({ ...m, status: 'ready' }));
}));

router.get('/:id', validate({ params: z.object({ id: z.coerce.number().int().positive() }) }), asyncHandler(async (req, res) => {
  const m = await db('media').where({ id: req.params.id, owner_id: req.user.id }).first();
  if (!m) throw err.notFound('Media not found');
  res.json(mediaView(m));
}));

/** Used by posts/stories: media must belong to the user, be ready, and be of an allowed kind. */
async function requireReadyMedia(id, userId, kinds) {
  const m = await db('media').where({ id, owner_id: userId }).first();
  if (!m || m.status !== 'ready') throw err.badRequest('Media not found or not ready');
  if (!kinds.includes(m.kind)) throw err.badRequest(`Media must be ${kinds.join(' or ')}`);
  return m;
}
module.exports = { router, requireReadyMedia, mediaView };
