# M4 — Progress & Skills (Design Spec)

**Date:** 2026-06-02 · **Milestone:** M4 (issue #4) · **Tasks:** T15–T18

## Context
M1–M3 done: a user can pick a program, log workouts (persisted to
`users/{uid}/workouts`), and skill state is modelled (`SkillProgress`). M4 turns
that logged data into **insight** (per-exercise progress charts) and adds
**skill progression** (preset trees the user climbs). Reuses the existing
models, the dark Material-3 design language, and the per-task review discipline.
Data stays in assets (skill trees) + Firestore (workouts/skill progress); charts
via `fl_chart` (already a dependency).

## Architecture

### Progress (T15 repo, T16 screen)
- **ProgressRepository** (T15) — aggregates `users/{uid}/workouts` (via the
  existing `WorkoutRepository.recent`) into per-exercise time series. For an
  `exerciseId`, returns an ordered list of `ExerciseDataPoint(date, totalReps,
  totalVolume, topWeight, bestHoldSeconds, totalDistanceMeters)` — one per
  workout that contained it. Pure aggregation over `Workout`/`LoggedExercise`
  (no new Firestore reads beyond `recent`). Providers:
  `exerciseHistoryProvider.family(exerciseId)`, plus an
  `overallStatsProvider` (total workouts, total volume, this-week count, streak).
- **Progress screen** (T16) — top **overall stats** card; an **exercise picker**
  (only exercises that appear in history); a **fl_chart line chart** of the
  metric appropriate to the movement type (volume/reps for reps; best-hold for
  holds; distance for cardio) over sessions; empty state when no history.
  Loading/error/empty everywhere.

### Skills (T17 data+repo, T18 screen)
- **`assets/data/skills.json`** — preset progression trees (data, not inline).
  Each: `{id, name, description, steps:[{id, name, description, targetHoldSeconds?
  / targetReps?}]}`. Seed set: **Muscle-up, Front Lever, Planche, Handstand,
  Pistol Squat**.
- **SkillRepository** (T17) — `presets()` from assets; user progress at
  `users/{uid}/skills/{skillId}` (existing `SkillProgress` model:
  currentStepIndex + logs). `watch(uid)` merges preset trees with saved progress
  (default index 0, no logs). `logAttempt(uid, skillId, SkillLog)` and
  `setStep(uid, skillId, index)` persist. Integrity test: every preset has ≥1
  step with non-empty ids.
- **Skills screen** (T18) — list of skills with a **completion bar**
  (`SkillProgress.completionRatio`) + current step; tap → detail: the step
  ladder (current highlighted, earlier steps checked), **log an attempt**
  (hold-seconds or reps stepper → appends a `SkillLog`), and **advance / step
  back** the current step. Persists to Firestore.

### State (Riverpod), per existing conventions
Future/Stream providers keyed off the signed-in uid (`authStateProvider`),
controllers as `AsyncNotifier` for log/advance actions with loading/error.
`lib/preview.dart` extended to seed skill progress + extra workout history so
Progress/Skills render in the no-Firebase preview.

## Testing (per feature, fake repos)
- ProgressRepository aggregation math (reps/volume/top-weight/hold/distance per
  point; ordering; empty history) — pure unit tests.
- Skill preset parse + integrity; SkillRepository merge (preset + saved
  progress), logAttempt/setStep via a fake.
- Widget: Progress empty state + a chart renders for an exercise with history;
  Skills list shows progress, detail logs an attempt + advances. Deterministic
  boots via preloaded provider overrides (as in the Today tests).

## No-magic-numbers
Skill trees + targets → `skills.json`. Streak/stat windows → named consts or a
small `progress_defaults` if more than trivial.

## Task order (per-task PR + zero-context adversarial review)
**T15** ProgressRepository + providers + tests → **T16** Progress screen +
chart → **T17** skills.json + SkillRepository + tests → **T18** Skills screen.
Each: branch → format/analyze/test green → update PROGRESS/TASKS → conventional
commit → PR → fresh review → fix → merge → preview screenshot.

## Acceptance (M4 exit)
After logging workouts, the Progress tab shows real per-exercise charts + overall
stats; the Skills tab lists preset progressions, logs step attempts, and advances
the current step — all persisted. CI green; tests per feature.

## Out of scope (later)
M5 AI generation, M6 offline sync / a11y / coverage gate. Live Firebase
persistence verification needs `flutterfire configure` (human step); preview +
fakes cover it meanwhile.
