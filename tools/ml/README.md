# tools/ml — on-device "Smart next target" model

A tiny **multinomial logistic regression** that recommends the next session's
action for an exercise — `DELOAD` / `MAINTAIN` / `INCREASE` — from the user's
recent set history. It is trained here in Python and shipped as exported weights
that run in **pure Dart** on-device: **$0, offline, no native deps, works on web**.

## Why this design

We have **no real user data**, so we generate synthetic samples from established
progression heuristics (double progression + RPE/RIR autoregulation + deload),
label each "next action", add 5% label noise, and fit logistic regression. The
heuristic stays the **ground truth** the Dart inference is regression-tested
against (`golden_cases.json`), and a runtime **fallback** when the asset is
missing. The model adds calibrated confidence + noise-robustness over rigid
`if/else` thresholds, while staying tiny enough to run as a dot-product + softmax.

## Features

6 base measurements (computed in Dart from logged history) + 5 soft interaction
features that give the linear model the AND/OR expressiveness the heuristic needs:

| base | meaning |
|---|---|
| `top_reps_last` | best-set reps in the most recent session |
| `rep_high` | prescribed top of the rep range (program target) |
| `margin` | `top_reps_last - rep_high` (≥0 ⇒ range top hit) |
| `sessions_at_top` | consecutive recent sessions at/above range top |
| `trend3` | avg per-session change in top reps over the last ≤3 sessions |
| `avg_rir` | avg reps-in-reserve last session (default 2.0 when unlogged) |

engineered: `grind=relu(1-rir)`, `decline=relu(-trend3)`,
`deload_and=grind*decline`, `ready_load=relu(margin)*relu(rir-0.5)`,
`ready_reps=relu(-margin)*relu(rir-1.5)`. **The Dart `ProgressionModel` must
reproduce this derivation exactly.**

## Result (seed=7)

~**0.88** accuracy vs the clean heuristic on a held-out split (DELOAD recall
0.97, INCREASE 0.94, MAINTAIN 0.81). Tuning log: raw-6 features → 0.75; + soft
interactions → **0.88** (kept); threshold-tightened variant → 0.85 (worse,
reverted).

## Reproduce

```bash
python3 -m venv tools/ml/.venv
tools/ml/.venv/bin/python -m pip install numpy scikit-learn matplotlib
tools/ml/.venv/bin/python tools/ml/generate_and_train.py
```

Outputs (committed): `assets/data/progression_model.json` (the shipped weights)
and `tools/ml/golden_cases.json` (Dart parity fixtures). The run is deterministic
(`SEED=7`).
