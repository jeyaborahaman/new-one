// SQLite (tests) would store CURRENT_TIMESTAMP as text, which cannot be compared with JS Dates
// (bound as epoch ms). Use epoch-ms defaults there; MySQL keeps native timestamps.
const NOW = (knex) => (knex.client.config.client === 'better-sqlite3' ? knex.raw("(cast(strftime('%s','now') as integer) * 1000)") : knex.fn.now());

exports.up = async (knex) => {
  const ts = (t) => t.timestamp('created_at').defaultTo(NOW(knex));

  await knex.schema.alterTable('users', (t) => {
    t.boolean('two_factor_enabled').notNullable().defaultTo(false);
    t.text('two_factor_secret'); // AES-256-GCM encrypted
    t.string('referral_code', 12).unique();
    t.string('locale', 10).defaultTo('en');
  });
  await knex.schema.alterTable('posts', (t) => {
    t.bigInteger('community_id').unsigned().index();
    t.bigInteger('media_id').unsigned();
  });

  await knex.schema.createTable('otp_codes', (t) => {
    t.bigIncrements('id');
    t.string('target', 255).notNullable();
    t.string('purpose', 20).notNullable(); // login|reset
    t.string('code_hash', 64).notNullable();
    t.integer('attempts').notNullable().defaultTo(0);
    t.timestamp('expires_at').notNullable();
    t.timestamp('consumed_at');
    ts(t);
    t.index(['target', 'purpose']);
  });
  await knex.schema.createTable('oauth_identities', (t) => {
    t.string('provider', 10).notNullable();
    t.string('provider_uid', 255).notNullable();
    t.bigInteger('user_id').unsigned().notNullable().index();
    t.primary(['provider', 'provider_uid']);
  });
  await knex.schema.createTable('two_factor_backup', (t) => {
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('code_hash', 64).notNullable();
    t.timestamp('used_at');
    t.primary(['user_id', 'code_hash']);
  });

  await knex.schema.createTable('media', (t) => {
    t.bigIncrements('id');
    t.bigInteger('owner_id').unsigned().notNullable().index();
    t.string('kind', 10).notNullable(); // image|video|audio|file
    t.string('r2_key', 500).notNullable().unique();
    t.string('mime', 100).notNullable();
    t.bigInteger('size_bytes').notNullable();
    t.string('status', 12).notNullable().defaultTo('uploading'); // uploading|ready|rejected
    ts(t);
  });

  await knex.schema.createTable('stories', (t) => {
    t.bigIncrements('id');
    t.bigInteger('author_id').unsigned().notNullable();
    t.bigInteger('media_id').unsigned().notNullable();
    t.string('caption', 200);
    t.timestamp('expires_at').notNullable();
    ts(t);
    t.index(['author_id', 'expires_at']);
    t.index('expires_at');
  });
  await knex.schema.createTable('story_views', (t) => {
    t.bigInteger('story_id').unsigned().notNullable();
    t.bigInteger('viewer_id').unsigned().notNullable();
    t.timestamp('viewed_at').defaultTo(NOW(knex));
    t.primary(['story_id', 'viewer_id']);
  });

  await knex.schema.createTable('video_categories', (t) => {
    t.increments('id');
    t.string('slug', 50).notNullable().unique();
    t.string('name', 80).notNullable();
  });
  await knex('video_categories').insert(['Music', 'Gaming', 'News', 'Sports', 'Education', 'Comedy', 'Travel', 'Food', 'Tech'].map((n) => ({ slug: n.toLowerCase(), name: n })));
  await knex.schema.createTable('videos', (t) => {
    t.bigInteger('post_id').unsigned().primary();
    t.string('title', 150);
    t.integer('category_id').unsigned();
    t.boolean('is_short').notNullable().defaultTo(false);
    t.text('effects'); // JSON
    t.bigInteger('views_count').notNullable().defaultTo(0);
    t.index(['category_id', 'is_short']);
  });
  await knex.schema.createTable('playlists', (t) => {
    t.bigIncrements('id');
    t.bigInteger('owner_id').unsigned().notNullable().index();
    t.string('title', 100).notNullable();
    t.boolean('is_public').notNullable().defaultTo(true);
  });
  await knex.schema.createTable('playlist_items', (t) => {
    t.bigInteger('playlist_id').unsigned().notNullable();
    t.bigInteger('post_id').unsigned().notNullable();
    t.integer('position').notNullable().defaultTo(0);
    t.primary(['playlist_id', 'post_id']);
  });
  await knex.schema.createTable('subscriptions', (t) => {
    t.bigInteger('subscriber_id').unsigned().notNullable();
    t.bigInteger('channel_id').unsigned().notNullable();
    ts(t);
    t.primary(['subscriber_id', 'channel_id']);
    t.index('channel_id');
  });

  await knex.schema.createTable('communities', (t) => {
    t.bigIncrements('id');
    t.string('kind', 10).notNullable(); // group|page
    t.string('page_type', 12); // business|community|creator
    t.string('privacy', 10).notNullable().defaultTo('public');
    t.string('name', 100).notNullable();
    t.text('description');
    t.integer('members_count').notNullable().defaultTo(0);
    t.bigInteger('owner_id').unsigned().notNullable();
    ts(t);
  });
  await knex.schema.createTable('community_members', (t) => {
    t.bigInteger('community_id').unsigned().notNullable();
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('role', 12).notNullable().defaultTo('member'); // owner|admin|moderator|member
    t.string('status', 10).notNullable().defaultTo('active'); // active|pending|banned
    ts(t);
    t.primary(['community_id', 'user_id']);
    t.index('user_id');
  });

  await knex.schema.createTable('hashtags', (t) => {
    t.bigIncrements('id');
    t.string('tag', 60).notNullable().unique();
    t.bigInteger('uses').notNullable().defaultTo(0);
  });
  await knex.schema.createTable('post_hashtags', (t) => {
    t.bigInteger('post_id').unsigned().notNullable();
    t.bigInteger('hashtag_id').unsigned().notNullable();
    t.primary(['hashtag_id', 'post_id']);
  });

  await knex.schema.createTable('poll_options', (t) => {
    t.bigIncrements('id');
    t.bigInteger('post_id').unsigned().notNullable().index();
    t.string('label', 120).notNullable();
    t.integer('votes_count').notNullable().defaultTo(0);
  });
  await knex.schema.createTable('poll_votes', (t) => {
    t.bigInteger('post_id').unsigned().notNullable();
    t.bigInteger('user_id').unsigned().notNullable();
    t.bigInteger('option_id').unsigned().notNullable();
    t.primary(['post_id', 'user_id']);
  });

  await knex.schema.createTable('friendships', (t) => {
    t.bigInteger('requester_id').unsigned().notNullable();
    t.bigInteger('addressee_id').unsigned().notNullable();
    t.string('status', 10).notNullable().defaultTo('pending'); // pending|accepted
    ts(t);
    t.primary(['requester_id', 'addressee_id']);
    t.index('addressee_id');
  });

  await knex.schema.createTable('notifications', (t) => {
    t.bigIncrements('id');
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('type', 20).notNullable();
    t.text('payload');
    t.timestamp('read_at');
    ts(t);
    t.index(['user_id', 'id']);
  });
  await knex.schema.createTable('notification_prefs', (t) => {
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('type', 20).notNullable();
    t.boolean('push').notNullable().defaultTo(true);
    t.primary(['user_id', 'type']);
  });
  await knex.schema.createTable('devices', (t) => {
    t.bigIncrements('id');
    t.bigInteger('user_id').unsigned().notNullable().index();
    t.string('token', 400).notNullable().unique();
    t.string('platform', 10).notNullable();
    ts(t);
  });

  await knex.schema.createTable('call_sessions', (t) => {
    t.string('id', 36).primary();
    t.bigInteger('conversation_id').unsigned().notNullable();
    t.bigInteger('initiator_id').unsigned().notNullable();
    t.string('kind', 6).notNullable(); // audio|video
    t.boolean('is_group').notNullable().defaultTo(false);
    t.string('status', 10).notNullable().defaultTo('ringing'); // ringing|active|ended|missed|declined
    t.timestamp('started_at');
    t.timestamp('ended_at');
    ts(t);
  });

  await knex.schema.createTable('xp_events', (t) => {
    t.bigIncrements('id');
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('action', 40).notNullable();
    t.integer('xp').notNullable();
    ts(t);
    t.index(['user_id', 'created_at']);
    t.index('created_at');
  });
  await knex.schema.createTable('badges', (t) => {
    t.increments('id');
    t.string('code', 40).notNullable().unique();
    t.string('name', 80).notNullable();
    t.string('description', 200);
  });
  await knex.schema.createTable('user_badges', (t) => {
    t.bigInteger('user_id').unsigned().notNullable();
    t.integer('badge_id').unsigned().notNullable();
    ts(t);
    t.primary(['user_id', 'badge_id']);
  });
  await knex.schema.createTable('challenges', (t) => {
    t.bigIncrements('id');
    t.string('scope', 10).notNullable().defaultTo('weekly'); // weekly|community
    t.string('title', 120).notNullable();
    t.string('metric', 20).notNullable(); // post|comment|reaction|xp
    t.integer('target').notNullable();
    t.integer('reward_coins').notNullable();
    t.timestamp('starts_at').notNullable();
    t.timestamp('ends_at').notNullable();
  });
  await knex.schema.createTable('challenge_progress', (t) => {
    t.bigInteger('challenge_id').unsigned().notNullable();
    t.bigInteger('user_id').unsigned().notNullable();
    t.timestamp('joined_at').defaultTo(NOW(knex));
    t.timestamp('claimed_at');
    t.primary(['challenge_id', 'user_id']);
  });
  await knex.schema.createTable('referrals', (t) => {
    t.bigIncrements('id');
    t.bigInteger('referrer_id').unsigned().notNullable().index();
    t.bigInteger('referred_id').unsigned().notNullable().unique();
    t.integer('bonus_coins').notNullable();
    ts(t);
  });
  await knex.schema.createTable('reports', (t) => {
    t.bigIncrements('id');
    t.bigInteger('reporter_id').unsigned().notNullable();
    t.string('target_type', 20).notNullable();
    t.bigInteger('target_id').unsigned().notNullable();
    t.string('reason', 40).notNullable();
    t.text('details');
    t.string('status', 10).notNullable().defaultTo('open'); // open|actioned|dismissed
    t.bigInteger('handled_by').unsigned();
    ts(t);
    t.index('status');
  });
  await knex.schema.alterTable('posts', (t) => { t.decimal('moderation_score', 4, 3); t.timestamp('poll_closes_at'); });
};

exports.down = async (knex) => {
  for (const t of ['poll_votes','poll_options','reports','referrals','challenge_progress','challenges','user_badges','badges','xp_events','call_sessions','devices','notification_prefs','notifications','friendships','post_hashtags','hashtags','community_members','communities','subscriptions','playlist_items','playlists','videos','video_categories','story_views','stories','media','two_factor_backup','oauth_identities','otp_codes'])
    await knex.schema.dropTableIfExists(t);
};
