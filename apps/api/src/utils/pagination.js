/** Keyset pagination on an auto-increment id, newest first. cursor = last id seen. */
const { z } = require('zod');
const pageQuery = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.coerce.number().int().positive().optional(),
});
function page(rows, limit) {
  const data = rows.slice(0, limit);
  return { data, next_cursor: rows.length > limit ? data[data.length - 1].id : null };
}
module.exports = { pageQuery, page };
