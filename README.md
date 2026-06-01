# CalisTrack

A cross-platform (iOS + Android) calisthenics workout-tracking app.

> Built inside the `studio` monorepo under `calistrack/`. It is an **application**,
> not part of the Studio game framework — it intentionally uses Firebase + an
> OpenAI-backed Cloud Function, which the framework's own rules forbid for *game*
> code. Keep CalisTrack code inside `calistrack/`.

## Stack
- **Flutter** (stable) + Dart, **Riverpod** state management
- **Firebase**: Auth + Cloud Firestore + Cloud Functions
- **AI**: OpenAI via a Cloud Function (the API key is **never** in the client)
- **Charts**: `fl_chart` · **Local cache**: Hive (offline-first)

## Features (MVP)
1. Auth — email + Google Sign-In
2. Preset programs — Push / Pull / Legs / Core / Run
3. Daily workout tracking — complete today's session exercise by exercise
4. Set/rep/weight logging with history
5. Progress charts — reps / weight / volume per exercise over time
6. Skill progression — muscle-up, front lever, … step by step
7. AI program generation — level/goals/days → generated program JSON → parsed & saved

## Project layout
```
calistrack/
  lib/
    main.dart, app.dart, firebase_options.dart   # entry + root + (placeholder) config
    core/        theme · router · widgets         # cross-cutting
    models/      app_user · program · workout · skill_progress · exercise
    features/    today · programs · progress · skills · profile · home (+ auth, ai later)
  functions/     Cloud Functions (generateProgram) — added in M5
  test/          model + widget tests
```

## Architecture
Feature-based folders with the **repository pattern** (`data/` ← repositories,
`application/` ← Riverpod controllers, `presentation/` ← widgets). Offline-first:
Hive caches; Firestore is source of truth; repositories reconcile.

## Running locally
This repo's CI container has no Flutter SDK; verification runs in GitHub Actions
(`.github/workflows/calistrack-ci.yml`). To run locally you need Flutter ≥ 3.22:
```bash
cd calistrack
flutter pub get
flutter analyze
flutter test
flutter run            # needs real Firebase config via `flutterfire configure`
```

## Firebase config
`lib/firebase_options.dart` is a **non-secret placeholder** so the app compiles in
CI. Replace it with `flutterfire configure` against a real project before running
on device. Real `google-services.json` / `GoogleService-Info.plist` are gitignored.

## Roadmap & process
See [`ROADMAP.md`](ROADMAP.md), [`PLAN.md`](PLAN.md), [`TASKS.md`](TASKS.md),
[`PROGRESS.md`](PROGRESS.md). Work is sliced into milestone-labelled GitHub issues
(`calistrack` + `M1`…`M6`); each task PR is reviewed by a fresh zero-context agent.
