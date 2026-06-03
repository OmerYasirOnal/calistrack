#!/usr/bin/env python3
"""
CalisTrack — financial projection + charts.

A transparent 18-month bottom-up model for the freemium (free+ads + Pro
subscription) plan. Assumptions trace to the research brief
(docs/strategy/2026-06-03-monetization-strategy-brief.md, §7) — rows 1-3,5,7-15.
The §7 row-6 RLTV/payer ($17/$35.64/$70) is an independent top-down cross-check,
NOT a bound input: this model derives per-payer LTV from price x mix x churn, so
its emergent LTV need not match row 6 exactly (BASE aligns; LOW/HIGH compress).
The single largest unknown — monthly organic installs — is run as THREE coherent
scenarios
(LOW / BASE / HIGH), each bundling an install volume + conversion + ARPDAU +
churn, so the output is a range, not a false point estimate.

Outputs PNGs to docs/finance/. Deterministic (no randomness).

Run:  tools/ml/.venv/bin/python tools/finance/model.py
"""
from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "docs" / "finance"
MONTHS = 18

# Verified economics (brief §3): 15% store commission -> 85% retained on IAP.
NET_IAP = 0.85
PRICE_MONTHLY = 5.99
PRICE_ANNUAL = 29.99

# Publish costs (brief §3) — shown on the "if you publish" cash line.
GOOGLE_PLAY_ONE_TIME = 25.0   # month 1
APPLE_YEARLY = 99.0           # months 1 and 13

# id: (installs/mo month1, monthly install growth, free->paid conv, annual mix,
#      monthly-sub churn, free-user monthly churn, activation, ad ARPDAU,
#      active days/mo for a free user)
# Ad assumptions are deliberately conservative (brief §2: a TR/EU-weighted
# habit-tracking utility realizes ARPDAU at/below the LOW end, and ads must NOT
# carry the model) and free-user churn is realistic (free users leave fast), so
# subscriptions dominate the mix — matching the strategy.
SCENARIOS = {
    "LOW":  dict(inst0=300,  g=0.00, conv=0.010, amix=0.50, mchurn=0.18,
                 uchurn=0.35, act=0.55, arpdau=0.01, days=4, color="#d1495b"),
    "BASE": dict(inst0=1200, g=0.05, conv=0.020, amix=0.60, mchurn=0.12,
                 uchurn=0.28, act=0.60, arpdau=0.02, days=5, color="#2a9d8f"),
    "HIGH": dict(inst0=4000, g=0.08, conv=0.035, amix=0.67, mchurn=0.08,
                 uchurn=0.20, act=0.65, arpdau=0.05, days=7, color="#1d3557"),
}


def simulate(s):
    """Run one scenario; return per-month dicts of the key series."""
    installs, free_mau, sub_rev, ad_rev = [], [], [], []
    active_monthly_subs = 0.0           # paying monthly subscribers
    annual_cohorts = []                 # (size, months_remaining) for renewals
    mau = 0.0
    for m in range(MONTHS):
        new_inst = s["inst0"] * ((1 + s["g"]) ** m)
        installs.append(new_inst)

        # Free monthly-active users: decay + newly activated installs.
        mau = mau * (1 - s["uchurn"]) + new_inst * s["act"]
        free_mau.append(mau)

        new_payers = new_inst * s["conv"]
        new_annual = new_payers * s["amix"]
        new_monthly = new_payers - new_annual

        # Monthly subs: churn the base, add new monthly payers.
        active_monthly_subs = active_monthly_subs * (1 - s["mchurn"]) + new_monthly
        m_rev = active_monthly_subs * PRICE_MONTHLY

        # Annual: upfront this month + renewals from cohorts hitting 12 months.
        a_rev = new_annual * PRICE_ANNUAL
        renewed = []
        for size, rem in annual_cohorts:
            rem -= 1
            if rem == 0:
                # ~ retain (1 - annual churn ~ 2x monthly) at renewal.
                size = size * (1 - min(0.9, s["mchurn"] * 2))
                a_rev += size * PRICE_ANNUAL
                rem = 12
            renewed.append((size, rem))
        renewed.append((new_annual, 12))
        annual_cohorts = renewed

        # Ads accrue to free (non-paying) MAU only.
        free_only = max(0.0, mau)
        a_ad = free_only * s["arpdau"] * s["days"]

        sub_rev.append((m_rev + a_rev) * NET_IAP)  # store fee on IAP only
        ad_rev.append(a_ad)                          # ARPDAU already net to publisher

    return dict(installs=installs, free_mau=free_mau, sub_rev=sub_rev,
                ad_rev=ad_rev,
                total=[a + b for a, b in zip(sub_rev, ad_rev)])


