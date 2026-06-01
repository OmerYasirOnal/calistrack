# CalisTrack — Progress Log

Append-only. Newest at top. One entry per completed task/work session.

---

## 2026-06-01 — M3 T11 Programs repo + presets [branch feat/calistrack-m3-t11-programs-repo]
- **Task:** preset programs + ProgramRepository, plus a backward-compatible
  cardio model extension so a Run day logs end-to-end.
- **Models:** `LoggedSet` += `distanceMeters?` / `durationSeconds?`;
  `ProgramExercise` += `targetDistanceMeters?` / `targetDurationSeconds?` (all
  nullable + conditional JSON → legacy docs still parse).
- **Added:** `assets/data/programs.json` — 4 presets (Classic PPL · PPL + Core ·
  Foundations · Hybrid w/ a Run day), storing ids + targets only with names
  resolved from the library. `features/programs/data/program_repository.dart`
  (`presets(library)` resolves names, throws on unknown ids) with
  `programRepositoryProvider` + `presetProgramsProvider`.
- **Tests:** model round-trip + legacy-parse for the new fields; ProgramRepository
  preset parse, **preset-integrity** (every exerciseId resolves in the library),
  cardio-target presence, and a `StateError` on an unknown id.
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 26/26 pass.

## 2026-06-01 — M3 T10 Exercise library repo [branch feat/calistrack-m3-t10-exercise-repo]
- **Task:** ExerciseRepository — load the bundled movement library from assets.
- **Added:** `features/exercises/data/exercise_repository.dart` (injectable
  `AssetBundle`, in-memory cache, `all()` + `byId()`) with
  `exerciseRepositoryProvider` + `exerciseLibraryProvider`. Tests:
  `test/features/exercises/exercise_repository_test.dart` — real-asset load
  (19 unique, well-formed movements), `byId` hit/miss, cache identity, and an
  injected-fixture parse proving the loader is unit-testable.
- **Also:** corrected the design spec's library count (18 → 19).
- **Verified locally (Flutter 3.38.9):** format clean · analyze clean · 18/18 pass.

## 2026-06-01 — M2 Auth (T6–T9) [branch feat/calistrack-m2-auth]
- **Task:** Firebase-backed auth — email + Google sign-in, gated routing,
  profile bootstrap.
- **Changed:** `core/providers/firebase_providers.dart`,
  `features/auth/data/auth_repository.dart` (+`authStateProvider`),
  `features/profile/data/user_repository.dart` (`ensureProfile` = T9),
  `features/auth/application/auth_controller.dart`,
  `features/auth/presentation/{login,register}_screen.dart` + `auth_form_fields`,
  `core/router/app_router.dart` → `goRouterProvider` w/ auth gate,
  `app.dart` → ConsumerWidget, `features/profile/presentation/profile_screen.dart`.
  Tests: `auth_controller_test`, `login_screen_test`, updated `app_smoke_test`,
  `test/support/fakes.dart`.
- **Process note:** code-signing only works from the main checkout, not linked
  worktrees — so milestones are developed in the main checkout on feature
  branches (worktree commit attempts fail signing). Lost the first worktree copy
  to a bad `worktree remove` and recreated it here.
- **Verified locally (Flutter 3.44.0):** format clean · analyze clean · 13/13 pass.

## 2026-06-01 — Local Flutter toolchain + verified-green M1
- Installed **Flutter 3.44.0 stable** in the session container (network policy
  allows storage.googleapis.com), ending blind CI iteration. All future
  milestones are now verified locally (`dart format`, `flutter analyze`,
  `flutter test`) before pushing.
- Ran the real gates on the branch and fixed the last issues definitively:
  - `flutter analyze` → removed `unnecessary_import` (foundation in main.dart)
    and `unused_import` (material in app_smoke_test) → **No issues found**.
  - `dart format` (3.44 "tall" style) reformatted `firebase_options.dart` and
    `exercise.dart` → **clean**.
  - `flutter test` → **8/8 passed**.
- M1 is functionally complete pending the CI mirror going green.

## 2026-06-01 — M1 review + CI fix
- **Review:** Fresh zero-context agent audited the M1 diff against the CI gates
  (`dart format`, `flutter analyze`, `flutter test`).
- **Findings & resolution:**
  - Two `dart format` wraps (`models_test.dart` SkillLog, `app_smoke_test.dart`
    for-loop) → pre-wrapped to match `dart format` output.
  - One `require_trailing_commas` lint (`models_test.dart` ProgramDay) → fixed.
  - Agent also flagged `Color.withValues`/`CardThemeData` as "3.22 blockers".
    **Overridden:** CI runs *latest stable* Flutter (≥3.27) where these are the
    correct, non-deprecated APIs; switching to `withOpacity`/`CardTheme` would
    fail analyze on deprecation infos. Instead bumped pubspec floor to
    flutter ≥3.27 / Dart ≥3.6 so the manifest matches the APIs used.
  - Removed unused codegen dev-deps (build_runner/riverpod_generator/
    hive_generator) + riverpod_annotation to avoid `analyzer` resolution
    conflicts on latest stable; they return when codegen is actually used.
- **Result:** Pending CI re-run on PR #64.

## 2026-06-01 — T1–T5 Foundation (M1)
- **Task:** Bootstrap the CalisTrack Flutter project (scaffold, theme, router, models, CI).
- **Changed:**
  - `calistrack/pubspec.yaml`, `analysis_options.yaml`, `.gitignore`
  - `lib/main.dart`, `lib/app.dart`
  - `lib/core/theme/app_theme.dart` — Material 3 dark-first theme + tokens
  - `lib/core/router/app_router.dart` — go_router + bottom-nav shell
  - `lib/models/{app_user,program,workout,skill_progress,exercise}.dart` — JSON models
  - `lib/features/*/presentation/*_screen.dart` — five shell screens
  - `test/models/*_test.dart` — model round-trip tests
  - `.github/workflows/calistrack-ci.yml` — analyze + test gate
- **Result:** Scaffold compiles to a navigable 5-tab shell (pending CI confirmation — no local Flutter SDK in the build container, so `flutter analyze`/`test` run in CI).
- **Next:** M2 Auth (T6–T9).
