# CalisTrack — Privacy Policy (DRAFT)

> **Owner action required.** This is a starting draft generated from what the app
> technically collects. Review it, fill the **[bracketed]** placeholders, have it
> checked against your jurisdiction's requirements (GDPR/CCPA as applicable), then
> host it at a public URL and reference that URL in App Store Connect (App
> Privacy) and Google Play (Data safety). Not legal advice.

**Last updated:** [DATE]
**Contact:** [your support email]

## Who we are

CalisTrack ("the app", "we") is a calisthenics workout-tracking app published by
[your name / company].

## What we collect and why

- **Account information** — your email address and (for Google sign-in) the
  basic profile from Google. Used to authenticate you and sync your data across
  devices. Provided by Firebase Authentication.
- **Profile details** — display name, experience level, training goals, and
  optional body stats (height/weight) that you enter. Used to personalize your
  programs and recommendations.
- **Workout data** — programs, logged sets, and skill progress you create. Used
  to provide the core tracking features and your progress charts.
- **Advertising identifier** — on supported devices we (via Google AdMob) may
  access your device advertising ID (IDFA on iOS, GAID on Android) to show ads.
  On iOS this requires your permission via the App Tracking Transparency prompt,
  and where required we show a consent (GDPR/UMP) form; if you decline, you still
  see ads, but non-personalized.
- **AI program generation (optional)** — when you generate a program, your
  inputs (experience, days/week, goals, equipment) are sent to our server-side
  Cloud Function, which calls OpenAI to produce a program. We do not send your
  identity or other personal data for this; the OpenAI API key is held only on
  the server, never in the app.

We do **not** sell your personal data.

## Guest mode

You can use the app without an account ("Try without an account"). Guest data is
stored under an anonymous identity; if you later create an account, your data
carries over. Guest data may be lost if you uninstall before creating an account.

## Where your data lives

Account, profile, workout, and skill data are stored in Google Firebase
(Authentication + Cloud Firestore). See Google's privacy policy for how Google
processes data on our behalf. Ads are served by Google AdMob.

## Third parties

- **Google Firebase** (authentication, database, cloud functions)
- **Google AdMob** (advertising) — see Google's policies for ad personalization
  and the controls available to you
- **OpenAI** (server-side program generation only, from non-identifying inputs)

## Your choices

- Edit or update your profile details in the app at any time (Profile → Edit).
- Reset your password from the login screen.
- iOS: manage tracking permission in Settings → Privacy → Tracking.
- Request account/data deletion by contacting us at [your support email].
  [Describe your deletion process / SLA.]

## Children

CalisTrack is not directed at children under [13/16, per your jurisdiction] and
we do not knowingly collect their data.

## Changes

We may update this policy; material changes will be reflected here with a new
"Last updated" date.

## Contact

Questions? [your support email].
