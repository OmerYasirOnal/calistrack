#!/usr/bin/env python3
"""
CalisTrack — on-device "Smart next target" model: synthetic data + training.

We have NO real user data, so we generate synthetic samples from established
calisthenics/strength progression heuristics (double progression + RPE/RIR
autoregulation + deload), label each "next-session action", add realistic label
noise, and fit a tiny MULTINOMIAL LOGISTIC REGRESSION. The trained weights are
exported to assets/data/progression_model.json and run in pure Dart on-device
($0, offline, no native deps, works on web).

Classes (the model's *judgment*; the concrete arithmetic is a Dart rule):
  0 DELOAD    back off (fatigued / grinding + declining)
  1 MAINTAIN  repeat the same target (consolidate / not enough room to push)
  2 INCREASE  progress next session (add reps if below range top, else add load)

Features (all computable in Dart from logged set history + program target):
  f0 top_reps_last   max reps in the most recent session's sets
  f1 rep_high        prescribed top of the rep range (program target)
  f2 margin          top_reps_last - rep_high  (>=0 means range top hit)
  f3 sessions_at_top consecutive recent sessions with top reps >= rep_high
  f4 trend3          avg per-session change in top reps over the last <=3 sessions
  f5 avg_rir         avg reps-in-reserve last session (default 2.0 when unlogged)

Run:  tools/ml/.venv/bin/python tools/ml/generate_and_train.py
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, classification_report,
                             confusion_matrix)
from sklearn.model_selection import train_test_split

SEED = 7
RNG = np.random.default_rng(SEED)

CLASS_NAMES = ["DELOAD", "MAINTAIN", "INCREASE"]
# The 6 base measurements Dart computes from logged history.
BASE_FEATURE_NAMES = ["top_reps_last", "rep_high", "margin",
                      "sessions_at_top", "trend3", "avg_rir"]
# Engineered (soft interaction) features derived from the base ones — they give
# the linear model the AND/OR expressiveness the heuristic needs. Dart reproduces
# this exact derivation (see featurize()).
ENG_FEATURE_NAMES = ["grind", "decline", "deload_and", "ready_load",
                     "ready_reps"]
FEATURE_NAMES = BASE_FEATURE_NAMES + ENG_FEATURE_NAMES


def featurize(X6):
    """base-6 measurements -> full feature matrix (base + soft interactions).

    grind=relu(1-rir), decline=relu(-trend3): soft 'low reps-in-reserve' and
    'declining'. deload_and=grind*decline encodes the DELOAD conjunction.
    ready_load=relu(margin)*relu(rir-0.5): at/above range top with reps to
    spare -> add load. ready_reps=relu(-margin)*relu(rir-1.5): below top but
    easy -> add reps. Must match the Dart implementation exactly."""
    X6 = np.atleast_2d(X6).astype(float)
    margin = X6[:, 2]
    trend3 = X6[:, 4]
    avg_rir = X6[:, 5]
    grind = np.maximum(0.0, 1.0 - avg_rir)      # soft 'low reps-in-reserve'
    decline = np.maximum(0.0, -trend3)          # soft 'declining'
    deload_and = grind * decline                # the DELOAD conjunction
    ready_load = np.maximum(0.0, margin) * np.maximum(0.0, avg_rir - 0.5)
    ready_reps = np.maximum(0.0, -margin) * np.maximum(0.0, avg_rir - 1.5)
    eng = np.column_stack([grind, decline, deload_and, ready_load, ready_reps])
    return np.hstack([X6, eng])

REPO = Path(__file__).resolve().parents[2]
ASSET_OUT = REPO / "assets" / "data" / "progression_model.json"
GOLDEN_OUT = REPO / "tools" / "ml" / "golden_cases.json"
N_SAMPLES = 8000
NOISE_RATE = 0.05  # fraction of labels randomly flipped (real life is noisy)


def heuristic_label(top_reps_last, rep_high, sessions_at_top, trend3, avg_rir):
    """Ground-truth next-session action from progression heuristics."""
    margin = top_reps_last - rep_high
    # Deload: performance declining AND grinding (no reps in reserve) -> fatigue.
    if trend3 <= -1.0 and avg_rir <= 0.5:
        return 0  # DELOAD
    # Increase via reps: below range top but easy and improving -> add reps.
    if margin < 0 and avg_rir >= 2.0 and trend3 >= 0.0:
        return 2  # INCREASE
    # Increase via load: at/above range top, consolidated, with reps in reserve.
    if margin >= 0 and sessions_at_top >= 1 and avg_rir >= 1.0:
        return 2  # INCREASE
    return 1  # MAINTAIN


def _rows(n, *, rir_lo, rir_hi, trend_mu, trend_sd, offset_lo, offset_hi):
    """One regime's worth of feature rows."""
    rep_high = RNG.choice([8.0, 10.0, 12.0, 15.0], size=n)
    offset = RNG.integers(offset_lo, offset_hi, size=n).astype(float)
    top_reps_last = np.clip(rep_high + offset, 1.0, None)
    margin = top_reps_last - rep_high
    # can only have recent sessions "at top" if currently at/above top.
    sessions_at_top = np.where(
        margin >= 0, RNG.integers(0, 5, size=n), 0).astype(float)
    trend3 = np.clip(np.round(RNG.normal(trend_mu, trend_sd, size=n), 1),
                     -3.0, 3.0)
    avg_rir = np.round(RNG.uniform(rir_lo, rir_hi, size=n), 1)
    return np.column_stack(
        [top_reps_last, rep_high, margin, sessions_at_top, trend3, avg_rir])


