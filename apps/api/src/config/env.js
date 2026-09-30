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
  REDIS_URL: z.string().optional(),
  ENCRYPTION_KEY: z.string().optional(), // 32+ chars; falls back to JWT_SECRET
  APP_NAME: z.string().default('Jeyabo'),
  R2_DRIVER: z.enum(['r2', 'fake', 'local']).default('r2'), // 'local' stores files on this server's disk: development only
  API_PUBLIC_URL: z.string().default('http://localhost:4000'), // used to build URLs for the local driver
  R2_ACCOUNT_ID: z.string().optional(), R2_ACCESS_KEY: z.string().optional(), R2_SECRET: z.string().optional(),
  R2_BUCKET: z.string().default('jeyabo-media'),
  CDN_BASE_URL: z.string().default('https://cdn.jeyabo.example'),
  FCM_SERVICE_ACCOUNT: z.string().optional(), // JSON string; unset = push is logged only
  AGORA_APP_ID: z.string().optional(), AGORA_CERT: z.string().optional(),
  GOOGLE_CLIENT_ID: z.string().optional(), APPLE_CLIENT_ID: z.string().optional(),
  SMS_DRIVER: z.enum(['console', 'memory']).default('console'),
  AI_PROVIDER: z.enum(['none', 'anthropic']).default('none'),
  ANTHROPIC_API_KEY: z.string().optional(),
  AI_MODEL: z.string().default('claude-haiku-4-5-20251001'),
  LUCKY_DRAW_REGIONS: z.string().default('').transform((v) => v.split(',').map((s) => s.trim().toUpperCase()).filter(Boolean)),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid environment:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}
if (parsed.data.NODE_ENV === 'production' && parsed.data.R2_DRIVER !== 'r2') {
  console.error('R2_DRIVER must be "r2" in production');
  process.exit(1);
}
module.exports = parsed.data;
