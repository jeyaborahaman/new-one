const jwt = require('jsonwebtoken');
const env = require('../config/env');
const db = require('../db/knex');
const { err } = require('../utils/errors');

const ROLE_RANK = { user: 0, moderator: 1, admin: 2, superadmin: 3 };

function verifyAccess(token) {
  try {
    return jwt.verify(token, env.JWT_SECRET, { algorithms: ['HS256'] });
  } catch {
    throw err.unauthorized('Invalid or expired token');
  }
}

async function authenticate(req, _res, next) {
  if (req.user) return next(); // already authenticated by an earlier router on this request
  try {
    const h = req.headers.authorization || '';
    if (!h.startsWith('Bearer ')) throw err.unauthorized();
    const claims = verifyAccess(h.slice(7));
    const user = await db('users').where({ id: claims.sub }).first('id', 'role', 'status', 'country');
    if (!user || user.status !== 'active') throw err.unauthorized('Account unavailable');
    req.user = user;
    next();
  } catch (e) {
    next(e);
  }
}

const requireRole = (min) => (req, _res, next) =>
  ROLE_RANK[req.user.role] >= ROLE_RANK[min] ? next() : next(err.forbidden('Insufficient role'));

module.exports = { authenticate, requireRole, verifyAccess, ROLE_RANK };
