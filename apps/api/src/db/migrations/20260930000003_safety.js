// SQLite (tests) would store CURRENT_TIMESTAMP as text, which cannot be compared with JS Dates
// (bound as epoch ms). Use epoch-ms defaults there; MySQL keeps native timestamps.
const NOW = (knex) => (knex.client.config.client === 'better-sqlite3' ? knex.raw("(cast(strftime('%s','now') as integer) * 1000)") : knex.fn.now());

exports.up = async (knex) => {
  await knex.schema.createTable('user_blocks', (t) => {
    t.bigInteger('blocker_id').unsigned().notNullable();
    t.bigInteger('blocked_id').unsigned().notNullable();
    t.timestamp('created_at').defaultTo(NOW(knex));
    t.primary(['blocker_id', 'blocked_id']);
    t.index('blocked_id');
  });
  await knex.schema.alterTable('users', (t) => { t.timestamp('deleted_at'); });
};

exports.down = async (knex) => {
  await knex.schema.alterTable('users', (t) => { t.dropColumn('deleted_at'); });
  await knex.schema.dropTableIfExists('user_blocks');
};
