// Own process with production settings: one-time codes must never reach the logs.
process.env.NODE_ENV = 'production';
process.env.JWT_SECRET = 'test-secret-test-secret-test-secret-123';
process.env.ENCRYPTION_KEY = 'separate-encryption-key-separate-key-1';
process.env.R2_DRIVER = 'r2';
process.env.SMS_DRIVER = 'console';
process.env.MAIL_DRIVER = 'console';
process.env.LOG_LEVEL = 'silent';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const logger = require('../src/utils/logger');
const sms = require('../src/integrations/sms');
const mailer = require('../src/integrations/mailer');

test('console SMS/mail drivers never log codes or full addresses in production', async () => {
  const lines = [];
  for (const level of ['info', 'warn', 'error']) logger[level] = (...args) => lines.push(JSON.stringify(args));
  await sms.send('+14155550123', 'Jeyabo code: 482913. Valid 5 minutes.');
  await mailer.send('someone@example.com', 'Jeyabo password reset', 'Your reset code is 771204. It expires in 5 minutes.');
  const all = lines.join('\n');
  assert.equal(lines.length, 2); // still reported, so operators see delivery is not configured
  for (const secret of ['482913', '771204', '+14155550123', 'someone@example.com']) assert.ok(!all.includes(secret), `leaked ${secret}`);
  assert.ok(all.includes('0123')); // masked target keeps the last digits for support
});