def sample_features(n):
    """Mix three regimes so all three classes are well represented.

    A purely broad sample leaves DELOAD (declining + grinding) at ~2% — too rare
    to learn. We deliberately allocate mass to a fatigue regime and a ready
    regime, then label every row by the SAME heuristic (the rule stays the
    ground truth; we only steer where in feature space we look)."""
    n_broad = int(n * 0.60)
    n_fatig = int(n * 0.20)
    n_ready = n - n_broad - n_fatig
    broad = _rows(n_broad, rir_lo=0.0, rir_hi=4.0, trend_mu=0.2, trend_sd=1.5,
                  offset_lo=-6, offset_hi=5)
    fatig = _rows(n_fatig, rir_lo=0.0, rir_hi=1.2, trend_mu=-1.6, trend_sd=0.9,
                  offset_lo=-5, offset_hi=2)
    ready = _rows(n_ready, rir_lo=1.0, rir_hi=4.0, trend_mu=0.6, trend_sd=1.0,
                  offset_lo=0, offset_hi=4)
    X = np.vstack([broad, fatig, ready])
    RNG.shuffle(X)  # de-block the regimes
    return X


def main():
    X6 = sample_features(N_SAMPLES)            # base measurements (Dart computes these)
    y = np.array([
        heuristic_label(r[0], r[1], r[3], r[4], r[5]) for r in X6
    ])

    # Inject label noise so the model learns a robust boundary, not a lookup.
    flip = RNG.random(len(y)) < NOISE_RATE
    y_noisy = y.copy()
    y_noisy[flip] = RNG.integers(0, 3, size=flip.sum())

    print(f"Generated {N_SAMPLES} synthetic samples (seed={SEED}).")
    counts = {CLASS_NAMES[c]: int((y == c).sum()) for c in range(3)}
    print("Class distribution (clean labels):", counts)

    X = featurize(X6)                          # base + soft interaction features
    mean = X.mean(axis=0)
    std = X.std(axis=0)
    std[std == 0] = 1.0
    Xs = (X - mean) / std

    # Index split so we can recover the base-6 inputs for the Dart golden cases.
    idx = np.arange(N_SAMPLES)
    tr, te = train_test_split(
        idx, test_size=0.2, random_state=SEED, stratify=y_noisy)

    clf = LogisticRegression(
        solver="lbfgs", C=2.0, max_iter=4000,
        class_weight="balanced", random_state=SEED)
    clf.fit(Xs[tr], y_noisy[tr])

    # Evaluate against the CLEAN heuristic labels (the model's job is to recover
    # the true rule despite noisy training labels).
    pred = clf.predict(Xs[te])
    acc_noisy = accuracy_score(y_noisy[te], pred)
    acc_clean = accuracy_score(y[te], pred)

    print(f"\nTest accuracy vs noisy labels : {acc_noisy:.3f}")
    print(f"Test accuracy vs CLEAN rule   : {acc_clean:.3f}")
    print("\nClassification report (vs clean rule):")
    print(classification_report(y[te], pred,
                                target_names=CLASS_NAMES, digits=3))
    print("Confusion matrix (rows=true, cols=pred), classes "
          f"{CLASS_NAMES}:")
    print(confusion_matrix(y[te], pred))

    # Export: standardization + softmax weights over the FULL feature vector.
    # Dart: base6 -> featurize() -> standardize (mean/std) -> z=W.x+b -> softmax.
    model = {
        "_comment": ("On-device progression model. Multinomial logistic "
                     "regression on synthetic data from progression "
                     "heuristics. Dart pipeline: compute the 6 baseFeatures "
                     "from logged history, derive the engineered features "
                     "(grind=relu(1-rir), decline=relu(-trend3), "
                     "deload_and=grind*decline, ready_load=relu(margin)*"
                     "relu(rir-0.5), ready_reps=relu(-margin)*relu(rir-1.5)), "
                     "standardize with mean/std, then z=W.x+b, softmax, argmax. "
                     "Generated by tools/ml/generate_and_train.py — do not hand-edit."),
        "version": 1,
        "seed": SEED,
        "classes": CLASS_NAMES,
        "baseFeatureNames": BASE_FEATURE_NAMES,
        "featureNames": FEATURE_NAMES,
        "mean": mean.tolist(),
        "std": std.tolist(),
        "coef": clf.coef_.tolist(),          # (3, 11)
        "intercept": clf.intercept_.tolist(),  # (3,)
        "trainAccuracyVsCleanRule": round(float(acc_clean), 4),
    }
    ASSET_OUT.parent.mkdir(parents=True, exist_ok=True)
    ASSET_OUT.write_text(json.dumps(model, indent=2) + "\n")
    print(f"\nExported model -> {ASSET_OUT.relative_to(REPO)}")

    # Golden parity cases: store the ROUNDED base-6 inputs and recompute probs
    # through the full pipeline from exactly those rounded values, so the Dart
    # inference (which receives the same base-6) must reproduce them.
    golden = []
    per_class = {0: 0, 1: 0, 2: 0}
    for i in te:
        base = np.round(X6[i], 4)
        xs = ((featurize(base) - mean) / std)
        probs = clf.predict_proba(xs)[0]
        c = int(np.argmax(probs))
        if per_class[c] >= 14:
            continue
        per_class[c] += 1
        golden.append({
            "baseFeatures": base.tolist(),
            "probs": [round(float(p), 6) for p in probs],
            "predicted": c,
            "predictedClass": CLASS_NAMES[c],
        })
        if sum(per_class.values()) >= 40:
            break
    GOLDEN_OUT.write_text(json.dumps(golden, indent=2) + "\n")
    print(f"Wrote {len(golden)} golden parity cases -> "
          f"{GOLDEN_OUT.relative_to(REPO)}")


if __name__ == "__main__":
    main()
