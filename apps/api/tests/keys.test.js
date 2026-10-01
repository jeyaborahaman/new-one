// Own process (node --test runs each file separately), so it can set its own keys and storage driver.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-test-secret-test-secret-123';
process.env.ENCRYPTION_KEY = 'separate-encryption-key-separate-key-1';
process.env.R2_DRIVER = 'local';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { encrypt, decrypt } = require('../src/utils/crypto');
const r2 = require('../src/integrations/r2');

const gcm = (keySource, plain) => {
  const key = crypto.createHash('sha256').update(keySource).digest(); const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', key, iv); const enc = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return [iv, c.getAuthTag(), enc].map((b) => b.toString('base64url')).join('.');
};

test('stored secrets use ENCRYPTION_KEY, not JWT_SECRET; legacy ciphertexts still decrypt', () => {
  const blob = encrypt('TOTPSECRET');
  assert.equal(decrypt(blob), 'TOTPSECRET');
  const jwtKey = crypto.createHash('sha256').update(process.env.JWT_SECRET).digest();
  const [iv, tag, enc] = blob.split('.').map((s) => Buffer.from(s, 'base64url'));
  const d = crypto.createDecipheriv('aes-256-gcm', jwtKey, iv); d.setAuthTag(tag);
  assert.throws(() => Buffer.concat([d.update(enc), d.final()])); // not readable with the JWT secret
  assert.equal(decrypt(gcm(process.env.JWT_SECRET, 'OLDSECRET')), 'OLDSECRET'); // data from before ENCRYPTION_KEY
  assert.throws(() => decrypt(gcm('an-unrelated-key', 'X')));
});

test('local upload links are signed with a derived key, not the raw JWT secret', async () => {
  const key = `u/1/2026/${crypto.randomUUID()}.jpg`;
  const url = new URL(await r2.presignPut({ key, contentType: 'image/jpeg', size: 1 }));
  const exp = url.searchParams.get('exp');
  r2.verifyLocalSignature(key, exp, url.searchParams.get('sig'));
  const rawJwtSig = crypto.createHmac('sha256', process.env.JWT_SECRET).update(`${key}:${exp}`).digest('hex');
  assert.throws(() => r2.verifyLocalSignature(key, exp, rawJwtSig), /expired or invalid/);
});
