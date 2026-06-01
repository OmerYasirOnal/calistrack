# CalisTrack — Task Board

## ⭐ TOP-PRIORITY FOLLOW-UP (do first, from a local machine)
- **T0 — Migrate CalisTrack to its own dedicated public GitHub repo.**
  Right now it lives under `calistrack/` inside `OmerYasirOnal/studio` only because
  this remote session is scoped to that repo and a fresh repo can't be pushed to
  locally from the container. When the owner is at their own computer, extract
  `calistrack/` into a **new standalone public repo** (preserve history via
  `git subtree split` / `git filter-repo`), move the CI workflow to that repo's
  root `.github/workflows/`, migrate the M1–M6 issues/labels, and update remotes.
  This is important — it removes the framework-vs-app rule conflict entirely.


Status legend: `TODO` · `DOING` · `REVIEW` · `DONE`
Each task links to its GitHub issue once created.

## M1 — Foundation  ✅ (verified locally on Flutter 3.44.0; CI mirror pending)
| Task | Title | Status | Issue | PR |
|------|-------|--------|-------|----|
| T1 | Project scaffold | DONE | #65 | #64 |
| T2 | Material 3 dark theme | DONE | #65 | #64 |
| T3 | Router + bottom-nav shell | DONE | #65 | #64 |
| T4 | Data models + JSON + tests | DONE | #65 | #64 |
| T5 | GitHub Actions CI | DONE | #65 | #64 |

## M2 — Auth  ✅ (verified locally on Flutter 3.44.0; in review)
| Task | Title | Status | Issue | PR |
|------|-------|--------|-------|----|
| T6 | Firebase bootstrap (providers) | DONE | #66 | — |
| T7 | Auth repository (email/Google) | DONE | #66 | — |
| T8 | Auth UI + gated routing | DONE | #66 | — |
| T9 | Profile bootstrap | DONE | #66 | — |

## M3 — Programs & Workout  ✅ (complete; issue #3 closed)
| Task | Title | Status | Issue | PR |
|------|-------|--------|-------|----|
| T10 | Exercise library + repo | DONE | #3 | #7 |
| T11 | Program repo + presets | DONE | #3 | #8 |
| T12 | Programs screen | DONE | #3 | #9 |
| T13 | Today screen | DONE | #3 | #10 |
| T14 | Set logging | DONE | #3 | #10 |

## M4 — Progress & Skills
| Task | Title | Status | Issue | PR |
|------|-------|--------|-------|----|
| T15 | Progress repository | REVIEW | #4 | — |
| T16 | Progress charts (fl_chart) | REVIEW | #4 | — |
| T17 | Skill model + preset trees | REVIEW | #4 | — |
| T18 | Skills screen | REVIEW | #4 | — |

## M5 — AI generation
| Task | Title | Status | Issue | PR |
|------|-------|--------|-------|----|
| T19 | generateProgram Cloud Function | TODO | — | — |
| T20 | Client parse/persist + fallback | TODO | — | — |
| T21 | AI generation UI | TODO | — | — |

## M6 — Polish
| Task | Title | Status | Issue | PR |
|------|-------|--------|-------|----|
| T22 | Offline sync (Hive↔Firestore) | TODO | — | — |
| T23 | Animations + a11y polish | TODO | — | — |
| T24 | Widget tests + coverage gate | TODO | — | — |
