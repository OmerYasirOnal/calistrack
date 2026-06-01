# CalisTrack — Progress Log

Append-only. Newest at top. One entry per completed task/work session.

---

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
