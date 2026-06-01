# M3 — Programs & Workout (Design Spec)

**Date:** 2026-06-01 · **Milestone:** M3 (issue #3) · **Tasks:** T10–T14
**Decisions:** depth = *Solid + depth*; today model = *pick-your-session*.

## Context
M1 (scaffold/theme/router/models/CI) and M2 (Firebase auth) are done. M3 delivers
the core product loop: a user picks a **program**, sees **today's** session, and
**logs sets**. The data models (`Program/ProgramDay/ProgramExercise`,
`Workout/LoggedExercise/LoggedSet`, `Exercise`) already exist and support most of
this. The goal is a loop that feels *meaningful*, not a checkbox list: per-set
entry pre-filled from targets and last session, a rest/run timer, an inline
"last time" reference, live volume + completion, and a satisfying session summary.

Bundled library + presets stay in **assets** (offline, zero cost). Only workouts
and the active-program pointer touch **Firestore**.

## Architecture

### Data layer (repositories + providers)
- **ExerciseRepository** (T10) — loads the 19-movement library from
  `assets/data/exercises.json`; `Future<List<Exercise>> all()` + `Exercise? byId(id)`,
  in-memory cached. Provider: `exerciseLibraryProvider` (FutureProvider).
- **ProgramRepository** (T11) — preset programs from a new
  `assets/data/programs.json` (data, never inline). `presets()` resolves exercise
  names via the library. Provider: `presetProgramsProvider` (FutureProvider).
- **WorkoutRepository** (T14) — CRUD over `users/{uid}/workouts/{id}`;
  `lastSetsFor(exerciseId)` and `lastWorkoutForDay(programId, dayLabel)` drive the
  "last time" reference and pre-fill. Providers expose recent history.
- **Active program** — add nullable `activeProgramId` to the existing `users/{uid}`
  profile doc; extend `UserRepository` (`setActiveProgram`, read in profile stream).
  Provider: `activeProgramProvider` resolves the pointer → `Program`.
  (M5's AI/custom programs will live at `users/{uid}/programs`; out of scope here.)

### Model extension (minimal, backward-compatible) — part of T11
Cardio needs fields the models lack. Add **nullable, optional** fields so all JSON
stays backward-compatible (old docs still parse):
- `LoggedSet`: `int? distanceMeters`, `int? durationSeconds`.
- `ProgramExercise`: `int? targetDistanceMeters`, `int? targetDurationSeconds`.
This lets a **Run** day (distance + run timer) log end-to-end. `volume` stays
rep/weight-based; cardio contributes via distance/duration, surfaced in M4 charts.

### Session engine (the heart) — T13/T14
- **`workoutSessionProvider`** — a `Notifier<WorkoutSession>` holding the in-progress
  `Workout` (selected program day + accumulating `LoggedExercise`/`LoggedSet`).
  Methods: `startDay(program, dayLabel)`, `logSet(exerciseId, set)`,
  `editSet/removeSet`, `finish()`. Derived: completion % (sets done ÷ target),
  running volume. On `finish()` → persist the `Workout` (completed=true) via
  WorkoutRepository, then emit a summary.
- Pure logic (math, pre-fill, completion) is unit-tested independently of widgets.

### Screens
- **Programs** (T12) — preset cards: name, days/week, day chips, muscle-focus
  accent; the active program shows an "Active" badge. Tap → **detail**: each
  `ProgramDay` with its exercises + targets ("3 × 8–12", "3 × 30s", "5 km").
  Actions: **Set as active**, **Start a day now** (→ Today with that day).
  Loading/error/empty states.
- **Today** (T13) — no active program → empty state CTA ("Choose a program").
  Active → program header + **day-picker chips** (pick-your-session: tap Push /
  Pull / Legs / …) → exercise cards. Live header: **completion %** + running
  **volume**. **Finish session** → animated **summary** (sets/reps/volume, vs last
  time).
- **Set logging** (T14) — per exercise card, set rows pre-filled from target + last
  session. Tap a set to complete:
  - reps / weighted-reps → reps + optional added-kg stepper,
  - hold → seconds (with a built-in countdown),
  - distance → meters, time/intervals → a run/interval **timer**.
  Edit/undo a logged set. After each set, an optional **rest countdown** with a
  haptic on completion (defaults from `assets/data/training_defaults.json`).

### Preset programs (`assets/data/programs.json`)
Concrete, drawn from the library (targets are starting points, tunable later):
1. **Classic PPL** — Push (push_up 3×12, pike_push_up 3×8, dip 3×8, diamond_push_up 2×10) ·
   Pull (pull_up 3×6, australian_row 3×10, chin_up 3×6, scapular_pull 2×10) ·
   Legs (pistol_squat 3×6, bulgarian_split_squat 3×10, nordic_curl 3×5, calf_raise 3×15).
2. **PPL + Core** — Classic PPL + Core (hanging_leg_raise 3×12, plank 3×45s,
   hollow_hold 3×30s, l_sit 3×15s).
3. **Foundations** (beginner full-body, 3×/wk) — push_up 3×8, australian_row 3×8,
   bulgarian_split_squat 3×10, plank 3×30s, hollow_hold 3×20s.
4. **Hybrid** — Push · Pull · Legs (as Classic, lighter) + **Run** (easy_run 1× 5 km;
   intervals 6× 60s).

## Firestore shape
- `users/{uid}` (existing): add `activeProgramId: string?`.
- `users/{uid}/workouts/{workoutId}`: `Workout` docs (existing model + new optional fields).
- Library + presets: **bundled assets**, not Firestore.

## Error handling & states
Every async surface has loading / error / empty states (Riverpod `AsyncValue.when`).
Firebase-unavailable (placeholder/offline) degrades gracefully: presets/library
still load (assets); workout writes surface a retryable error. No uncaught throws.

## Testing (per feature; fakes in `test/support/fakes.dart`)
- ExerciseRepository: load + `byId`.
- ProgramRepository: preset parse + **integrity gate** — every
  `ProgramExercise.exerciseId` resolves in the library (fails CI if a preset
  references a missing movement).
- Model round-trip for the new optional fields (back-compat: old JSON parses).
- `workoutSessionProvider`: logSet/editSet/finish, completion % + volume math,
  last-session pre-fill.
- Widget: Programs list renders presets + set-active; Today empty state; the
  log→completion→finish→summary flow.

## No-magic-numbers
Presets → `programs.json`. Rest-timer + rep-range + default cardio targets →
`training_defaults.json`. Nothing tuning-related inlined in Dart.

## Task breakdown & order (per-task PR + zero-context adversarial review)
- **T10** ExerciseRepository + provider + tests.
- **T11** Model cardio extension + ProgramRepository + `programs.json` +
  `training_defaults.json` + integrity test.
- **T12** Programs screen (list + detail + set-active).
- **T13 + T14** Today screen + `workoutSessionProvider` + set logging
  (reps/weight/hold/distance/time) + rest/run timer + summary (built together —
  tightly coupled).
Each: branch off `main` → code → `dart format`/`analyze`/`test` green → update
`PROGRESS.md`/`TASKS.md` → conventional commit → PR → fresh zero-context
adversarial review → fix → merge → screenshot running.

## Acceptance criteria (M3 exit)
A signed-in user can: browse presets, set one active, open Today, pick a day, log
sets (reps + optional weight; holds in seconds; a run in distance/time), see live
completion + volume, finish, and get a summary — all persisted to
`users/{uid}/workouts`. CI green; widget + logic tests cover each feature.

## Explicitly out of scope (later milestones)
Progress charts & skills (M4), AI generation (M5), offline Hive sync & coverage
gate (M6), editable/custom programs, supersets, RPE.
