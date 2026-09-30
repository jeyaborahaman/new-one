# Jeyabo API

Node.js 22 + Express 5 + Socket.IO + Knex (MySQL 8 in production, SQLite in tests).

```bash
cp .env.example .env      # set JWT_SECRET (32+ chars) and DB_* values
npm ci
npm run migrate           # creates the schema in MySQL
npm run dev               # http://localhost:4000, GET /health
npm test                  # 11 integration tests, in-memory SQLite
```

## Implemented

| Area | What it does |
| --- | --- |
| Auth | Email/password, phone OTP (5 min, 5 attempts, 3/hour), Google + Apple ID-token login, password reset by emailed code, TOTP 2FA with encrypted secret and 10 single-use backup codes (enforced on every login path), rotating refresh tokens with reuse detection, device session list/revoke |
| Users | Profile, follow/unfollow, friend requests (accepting makes both follow each other), friend suggestions from the follow graph |
| Posts | Text/image/video/poll posts, visibility, scheduling, hashtags, @mentions (notified), keyset feed, 5 reactions, nested comments, poll voting, AI/rule moderation (422 on violation) |
| Media | Presigned direct-to-R2 uploads (type + size allow-list, size verified on completion, ownership enforced) |
| Stories | 24h lifetime, tray with seen state, views, viewer list (author only), reactions, expiry job |
| Videos | Reels feed + trending, long videos with categories, subscriptions + feed, playlists, view counts, recommendations |
| Communities | Public/private groups, pages (business/community/creator), join approval, owner/admin/moderator roles, bans, page staff-only posting, private content never leaks into global feeds |
| Chat | Direct + group chat, exactly-once sends, read cursors, group admin controls (rename/add/remove/roles), Socket.IO live delivery, offline push |
| Calls | Agora RTC tokens, ring/join/decline/end, group calls, call history, missed-call job, `call:incoming` socket event + push |
| Notifications | Inbox, live socket event, FCM push with per-type preferences, dead-token cleanup |
| Engagement | XP + levels, badges, referral codes (+bonus coins, also at signup), weekly/community challenges, leaderboards |
| Wallet | Atomic coin ledger with idempotency keys, daily reward streaks |
| Lucky Draw | Hidden (404) unless enabled; region gating; commit/reveal seed; admin create/open/draw/publish/analytics |
| Admin | Ban/suspend/reinstate/verify, reports queue (remove/dismiss), feature flags, analytics, audit log |
| Search / AI | Smart search (@user, #tag, text; wildcard-safe), trending hashtags, translation via Claude when `AI_PROVIDER=anthropic` |
| Infra | Redis-backed rate limits, Socket.IO Redis adapter, BullMQ scheduled jobs (in-process timers when Redis is absent) |

## Needs your credentials before it works for real

| Feature | Set |
| --- | --- |
| Media uploads | `R2_ACCOUNT_ID`, `R2_ACCESS_KEY`, `R2_SECRET`, `R2_BUCKET`, `CDN_BASE_URL` |
| Push | `FCM_SERVICE_ACCOUNT` (JSON) |
| Calls | `AGORA_APP_ID`, `AGORA_CERT` |
| Social login | `GOOGLE_CLIENT_ID`, `APPLE_CLIENT_ID` |
| SMS / email | replace the console drivers in `src/integrations/sms.js` and `mailer.js` with your provider |
| AI translation / moderation | `AI_PROVIDER=anthropic`, `ANTHROPIC_API_KEY` |

## Local development without R2

Set `R2_DRIVER=local` and `API_PUBLIC_URL=http://localhost:4000`: uploads are stored in `apps/api/.uploads` and served from `/uploads`, using the same presigned-URL flow the app uses in production. The server refuses to start with this driver when `NODE_ENV=production`.

## Known gaps

- Tested on SQLite only; run `npm run migrate` against a real MySQL 8 before relying on it.
- No video transcoding (ffmpeg/HLS renditions), thumbnails or image/video moderation: media is served as uploaded. "Video effects" are stored as metadata for the client to apply.
- Moderation checks text only (rule list, plus the model when configured).
- End-to-end encrypted chat and screen sharing are client-side concerns and not part of this API.
