const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { api, db, setup, teardown, signup, setRole } = require('./helpers');
const { applyCoins } = require('../src/modules/wallet/service');

before(setup); after(teardown);

test('daily reward once per day; ledger and idempotency; no overdraft', async () => {
  const u = await signup();
  const r = await api().post('/v1/rewards/daily/claim').set(u.auth).expect(200);
  assert.deepEqual([r.body.streak, r.body.coins, r.body.balance], [1, 10, 10]);
  await api().post('/v1/rewards/daily/claim').set(u.auth).expect(409);
  assert.equal((await api().get('/v1/wallet').set(u.auth)).body.balance, 10);

  await applyCoins(u.id, 5, 'bonus', { idempotencyKey: 'k1' });
  const again = await applyCoins(u.id, 5, 'bonus', { idempotencyKey: 'k1' });
  assert.equal(again.replayed, true);
  assert.equal((await api().get('/v1/wallet').set(u.auth)).body.balance, 15);
  await assert.rejects(applyCoins(u.id, -100, 'spend'), /Insufficient/);
  const tx = await api().get('/v1/wallet/transactions').set(u.auth).expect(200);
  assert.equal(tx.body.data.length, 2);
});

test('lucky draw is invisible when disabled, works when enabled', async () => {
  const admin = await signup({ username: 'boss' }); const p1 = await signup({ country: 'us' }); const p2 = await signup({ country: 'us' }); const p3 = await signup({ country: 'de' });
  await setRole(admin.id, 'superadmin');
  await api().get('/v1/luckydraw/campaigns').set(p1.auth).expect(404); // env default: disabled
  await api().put('/v1/admin/flags/LUCKY_DRAW_ENABLED').set(admin.auth).send({ enabled: true }).expect(200);

  const c = await api().post('/v1/admin/luckydraw/campaigns').set(admin.auth).send({ title: 'Summer', allowed_countries: ['US'], winners_count: 1, max_entries_per_user: 2, coins_per_entry: 5 }).expect(201);
  const id = c.body.id;
  await api().post(`/v1/luckydraw/campaigns/${id}/join`).set(p1.auth).expect(400); // still draft
  const opened = await api().post(`/v1/admin/luckydraw/campaigns/${id}/open`).set(admin.auth).expect(200);
  assert.equal(opened.body.seed_hash.length, 64);
  assert.equal(opened.body.seed_secret, undefined);

  await api().post(`/v1/luckydraw/campaigns/${id}/join`).set(p3.auth).expect(404); // region blocked
  await api().post(`/v1/luckydraw/campaigns/${id}/join`).set(p1.auth).expect(400); // no coins
  await applyCoins(p1.id, 20, 'bonus'); await applyCoins(p2.id, 20, 'bonus');
  await api().post(`/v1/luckydraw/campaigns/${id}/join`).set(p1.auth).expect(201);
  await api().post(`/v1/luckydraw/campaigns/${id}/join`).set(p1.auth).expect(201);
  await api().post(`/v1/luckydraw/campaigns/${id}/join`).set(p1.auth).expect(409); // limit
  await api().post(`/v1/luckydraw/campaigns/${id}/join`).set(p2.auth).expect(201);
  assert.equal((await api().get('/v1/wallet').set(p1.auth)).body.balance, 10);

  await api().post(`/v1/admin/luckydraw/campaigns/${id}/draw`).set(p1.auth).expect(403);
  const d = await api().post(`/v1/admin/luckydraw/campaigns/${id}/draw`).set(admin.auth).expect(200);
  assert.deepEqual([d.body.winners, d.body.entries], [1, 3]);
  await api().post(`/v1/admin/luckydraw/campaigns/${id}/draw`).set(admin.auth).expect(409);
  await api().get(`/v1/luckydraw/campaigns/${id}/results`).set(p1.auth).expect(404); // not yet published
  await api().post(`/v1/admin/luckydraw/campaigns/${id}/publish`).set(admin.auth).expect(200);
  const res = await api().get(`/v1/luckydraw/campaigns/${id}/results`).set(p1.auth).expect(200);
  const crypto = require('crypto');
  assert.equal(crypto.createHash('sha256').update(res.body.seed).digest('hex'), res.body.seed_hash); // verifiable

  await api().put('/v1/admin/flags/LUCKY_DRAW_ENABLED').set(admin.auth).send({ enabled: false }).expect(200);
  await api().get('/v1/luckydraw/campaigns').set(p1.auth).expect(404);
});
