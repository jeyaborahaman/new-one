const db = require('../../db/knex');
const { err } = require('../../utils/errors');

async function assertMember(conversationId, userId) {
  const m = await db('conversation_members').where({ conversation_id: conversationId, user_id: userId }).first();
  if (!m) throw err.forbidden('Not a member of this conversation');
  return m;
}
const memberIds = async (conversationId) => (await db('conversation_members').where({ conversation_id: conversationId }).select('user_id')).map((r) => r.user_id);

async function openDirect(userId, otherId) {
  if (userId === otherId) throw err.badRequest('Cannot message yourself');
  if (!(await db('users').where({ id: otherId, status: 'active' }).first('id'))) throw err.notFound('User not found');
  const key = [userId, otherId].sort((a, b) => a - b).join(':');
  const existing = await db('conversations').where({ direct_key: key }).first();
  if (existing) return existing;
  try {
    return await db.transaction(async (trx) => {
      const [id] = await trx('conversations').insert({ type: 'direct', created_by: userId, direct_key: key });
      await trx('conversation_members').insert([{ conversation_id: id, user_id: userId }, { conversation_id: id, user_id: otherId }]);
      return trx('conversations').where({ id }).first();
    });
  } catch (e) { // lost a race with the other side: unique(direct_key) guarantees one DM
    const again = await db('conversations').where({ direct_key: key }).first();
    if (again) return again;
    throw e;
  }
}

async function createGroup(userId, title, members) {
  const ids = [...new Set([userId, ...members])];
  const found = await db('users').whereIn('id', ids).where({ status: 'active' }).count({ c: '*' }).first();
  if (Number(found.c) !== ids.length) throw err.badRequest('Unknown member id');
  return db.transaction(async (trx) => {
    const [id] = await trx('conversations').insert({ type: 'group', title, created_by: userId });
    await trx('conversation_members').insert(ids.map((uid) => ({ conversation_id: id, user_id: uid, role: uid === userId ? 'owner' : 'member' })));
    return trx('conversations').where({ id }).first();
  });
}

/** Exactly-once: (conversation_id, client_id) is unique, so a retried send returns the stored message. */
async function sendMessage({ conversationId, senderId, clientId, type = 'text', body, mediaId }) {
  await assertMember(conversationId, senderId);
  const existing = await db('messages').where({ conversation_id: conversationId, client_id: clientId }).first();
  if (existing) return { message: existing, created: false };
  const message = await db.transaction(async (trx) => {
    const [id] = await trx('messages').insert({ conversation_id: conversationId, sender_id: senderId, client_id: clientId, type, body, media_id: mediaId });
    await trx('conversations').where({ id: conversationId }).update({ last_message_at: new Date() });
    return trx('messages').where({ id }).first();
  });
  return { message, created: true };
}

async function markRead(conversationId, userId, upToId) {
  await assertMember(conversationId, userId);
  // never move the cursor backwards
  await db('conversation_members').where({ conversation_id: conversationId, user_id: userId }).andWhere('last_read_message_id', '<', upToId).update({ last_read_message_id: upToId });
}

module.exports = { assertMember, memberIds, openDirect, createGroup, sendMessage, markRead };
