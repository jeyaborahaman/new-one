// Admin moderation panel: review state, outcome notes and timing on reports; audit lookups by target/actor.
// Report status gains 'reviewing' (fits the existing string(10) column): open -> reviewing -> actioned|dismissed.
exports.up = async (knex) => {
  await knex.schema.alterTable('reports', (t) => {
    t.bigInteger('reviewer_id').unsigned();
    t.string('resolution', 30); // what was done: content_removed, user_suspended, user_banned, no_violation…
    t.text('note');
    t.timestamp('handled_at');
    t.index(['target_type', 'target_id']);
  });
  await knex.schema.alterTable('audit_logs', (t) => { t.index('target'); t.index('actor_id'); });
};

exports.down = async (knex) => {
  await knex.schema.alterTable('audit_logs', (t) => { t.dropIndex('target'); t.dropIndex('actor_id'); });
  await knex.schema.alterTable('reports', (t) => {
    t.dropIndex(['target_type', 'target_id']);
    t.dropColumn('reviewer_id'); t.dropColumn('resolution'); t.dropColumn('note'); t.dropColumn('handled_at');
  });
};
