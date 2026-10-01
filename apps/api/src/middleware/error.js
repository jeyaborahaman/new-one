const { HttpError } = require('../utils/errors');
const logger = require('../utils/logger');
const { pickLanguage, translateError } = require('../i18n');
/** Error messages in the caller's language (Accept-Language); codes stay stable for clients. */
const tr = (req, message) => translateError(pickLanguage(req.headers['accept-language']), message);
const notFound = (req, res) => res.status(404).json({ error: { code: 'NOT_FOUND', message: tr(req, 'Route not found') } });
// eslint-disable-next-line no-unused-vars
const errorHandler = (e, req, res, _next) => {
  if (e instanceof HttpError) return res.status(e.status).json({ error: { code: e.code, message: tr(req, e.message), fields: e.fields } });
  if (e.type === 'entity.parse.failed') return res.status(400).json({ error: { code: 'BAD_JSON', message: tr(req, 'Malformed JSON') } });
  logger.error({ err: e, path: req.path }, 'unhandled');
  res.status(500).json({ error: { code: 'INTERNAL', message: tr(req, 'Something went wrong') } });
};
module.exports = { notFound, errorHandler, tr };
