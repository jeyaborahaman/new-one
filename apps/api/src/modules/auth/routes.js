const router = require('express').Router();
const { z } = require('zod');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const { auth: authLimit } = require('../../middleware/rateLimit');
const asyncHandler = require('../../utils/asyncHandler');
const svc = require('./service');

const password = z.string().min(8).max(128);
const email = z.string().email().max(255).transform((s) => s.toLowerCase());
const phone = z.string().regex(/^\+[1-9]\d{7,14}$/, 'E.164 format, e.g. +14155550123');
const country = z.string().length(2).optional();
router.use(authLimit);
const h = (fn, status = 200) => asyncHandler(async (req, res) => { const out = await fn(req); out === undefined ? res.status(204).end() : res.status(status).json(out); });

router.post('/register', validate({ body: z.object({ email, username: z.string().regex(/^[a-zA-Z0-9_]{3,30}$/, '3-30 letters, digits or _').transform((s) => s.toLowerCase()), password, display_name: z.string().min(1).max(80).optional(), country, referral_code: z.string().max(12).optional() }).strict() }), h((r) => svc.register(r.body), 201));
router.post('/login', validate({ body: z.object({ identifier: z.string().min(1).max(255).transform((s) => s.toLowerCase()), password: z.string().min(1).max(128), device: z.string().max(100).optional() }).strict() }), h((r) => svc.login(r.body)));

router.post('/otp/request', validate({ body: z.object({ phone }).strict() }), h(async (r) => { await svc.requestPhoneOtp(r.body.phone); }));
router.post('/otp/verify', validate({ body: z.object({ phone, code: z.string().length(6), device: z.string().max(100).optional(), country }).strict() }), h((r) => svc.verifyPhoneOtp(r.body)));

const oauthBody = validate({ body: z.object({ id_token: z.string().min(20).max(4096), device: z.string().max(100).optional() }).strict() });
router.post('/oauth/google', oauthBody, h((r) => svc.oauthLogin('google', r.body.id_token, r.body.device)));
router.post('/oauth/apple', oauthBody, h((r) => svc.oauthLogin('apple', r.body.id_token, r.body.device)));

router.post('/password/forgot', validate({ body: z.object({ email }).strict() }), h(async (r) => { await svc.forgotPassword(r.body.email); }));
router.post('/password/reset', validate({ body: z.object({ email, code: z.string().length(6), new_password: password }).strict() }), h(async (r) => { await svc.resetPassword(r.body); }));

router.post('/2fa/verify', validate({ body: z.object({ challenge_token: z.string().min(20), code: z.string().min(6).max(12) }).strict() }), h((r) => svc.twoFactorLogin(r.body.challenge_token, r.body.code)));
router.post('/2fa/setup', authenticate, h((r) => svc.twoFactorSetup(r.user.id)));
router.post('/2fa/enable', authenticate, validate({ body: z.object({ code: z.string().length(6) }).strict() }), h((r) => svc.twoFactorConfirm(r.user.id, r.body.code)));
router.post('/2fa/disable', authenticate, validate({ body: z.object({ password: z.string().min(1).max(128), code: z.string().min(6).max(12) }).strict() }), h(async (r) => { await svc.twoFactorDisable(r.user.id, r.body.password, r.body.code); }));

const tokenBody = validate({ body: z.object({ refreshToken: z.string().min(20).max(200) }).strict() });
router.post('/refresh', tokenBody, h((r) => svc.refresh(r.body.refreshToken)));
router.post('/logout', tokenBody, h(async (r) => { await svc.logout(r.body.refreshToken); }));

router.get('/sessions', authenticate, h(async (r) => ({ data: await svc.listSessions(r.user.id) })));
router.delete('/sessions/:id', authenticate, validate({ params: z.object({ id: z.string().uuid() }) }), h(async (r) => { await svc.revokeSession(r.user.id, r.params.id); }));

module.exports = router;
