# CalisTrack — Launch Runbook

The app is **code-complete** (M1–M10): onboarding, workout logging, programs +
AI generation, progress, skills, AdMob monetization, account recovery, guest
mode, profile editing — all merged, CI green (~82% line coverage). Everything in
this document is **owner-only**: it needs your accounts, real credentials, and a
physical device, so it can't be done from the dev environment. Do these in order.

> Toolchain assumed: Flutter (stable), a Mac for iOS builds, and accounts for
> Firebase, AdMob, Apple Developer, and Google Play.

---

## 1. Firebase (auth + Firestore + Functions)

The repo ships a **placeholder** `firebase_options.dart` so the UI builds and CI
runs. Wire your real project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure          # select/create your Firebase project; pick iOS + Android
```

This regenerates `lib/firebase_options.dart` and writes the platform configs
(`google-services.json`, `GoogleService-Info.plist`) — all `.gitignore`d.

In the Firebase console:
- **Authentication** → enable **Email/Password**, **Google**, and **Anonymous**
  (guest mode uses anonymous + account linking).
- **Firestore** → create the database; start in production mode and add rules so
  a user can only read/write their own `users/{uid}/**` documents.

## 2. AI program-generation Cloud Function

Deploy-ready under `functions/` (it is **not** deployed; the app falls back to a
local template until it is — see `functions/README.md`).

```bash
cd functions && npm install
firebase functions:secrets:set OPENAI_API_KEY     # paste your OpenAI key when prompted
firebase deploy --only functions
```

The key lives **only** in the Firebase secret — never in the client. After
deploy, AI generation hits the live function instead of the fallback.

## 3. AdMob (monetization)

Code-side AdMob is fully wired (banner on Progress, capped interstitial after a
session, GDPR/UMP consent + iOS ATT in the ad init). You must supply real IDs:

1. Create an AdMob account + an app; create **banner** and **interstitial** ad
   units for **both** Android and iOS.
2. Replace the Google **sample/test** IDs with your real ones:
   - **App ID** in `android/app/src/main/AndroidManifest.xml`
     (`com.google.android.gms.ads.APPLICATION_ID`) and
     `ios/Runner/Info.plist` (`GADApplicationIdentifier`).
   - **Ad-unit IDs** in `assets/data/ad_config.json` → the **`prod`** block
     (currently `TODO_REPLACE_*` placeholders). The app auto-selects `prod` in
     release builds, `test` in debug.
3. In the AdMob console → **Privacy & messaging**, create a **GDPR/EU consent
   message** (UMP). The app already calls `loadAndShowConsentFormIfRequired`.
4. **Verify on a real device:** the iOS ATT prompt and the UMP consent form only
   appear on-device; confirm both show and that ads load with your real units.

## 4. Privacy policy + store data-safety

Required by both stores and by AdMob/IDFA. A starting draft is in
[`docs/privacy-policy.md`](docs/privacy-policy.md) — review it with your details,
host it at a public URL, and reference that URL in:
- App Store Connect → App Privacy.
- Google Play Console → Data safety.
- (Optional) link it from the app.

Declare the data the app handles: account email, profile (level/goals/body
stats), workout history; Firebase (auth/Firestore); AdMob advertising ID (IDFA/
GAID); Google sign-in.

## 5. App icon + splash polish

The repo uses the default Flutter launcher icon and an in-app branded splash
(dumbbell + wordmark). For store-quality branding:
```bash
flutter pub add dev:flutter_launcher_icons
# add a 1024×1024 icon at assets/icon/icon.png + a flutter_launcher_icons config, then:
dart run flutter_launcher_icons
```

## 6. iOS + Android release signing

- **iOS:** open `ios/Runner.xcworkspace` in Xcode, set the bundle id + your
  Team, create the App Store Connect app record, archive, and upload.
  Confirm `NSUserTrackingUsageDescription` copy in `Info.plist` reads how you
  want (ATT prompt text).
- **Android:** create an upload keystore + `android/key.properties`, set the
  release signing config in `android/app/build.gradle.kts`, then
  `flutter build appbundle --release` and upload the `.aab` to Play Console.

The org/bundle id is currently `com.calistrack` — change it everywhere if you
want a different one before the first store upload (it can't change later).

## 7. Final pre-submit checks

- `flutter analyze` clean · `flutter test` green (CI enforces both + a ≥75%
  coverage gate).
- Smoke-test the full new-user journey on a real device: sign up → onboarding →
  recommended program → log a set → finish → see Progress/Skills; plus guest →
  upgrade, forgot-password, and (with real Firebase) email verification.
- Store listing: screenshots (you can capture the authed UI without Firebase via
  `flutter run -t lib/preview.dart`), description, category (Health & Fitness).

---

When these are done, CalisTrack is ready to submit. The code does not need
further changes to ship.
