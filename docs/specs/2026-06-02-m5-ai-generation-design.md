# M5 — AI Program Generation (Design Spec)

**Date:** 2026-06-02 · **Milestone:** M5 (issue #5) · **Tasks:** T19–T21

## Context
M3 added preset programs; M5 lets a user generate a tailored program from a
short form (experience level, goals, days/week, equipment). The generation runs
**server-side only** — a Firebase Cloud Function calls OpenAI with a key that
never touches the client (CalisTrack rule). Because deploying the function needs
the owner's Firebase project + OpenAI key (a human step), the client is built
**fallback-first**: if the function is absent/errors/returns bad JSON, it falls
back to a deterministic local template so the feature always produces a usable
program. Generated programs are saved to `users/{uid}/programs` and can be set
active (the active-program resolution is extended to include user programs).

## Architecture

### Cloud Function (T19) — `functions/`
- TypeScript `onCall` `generateProgram({level, goals, daysPerWeek, equipment})`.
- Calls OpenAI (key from `functions` secret/env `OPENAI_API_KEY` — never
  committed) with a strict-JSON system prompt that returns a `Program`-shaped
  object: `{name, description, days:[{label, exercises:[{exerciseId, targetSets,
  targetReps?|targetHoldSeconds?|targetDistanceMeters?|targetDurationSeconds?}]}]}`
  using only ids from the bundled exercise library (passed in the prompt).
- Validates/repairs the response server-side; throws `https` errors on failure.
- **Not deployed by us** — ships deploy-ready with a `functions/README.md`
  (set the secret, `firebase deploy --only functions`). Not exercised by the
  Flutter CI (Node).

### Client (T20)
- **AiProgramService** — `generate(GenerationRequest)` → `Program`. Calls the
  callable via `cloud_functions`; parses + validates the JSON against the
  exercise library (drops unknown ids, ensures ≥1 day). On ANY failure
  (function missing, network, bad JSON, empty) → `fallbackProgram(request,
  presets)`: a deterministic local template (pick the preset matching
  daysPerWeek, else Foundations; rename to a goal-based title). Pure fallback
  is unit-tested.
- **ProgramRepository** gains user-programs: `userPrograms(uid)` (stream of
  `users/{uid}/programs`), `saveProgram(uid, program)`.
- **activeProgramProvider** now resolves from **presets + user programs**;
  `allProgramsProvider`/`userProgramsProvider` expose user programs.

### Screen (T21)
- **AI generation screen** (reached from Programs via a "Generate with AI"
  button): a form (level dropdown, days/week stepper, goals chips, equipment
  chips) → **Generate** (loading) → **preview** the resulting `Program` (reuse
  the program-detail layout) → **Save** (writes to `users/{uid}/programs` + sets
  active). Loading/error states; a banner when the local fallback was used.
- **Programs screen** gains a "Your programs" section (user programs) above/below
  the presets, each opening the existing detail/set-active flow.

## Testing (per feature, fakes)
- Fallback generator: maps daysPerWeek → a sensible preset; never throws.
- AiProgramService: parses a valid function response → Program; invalid/empty →
  fallback; unknown exerciseIds dropped.
- ProgramRepository user-programs save/watch via a fake; activeProgramProvider
  resolves a user program.
- Widget: AI form → generate (fake service) → preview → save persists + active;
  Programs shows a saved user program.

## No-magic-numbers / security
Prompt + schema constants in the function. **No API key in the repo** — the
function reads it from a Firebase secret; the client never sees it.

## Task order
**T19** Cloud Function (+README) → **T20** client service + repo + fallback +
tests → **T21** AI screen + user programs in Programs + tests. Per-task PR +
zero-context adversarial review + merge.

## Acceptance (M5 exit)
A user fills the form and gets a saved, active, tailored program — via OpenAI
when the function is deployed, via the local fallback otherwise. CI green;
no key committed.

## Human step (flagged, not blocking)
Deploy needs `flutterfire configure` + a Firebase project + `firebase functions:secrets:set OPENAI_API_KEY` + `firebase deploy --only functions`. Until
then the fallback path is what runs.
