# CalisTrack — Roadmap

> Milestones are tracked as GitHub issue labels (`M1`…`M6`) because milestone
> objects can't be created through the available tooling. Each milestone groups
> its task issues (label `calistrack`).

```mermaid
gantt
    title CalisTrack MVP
    dateFormat  YYYY-MM-DD
    section M1 Foundation
    Scaffold/theme/router/models/CI      :m1, 2026-06-01, 2d
    section M2 Auth
    Firebase + email/Google + gating     :m2, after m1, 3d
    section M3 Programs & Workout
    Presets + Today + set logging        :m3, after m2, 4d
    section M4 Progress & Skills
    Charts + skill progression           :m4, after m3, 3d
    section M5 AI generation
    generateProgram fn + client parse    :m5, after m4, 3d
    section M6 Polish
    Offline sync + a11y + tests          :m6, after m5, 3d
```

## Milestone exit criteria

- **M1 Foundation** — App builds; 5-tab shell navigates; models have passing round-trip tests; CI green.
- **M2 Auth** — A new user can register/sign-in (email + Google) and land authenticated; `users/{uid}` created.
- **M3 Programs & Workout** — User can pick a preset program, see today's workout, and log sets (reps + weight).
- **M4 Progress & Skills** — Per-exercise charts render from history; skill steps loggable.
- **M5 AI generation** — Form → Cloud Function → parsed `Program` saved; bad/missing response falls back to a template.
- **M6 Polish** — Works offline and reconciles; loading/error/empty states everywhere; widget tests per feature.

## Review discipline

Every task PR is reviewed by a **fresh zero-context agent** (no build history) that
audits correctness, the repo separation rules, and the spec before merge. Findings are
fixed on the same branch and re-verified by CI.
