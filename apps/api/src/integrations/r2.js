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

module.exports = {
  fakeObjects,
  publicUrl: (key) => `${env.CDN_BASE_URL}/${key}`,
  /** Presigned PUT valid for 10 minutes, bound to content-type and length. */
  async presignPut({ key, contentType, size }) {
    if (env.R2_DRIVER === 'fake') return `https://fake-r2.test/${key}?sig=fake`;
    return getSignedUrl(s3(), new PutObjectCommand({ Bucket: env.R2_BUCKET, Key: key, ContentType: contentType, ContentLength: size }), { expiresIn: 600 });
  },
  async head(key) {
    if (env.R2_DRIVER === 'fake') return fakeObjects.has(key) ? { size: fakeObjects.get(key) } : null;
    try { const r = await s3().send(new HeadObjectCommand({ Bucket: env.R2_BUCKET, Key: key })); return { size: r.ContentLength }; } catch { return null; }
  },
  async remove(key) {
    if (env.R2_DRIVER === 'fake') { fakeObjects.delete(key); return; }
    await s3().send(new DeleteObjectCommand({ Bucket: env.R2_BUCKET, Key: key }));
  },
};
