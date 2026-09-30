class HttpError extends Error {
  constructor(status, code, message, fields) {
    super(message);
    this.status = status;
    this.code = code;
    this.fields = fields;
  }
}
const err = {
  badRequest: (m = 'Bad request', f) => new HttpError(400, 'BAD_REQUEST', m, f),
  unauthorized: (m = 'Authentication required') => new HttpError(401, 'UNAUTHORIZED', m),
  forbidden: (m = 'Forbidden') => new HttpError(403, 'FORBIDDEN', m),
  notFound: (m = 'Not found') => new HttpError(404, 'NOT_FOUND', m),
  tooMany: (m = 'Too many requests') => new HttpError(429, 'RATE_LIMITED', m),
  conflict: (m = 'Conflict') => new HttpError(409, 'CONFLICT', m),
};
module.exports = { HttpError, err };
