const { HttpError } = require('../utils/errors');
const logger = require('../utils/logger');
const notFound = (_req, res) => res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Route not found' } });
// eslint-disable-next-line no-unused-vars
const errorHandler = (e, req, res, _next) => {
  if (e instanceof HttpError) return res.status(e.status).json({ error: { code: e.code, message: e.message, fields: e.fields } });
  if (e.type === 'entity.parse.failed') return res.status(400).json({ error: { code: 'BAD_JSON', message: 'Malformed JSON' } });
  logger.error({ err: e, path: req.path }, 'unhandled');
  res.status(500).json({ error: { code: 'INTERNAL', message: 'Something went wrong' } });
};
module.exports = { notFound, errorHandler };
