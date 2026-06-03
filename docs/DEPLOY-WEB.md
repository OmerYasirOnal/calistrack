# Deploying the CalisTrack web/PWA demo ($0)

The app has a Flutter **web** target. The `lib/preview.dart` entrypoint runs the
full UI on in-memory repositories — **no Firebase required** — so it's a perfect
live, installable demo: it shows logging, programs, progress, skills, the
on-device **Smart-target** model, and the **Pro paywall** (in demo mode, with a
toggle). Hosting it is free.

## Option A — GitHub Pages via GitHub Actions (zero extra accounts)

The repo already lives on GitHub, so this needs no new credentials.

1. In the repo: **Settings → Pages → Build and deployment → Source = "GitHub
   Actions"** (one-time).
2. Push to `main` (or run the **deploy-web** workflow manually from the Actions
   tab). `.github/workflows/deploy-web.yml` builds and publishes automatically.
3. The live URL is **https://omeryasironal.github.io/calistrack/**.

> GitHub Pages leans non-commercial; it's ideal for a demo/PWA. For the
> commercial launch, use Option B.

## Option B — Cloudflare Pages (commercial-grade, still free)

The strongest free *commercial-safe* static host (unlimited static bandwidth,
free HTTPS + custom domains). One-time, needs a Cloudflare account:

```bash
flutter build web --release -t lib/preview.dart   # or -t lib/main.dart for the real app
npm i -g wrangler
wrangler login
wrangler pages deploy build/web --project-name calistrack
```

(Drop `--base-href` when serving from a domain root.)

## Building the REAL app for the web (not the demo)

`lib/main.dart` needs real Firebase web config (`flutterfire configure` writes
it into `firebase_options.dart`). Then `flutter build web --release` and deploy
the same way. Keep Firebase on the **Spark (free)** plan — Auth + Firestore only;
Cloud Functions force Blaze (set a budget alert). See
[`docs/strategy/2026-06-03-monetization-strategy-brief.md`](strategy/2026-06-03-monetization-strategy-brief.md) §4.

## Notes

- Ads (`google_mobile_ads`) and local notifications are **mobile-only**; the web
  build uses no-op stubs via conditional imports, so the web target compiles and
  runs cleanly.
- The on-device progression model is **pure Dart**, so it runs in the browser
  exactly as on device — no native deps.
