const { err } = require('../utils/errors');
/** validate({ body, query, params }) with Zod schemas; parsed values replace originals. */
module.exports = (schemas) => (req, _res, next) => {
  for (const part of ['params', 'query', 'body']) {
    if (!schemas[part]) continue;
    const r = schemas[part].safeParse(req[part]);
    if (!r.success) return next(err.badRequest('Validation failed', r.error.flatten().fieldErrors));
    Object.defineProperty(req, part, { value: r.data, writable: true, configurable: true });
  }
  next();
};
