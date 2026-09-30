const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const env = require('./config/env');
const { general } = require('./middleware/rateLimit');
const { notFound, errorHandler } = require('./middleware/error');
const luckydraw = require('./modules/luckydraw/routes');

function createApp() {
  const app = express();
  app.set('trust proxy', 1); // behind Nginx/Cloudflare
  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({ origin: env.CORS_ORIGINS.split(',').filter(Boolean) }));
  app.use(express.json({ limit: '100kb' }));
  if (env.R2_DRIVER === 'local') app.use('/uploads', express.static(require('./integrations/r2').UPLOAD_DIR, { maxAge: '1h', setHeaders: (res) => res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin') }));
  app.get('/health', (_req, res) => res.json({ ok: true }));

  const v1 = express.Router();
  v1.use(general);
  v1.use('/auth', require('./modules/auth/routes'));
  v1.use('/users', require('./modules/users/routes'));
  v1.use('/friends', require('./modules/users/friends'));
  v1.use('/posts', require('./modules/posts/routes'));
  v1.use('/media', require('./modules/media/routes').router);
  v1.use('/stories', require('./modules/stories/routes'));
  v1.use('/videos', require('./modules/videos/routes'));
  v1.use('/communities', require('./modules/communities/routes'));
  v1.use('/conversations', require('./modules/chat/routes').router);
  v1.use('/calls', require('./modules/calls/routes'));
  v1.use('/', require('./modules/wallet/routes'));
  v1.use('/', require('./modules/engagement/routes'));
  v1.use('/', require('./modules/notify/routes'));
  v1.use('/', require('./modules/moderation/routes'));
  v1.use('/', require('./modules/search/routes'));
  v1.use('/luckydraw', luckydraw.user);
  v1.use('/admin/luckydraw', luckydraw.admin);
  v1.use('/admin', require('./modules/admin'));
  app.use('/v1', v1);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
module.exports = { createApp };
