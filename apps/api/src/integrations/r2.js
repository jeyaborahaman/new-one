const { S3Client, PutObjectCommand, HeadObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const env = require('../config/env');
const { HttpError } = require('../utils/errors');

let client;
const s3 = () => {
  if (!env.R2_ACCOUNT_ID || !env.R2_ACCESS_KEY || !env.R2_SECRET) throw new HttpError(503, 'STORAGE_NOT_CONFIGURED', 'Media storage is not configured');
  client ||= new S3Client({ region: 'auto', endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`, credentials: { accessKeyId: env.R2_ACCESS_KEY, secretAccessKey: env.R2_SECRET } });
  return client;
};
const fakeObjects = new Map(); // test driver: key -> size

// Local driver (development): files live under apps/api/.uploads and are served by this API.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const UPLOAD_DIR = path.join(__dirname, '../../.uploads');
const KEY_RE = /^u\/\d+\/\d{4}\/[0-9a-f-]{36}\.[a-z0-9]+$/;
const sign = (key, exp) => crypto.createHmac('sha256', env.JWT_SECRET).update(`${key}:${exp}`).digest('hex');
const localPath = (key) => { if (!KEY_RE.test(key)) throw new HttpError(400, 'BAD_KEY', 'Invalid key'); return path.join(UPLOAD_DIR, key); };

module.exports = {
  fakeObjects,
  UPLOAD_DIR,
  publicUrl: (key) => (env.R2_DRIVER === 'local' ? `${env.API_PUBLIC_URL}/uploads/${key}` : `${env.CDN_BASE_URL}/${key}`),
  verifyLocalSignature(key, exp, sig) {
    const ok = Number(exp) > Date.now() && typeof sig === 'string' && sig.length === 64 && crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(sign(key, exp)));
    if (!ok) throw new HttpError(403, 'BAD_SIGNATURE', 'Upload link expired or invalid');
  },
  saveLocal(key, buffer) { const p = localPath(key); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, buffer); },
  /** Presigned PUT valid for 10 minutes, bound to content-type and length. */
  async presignPut({ key, contentType, size }) {
    if (env.R2_DRIVER === 'fake') return `https://fake-r2.test/${key}?sig=fake`;
    if (env.R2_DRIVER === 'local') { const exp = Date.now() + 600_000; return `${env.API_PUBLIC_URL}/v1/media/local/${key}?exp=${exp}&sig=${sign(key, exp)}`; }
    return getSignedUrl(s3(), new PutObjectCommand({ Bucket: env.R2_BUCKET, Key: key, ContentType: contentType, ContentLength: size }), { expiresIn: 600 });
  },
  async head(key) {
    if (env.R2_DRIVER === 'fake') return fakeObjects.has(key) ? { size: fakeObjects.get(key) } : null;
    if (env.R2_DRIVER === 'local') { try { return { size: fs.statSync(localPath(key)).size }; } catch { return null; } }
    try { const r = await s3().send(new HeadObjectCommand({ Bucket: env.R2_BUCKET, Key: key })); return { size: r.ContentLength }; } catch { return null; }
  },
  async remove(key) {
    if (env.R2_DRIVER === 'fake') { fakeObjects.delete(key); return; }
    if (env.R2_DRIVER === 'local') { fs.rmSync(localPath(key), { force: true }); return; }
    await s3().send(new DeleteObjectCommand({ Bucket: env.R2_BUCKET, Key: key }));
  },
};
