const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { generateSecret, generateURI, verify: verifyTotp } = require('otplib');
const env = require('../../config/env');
const db = require('../../db/knex');
const { err } = require('../../utils/errors');
const { encrypt, decrypt, sha256, randomDigits } = require('../../utils/crypto');
const sms = require('../../integrations/sms');
const mailer = require('../../integrations/mailer');
const oauth = require('../../integrations/oauth');

const addDays = (d) => new Date(Date.now() + d * 864e5);
const hashPw = (pw) => argon2.hash(pw, { type: argon2.argon2id, memoryCost: 65536, timeCost: 3 });

function signAccess(user, sid) {
  return jwt.sign({ sub: String(user.id), role: user.role, sid }, env.JWT_SECRET, { algorithm: 'HS256', expiresIn: env.ACCESS_TTL });
}
async function issueTokens(user, { familyId = crypto.randomUUID(), device } = {}) {
  const id = crypto.randomUUID();
  const refresh = crypto.randomBytes(48).toString('base64url');
  await db('sessions').insert({ id, user_id: user.id, family_id: familyId, refresh_hash: sha256(refresh), device_name: device, expires_at: addDays(env.REFRESH_TTL_DAYS) });
  return { accessToken: signAccess(user, id), refreshToken: refresh, expiresIn: env.ACCESS_TTL };
}
const publicUser = (u) => ({ id: u.id, username: u.username, display_name: u.display_name, bio: u.bio, is_verified: !!u.is_verified, level: u.level, xp: Number(u.xp), followers_count: u.followers_count, following_count: u.following_count, two_factor_enabled: !!u.two_factor_enabled, referral_code: u.referral_code, created_at: u.created_at });

/** Every login path ends here so 2FA cannot be bypassed via OTP or OAuth. */
async function finishLogin(user, device) {
  if (user.status !== 'active') throw err.forbidden(`Account ${user.status}`);
  if (user.two_factor_enabled) {
    const challenge_token = jwt.sign({ sub: String(user.id), purpose: '2fa', device }, env.JWT_SECRET, { algorithm: 'HS256', expiresIn: '5m' });
    return { requires_2fa: true, challenge_token };
  }
  return { user: publicUser(user), ...(await issueTokens(user, { device })) };
}

async function createUser({ email, phone, username, password, display_name, country, referral_code }) {
  const password_hash = password ? await hashPw(password) : null;
  const code = crypto.randomBytes(5).toString('hex').slice(0, 8).toUpperCase();
  const [id] = await db('users').insert({ email, phone, username, password_hash, display_name: display_name || username, country: country?.toUpperCase(), referral_code: code });
  await db('wallets').insert({ user_id: id, balance: 0 });
  if (referral_code) await require('../engagement/service').applyReferral(id, referral_code).catch(() => {}); // a bad code never blocks signup
  return db('users').where({ id }).first();
}
const freeUsername = async (base) => {
  const clean = (base || 'user').toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 20) || 'user';
  for (let i = 0; i < 8; i++) {
    const cand = `${clean}${crypto.randomInt(100, 99999)}`;
    if (!(await db('users').where({ username: cand }).first('id'))) return cand;
  }
  throw err.conflict('Could not allocate username');
};

async function register(input) {
  const taken = await db('users').where({ email: input.email }).orWhere({ username: input.username }).first('id');
  if (taken) throw err.conflict('Email or username already in use');
  const user = await createUser(input);
  return { user: publicUser(user), ...(await issueTokens(user)) };
}

async function login({ identifier, password, device }) {
  const user = await db('users').where({ email: identifier }).orWhere({ username: identifier }).first();
  const ok = user?.password_hash ? await argon2.verify(user.password_hash, password) : (await hashPw(password), false);
  if (!ok) throw err.unauthorized('Invalid credentials');
  return finishLogin(user, device);
}

