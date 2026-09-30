/** Portable schema (MySQL 8 in production, SQLite in tests). Mirrors the design-system blueprint. */
// SQLite (tests) would store CURRENT_TIMESTAMP as text, which cannot be compared with JS Dates
// (bound as epoch ms). Use epoch-ms defaults there; MySQL keeps native timestamps.
const NOW = (knex) => (knex.client.config.client === 'better-sqlite3' ? knex.raw("(cast(strftime('%s','now') as integer) * 1000)") : knex.fn.now());

exports.up = async (knex) => {
  const ts = (t) => t.timestamp('created_at').defaultTo(NOW(knex));

  await knex.schema.createTable('users', (t) => {
    t.bigIncrements('id');
    t.string('username', 30).notNullable().unique();
    t.string('email', 255).unique();
    t.string('phone', 20).unique();
    t.string('password_hash', 255);
    t.string('display_name', 80).notNullable();
    t.string('bio', 300);
    t.string('role', 20).notNullable().defaultTo('user'); // user|moderator|admin|superadmin
    t.string('status', 20).notNullable().defaultTo('active'); // active|suspended|banned|deleted
    t.boolean('is_verified').notNullable().defaultTo(false);
    t.integer('level').notNullable().defaultTo(1);
    t.bigInteger('xp').notNullable().defaultTo(0);
    t.integer('followers_count').notNullable().defaultTo(0);
    t.integer('following_count').notNullable().defaultTo(0);
    t.string('country', 2);
    ts(t);
    t.index('status');
  });

  await knex.schema.createTable('sessions', (t) => {
    t.string('id', 36).primary();
    t.bigInteger('user_id').unsigned().notNullable().index();
    t.string('family_id', 36).notNullable().index();
    t.string('refresh_hash', 64).notNullable().unique();
    t.string('device_name', 100);
    t.timestamp('expires_at').notNullable();
    t.timestamp('revoked_at');
    ts(t);
  });

  await knex.schema.createTable('follows', (t) => {
    t.bigInteger('follower_id').unsigned().notNullable();
    t.bigInteger('followee_id').unsigned().notNullable();
    ts(t);
    t.primary(['follower_id', 'followee_id']);
    t.index('followee_id');
  });

  await knex.schema.createTable('posts', (t) => {
    t.bigIncrements('id');
    t.bigInteger('author_id').unsigned().notNullable();
    t.string('type', 20).notNullable().defaultTo('text'); // text|image|video|poll|reel|long_video
    t.text('body');
    t.string('visibility', 20).notNullable().defaultTo('public');
    t.string('status', 20).notNullable().defaultTo('published'); // scheduled|published|removed
    t.timestamp('publish_at');
    t.integer('reactions_count').notNullable().defaultTo(0);
    t.integer('comments_count').notNullable().defaultTo(0);
    ts(t);
    t.index(['author_id', 'id']);
    t.index(['status', 'publish_at']);
  });

  await knex.schema.createTable('reactions', (t) => {
    t.string('target_type', 20).notNullable();
    t.bigInteger('target_id').unsigned().notNullable();
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('kind', 10).notNullable(); // like|love|wow|laugh|sad
    ts(t);
    t.primary(['target_type', 'target_id', 'user_id']);
  });

  await knex.schema.createTable('comments', (t) => {
    t.bigIncrements('id');
    t.bigInteger('post_id').unsigned().notNullable();
    t.bigInteger('parent_id').unsigned();
    t.bigInteger('author_id').unsigned().notNullable();
    t.text('body').notNullable();
    t.string('gif_url', 500);
    t.integer('depth').notNullable().defaultTo(0);
    t.timestamp('deleted_at');
    ts(t);
    t.index(['post_id', 'parent_id', 'id']);
  });

  await knex.schema.createTable('conversations', (t) => {
    t.bigIncrements('id');
    t.string('type', 10).notNullable(); // direct|group
    t.string('title', 100);
    t.bigInteger('created_by').unsigned().notNullable();
    t.string('direct_key', 50).unique(); // "minId:maxId" prevents duplicate DMs
    t.timestamp('last_message_at');
    ts(t);
    t.index('last_message_at');
  });

  await knex.schema.createTable('conversation_members', (t) => {
    t.bigInteger('conversation_id').unsigned().notNullable();
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('role', 10).notNullable().defaultTo('member'); // owner|admin|member
    t.bigInteger('last_read_message_id').unsigned().notNullable().defaultTo(0);
    ts(t);
    t.primary(['conversation_id', 'user_id']);
    t.index('user_id');
  });

  await knex.schema.createTable('messages', (t) => {
    t.bigIncrements('id');
    t.bigInteger('conversation_id').unsigned().notNullable();
    t.bigInteger('sender_id').unsigned().notNullable();
    t.string('client_id', 36).notNullable();
    t.string('type', 10).notNullable().defaultTo('text');
    t.text('body');
    t.bigInteger('media_id').unsigned();
    t.timestamp('deleted_at');
    ts(t);
    t.unique(['conversation_id', 'client_id']);
    t.index(['conversation_id', 'id']);
  });

  await knex.schema.createTable('wallets', (t) => {
    t.bigInteger('user_id').unsigned().primary();
    t.bigInteger('balance').notNullable().defaultTo(0);
  });

  await knex.schema.createTable('wallet_transactions', (t) => {
    t.bigIncrements('id');
    t.bigInteger('user_id').unsigned().notNullable();
    t.bigInteger('amount').notNullable();
    t.bigInteger('balance_after').notNullable();
    t.string('reason', 20).notNullable();
    t.string('ref_type', 30);
    t.bigInteger('ref_id').unsigned();
    t.string('idempotency_key', 80).unique();
    ts(t);
    t.index(['user_id', 'id']);
  });

  await knex.schema.createTable('daily_rewards', (t) => {
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('day', 10).notNullable(); // YYYY-MM-DD (UTC)
    t.integer('streak').notNullable();
    t.integer('coins').notNullable();
    t.primary(['user_id', 'day']);
  });

  await knex.schema.createTable('feature_flags', (t) => {
    t.string('k', 50).primary();
    t.boolean('enabled').notNullable().defaultTo(false);
    t.text('config');
  });

  await knex.schema.createTable('lucky_campaigns', (t) => {
    t.bigIncrements('id');
    t.string('title', 150).notNullable();
    t.text('description');
    t.string('status', 20).notNullable().defaultTo('draft'); // draft|open|closed|published|cancelled
    t.integer('coins_per_entry').notNullable().defaultTo(0);
    t.integer('max_entries_per_user').notNullable().defaultTo(1);
    t.text('allowed_countries'); // JSON array, empty = all
    t.text('disclaimer');
    t.integer('winners_count').notNullable().defaultTo(1);
    t.timestamp('starts_at');
    t.timestamp('ends_at');
    t.string('seed_hash', 64); // sha256(seed_secret), published when the campaign opens
    t.string('seed_secret', 64); // never returned by the API until results are published
    t.bigInteger('created_by').unsigned();
    ts(t);
  });

  await knex.schema.createTable('lucky_entries', (t) => {
    t.bigIncrements('id');
    t.bigInteger('campaign_id').unsigned().notNullable();
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('source', 40).notNullable();
    ts(t);
    t.index(['campaign_id', 'user_id']);
  });

  await knex.schema.createTable('lucky_results', (t) => {
    t.bigInteger('campaign_id').unsigned().notNullable();
    t.integer('rank_no').notNullable();
    t.bigInteger('entry_id').unsigned().notNullable();
    t.bigInteger('user_id').unsigned().notNullable();
    t.string('seed', 64).notNullable();
    t.timestamp('published_at');
    t.primary(['campaign_id', 'rank_no']);
  });

  await knex.schema.createTable('audit_logs', (t) => {
    t.bigIncrements('id');
    t.bigInteger('actor_id').unsigned();
    t.string('action', 60).notNullable();
    t.string('target', 80);
    t.text('meta');
    ts(t);
  });
};

exports.down = async (knex) => {
  for (const t of ['audit_logs','lucky_results','lucky_entries','lucky_campaigns','feature_flags','daily_rewards','wallet_transactions','wallets','messages','conversation_members','conversations','comments','reactions','posts','follows','sessions','users'])
    await knex.schema.dropTableIfExists(t);
};
