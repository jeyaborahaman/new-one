const argon2 = require('argon2');
const db = require('../../db/knex');
const { err } = require('../../utils/errors');
const logger = require('../../utils/logger');

/** Recount followers/following for these users from the follows table. */
const recountFollows = (trx, ids) => ids.length && trx('users').whereIn('id', ids).update({
  followers_count: trx('follows').count('*').where('followee_id', trx.ref('users.id')),
  following_count: trx('follows').count('*').where('follower_id', trx.ref('users.id')),
});
/** Recount reactions/comments for these posts. */
const recountPosts = (trx, ids) => ids.length && trx('posts').whereIn('id', ids).update({
  reactions_count: trx('reactions').count('*').where('target_type', 'post').where('target_id', trx.ref('posts.id')),
  comments_count: trx('comments').count('*').whereNull('deleted_at').where('post_id', trx.ref('posts.id')),
});

/**
 * Self-service account deletion. The row is kept but anonymised (other people's chats and ledgers still reference
 * the id); personal data, credentials, sessions, devices and social links are removed, content is taken down,
 * and uploaded files are deleted from storage in the background.
 */
async function deleteAccount(userId, password) {
  const user = await db('users').where({ id: userId }).first();
  if (!user || user.status === 'deleted') throw err.notFound('Account not found');
  if (user.password_hash && !(password && (await argon2.verify(user.password_hash, password)))) throw err.unauthorized('Invalid credentials');

  const mediaKeys = await db.transaction(async (trx) => {
    const followRows = await trx('follows').where({ follower_id: userId }).orWhere({ followee_id: userId }).select('follower_id', 'followee_id');
    const touchedUsers = [...new Set(followRows.flatMap((f) => [f.follower_id, f.followee_id]))].filter((id) => id !== userId);
    const reacted = (await trx('reactions').where({ user_id: userId, target_type: 'post' }).select('target_id')).map((r) => r.target_id);
    const commented = (await trx('comments').where({ author_id: userId }).distinct('post_id')).map((r) => r.post_id);
    const media = await trx('media').where({ owner_id: userId }).whereNot({ status: 'deleted' }).select('r2_key');

    await trx('users').where({ id: userId }).update({
      username: `deleted_${userId}`, email: null, phone: null, password_hash: null, display_name: 'Deleted user', bio: null, country: null,
      status: 'deleted', is_verified: false, two_factor_enabled: false, two_factor_secret: null, referral_code: null,
      followers_count: 0, following_count: 0, deleted_at: new Date(),
    });
    await trx('sessions').where({ user_id: userId }).whereNull('revoked_at').update({ revoked_at: new Date() });
    for (const [table, col] of [['devices', 'user_id'], ['oauth_identities', 'user_id'], ['two_factor_backup', 'user_id'], ['notifications', 'user_id'], ['notification_prefs', 'user_id'], ['story_views', 'viewer_id'], ['reactions', 'user_id'], ['subscriptions', 'subscriber_id'], ['subscriptions', 'channel_id'], ['user_blocks', 'blocker_id'], ['user_blocks', 'blocked_id'], ['friendships', 'requester_id'], ['friendships', 'addressee_id']])
      await trx(table).where(col, userId).del();
    const targets = [user.email, user.phone].filter(Boolean);
    if (targets.length) await trx('otp_codes').whereIn('target', targets).del();
    await trx('follows').where({ follower_id: userId }).orWhere({ followee_id: userId }).del();
    const storyIds = (await trx('stories').where({ author_id: userId }).select('id')).map((s) => s.id);
    if (storyIds.length) { await trx('story_views').whereIn('story_id', storyIds).del(); await trx('reactions').where({ target_type: 'story' }).whereIn('target_id', storyIds).del(); }
    await trx('stories').where({ author_id: userId }).del();
    await trx('posts').where({ author_id: userId }).update({ status: 'removed' });
    await trx('comments').where({ author_id: userId }).whereNull('deleted_at').update({ deleted_at: new Date() });
    await trx('community_members').where({ user_id: userId }).whereNot({ role: 'owner' }).del();
    await trx('media').where({ owner_id: userId }).update({ status: 'deleted' });
    await recountFollows(trx, touchedUsers);
    await recountPosts(trx, [...new Set([...reacted, ...commented])]);
    await trx('audit_logs').insert({ actor_id: userId, action: 'user.delete_self', target: `user:${userId}` });
    return media.map((m) => m.r2_key);
  });

  require('../../realtime/bus').disconnectUser(userId);
  // Storage cleanup never blocks or fails the request; failures are logged for a manual sweep.
  const r2 = require('../../integrations/r2');
  setImmediate(async () => {
    for (const key of mediaKeys) await r2.remove(key).catch((e) => logger.error({ err: e, key }, 'media delete failed'));
  });
}
module.exports = { deleteAccount };