async function refresh(token) {
  const s = await db('sessions').where({ refresh_hash: sha256(token) }).first();
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
const logout = (token) => db('sessions').where({ refresh_hash: sha256(token) }).whereNull('revoked_at').update({ revoked_at: new Date() });
const revokeAll = (userId) => db('sessions').where({ user_id: userId }).whereNull('revoked_at').update({ revoked_at: new Date() });

// ---- one-time codes (phone login, password reset) ----
const OTP_TTL_MS = 5 * 60_000; const OTP_MAX_ATTEMPTS = 5; const OTP_MAX_PER_HOUR = 3;
async function issueOtp(target, purpose) {
  const recent = Number((await db('otp_codes').where({ target, purpose }).where('created_at', '>', new Date(Date.now() - 3600_000)).count({ c: '*' }).first()).c);
  if (recent >= OTP_MAX_PER_HOUR) throw err.tooMany('Too many codes requested. Try again later.');
  const code = randomDigits(6);
  await db('otp_codes').insert({ target, purpose, code_hash: sha256(`${target}:${code}`), expires_at: new Date(Date.now() + OTP_TTL_MS) });
  return code;
}
async function consumeOtp(target, purpose, code) {
  const row = await db('otp_codes').where({ target, purpose }).whereNull('consumed_at').orderBy('id', 'desc').first();
  if (!row || new Date(row.expires_at) < new Date() || row.attempts >= OTP_MAX_ATTEMPTS) throw err.unauthorized('Code expired or invalid');
  if (row.code_hash !== sha256(`${target}:${code}`)) {
    await db('otp_codes').where({ id: row.id }).increment('attempts', 1);
    throw err.unauthorized('Code expired or invalid');
  }
  await db('otp_codes').where({ id: row.id }).update({ consumed_at: new Date() });
}

async function requestPhoneOtp(phone) { await sms.send(phone, `${env.APP_NAME} code: ${await issueOtp(phone, 'login')}. Valid 5 minutes.`); }
async function verifyPhoneOtp({ phone, code, device, country }) {
  await consumeOtp(phone, 'login', code);
  let user = await db('users').where({ phone }).first();
  if (!user) user = await createUser({ phone, username: await freeUsername('user'), country });
  return finishLogin(user, device);
}

async function forgotPassword(email) {
  const user = await db('users').where({ email }).first('id');
  if (!user) return; // no account enumeration: same response either way
  await mailer.send(email, `${env.APP_NAME} password reset`, `Your reset code is ${await issueOtp(email, 'reset')}. It expires in 5 minutes.`);
}
async function resetPassword({ email, code, new_password }) {
  await consumeOtp(email, 'reset', code);
  const user = await db('users').where({ email }).first();
  if (!user) throw err.unauthorized('Code expired or invalid');
  await db('users').where({ id: user.id }).update({ password_hash: await hashPw(new_password) });
  await revokeAll(user.id);
}

// ---- Google / Apple ----
async function oauthLogin(provider, idToken, device) {
  const p = await oauth[provider](idToken);
  const link = await db('oauth_identities').where({ provider, provider_uid: p.uid }).first();
  let user = link && (await db('users').where({ id: link.user_id }).first());
  if (!user) {
    // Link to an existing account by email ONLY when the provider verified it; otherwise a fresh account.
    if (p.email && p.emailVerified) user = await db('users').where({ email: p.email }).first();
    if (!user) {
      const emailFree = p.email && p.emailVerified && !(await db('users').where({ email: p.email }).first('id'));
      user = await createUser({ email: emailFree ? p.email : null, username: await freeUsername(p.email?.split('@')[0] || p.name), display_name: p.name });
    }
    await db('oauth_identities').insert({ provider, provider_uid: p.uid, user_id: user.id });
  }
  return finishLogin(user, device);
}

// ---- 2FA (TOTP + backup codes) ----
const totpOk = async (secret, token) => /^\d{6}$/.test(String(token)) && (await verifyTotp({ secret, token: String(token), epochTolerance: 30 })).valid;

async function twoFactorSetup(userId) {
  const user = await db('users').where({ id: userId }).first();
  if (user.two_factor_enabled) throw err.conflict('2FA is already enabled');
  const secret = generateSecret();
  await db('users').where({ id: userId }).update({ two_factor_secret: encrypt(secret) });
  return { secret, otpauth_url: generateURI({ issuer: env.APP_NAME, label: user.email || user.username, secret }) };
}
async function twoFactorConfirm(userId, token) {
  const user = await db('users').where({ id: userId }).first();
  if (user.two_factor_enabled || !user.two_factor_secret) throw err.badRequest('Start 2FA setup first');
  if (!(await totpOk(decrypt(user.two_factor_secret), token))) throw err.unauthorized('Invalid code');
  const codes = Array.from({ length: 10 }, () => crypto.randomBytes(5).toString('hex'));
  await db.transaction(async (trx) => {
    await trx('two_factor_backup').where({ user_id: userId }).del();
    await trx('two_factor_backup').insert(codes.map((c) => ({ user_id: userId, code_hash: sha256(c) })));
    await trx('users').where({ id: userId }).update({ two_factor_enabled: true });
  });
  return { backup_codes: codes };
}
async function checkSecondFactor(user, code) {
  if (await totpOk(decrypt(user.two_factor_secret), code)) return true;
  const used = await db('two_factor_backup').where({ user_id: user.id, code_hash: sha256(String(code).toLowerCase()) }).whereNull('used_at').update({ used_at: new Date() });
  return used > 0;
}
async function twoFactorLogin(challengeToken, code) {
  let c;
  try { c = jwt.verify(challengeToken, env.JWT_SECRET, { algorithms: ['HS256'] }); } catch { throw err.unauthorized('Challenge expired'); }
  if (c.purpose !== '2fa') throw err.unauthorized('Invalid challenge');
  const user = await db('users').where({ id: c.sub }).first();
  if (!user || user.status !== 'active' || !user.two_factor_enabled) throw err.unauthorized('Invalid challenge');
  if (!(await checkSecondFactor(user, code))) throw err.unauthorized('Invalid code');
  return { user: publicUser(user), ...(await issueTokens(user, { device: c.device })) };
}
async function twoFactorDisable(userId, password, code) {
  const user = await db('users').where({ id: userId }).first();
  if (!user.two_factor_enabled) throw err.badRequest('2FA is not enabled');
  if (!user.password_hash || !(await argon2.verify(user.password_hash, password))) throw err.unauthorized('Invalid credentials');
  if (!(await checkSecondFactor(user, code))) throw err.unauthorized('Invalid code');
  await db('users').where({ id: userId }).update({ two_factor_enabled: false, two_factor_secret: null });
  await db('two_factor_backup').where({ user_id: userId }).del();
}

async function listSessions(userId) {
  return db('sessions').where({ user_id: userId }).whereNull('revoked_at').where('expires_at', '>', new Date()).orderBy('created_at', 'desc').select('id', 'device_name', 'created_at', 'expires_at');
}
const revokeSession = (userId, id) => db('sessions').where({ id, user_id: userId }).whereNull('revoked_at').update({ revoked_at: new Date() });

module.exports = { register, login, refresh, logout, publicUser, requestPhoneOtp, verifyPhoneOtp, forgotPassword, resetPassword, oauthLogin, twoFactorSetup, twoFactorConfirm, twoFactorLogin, twoFactorDisable, listSessions, revokeSession, revokeAll };
