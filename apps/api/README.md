# Jeyabo API

Node.js 22 + Express 5 + Socket.IO + Knex (MySQL 8 in production, SQLite in tests).

```bash
cp .env.example .env      # set JWT_SECRET (32+ chars) and DB_* values
npm ci
npm run migrate           # creates the schema in MySQL
npm run dev               # http://localhost:4000, GET /health
npm test                  # 11 integration tests, in-memory SQLite
```

## Implemented (v0.1)

| Area | Endpoints |
| --- | --- |
| Auth | `POST /v1/auth/register\|login\|refresh\|logout` (argon2id, 15 min JWT, rotating refresh with reuse detection) |
| Users | `GET/PATCH /v1/users/me`, `GET /v1/users/:id`, `POST/DELETE /v1/users/:id/follow` |
| Posts | `POST /v1/posts` (scheduled + visibility), `GET /v1/posts/feed`, `GET/DELETE /v1/posts/:id`, `PUT/DELETE /:id/reaction`, `GET/POST /:id/comments` (nested) |
| Chat | `GET/POST /v1/conversations`, `GET/POST /:id/messages`, `POST /:id/read`; Socket.IO `message:send`, `message:read`, `typing`, `message:new` |
| Wallet | `GET /v1/wallet`, `GET /v1/wallet/transactions`, `POST /v1/rewards/daily/claim` |
| Lucky Draw | `/v1/luckydraw/*` and `/v1/admin/luckydraw/*`; hidden (404) unless `LUCKY_DRAW_ENABLED` or the DB flag is on; verifiable seed commitment |
| Admin | ban / suspend / reinstate / verify, `PUT /v1/admin/flags/:key`, `GET /v1/admin/stats` |

## Not yet built

Phone OTP, Google/Apple login, 2FA, password reset, media uploads to R2, stories, reels/videos, groups and pages, FCM push, Agora call tokens, AI moderation/translation/search, referrals, badges/leaderboards, Redis (rate limits are in-memory; single node only), background jobs.
