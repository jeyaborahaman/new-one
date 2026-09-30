# Jeyabo app (Flutter: Android, iOS, Web)

Material 3, light/dark themes built from the design-system tokens, Riverpod state, go_router navigation, Dio networking with automatic token refresh, and a Socket.IO connection for live chat.

```bash
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:4000      # local backend
flutter test && flutter analyze                                         # 18 tests, no analyzer issues
flutter build web --release --dart-define=API_URL=https://api.jeyabo.com   # production web (serve build/web with Nginx)
flutter build appbundle --dart-define=API_URL=https://api.jeyabo.com       # Android (needs the Android SDK)
```

Do not pass `--no-web-resources-cdn` for production web builds: without the CDN the emoji font is missing and reaction emoji render as boxes.

## What works (verified in a real browser against the real API)

Photo and video posts, short reels and 24-hour stories (pick, upload with progress, view, react, see who viewed); sign in, register, phone OTP, forgot password, 2FA challenge; feed with infinite scroll, pull to refresh, story tray, polls, hashtags and mentions, five reactions (long-press), nested comments; text/poll composer with visibility and scheduling; reels player with trending tab; chat list with unread badges, live chat with typing indicator and exactly-once send (falls back to REST when the socket is down); search and friend suggestions; profile, follow, edit profile; wallet, daily reward, badges, challenges, leaderboard, referral code, notifications; Lucky Draw (only shown when the server enables it); light/dark/auto theme; responsive navigation rail on wide screens.

## Push notifications (Firebase project `call-1c522`)

The app registers its device token with the API after sign-in, removes it on sign-out, opens the right chat when a notification is tapped, and shows a banner for pushes that arrive while it is open. It silently does nothing when push is unavailable, denied, or not configured.

| Platform | Status | What is still needed |
| --- | --- | --- |
| Android | Wired (`google-services.json`, Gradle plugin). Not built or tested here (no Android SDK). | Build once and send a test message from the Firebase console |
| Web | Wired (service worker, config) but off until you set the key | Firebase console > Cloud Messaging > Web Push certificates > Generate key pair, then build with `--dart-define=FIREBASE_VAPID_KEY=<key>` |
| iOS | Not wired | `GoogleService-Info.plist` and an APNs key from your Apple developer account |
| Server | Sends via FCM once configured | Service account JSON in `FCM_SERVICE_ACCOUNT` on the API server (Project settings > Service accounts). This one is a real secret: never commit or paste it. |

## Not built yet

- Camera capture on web (gallery only there); video upload was verified by unit and API tests, not in a browser (the test browser has no video codecs).
- Audio/video calls (needs the Agora SDK and platform setup), voice notes, group creation UI, communities/pages screens.
- Google and Apple sign-in buttons (API is ready; needs your OAuth client IDs).
- Android/iOS builds were not run here (no Android SDK or Xcode in this environment); only web was built and tested.
