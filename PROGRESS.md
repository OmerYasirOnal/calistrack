# CalisTrack — Progress Log

Append-only. Newest at top. One entry per completed task/work session.

---

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
