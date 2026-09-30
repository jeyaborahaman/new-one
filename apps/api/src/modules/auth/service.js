const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const env = require('../../config/env');
const db = require('../../db/knex');
const { err } = require('../../utils/errors');

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
const addDays = (d) => new Date(Date.now() + d * 864e5);

function signAccess(user, sid) {
  return jwt.sign({ sub: String(user.id), role: user.role, sid }, env.JWT_SECRET, { algorithm: 'HS256', expiresIn: env.ACCESS_TTL });
}

async function issueTokens(user, { familyId = crypto.randomUUID(), device } = {}) {
  const id = crypto.randomUUID();
  const refresh = crypto.randomBytes(48).toString('base64url');
  await db('sessions').insert({ id, user_id: user.id, family_id: familyId, refresh_hash: sha(refresh), device_name: device, expires_at: addDays(env.REFRESH_TTL_DAYS) });
  return { accessToken: signAccess(user, id), refreshToken: refresh, expiresIn: env.ACCESS_TTL };
}

const publicUser = (u) => ({ id: u.id, username: u.username, display_name: u.display_name, bio: u.bio, is_verified: !!u.is_verified, level: u.level, xp: Number(u.xp), followers_count: u.followers_count, following_count: u.following_count, created_at: u.created_at });

async function register({ email, username, password, display_name, country }) {
  const taken = await db('users').where({ email }).orWhere({ username }).first('id');
  if (taken) throw err.conflict('Email or username already in use');
  const password_hash = await argon2.hash(password, { type: argon2.argon2id, memoryCost: 65536, timeCost: 3 });
  const [id] = await db('users').insert({ email, username, password_hash, display_name: display_name || username, country: country?.toUpperCase() });
  await db('wallets').insert({ user_id: id, balance: 0 });
  const user = await db('users').where({ id }).first();
  return { user: publicUser(user), ...(await issueTokens(user)) };
}

async function login({ identifier, password, device }) {
  const user = await db('users').where({ email: identifier }).orWhere({ username: identifier }).first();
  // Same error and comparable work for unknown user and wrong password.
  const ok = user?.password_hash ? await argon2.verify(user.password_hash, password) : (await argon2.hash(password), false);
  if (!ok) throw err.unauthorized('Invalid credentials');
  if (user.status !== 'active') throw err.forbidden(`Account ${user.status}`);
  return { user: publicUser(user), ...(await issueTokens(user, { device })) };
}

/** Rotating refresh; reuse of a revoked token revokes the whole family. */
async function refresh(token) {
  const s = await db('sessions').where({ refresh_hash: sha(token) }).first();
  if (!s) throw err.unauthorized('Invalid refresh token');
  if (s.revoked_at) {
    await db('sessions').where({ family_id: s.family_id }).whereNull('revoked_at').update({ revoked_at: new Date() });
    throw err.unauthorized('Refresh token reuse detected');
  }
  if (new Date(s.expires_at) < new Date()) throw err.unauthorized('Refresh token expired');
  const user = await db('users').where({ id: s.user_id }).first();
  if (!user || user.status !== 'active') throw err.unauthorized('Account unavailable');
  await db('sessions').where({ id: s.id }).update({ revoked_at: new Date() });
  return issueTokens(user, { familyId: s.family_id, device: s.device_name });
}

async function logout(token) {
  await db('sessions').where({ refresh_hash: sha(token) }).whereNull('revoked_at').update({ revoked_at: new Date() });
}

module.exports = { register, login, refresh, logout, publicUser };
