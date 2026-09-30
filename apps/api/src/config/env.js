require('dotenv').config();
const { z } = require('zod');

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(4000),
  DB_CLIENT: z.enum(['mysql2', 'better-sqlite3']).default('mysql2'),
  DB_HOST: z.string().default('127.0.0.1'),
  DB_PORT: z.coerce.number().default(3306),
  DB_USER: z.string().default('jeyabo'),
  DB_PASSWORD: z.string().default(''),
  DB_NAME: z.string().default('jeyabo'),
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters'),
  ACCESS_TTL: z.string().default('15m'),
  REFRESH_TTL_DAYS: z.coerce.number().default(30),
  CORS_ORIGINS: z.string().default(''),
  LUCKY_DRAW_ENABLED: z.string().default('false').transform((v) => v === 'true'),
  LUCKY_DRAW_REGIONS: z.string().default('').transform((v) => v.split(',').map((s) => s.trim().toUpperCase()).filter(Boolean)),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid environment:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}
module.exports = parsed.data;
