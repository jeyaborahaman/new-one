const crypto = require('crypto');
const env = require('../config/env');
const key = crypto.createHash('sha256').update(env.ENCRYPTION_KEY || env.JWT_SECRET).digest();
/** AES-256-GCM, output "iv.tag.ciphertext" base64url. Used for 2FA secrets. */
const encrypt = (plain) => {
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return [iv, c.getAuthTag(), enc].map((b) => b.toString('base64url')).join('.');
};
const decrypt = (blob) => {
  const [iv, tag, enc] = blob.split('.').map((s) => Buffer.from(s, 'base64url'));
  const d = crypto.createDecipheriv('aes-256-gcm', key, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(enc), d.final()]).toString('utf8');
};
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const randomDigits = (n = 6) => String(crypto.randomInt(0, 10 ** n)).padStart(n, '0');
module.exports = { encrypt, decrypt, sha256, randomDigits };