def fmt_usd(x, _=None):
    return f"${x:,.0f}"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sims = {k: simulate(v) for k, v in SCENARIOS.items()}
    x = list(range(1, MONTHS + 1))

    # 1) Monthly net revenue, 3 scenarios.
    plt.figure(figsize=(9, 5))
    for k, s in SCENARIOS.items():
        plt.plot(x, sims[k]["total"], label=f"{k}", color=s["color"], lw=2.4)
    plt.title("CalisTrack — Monthly net revenue (18-month scenarios)")
    plt.xlabel("Month"); plt.ylabel("Net revenue / month")
    plt.gca().yaxis.set_major_formatter(fmt_usd)
    plt.legend(title="Scenario"); plt.grid(alpha=0.25)
    plt.tight_layout(); plt.savefig(OUT / "01_monthly_revenue.png", dpi=130)
    plt.close()

    # 2) Cumulative net cash incl. publish costs (the "if you publish" path).
    plt.figure(figsize=(9, 5))
    for k, s in SCENARIOS.items():
        cum, run = [], 0.0
        for m in range(MONTHS):
            run += sims[k]["total"][m]
            if m == 0:
                run -= GOOGLE_PLAY_ONE_TIME + APPLE_YEARLY
            if m == 12:
                run -= APPLE_YEARLY
            cum.append(run)
        plt.plot(x, cum, label=k, color=s["color"], lw=2.4)
    plt.axhline(0, color="#888", lw=1, ls="--")
    plt.title(r"Cumulative net cash (incl. \$25 Play + \$99/yr Apple)")
    plt.xlabel("Month"); plt.ylabel("Cumulative net cash")
    plt.gca().yaxis.set_major_formatter(fmt_usd)
    plt.legend(title="Scenario"); plt.grid(alpha=0.25)
    plt.tight_layout(); plt.savefig(OUT / "02_cumulative_cash.png", dpi=130)
    plt.close()

    # 3) Revenue mix (BASE): subscriptions vs ads.
    b = sims["BASE"]
    plt.figure(figsize=(9, 5))
    plt.stackplot(x, b["sub_rev"], b["ad_rev"],
                  labels=["Subscriptions (net)", "Ads"],
                  colors=["#2a9d8f", "#e9c46a"])
    plt.title("Revenue mix over time (BASE) — subscriptions carry it")
    plt.xlabel("Month"); plt.ylabel("Net revenue / month")
    plt.gca().yaxis.set_major_formatter(fmt_usd)
    plt.legend(loc="upper left"); plt.grid(alpha=0.25)
    plt.tight_layout(); plt.savefig(OUT / "03_revenue_mix.png", dpi=130)
    plt.close()

    # 4) Sensitivity: month-18 monthly revenue vs conversion (BASE installs).
    base = SCENARIOS["BASE"]
    convs = [0.005 * i for i in range(1, 9)]  # 0.5%..4.0%
    finals = []
    for c in convs:
        s = dict(base); s["conv"] = c
        finals.append(simulate(s)["total"][-1])
    plt.figure(figsize=(9, 5))
    plt.plot([c * 100 for c in convs], finals, "-o", color="#1d3557", lw=2.4)
    for c, f in zip(convs, finals):
        if abs(c - base["conv"]) < 1e-9:
            plt.scatter([c * 100], [f], color="#e76f51", zorder=5, s=80)
            plt.annotate("BASE 2.0%", (c * 100, f),
                         textcoords="offset points", xytext=(8, -14))
    plt.title("Sensitivity — month-18 monthly revenue vs free→paid conversion")
    plt.xlabel("Free→paid conversion (%)"); plt.ylabel("Net revenue / month")
    plt.gca().yaxis.set_major_formatter(fmt_usd)
    plt.grid(alpha=0.25)
    plt.tight_layout(); plt.savefig(OUT / "04_sensitivity_conversion.png", dpi=130)
    plt.close()

    # 5) Funnel (BASE, month 12): installs -> free MAU -> payers.
    m12 = 11
    cum_installs = sum(SCENARIOS["BASE"]["inst0"] * ((1 + SCENARIOS["BASE"]["g"]) ** i)
                       for i in range(m12 + 1))
    mau12 = sims["BASE"]["free_mau"][m12]
    payers12 = cum_installs * SCENARIOS["BASE"]["conv"]
    labels = ["Cumulative installs", "Monthly-active (free)", "Paying users"]
    vals = [cum_installs, mau12, payers12]
    plt.figure(figsize=(9, 5))
    bars = plt.barh(labels[::-1], vals[::-1],
                    color=["#e9c46a", "#2a9d8f", "#1d3557"])
    for bar, v in zip(bars, vals[::-1]):
        plt.text(v, bar.get_y() + bar.get_height() / 2, f"  {v:,.0f}",
                 va="center")
    plt.title("Acquisition funnel (BASE, by month 12)")
    plt.xlabel("Users"); plt.tight_layout()
    plt.savefig(OUT / "05_funnel.png", dpi=130)
    plt.close()

    # Print a compact summary table for the roadmap doc.
    print("Scenario | M18 net rev/mo | 18-mo cumulative | payers M12")
    for k in SCENARIOS:
        cum18 = sum(sims[k]["total"])
        ci = sum(SCENARIOS[k]["inst0"] * ((1 + SCENARIOS[k]["g"]) ** i)
                 for i in range(12))
        print(f"{k:5} | ${sims[k]['total'][-1]:>10,.0f} | "
              f"${cum18:>12,.0f} | {ci * SCENARIOS[k]['conv']:>8,.0f}")
    print(f"\nWrote 5 charts -> {OUT.relative_to(REPO)}")


if __name__ == "__main__":
    main()
