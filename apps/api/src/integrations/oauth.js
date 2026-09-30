const { OAuth2Client } = require('google-auth-library');
const { createRemoteJWKSet, jwtVerify } = require('jose');
const env = require('../config/env');
const { err } = require('../utils/errors');

const google = new OAuth2Client();
const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

/** Each verifier returns { uid, email, emailVerified, name } or throws 401. Tests replace these. */
module.exports = {
  async google(idToken) {
    if (!env.GOOGLE_CLIENT_ID) throw err.badRequest('Google login is not configured');
    try {
      const p = (await google.verifyIdToken({ idToken, audience: env.GOOGLE_CLIENT_ID })).getPayload();
      return { uid: p.sub, email: p.email?.toLowerCase(), emailVerified: !!p.email_verified, name: p.name };
    } catch { throw err.unauthorized('Invalid Google token'); }
  },
  async apple(idToken) {
    if (!env.APPLE_CLIENT_ID) throw err.badRequest('Apple login is not configured');
    try {
      const { payload: p } = await jwtVerify(idToken, appleKeys, { issuer: 'https://appleid.apple.com', audience: env.APPLE_CLIENT_ID });
      return { uid: p.sub, email: p.email?.toLowerCase(), emailVerified: p.email_verified === true || p.email_verified === 'true' };
    } catch { throw err.unauthorized('Invalid Apple token'); }
  },
};
