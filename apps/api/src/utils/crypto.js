const crypto = require('crypto');
const env = require('../config/env');
const sha256Key = (s) => crypto.createHash('sha256').update(s).digest();
// ENCRYPTION_KEY keeps stored secrets independent of JWT_SECRET. Data encrypted before it was set used the
// JWT_SECRET-derived key, so decryption still falls back to that legacy key (GCM's auth tag rejects a wrong key).
const legacyKey = sha256Key(env.JWT_SECRET);
const key = env.ENCRYPTION_KEY ? sha256Key(env.ENCRYPTION_KEY) : legacyKey;
/** AES-256-GCM, output "iv.tag.ciphertext" base64url. Used for 2FA secrets. */
const encrypt = (plain) => {
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return [iv, c.getAuthTag(), enc].map((b) => b.toString('base64url')).join('.');
};
const decryptWith = (k, blob) => {
  const [iv, tag, enc] = blob.split('.').map((s) => Buffer.from(s, 'base64url'));
  const d = crypto.createDecipheriv('aes-256-gcm', k, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(enc), d.final()]).toString('utf8');
};
const decrypt = (blob) => {
  try { return decryptWith(key, blob); } catch (e) { if (key === legacyKey) throw e; return decryptWith(legacyKey, blob); }
};
/** Purpose-bound subkey of JWT_SECRET, so one signing secret is never used raw for two jobs. */
const deriveKey = (purpose) => crypto.createHmac('sha256', env.JWT_SECRET).update(`jeyabo:${purpose}`).digest();
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const randomDigits = (n = 6) => String(crypto.randomInt(0, 10 ** n)).padStart(n, '0');
module.exports = { encrypt, decrypt, deriveKey, sha256, randomDigits };
