const router = require('express').Router();
const { z } = require('zod');
const validate = require('../../middleware/validate');
const { auth: authLimit } = require('../../middleware/rateLimit');
const asyncHandler = require('../../utils/asyncHandler');
const svc = require('./service');

const password = z.string().min(8).max(128);
router.use(authLimit);

router.post('/register', validate({ body: z.object({
  email: z.string().email().max(255).transform((s) => s.toLowerCase()),
  username: z.string().regex(/^[a-zA-Z0-9_]{3,30}$/, '3-30 letters, digits or _').transform((s) => s.toLowerCase()),
  password, display_name: z.string().min(1).max(80).optional(), country: z.string().length(2).optional(),
}).strict() }), asyncHandler(async (req, res) => res.status(201).json(await svc.register(req.body))));

router.post('/login', validate({ body: z.object({ identifier: z.string().min(1).max(255).transform((s) => s.toLowerCase()), password: z.string().min(1).max(128), device: z.string().max(100).optional() }).strict() }),
  asyncHandler(async (req, res) => res.json(await svc.login(req.body))));

const tokenBody = validate({ body: z.object({ refreshToken: z.string().min(20).max(200) }).strict() });
router.post('/refresh', tokenBody, asyncHandler(async (req, res) => res.json(await svc.refresh(req.body.refreshToken))));
router.post('/logout', tokenBody, asyncHandler(async (req, res) => { await svc.logout(req.body.refreshToken); res.status(204).end(); }));

module.exports = router;
