# CalisTrack — Build Plan

> Calisthenics workout-tracking app. Flutter + Riverpod + Firebase + (Cloud-Function-proxied) OpenAI.
> This plan slices the work into small, independently testable, zero-context tasks.
> Each task maps to a GitHub issue (label `calistrack`) and a milestone label (`M1`…`M6`).

## Architecture at a glance

```
Flutter (Riverpod)  ──►  Repositories  ──►  Firestore / Hive (offline-first)
        │                                          ▲
        │                                          │ sync
        └──► Cloud Function `generateProgram` ──► OpenAI (key server-side only)
```

- **Feature-based** folders under `lib/features/<feature>/{data,application,presentation}`.
- **Repository pattern**: presentation never touches Firestore directly.
- **Offline-first**: Hive is the local cache; Firestore is the source of truth; repositories reconcile.
- **No secrets in client**: OpenAI key lives only in the Cloud Function environment.

## Milestones

| ID | Theme | Outcome |
|----|-------|---------|
| **M1** | Foundation | Project scaffold, theme, router, data models, CI green |
| **M2** | Auth | Email + Google sign-in, auth-gated routing, profile bootstrap |
| **M3** | Programs & Workout | Preset programs, Today screen, set/rep/weight logging |
| **M4** | Progress & Skills | fl_chart progress, skill-progression tracking |
| **M5** | AI generation | `generateProgram` Cloud Function + client parse/persist + fallback |
| **M6** | Polish | Offline sync hardening, animations, empty/error states, a11y |

## Task list (each = one issue)

### M1 — Foundation
- **T1** Project scaffold: `pubspec.yaml`, `analysis_options.yaml`, folder structure, `main.dart`, app shell.
- **T2** Theme: Material 3 dark-first theme, typography, color scheme, spacing tokens.
- **T3** Router: `go_router` with bottom-nav shell (Today / Programs / Progress / Skills / Profile).
- **T4** Data models: `AppUser`, `Program`, `Workout`, `SkillProgress`, `Exercise` with JSON (de)serialization + tests.
- **T5** CI: GitHub Actions running `flutter pub get`, `flutter analyze`, `flutter test`.

### M2 — Auth
- **T6** Firebase bootstrap: `firebase_options` placeholder, init in `main`, providers.
- **T7** Auth repository: email sign-up/in, Google sign-in, sign-out, auth state stream.
- **T8** Auth UI: login + register screens, loading/error states, auth-gated router redirect.
- **T9** Profile bootstrap: create `users/{uid}` doc on first login.

### M3 — Programs & Workout
- **T10** Exercise library: seed `exercises/*` + global exercise repository.
- **T11** Program repository + preset programs (Push/Pull/Legs/Core/Run).
- **T12** Programs screen: list, detail, "start today's workout".
- **T13** Today screen: today's session, per-exercise checklist.
- **T14** Set logging: per-set reps + optional added weight, persist to `workouts/*`.

### M4 — Progress & Skills
- **T15** Progress repository: aggregate workout history per exercise.
- **T16** Progress screen: fl_chart reps/weight/volume over time.
- **T17** Skill model + preset skill trees (muscle-up, front lever, …).
- **T18** Skills screen: progression steps, log hold-time/reps per step.

### M5 — AI generation
- **T19** Cloud Function `generateProgram(level, goals, daysPerWeek, equipment)` → strict JSON.
- **T20** Client: call function, parse JSON → `Program`, persist, safe fallback template.
- **T21** AI generation UI: form + loading + preview + save.

### M6 — Polish
- **T22** Offline sync: Hive cache + Firestore reconciliation.
- **T23** Animations + empty/error/loading polish, a11y pass.
- **T24** Widget tests per feature; coverage gate.

## Working discipline (per CalisTrack workflow)
1. Pick a task → open/assign its issue → branch `feat/calistrack-<task>` (worktree).
2. Write what changes, write code, run analyze+test (in CI), log to `PROGRESS.md`.
3. Open PR → fresh zero-context review agent audits → fix → green CI → merge.
4. Next task starts from PLAN/TASKS/PROGRESS only — no carried context.
