#!/usr/bin/env python3
"""Data behind the figures and the numbers of thesis section 4.3 (performance optimizations).

Reads the CSV files in ../data (snapshots of the analysis files, see SOURCES below) and the
phase-timer and kernel files of the profiled baseline run (generated/baseline-run/data/perf-nsys-r1),
and writes into ../derived:

  baseline-breakdown.json   figure <fig-perf-baseline-breakdown>
  aa-margin.json            figure <fig-perf-aa>
  rescale-split.json        figure <fig-perf-rescale-split>
  input-regions.json        figure <fig-perf-input-regions>
  input-stack.json          figure <fig-perf-input-stack>
  anchor-kernels.json       figures <fig-perf-anchor-kernels> and <fig-perf-anchor-rounds>
  prop-kernels.json         figure <fig-perf-prop-kernels>
  prop-ncu.json             figures <fig-perf-prop-skip> and <fig-perf-prop-lookups>
  stack-run.json            figure <fig-perf-stack-run> (the final stack by stage)
  ablation.json             figure <fig-perf-ablation> and table <table-perf-ablation> (one row per commit of the final stack)
  final-test.json           figure <fig-perf-final-f1> and table <table-perf-final-test> (the stack against the fixed base, two scenes)
  final-breakdown.json      figure <fig-perf-final-breakdown> and table <table-perf-final-kernels>
  numbers-results.json      numbers of the text of 4.3 "Results of the whole stack"
  numbers-prop.json         numbers of the text of 4.3 "Propagation"
  class-kernels.json        figures <fig-perf-class-stall> and <fig-perf-class-kernels>
  class-profiles.json       figure <fig-perf-class-profiles>
  numbers-class.json        numbers of the text of 4.3 "Reliability classification"
  numbers-anchor.json       numbers of the text of 4.3 "Efficient anchor search"
  numbers-method.json       numbers of the text of 4.3 "Measurement methodology"
  numbers-baseline.json     numbers of the text of 4.3 "Baseline"
  numbers-input.json        numbers of the text of 4.3 "Hiding the input loading"

Values are raw numbers; rounding and signs are set where they are printed
(chapters/figures/perf-common.typ). A numbers file has `v` (the values) and `src` (for every
value, where it comes from). In this script every value is written by `put(key, value, src)`,
so its `// src:` stands next to its key. Paths in `src` are relative to the production-apd-mvs
checkout unless they start with `data/` (this folder), `~` or `thesis/`.

Standard library only. The output is byte-identical for the same input. The script stops
instead of writing a number that disagrees with the analysis notes (EXPECTED and `close`).

Use:  python3 perf43_json.py [--data DIR] [--baseline-run DIR] [--out DIR]
"""
import argparse
import csv
import hashlib
import itertools
import json
import math
import statistics as st
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Where the snapshots in ../data were copied from (production-apd-mvs checkout, .dev/perf/).
SOURCES = {
    "aa.csv": "thesis-4.3/m0/aa.csv (tools/s43_aa_analysis.py)",
    "base2.csv": "thesis-4.3/m0/base2.csv (tools/s43_base2_analysis.py)",
    "rescale_split.csv": "thesis-4.3/m0/rescale_split.csv (tools/s43_rescale_split_analysis.py)",
    "rescale_split_runs.csv": "thesis-4.3/m0/rescale_split_runs.csv (tools/s43_rescale_split_analysis.py)",
    "m0_phases.csv": "thesis-4.3/thesis/data/m0_phases.csv (thesis-4.3/thesis/scripts/m0_phases.py, from the phases.txt of the 10 base runs)",
    "breakdown-base2.csv": "thesis-4.3/stage-input/data/breakdown-base2.csv (tools/s43_input_breakdown.py, run s43-input-timers2-native-s1)",
    "breakdown-h1-2.csv": "thesis-4.3/stage-input/data/breakdown-h1-2.csv (tools/s43_input_breakdown.py, run s43-input-h1-2-native-s1)",
    "breakdown-h2h12.csv": "thesis-4.3/stage-input/data/breakdown-h2h12.csv (tools/s43_input_breakdown.py, run s43-input-h2h12-native-s1)",
    "breakdown-h14.csv": "thesis-4.3/stage-input/data/breakdown-h14.csv (tools/s43_input_breakdown.py, run s43-input-h14-native-s1)",
    "breakdown-h3h6.csv": "thesis-4.3/stage-input/data/breakdown-h3h6.csv (tools/s43_input_breakdown.py, run s43-input-h3h6-native-s1)",
    "card-h1-2.csv": "thesis-4.3/stage-input/data/card-h1-2.csv (tools/s43_input_cards.py)",
    "card-h2h12-h14.csv": "thesis-4.3/stage-input/data/card-h2h12-h14.csv (tools/s43_input_cards.py)",
    "card-h3h6.csv": "thesis-4.3/stage-input/data/card-h3h6.csv (tools/s43_input_cards.py)",
    "kern-per-round.csv": "thesis-4.3/stage-anchor/data/kern-per-round.csv (tools/s43_anchor_kernels.py: kernel seconds per round, nsys, native, seed 1)",
    "kern-per-round-anchor2.csv": "thesis-4.3/thesis/data/kern-per-round-anchor2.csv (thesis-4.3/thesis/scripts/s43_stack_csv.py, from kern_trace.csv of s43-anchor2-k3-nsys-s1 and s43-anchor2-k12-nsys-s1: the same quantity for the two builds of the reordered stack)",
    "anchor-run-spans.csv": "thesis-4.3/thesis/data/anchor-run-spans.csv (thesis-4.3/thesis/scripts/s43_stack_csv.py, from the phases.txt of the runs of thesis-4.3/stage-anchor/cards/IRS.md section 5)",
    "phases-stack.csv": "thesis-4.3/thesis/data/phases-stack.csv (thesis-4.3/thesis/scripts/s43_stack_csv.py, from the phases.txt of s43-base2-native-s1..3, s43-comb-native-s1..3, s43-prop-comb-plain-s1..3, s43-prop-comb-cu2-plain-s1..3, s43-prop-8bit-plain-s1..3, s43-class-comb-plain-s1..3, s43-input-h3h6-native-s1..3, s43-m6-fix-native-s1..3, s43-m6-stack-native-s1..3)",
    "comb-vs-base2.csv": "thesis-4.3/stack/data/comb-vs-base2.csv (tools/s43_comb_phases.py: phase totals paired by seed)",
    **{f"kern-anchor2-{c}-vs-{b}.csv": f"thesis-4.3/stage-anchor/data/kern-anchor2-{c}-vs-{b}.csv (tools/s43_anchor_kernels.py compare: reordered anchor stack, kernel seconds paired by launch, nsys, native, seed 1)"
       for c, b in (("k3", "base2"), ("k12", "k3"), ("k1c", "k12"))},
    **{f"kern-{c}-vs-{b}.csv": f"thesis-4.3/stage-prop/data/kern-{c}-vs-{b}.csv (tools/s43_prop_kernels.py: kernel seconds paired by launch, nsys, native, seed 1)"
       for c, b in (("k10-2", "base2"), ("reftex-2", "k10-2"), ("k2", "reftex-2"), ("k11", "k2"), ("k7lite", "k11"), ("cu2", "k7lite"))},
    **{f"ncu-{c}-vs-{b}.csv": f"thesis-4.3/stage-prop/data/ncu-{c}-vs-{b}.csv (tools/s43_prop_ncu.py: counters of one native launch per kernel, ncu, seed 1)"
       for c, b in (("k2", "reftex-2"), ("k11", "k2"), ("k7lite", "k11"), ("cu2", "k7lite"), ("8bit", "comb-cu2"))},
    **{f: f"thesis-4.3/stage-class/data/{f} (tools/s43_prop_kernels.py: kernel seconds paired by launch, nsys, native, seed 1)"
       for f in ("kern-c2-vs-5cf8608.csv", "kern-c1-vs-c2.csv", "kern-k13-vs-c1.csv", "kern-c9-vs-k13.csv", "kern-c3-vs-c9.csv", "kern-c3chain-vs-5cf8608.csv", "kern-comb-vs-ee07854.csv")},
    **{f: f"thesis-4.3/stage-class/data/{f} (tools/s43_prop_wall.py: plain seeded native runs, run span and F1 per seed)"
       for f in ("tier1-c2-vs-5cf8608.csv", "tier1-k13-vs-c1.csv", "wall-c1-vs-c2.csv", "wall-c9-vs-k13.csv", "wall-c3-vs-c9.csv", "wall-c3chain-vs-5cf8608.csv", "wall-comb-vs-ee07854.csv")},
    "ncu-5cf8608.csv": "thesis-4.3/stage-class/data/ncu-5cf8608.csv (tools/s43_prop_ncu.py: one launch of DepthToWeak and of LocalRefine, ncu, seed 1, s43-class-base-ncu-s1)",
    "ncu-k13-vs-c1.csv": "thesis-4.3/stage-class/data/ncu-k13-vs-c1.csv (tools/s43_prop_ncu.py: the same launches of two builds)",
    "stall-5cf8608-DepthToWeak.csv": "thesis-4.3/stage-class/data/stall-5cf8608-DepthToWeak.csv (tools/s43_class_stall.py: stall samples and instructions by code region, ncu source page)",
    "stall-5cf8608-LocalRefine.csv": "thesis-4.3/stage-class/data/stall-5cf8608-LocalRefine.csv (tools/s43_class_stall.py)",
    "counters-5cf8608-native-s1.csv": "thesis-4.3/stage-class/data/counters-5cf8608-native-s1.csv (tools/s43_class_counters.py: work counters of the instrumented build c397c7c, native, seed 1)",
    "rounds-5cf8608-c2.csv": "thesis-4.3/stage-class/data/rounds-5cf8608-c2.csv (tools/s43_class_rounds.py: kernel seconds per round and pass type)",
    "c8-summary.json": "thesis-4.3/stage-class/data/c8/c8-summary.json (tools/s43_class_c8.py: label agreement of cheaper sweeps, run s43-class-dump-1024-s1)",
    "fig1-profiles.json": "thesis-4.3/stage-class/data/c8/fig1-profiles.json (tools/s43_class_c8.py: the 61 costs of two pixels of the same run)",
    "kern-8bit-vs-comb-cu2.csv": "thesis-4.3/stage-prop/data/kern-8bit-vs-comb-cu2.csv (tools/s43_prop_kernels.py: kernel seconds paired by launch, nsys, native, seed 1; both builds on the combined stack)",
    "tier1-8bit-vs-comb-cu2.csv": "thesis-4.3/stage-prop/data/tier1-8bit-vs-comb-cu2.csv (tools/s43_prop_wall.py: plain seeded native runs, run span and F1 per seed, seeds 1-5)",
    **{f"{f}.csv": f"thesis-4.3/stage-prop/data/{f}.csv (tools/s43_prop_wall.py: plain seeded native runs, run span and F1 per seed)"
       for f in ("tier1-k10-2-vs-base2", "tier1-k2-vs-reftex-2", "tier1-cu2-vs-k7lite", "tier1-k2stack-vs-base2",
                 "wall-reftex-2-vs-k10-2", "wall-k11-vs-k2", "wall-k7lite-vs-k11", "wall-propcomb-vs-comb", "wall-propcomb-cu2-vs-714ed21")},
    **{f"kern-{c}-vs-{b}.csv": f"thesis-4.3/stage-anchor/data/kern-{c}-vs-{b}.csv (tools/s43_anchor_kernels.py compare: kernel seconds paired by launch, nsys, native, seed 1)"
       for c, b in (("k12-2", "base2"), ("k1c", "k12-2"), ("k3", "k1c"), ("gnl", "k3"), ("irs", "gnl"), ("irs", "base2"))},
    **{f: f"thesis-4.3/stack/data/{f} ({how})" for f, how in (
        ("ablation.csv", "tools/s43_m6_analysis.py ablation: one row per commit of exp/s43-stack, run spans of seeds 1-3, paired with the row before"),
        ("ablation-f1.csv", "tools/s43_m6_analysis.py ablation: F1 of the E1/E2 rows, seeds 1-5, paired with the row before"),
        ("final-test.csv", "tools/s43_m6_analysis.py final: the stack c20e935 against base2, pipes and office, summary"),
        ("final-test-runs.csv", "tools/s43_m6_analysis.py final: one row per run"),
        ("final-null.csv", "tools/s43_m6_analysis.py final: the seed-noise arm of base2, all 120 pairings"),
        ("breakdown-phases.csv", "tools/s43_m6_breakdown.py: phase totals, base2 and stack image, mean of seeds 1-3"),
        ("breakdown-kernels.csv", "tools/s43_m6_breakdown.py: kernel seconds of one nsys run each, native, seed 1"))},
    "main-hash-map.md": "thesis-4.3/stack/main-hash-map.md (Gate 6 item 4: exp/s43-stack replayed onto main; old and new hash of every commit, the tags, and the md5 check of the new tip)",
    "runs.csv": "thesis-4.3/m0/runs.csv (tools/s43_aa_analysis.py, tools/s43_seednoise_base2_analysis.py: one row per run)",
    "seednoise-base2.csv": "thesis-4.3/m0/seednoise-base2.csv (tools/s43_seednoise_base2_analysis.py)",
    "seednoise-base2-tier1.csv": "thesis-4.3/m0/seednoise-base2-tier1.csv (tools/s43_seednoise_base2_analysis.py)",
    "breakdown-h1.csv": "thesis-4.3/stage-input/data/breakdown-h1.csv (tools/s43_input_breakdown.py, run s43-input-h1-plain-r1)",
}

MARGIN_TIER1 = 0.003         # src: thesis-4.3/gate-m2-decisions.md item 1 (widened from 0.002)
MARGIN_TIER2 = 0.002         # src: thesis-4.3/acceptance.md, decision D2 (Tier 2: lower bound of the interval at least -0.002)
MARGIN_TIER1_FORMER = 0.002  # src: thesis-4.3/acceptance.md, decision D2 as frozen 2026-11-15
T975 = {2: 4.303, 4: 2.776}  # t(0.975, dof), as in tools/s43_aa_analysis.py and rescale_split.csv (t975)
TOLS = ["1cm", "2cm", "5cm"]
KERNEL_PHASES = ["patchmatch.init", "patchmatch.propagate", "prior_build", "patchmatch.finalize"]


def close(a, b, tol, what):
    """A recomputed number against the value in the analysis notes."""
    assert abs(a - b) <= tol, f"{what}: computed {a}, notes say {b}"


def read_csv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def paired(d):
    """Mean, sample sd and 95 % CI (t, n-1 dof) of paired differences."""
    n = len(d)
    m, sd = st.mean(d), st.stdev(d)
    hw = T975[n - 1] * sd / math.sqrt(n)
    return {"n": n, "t975": T975[n - 1], "mean": m, "sd": sd, "lo": m - hw, "hi": m + hw, "halfwidth": hw}


class Numbers:
    """Values of one section's text, each with its source."""

    def __init__(self):
        self.v, self.src = {}, {}

    def put(self, key, value, src):
        node = self.v
        *head, last = key.split(".")
        for k in head:
            node = node.setdefault(k, {})
        assert last not in node, f"{key} set twice"
        node[last] = value
        self.src[key] = src

    def put_stat(self, key, s, src):
        for k in ("mean", "lo", "hi"):
            self.put(f"{key}.{k}", s[k], src)


def phases_txt(path):
    """Total seconds per phase of a phases.txt (PHASE <name> BEGIN|END <ns> ...)."""
    begin, total, calls = defaultdict(list), defaultdict(float), defaultdict(int)
    for line in Path(path).read_text().splitlines():
        p = line.split()
        if len(p) < 4 or p[0] != "PHASE":
            continue
        if p[2] == "BEGIN":
            begin[p[1]].append(int(p[3]))
        else:
            total[p[1]] += (int(p[3]) - begin[p[1]].pop()) / 1e9
            calls[p[1]] += 1
    return dict(total), dict(calls)


# =================================================================================================
# The 10 runs of the unfixed base (b228c67): stage means, spread
# =================================================================================================
BREAKDOWN_STAGES = [  # key, phases summed, class
    ("propagation", ["patchmatch.propagate", "prior_build"], "kernel"),
    ("initialization", ["patchmatch.init"], "kernel"),
    ("finalization", ["patchmatch.finalize"], "kernel"),
    ("input_load", ["input_load"], "host"),
    ("fusion", ["fusion"], "host"),
    ("device_upload", ["device_upload"], "copy"),
    ("result_readback", ["result_readback"], "copy"),
    ("patchmatch.readback", ["patchmatch.readback"], "copy"),
]
# thesis-4.3/m0/baseline.md section 2, means over the 10 runs
EXPECTED_PHASES = {
    "run": 1101.5, "patchmatch.init": 170.2, "patchmatch.propagate": 550.4, "prior_build": 3.6,
    "patchmatch.finalize": 93.8, "input_load": 152.4, "fusion": 84.5, "device_upload": 19.2,
    "result_readback": 15.8, "patchmatch.readback": 4.0,
}


def base_runs(data):
    per = defaultdict(dict)
    for r in read_csv(data / "m0_phases.csv"):
        per[r["tag"]][r["phase"]] = float(r["seconds"])
    tags = sorted(per)
    assert len(tags) == 10, tags
    for k, v in EXPECTED_PHASES.items():
        close(st.mean(per[t][k] for t in tags), v, 0.051, f"10-run mean of {k}")

    def stat(fn):
        x = [fn(per[t]) for t in tags]
        return st.mean(x), st.stdev(x)

    span, span_sd = stat(lambda p: p["run"])
    kern, kern_sd = stat(lambda p: sum(p[k] for k in KERNEL_PHASES))
    host, host_sd = stat(lambda p: p["run"] - sum(p[k] for k in KERNEL_PHASES))
    close(span, 1101.5, 0.05, "run span"), close(span_sd, 1.9, 0.05, "run span sd")
    close(kern, 818.0, 0.051, "kernel sum"), close(kern_sd, 0.4, 0.05, "kernel sum sd")
    close(host, 283.5, 0.05, "host side"), close(host_sd, 1.8, 0.05, "host side sd")
    stages = []
    for key, ph, cls in BREAKDOWN_STAGES:
        m, sd = stat(lambda p: sum(p[k] for k in ph))
        stages.append({"key": key, "phases": ph, "class": cls, "mean_s": m, "sd_s": sd, "share": m / span})
    # what no drawn stage covers: setup, output writing, the parts of a pass without a timer
    drawn = [k for _, ph, _ in BREAKDOWN_STAGES for k in ph]
    m, sd = stat(lambda p: p["run"] - sum(p[k] for k in drawn))
    stages.append({"key": "other", "phases": [], "class": "other", "mean_s": m, "sd_s": sd, "share": m / span})
    assert abs(sum(s["mean_s"] for s in stages) - span) < 1e-9
    return {
        "runs": len(tags), "tags": tags,
        "span": {"mean_s": span, "sd_s": span_sd},
        "kernel": {"mean_s": kern, "sd_s": kern_sd, "share": kern / span},
        "host": {"mean_s": host, "sd_s": host_sd, "share": host / span},
        "stages": stages,
    }


# =================================================================================================
# The profiled baseline run of <fig-run-breakdown> (perf-nsys-r1, Nsight Systems attached)
# =================================================================================================
def profiled_run(run_dir):
    tot, calls = phases_txt(run_dir / "phases.txt")
    kernels = {r["kernel"]: int(r["total_ns"]) / 1e9 for r in read_csv(run_dir / "kernel-totals-base.csv")
               if r["config"] == "base" and r["run"] == run_dir.name and not r["kernel"].startswith("__")}
    assert len(kernels) == 15, sorted(kernels)   # generated/baseline-run/README.md: 15 kernels
    span = tot["run"]
    close(span, 1106.5, 0.05, "profiled run span")                # thesis-4.3/stage-input/analysis.md section 1
    close(tot["input_load"], 153.4, 0.05, "profiled input_load")  # same line
    phase_sum = sum(tot[k] for k in KERNEL_PHASES)
    # thesis-4.3/m0/baseline.md:51-53 gives 820.2 s against about 820 s; the files give 820.4 s
    # against 820.1 s (profiles/p1-macro.md:23), and the files are what is written out
    close(phase_sum, 820.2, 0.2, "profiled phase sum")
    close(sum(kernels.values()), 820.1, 0.05, "profiled kernel sum")
    return {
        "span_s": span,
        "input_load_s": tot["input_load"], "input_load_calls": calls["input_load"],
        "phase_kernel_sum_s": phase_sum, "nsys_kernel_sum_s": sum(kernels.values()),
        "share": {
            "input_load": tot["input_load"] / span,
            "initialization": tot["patchmatch.init"] / span,
            "propagation": (tot["patchmatch.propagate"] + tot["prior_build"]) / span,
            "finalization": tot["patchmatch.finalize"] / span,
            "depth_to_weak": kernels["DepthToWeak"] / span,
        },
    }


# =================================================================================================
# A/A arm
# =================================================================================================
def aa_arm(data):
    rows = read_csv(data / "aa.csv")
    runs = {(r["arm"], int(r["seed"])): r for r in read_csv(data / "rescale_split_runs.csv")}
    seeds = [int(r["seed"]) for r in rows]
    out = {"n": len(rows), "seeds": seeds, "tols": []}
    for t in TOLS:
        a = [float(r[f"f1_{t}_a"]) for r in rows]
        b = [float(r[f"f1_{t}_b"]) for r in rows]
        s = paired([y - x for x, y in zip(a, b)])
        s.update({"tol": t, "cm": int(t[:-2]), "d": [y - x for x, y in zip(a, b)],
                  "a_mean": st.mean(a), "a_sd": st.stdev(a), "b_mean": st.mean(b), "b_sd": st.stdev(b)})
        # accuracy and completeness of the same runs (arms old1 = A, old2 = B)
        for m in ("acc", "comp"):
            for r in rows:
                assert runs[("old1", int(r["seed"]))]["tag"] == r["tag_a"] and runs[("old2", int(r["seed"]))]["tag"] == r["tag_b"]
            s[m] = paired([float(runs[("old2", k)][f"{m}_{t}"]) - float(runs[("old1", k)][f"{m}_{t}"]) for k in seeds])
        out["tols"].append(s)
    two = out["tols"][1]
    # thesis-4.3/m0/baseline.md section 1, thesis-4.3/acceptance.md "Reference numbers"
    for got, exp in zip((two["mean"], two["lo"], two["hi"]), (-0.0002, -0.0014, 0.0009)):
        close(round(got, 4), exp, 1e-9, "A/A F1 2 cm")
    for got, exp in zip((two["comp"]["mean"], two["comp"]["lo"], two["comp"]["hi"]), (-0.0004, -0.0023, 0.0015)):
        close(round(got, 4), exp, 1e-9, "A/A completeness 2 cm")
    for got, exp in zip((two["acc"]["mean"], two["acc"]["lo"], two["acc"]["hi"]), (-0.0001, -0.0004, 0.0003)):
        close(round(got, 4), exp, 1e-9, "A/A accuracy 2 cm")
    close(round(two["a_sd"], 4), 0.0011, 1e-9, "seed sd")
    out["md5_distinct"] = len({r[k] for r in rows for k in ("md5_a", "md5_b")})
    out["md5_same_seed_equal"] = sum(r["md5_a"] == r["md5_b"] for r in rows)
    return out


# =================================================================================================
# Seed-noise arm on the fixed base: the same build with other seeds (the null on a base whose
# runs are bit-reproducible per seed)
# =================================================================================================
def seednoise_arm(data):
    runs = {r["tag"]: r for r in read_csv(data / "runs.csv")}
    welch = {(r["metric"], r["tol"]): r for r in read_csv(data / "seednoise-base2.csv")}
    tier1 = {(r["metric"], r["tol"]): r for r in read_csv(data / "seednoise-base2-tier1.csv")}
    seeds_a, seeds_b = list(range(1, 6)), list(range(6, 11))
    col = lambda m, t: f"{m}_{t[:-2]}"
    val = lambda k, m, t: float(runs[f"s43-base2-native-s{k}"][col(m, t)])
    out = {"n": len(seeds_a), "seeds_a": seeds_a, "seeds_b": seeds_b, "tols": []}
    for t in TOLS:
        a, b = [val(k, "f1", t) for k in seeds_a], [val(k, "f1", t) for k in seeds_b]
        d = [y - x for x, y in zip(a, b)]            # paired by index: seed k+5 against seed k
        s = paired(d)
        ref = tier1[("f1", t)]
        for k in ("mean", "lo", "hi"):
            close(s[k], float(ref[k]), 1.5e-6, f"seed noise f1 {t} {k}, from runs.csv")
        for got, exp in zip(d, ref["index_pairing_diffs"].split()):
            close(got, float(exp), 1e-6, f"seed noise f1 {t} per-seed difference")
        # the Tier 1 rule over every way of pairing the two sets
        stats = [paired([b[p[i]] - a[i] for i in range(len(a))]) for p in itertools.permutations(range(len(b)))]
        inside = lambda m: sum(-m < x["lo"] and x["hi"] < m for x in stats) / len(stats)
        close(inside(MARGIN_TIER1_FORMER), float(ref["frac_pass_all_120_pairings"]), 1e-6, f"pass rate {t}")
        close(st.median(x["halfwidth"] for x in stats), float(ref["median_hw_all_pairings"]), 1e-6, f"median half-width {t}")
        w = welch[("f1", t)]
        s.update({"tol": t, "cm": int(t[:-2]), "d": d, "pairings": len(stats),
                  "pass_former": inside(MARGIN_TIER1_FORMER), "pass_now": inside(MARGIN_TIER1),
                  "welch": {"mean": float(w["diff_b_minus_a"]), "lo": float(w["lo"]), "hi": float(w["hi"])},
                  "sd_pooled": float(w["sd_pooled"]), "expected_halfwidth": float(w["tier1_hw_n5"]),
                  "mc_null_pass_former": float(w["p_pass_eff0"])})
        for m in ("acc", "comp"):
            w = welch[(m, t)]
            s[m] = {"mean": float(w["diff_b_minus_a"]), "lo": float(w["lo"]), "hi": float(w["hi"])}
        out["tols"].append(s)
    two = out["tols"][1]
    # thesis-4.3/m0/determinism.md "Seed noise on base2"
    for got, exp in zip((two["mean"], two["lo"], two["hi"]), (0.0004, -0.0016, 0.0024)):
        close(round(got, 4), exp, 1e-9, "seed noise F1 2 cm, Tier 1 formula")
    for got, exp in zip((two["welch"]["mean"], two["welch"]["lo"], two["welch"]["hi"]), (0.0004, -0.0009, 0.0017)):
        close(round(got, 4), exp, 1e-9, "seed noise F1 2 cm, Welch")
    close(round(two["pass_former"], 2), 0.51, 1e-9, "pass rate at the former margin")
    # what the text says in words: this null is not inside the former margin, and every pairing passes the widened one
    assert not (-MARGIN_TIER1_FORMER < two["lo"] and two["hi"] < MARGIN_TIER1_FORMER)
    assert -MARGIN_TIER1 < two["lo"] and two["hi"] < MARGIN_TIER1 and two["pass_now"] == 1
    return out


# =================================================================================================
# The two commits of the RescaleMatToTargetSize fix
# =================================================================================================
RESCALE_SERIES = [  # comparison row of rescale_split.csv, commit, minuend arm, subtrahend
    ("zi-base", "024808a", "zi", "base"),
    ("base2-zi", "6c1f7b1", "base2", "zi"),
    ("base2-base", None, "base2", "base"),
]
EXPECTED_RESCALE = {  # thesis-4.3/m0/determinism.md, F1 at 2 cm
    "zi-base": (-0.0010, -0.0015, -0.0005), "base2-zi": (-0.0005, -0.0015, 0.0005), "base2-base": (-0.0015, -0.0027, -0.0002),
}


def rescale_split(data):
    rows = {(r["comparison"], r["metric"], r["tol"]): r for r in read_csv(data / "rescale_split.csv")}
    runs = {(r["arm"], int(r["seed"])): r for r in read_csv(data / "rescale_split_runs.csv")}
    seeds = sorted({k for a, k in runs if a == "base2"})

    def value(arm, k, col):
        if arm == "base":  # the unfixed side of a pair: the mean of the two base runs of that seed
            return (float(runs[("old1", k)][col]) + float(runs[("old2", k)][col])) / 2
        return float(runs[(arm, k)][col])

    def row(comp, metric, tol):
        r = rows[(comp, metric, tol)]
        return {"n": int(r["n"]), "t975": float(r["t975"]), "mean": float(r["mean"]), "sd": float(r["sd"]),
                "lo": float(r["lo"]), "hi": float(r["hi"])}

    series = []
    for comp, commit, hi_arm, lo_arm in RESCALE_SERIES:
        s = {"key": comp, "commit": commit, "f1": [], "acc": {}, "comp": {}}
        for t in TOLS:
            r = row(comp, "f1", t)
            # the CSV row, recomputed from the per-run values
            d = [value(hi_arm, k, f"f1_{t}") - value(lo_arm, k, f"f1_{t}") for k in seeds]
            again = paired(d)
            for k in ("mean", "lo", "hi"):
                close(again[k], r[k], 1.5e-6, f"{comp} f1 {t} {k}, from rescale_split_runs.csv")
            r.update({"tol": t, "cm": int(t[:-2]), "d": d})
            s["f1"].append(r)
            s["acc"][t], s["comp"][t] = row(comp, "acc", t), row(comp, "comp", t)
        two = s["f1"][1]
        for got, exp in zip((two["mean"], two["lo"], two["hi"]), EXPECTED_RESCALE[comp]):
            close(round(got, 4), exp, 1e-9, f"{comp} F1 2 cm")
        s["span_s"] = row(comp, "span_s", "")
        series.append(s)
    # the two commits add up to the total
    for i in range(len(TOLS)):
        assert abs(series[0]["f1"][i]["mean"] + series[1]["f1"][i]["mean"] - series[2]["f1"][i]["mean"]) < 2e-6
    drift = {t: row("fresh-base (drift)", "f1", t) for t in TOLS}
    assert all(float(r["t975"]) == T975[int(r["n"]) - 1] for r in rows.values())   # the intervals are 95 % intervals
    return {"n": len(seeds), "seeds": seeds, "series": series, "drift": drift, "ci_level_pct": 95,
            "pairings_negative_2cm": [k for (k, m, t), r in rows.items()
                                      if k.startswith("zi-") and m == "f1" and t == "2cm" and float(r["mean"]) < 0],
            "pairings_2cm": [k for (k, m, t) in rows if k.startswith("zi-") and m == "f1" and t == "2cm"]}


# =================================================================================================
# Input loading by region timer
# =================================================================================================
# The builds of the input stack, in order; each sits on the one before it, the first on the fixed
# base (base2, 6c1f7b1). A breakdown is one timed run with seed 1. `card` is the arm of the build in
# the card files (phase totals of three seeded runs, paired by seed).
INPUT_ARMS = [  # key, file, commit, run, card arm
    ("base2", "breakdown-base2.csv", "d9d1bf2", "s43-input-timers2-native-s1", "base2"),
    ("h1", "breakdown-h1-2.csv", "774a713", "s43-input-h1-2-native-s1", "h1-2"),
    ("h2h12", "breakdown-h2h12.csv", "45acddb", "s43-input-h2h12-native-s1", "h2h12"),
    ("h14", "breakdown-h14.csv", "88adf19", "s43-input-h14-native-s1", "h14"),
    ("h3h6", "breakdown-h3h6.csv", "5d0c66f", "s43-input-h3h6-native-s1", "h3h6"),
]
ARM_FILE = {a[0]: "data/" + a[1] for a in INPUT_ARMS}
BEFORE = "data/" + INPUT_ARMS[0][1]
CARD_FILES = ["card-h2h12-h14.csv", "card-h3h6.csv"]   # card-h1-2.csv repeats rows of the first
TOP_REGIONS = ["in.convert", "in.cameras", "in.resize", "in.geom_depths", "in.weak", "in.planes"]
# The bar: the six regions of input_load, in.planes divided into its inner timers and the rest.
# The parts of a group add up to the region the prose names.
INPUT_SEGMENTS = [  # key, group, seconds from the region totals
    ("convert", "images", lambda s: s["in.convert"]),
    ("resize", "images", lambda s: s["in.resize"]),
    ("plane_fill", "planes", lambda s: s["in.plane_fill"]),
    ("plane_upsample", "planes", lambda s: s["in.upsample.depth_normal"] + s["in.upsample.views"]),
    ("plane_rest", "planes", lambda s: s["in.planes"] - s["in.plane_fill"] - s["in.upsample.depth_normal"] - s["in.upsample.views"]),
    ("geom_depths", "geom_depths", lambda s: s["in.geom_depths"]),
    ("weak", "weak", lambda s: s["in.weak"]),
    ("untimed", "untimed", lambda s: s["in.cameras"] + s["input_load"] - sum(s[k] for k in TOP_REGIONS)),
    # the transfers around the kernels, which the last card addresses
    ("upload", "transfers", lambda s: s["device_upload"]),
    ("unpack", "transfers", lambda s: s["result_readback"]),
]
INPUT_LOAD_SEGMENTS = [k for k, g, _ in INPUT_SEGMENTS if g != "transfers"]
# seed-1 region totals in the cards (H1.md section 7, H2h12.md, H14.md and H3H6.md section 5)
EXPECTED_INPUT = {
    "base2": {"input_load": 151.6, "in.convert": 71.3, "in.resize": 17.1, "in.planes": 46.0, "in.geom_depths": 11.9},
    "h1": {"input_load": 56.9, "in.planes": 44.2, "in.plane_fill": 24.6, "in.geom_depths": 7.5, "in.weak": 4.6},
    "h2h12": {"input_load": 14.7, "in.planes": 11.5, "in.plane_fill": 3.3, "in.weak": 2.5, "result_readback": 16.4},
    "h14": {"input_load": 8.5, "device_upload": 19.5, "result_readback": 16.4, "pass.free": 1.3},
    "h3h6": {"device_upload": 4.0, "result_readback": 3.0, "patchmatch.readback": 2.0, "pass.free": 0.8},
}


def input_regions(data):
    arms = []
    for key, fname, commit, run, _ in INPUT_ARMS:
        sec, flt, gb = defaultdict(float), defaultdict(float), defaultdict(float)
        by_state = defaultdict(lambda: defaultdict(lambda: {"n": 0, "s": 0.0, "flt": 0.0}))
        outside, passes, views, calls = None, 0, 0, defaultdict(int)
        for r in read_csv(data / fname):
            if r["round"] == "outside":
                if r["region"] == "input_load":   # the calls before the first pass
                    outside = {"calls": int(r["n"]), "s": float(r["seconds"])}
                continue
            sec[r["region"]] += float(r["seconds"])
            flt[r["region"]] += float(r["minflt"] or 0)
            gb[r["region"]] += float(r["fault_gb"] or 0)
            calls[r["region"]] += int(r["n"])
            cell = by_state[r["region"]][(int(r["round"]), r["state"] == "REFINE_ITER")]
            cell["n"] += int(r["n"]); cell["s"] += float(r["seconds"]); cell["flt"] += float(r["minflt"] or 0)
            if r["region"] == "input_load":
                passes += int(r["n"])
            if r["region"] == "up.texobj" and r["parent"] == "up.images":
                views += int(r["n"])   # one texture object per uploaded view
        for k, v in EXPECTED_INPUT.get(key, {}).items():
            close(sec[k], v, 0.06, f"{key} {k}")   # the cards round to one decimal
        segs = [{"key": k, "group": g, "s": fn(sec), "faults": fn(flt)} for k, g, fn in INPUT_SEGMENTS]
        il = [x for x in segs if x["key"] in INPUT_LOAD_SEGMENTS]
        assert abs(sum(x["faults"] for x in il) - flt["input_load"]) < 0.5
        assert abs(sum(x["s"] for x in il) - sec["input_load"]) < 1e-6
        arms.append({
            "key": key, "commit": commit, "run": run, "passes": passes, "views_uploaded": views,
            "input_load_s": sec["input_load"], "total_s": sum(x["s"] for x in segs), "outside": outside, "segments": segs,
            "regions": {k: {"s": sec[k], "faults": flt[k], "fault_gb": gb[k], "calls": calls[k]} for k in sorted(sec)},
            "convert_by_state": [{"round": rd, "refine_iter": it, **c} for (rd, it), c in sorted(by_state["in.convert"].items())],
        })
    assert len({a["passes"] for a in arms}) == 1 and len({a["views_uploaded"] for a in arms}) == 1
    return {"arms": arms}


# =================================================================================================
# The input stack by build: phase totals of three seeded runs, paired by seed
# =================================================================================================
STACK_PHASES = ["patchmatch", "input_load", "device_upload", "result_readback"]


def input_stack(data):
    rows = {}
    for f in CARD_FILES + ["card-h1-2.csv"]:
        for r in read_csv(data / f):
            k = (r["arm"], r["vs"], r["phase"])
            assert rows.setdefault(k, r) == r, f"{f}: {k} differs between the card files"
    n = {int(r["n"]) for r in rows.values()}
    assert n == {3}, n
    order = [a[4] for a in INPUT_ARMS]
    arms = []
    for i, (key, _, commit, _, card) in enumerate(INPUT_ARMS):
        if i == 0:
            mean = {ph: float(rows[(order[1], card, ph)]["mean_vs"]) for ph in ["run"] + STACK_PHASES}
            arm = {"key": key, "commit": "6c1f7b1", "phase_s": mean, "vs_parent": None, "vs_base": None}
        else:
            mean = {ph: float(rows[(card, "base2", ph)]["mean_arm"]) for ph in ["run"] + STACK_PHASES}
            d = lambda vs: {ph: {k2: float(rows[(card, vs, ph)][k1]) for k1, k2 in (("delta", "mean"), ("ci_lo", "lo"), ("ci_hi", "hi"))}
                            for ph in ["run"] + STACK_PHASES}
            arm = {"key": key, "commit": commit, "phase_s": mean, "vs_parent": d(order[i - 1]), "vs_base": d("base2")}
            for ph in ["run"] + STACK_PHASES:   # the parent's mean is the same number in both comparisons
                close(float(rows[(card, order[i - 1], ph)]["mean_vs"]), arms[-1]["phase_s"][ph], 0.011, f"{card} parent {ph}")
        arm["other_s"] = mean["run"] - sum(mean[ph] for ph in STACK_PHASES)
        arm["host_s"] = mean["run"] - mean["patchmatch"]
        arms.append(arm)
    last = arms[-1]
    # thesis-4.3/gate-m2-decisions.md item 2; thesis-4.3/stage-input/analysis.md "Cheap track on base2 and the residual"
    close(arms[0]["phase_s"]["run"], 1106.1, 0.051, "base2 run"), close(last["phase_s"]["run"], 926.0, 0.051, "stack run")
    for got, exp in zip((last["vs_base"]["run"][k] for k in ("mean", "lo", "hi")), (-180.1, -185.0, -175.3)):
        close(got, exp, 0.051, "stack against base2")
    residual = sum(last["phase_s"][ph] for ph in ("input_load", "device_upload", "result_readback"))
    close(residual, 16.3, 0.051, "residual")
    return {"n": 3, "seeds": [1, 3], "ci_level_pct": 95, "t975": T975[2], "arms": arms,   # src: card files (n), H1.md section 7 (seeds 1-3, t(0.975, 2))
            "residual_s": residual, "phases": STACK_PHASES}


# =================================================================================================
# The anchor stack: kernel seconds per build and round (one profiled run each, seed 1)
# =================================================================================================
ANCHOR_KERNELS = ["FindNearestStrongPoint", "GenNeighbours", "InitRandomStates"]
# The builds of the reordered anchor stack (gate-m3-decisions.md item 2: K3 first, then K12), each
# on the one before it, the first on the fixed base, and the kernel each one changes. `run` is the
# name of the build's profiled run in the per-round files, `pair` the file that pairs it with its
# parent launch by launch. The build of the third change (1f81056) has the tree of the earlier
# 8f13b35, whose profiled run (k3 in kern-per-round.csv) is therefore its run; the builds of the
# fourth and fifth change have the trees of 79e9cf4 and 1bd5d5e.
# src: thesis-4.3/stage-anchor/cards/K12.md section 7 "Reordered" (commits, trees, pair files)
ANCHOR_ARMS = [  # key, commit, kernel changed, run, pair file
    ("base2", "6c1f7b1", None, "base2", None),
    ("k3", "e239b78", "GenNeighbours", "anchor2-k3", "kern-anchor2-k3-vs-base2.csv"),            # src: thesis-4.3/stage-anchor/cards/K3.md section 7
    ("k12", "0b66435", "GenNeighbours", "anchor2-k12", "kern-anchor2-k12-vs-k3.csv"),            # src: thesis-4.3/stage-anchor/cards/K12.md section 7
    ("k1c", "1f81056", "FindNearestStrongPoint", "k3", "kern-anchor2-k1c-vs-k12.csv"),           # src: thesis-4.3/stage-anchor/cards/K1c.md section 7
    ("gnl", "ef466db", "GenNeighbours", "gnl", "kern-gnl-vs-k3.csv"),                            # src: thesis-4.3/stage-anchor/cards/GN-L.md; K12.md section 7
    ("irs", "d6a087b", "InitRandomStates", "irs", "kern-irs-vs-gnl.csv"),                        # src: thesis-4.3/stage-anchor/cards/IRS.md; K12.md section 7
]
ANCHOR_PER_ROUND = ["kern-per-round.csv", "kern-per-round-anchor2.csv"]
# The same two changes in the order they were first built (K12 on the fixed base, K3 two builds
# later): what each took off GenNeighbours there.
ANCHOR_FIRST_ORDER = {"k12": "kern-k12-2-vs-base2.csv", "k3": "kern-k3-vs-k1c.csv"}
# Whole run of the stack against the fixed base: plain seeded native runs, seeds 1-3, run spans
# (phase `run`) on both sides, read from anchor-run-spans.csv. Seed 1 has three base runs, whose
# mean is its base value. The stack runs are s43-anchor-irs-plain-s1..3 (1bd5d5e, the tree of
# d6a087b). These are the runs of thesis-4.3/stage-anchor/cards/IRS.md section 5, which quotes the
# method wall time for four of the five base runs (about 0.9 s more than the span) and so gives
# another value; thesis-4.3/stack/comb.md section 1 has the span value, -157.7 s.


def anchor_stack(data):
    per = defaultdict(dict)
    for f in ANCHOR_PER_ROUND:
        for r in read_csv(data / f):
            rounds = [float(r[f"round{i}_s"]) for i in range(4)]
            close(sum(rounds), float(r["total_s"]), 0.0021, f"{r['run']} {r['kernel']}: rounds against total")
            assert r["kernel"] not in per[r["run"]], (f, r["run"], r["kernel"])
            per[r["run"]][r["kernel"]] = {"total_s": float(r["total_s"]), "round_s": rounds}
    arms, unchanged = [], []
    for i, (key, commit, changed, run, pair_file) in enumerate(ANCHOR_ARMS):
        assert sorted(per[run]) == sorted(ANCHOR_KERNELS), key
        arm = {"key": key, "commit": commit, "changed": changed, "run": run, "kernels": per[run],
               "anchor_s": sum(k["total_s"] for k in per[run].values()), "vs_parent": None}
        if i:
            parent = arms[-1]
            pair = {r["group"]: r for r in read_csv(data / pair_file)}
            arm["vs_parent"] = {}
            for k in ANCHOR_KERNELS:
                r = pair[k]
                assert int(r["n_launches"]) == 224
                # the fourth build is paired with the run of 8f13b35, the tree of its parent
                close(float(r["base_s"]), parent["kernels"][k]["total_s"], 0.0011, f"{key} vs {parent['key']} {k} base")
                close(float(r["cand_s"]), per[run][k]["total_s"], 0.0081, f"{key} vs {parent['key']} {k} cand")   # per-round values are rounded to 1 ms; after the last change they include the 0.007 s of the table build
                arm["vs_parent"][k] = {"delta_s": float(r["delta_s"])}
                if k != changed:   # a kernel whose code did not change: how well a profiled run repeats
                    unchanged.append(abs(float(r["delta_s"])))
            arm["all_kernels_s"] = float(pair["run (all kernels)"]["cand_s"])
            if i == 1:
                arms[0]["all_kernels_s"] = float(pair["run (all kernels)"]["base_s"])
        arms.append(arm)
    whole = {r["group"]: r for r in read_csv(data / "kern-irs-vs-base2.csv")}
    close(float(whole["anchor"]["base_s"]), arms[0]["anchor_s"], 0.002, "anchor kernels, base")
    close(float(whole["anchor"]["cand_s"]), arms[-1]["anchor_s"], 0.012, "anchor kernels, stack")
    close(float(whole["run (all kernels)"]["cand_s"]), arms[-1]["all_kernels_s"], 0.001, "all kernels, stack")
    # thesis-4.3/gate-m3-decisions.md item 1
    close(arms[0]["anchor_s"], 169.8, 0.051, "anchor kernels, base"), close(arms[-1]["anchor_s"], 16.6, 0.051, "anchor kernels, stack")
    # the two changes of GenNeighbours whose split depends on the order
    first = {k: float({r["group"]: r for r in read_csv(data / f)}["GenNeighbours"]["delta_s"]) for k, f in ANCHOR_FIRST_ORDER.items()}
    by_key = {a["key"]: a for a in arms}
    now = {k: by_key[k]["vs_parent"]["GenNeighbours"]["delta_s"] for k in ("k3", "k12")}
    # thesis-4.3/stage-anchor/cards/K12.md section 7 (K3 -27.88, K12 -21.95; first order: K12 -43.95, K3 -5.9)
    close(now["k3"], -27.88, 0.0051, "K3 on the fixed base"), close(now["k12"], -21.95, 0.0051, "K12 on K3")
    close(first["k3"], -5.9, 0.051, "K3 in the first order"), close(first["k12"], -43.95, 0.0051, "K12 in the first order")
    order = {"now": now, "first": first, "now_sum_s": sum(now.values()), "first_sum_s": sum(first.values())}
    spans = defaultdict(lambda: defaultdict(list))
    for r in read_csv(data / "anchor-run-spans.csv"):
        spans[r["arm"]][int(r["seed"])].append(float(r["span_s"]))
    assert sorted(spans["base2"]) == sorted(spans["anchor"]) == [1, 2, 3] and all(len(v) == 1 for v in spans["anchor"].values())
    base = [st.mean(spans["base2"][k]) for k in (1, 2, 3)]
    stack_runs = [spans["anchor"][k][0] for k in (1, 2, 3)]
    run = paired([c - b for b, c in zip(base, stack_runs)])
    # thesis-4.3/stack/comb.md section 1; thesis-4.3/README.md M6 (-157.7 s [-174.0, -141.4])
    for got, exp in zip((run["mean"], run["lo"], run["hi"]), (-157.7, -174.0, -141.4)):
        close(got, exp, 0.051, "whole run of the anchor stack against base2, run spans")
    return {"kernels": ANCHOR_KERNELS, "arms": arms, "launches": 224, "rounds": 4, "seed": 1,
            "repeatability_s": max(unchanged), "order": order,
            "run": {**run, "base_mean_s": st.mean(base), "stack_mean_s": st.mean(stack_runs), "base_by_seed": base,
                    "stack_by_seed": stack_runs, "base_s1_spans": spans["base2"][1], "seeds": [1, 3], "ci_level_pct": 95}}


def numbers_anchor(anc, sr):
    n = Numbers()
    put = n.put
    arms = {("base" if a["key"] == "base2" else a["key"]): a for a in anc["arms"]}
    short = {"FindNearestStrongPoint": "nearest", "GenNeighbours": "select", "InitRandomStates": "init"}
    per = "data/kern-per-round.csv, data/kern-per-round-anchor2.csv"
    for key, a in arms.items():
        for k, kk in short.items():
            put(f"{key}.{kk}_s", a["kernels"][k]["total_s"], f"{per} ({a['run']}, {k}, total_s)")
            put(f"{key}.{kk}_native_s", a["kernels"][k]["round_s"][-1], f"{per} ({a['run']}, {k}, round3_s: the native round)")
            put(f"{key}.{kk}_round_s", a["kernels"][k]["round_s"], f"{per} ({a['run']}, {k}, round0_s..round3_s)")
        put(f"{key}.anchor_s", a["anchor_s"], f"{per} ({a['run']}: the three kernels summed)")
        put(f"{key}.all_kernels_s", a["all_kernels_s"], f"data/kern-*-vs-*.csv ({a['key']}, run (all kernels))")
    b, last = arms["base"], arms["irs"]
    put("launches", anc["launches"], "data/kern-*-vs-*.csv (n_launches)")
    put("native_launches", anc["launches"] // anc["rounds"], "data/kern-*-vs-*.csv: n_launches / 4 rounds")
    put("repeatability_s", anc["repeatability_s"], "data/kern-*-vs-*.csv of the stack: largest |delta_s| of a kernel whose code is the same in both runs of a pair; thesis-4.3/stage-anchor/cards/K1c.md section 5 (at most 0.1 s)")
    assert anc["repeatability_s"] <= 0.1
    put("seed", anc["seed"], "thesis-4.3/stage-anchor/cards/K1c.md section 5 (nsys, native, APD_SEED=1)")
    put("changes", len(arms) - 1, "thesis-4.3/gate-m3-decisions.md items 1, 2 (K3, K12, K1c, GN-L, IRS)")
    put("base.anchor_share_of_kernels", b["anchor_s"] / b["all_kernels_s"], "data/kern-irs-vs-base2.csv: anchor / run (all kernels), base2")
    put("base.native_share", sum(k["round_s"][-1] for k in b["kernels"].values()) / b["anchor_s"], f"{per} (base2: round3_s of the three kernels / their totals)")
    # ---- gains per change, in the kernel it changes
    gain = lambda a, c, k: arms[a]["kernels"][k]["total_s"] - arms[c]["kernels"][k]["total_s"]
    put("k3.select_gain_s", gain("base", "k3", "GenNeighbours"), "data/kern-anchor2-k3-vs-base2.csv (GenNeighbours)")
    put("k3.select_gain_share", gain("base", "k3", "GenNeighbours") / b["kernels"]["GenNeighbours"]["total_s"], "data/kern-anchor2-k3-vs-base2.csv: GenNeighbours delta / base")
    put("k12.select_gain_s", gain("k3", "k12", "GenNeighbours"), "data/kern-anchor2-k12-vs-k3.csv (GenNeighbours)")
    put("k12.select_gain_share", gain("k3", "k12", "GenNeighbours") / arms["k3"]["kernels"]["GenNeighbours"]["total_s"], "data/kern-anchor2-k12-vs-k3.csv: GenNeighbours delta / base")
    put("k1c.nearest_speedup", arms["k12"]["kernels"]["FindNearestStrongPoint"]["total_s"] / arms["k1c"]["kernels"]["FindNearestStrongPoint"]["total_s"], "data/kern-anchor2-k1c-vs-k12.csv: FindNearestStrongPoint base_s / cand_s; thesis-4.3/stage-anchor/cards/K1c.md section 5 (167x)")
    nl = anc["launches"] // anc["rounds"]
    put("k12.nearest_native_launch_s", arms["k12"]["kernels"]["FindNearestStrongPoint"]["round_s"][-1] / nl, f"{per}: anchor2-k12 FindNearestStrongPoint round3_s / 56 launches")
    put("k1c.nearest_native_launch_ms", 1e3 * arms["k1c"]["kernels"]["FindNearestStrongPoint"]["round_s"][-1] / nl, f"{per}: k3 (the tree of 1f81056) FindNearestStrongPoint round3_s / 56 launches")
    put("gnl.select_gain_s", gain("k1c", "gnl", "GenNeighbours"), "data/kern-gnl-vs-k3.csv (GenNeighbours)")
    put("irs.init_gain_s", gain("gnl", "irs", "InitRandomStates"), "data/kern-irs-vs-gnl.csv (InitRandomStates)")
    # ---- the two changes of GenNeighbours in either order
    o = anc["order"]
    put("order.k3_s", -o["now"]["k3"], "data/kern-anchor2-k3-vs-base2.csv (GenNeighbours, -delta_s): the first change on the fixed base")
    put("order.k12_s", -o["now"]["k12"], "data/kern-anchor2-k12-vs-k3.csv (GenNeighbours, -delta_s): the second change on the first")
    put("order.sum_s", -o["now_sum_s"], "data/kern-anchor2-k3-vs-base2.csv + data/kern-anchor2-k12-vs-k3.csv (GenNeighbours, -delta_s); thesis-4.3/stage-anchor/cards/K12.md section 7 (about 49.8 s)")
    put("order.first.k12_s", -o["first"]["k12"], "data/kern-k12-2-vs-base2.csv (GenNeighbours, -delta_s): the register change built first, on the fixed base (ec3228a)")
    put("order.first.k3_s", -o["first"]["k3"], "data/kern-k3-vs-k1c.csv (GenNeighbours, -delta_s): the probe change built on top of it (8f13b35)")
    put("order.first.sum_s", -o["first_sum_s"], "data/kern-k12-2-vs-base2.csv + data/kern-k3-vs-k1c.csv (GenNeighbours, -delta_s)")
    assert abs(o["now_sum_s"] - o["first_sum_s"]) < 0.05, "the two orders remove the same time"
    put("stack.anchor_gain_s", b["anchor_s"] - last["anchor_s"], "data/kern-irs-vs-base2.csv (anchor)")
    put("stack.anchor_gain_share", 1 - last["anchor_s"] / b["anchor_s"], "data/kern-irs-vs-base2.csv: 1 - anchor cand_s / base_s")
    put("stack.all_kernels_gain_s", b["all_kernels_s"] - last["all_kernels_s"], "data/kern-irs-vs-base2.csv (run (all kernels)); thesis-4.3/stage-anchor/cards/IRS.md section 5 (-153.4 s)")
    r = anc["run"]
    run_src = "data/anchor-run-spans.csv (span_s of the stack run - mean span_s of the base2 runs of the seed, paired by seed, t 2 dof); thesis-4.3/stack/comb.md section 1 (-157.7 s)"
    n.put_stat("stack.run", r, run_src)
    put("stack.run_n", r["n"], "thesis-4.3/stage-anchor/cards/IRS.md section 5 (n = 3)")
    put("stack.run_seeds", r["seeds"], "thesis-4.3/stage-anchor/cards/IRS.md section 5 (seeds 1-3)")
    put("stack.run_base_s", r["base_mean_s"], "data/anchor-run-spans.csv (base2: mean over the seeds of the mean span_s of a seed)")
    put("stack.run_stack_s", r["stack_mean_s"], "data/anchor-run-spans.csv (anchor: mean span_s); thesis-4.3/stage-anchor/cards/IRS.md section 5 (952.6 / 946.3 / 942.2 s)")
    put("stack.run_share", -r["mean"] / r["base_mean_s"], "mean difference / base mean, run spans")
    put("stack.base_s1_spans", r["base_s1_spans"], "data/anchor-run-spans.csv (base2, seed 1: span_s of its three runs)")
    put("stack.init_phase_s", [171.8, 18.6], "thesis-4.3/stage-anchor/cards/K12.md section 7 (patchmatch.init 171.8 s on base2), IRS.md section 5 (18.6 s)")
    put("ci_level_pct", r["ci_level_pct"], "thesis-4.3/stage-anchor/cards/IRS.md section 5 (t(0.975, 2))")
    # ---- combined with the input stack
    c = sr["comb"]
    cs = "data/comb-vs-base2.csv"
    n.put_stat("comb.run", c["run"], f"{cs} (comb, run: delta, ci_lo, ci_hi; paired by seed, t 2 dof); data/phases-stack.csv gives the same within 0.06 s")
    put("comb.base_run_s", c["base_run_s"], f"{cs} (comb, run, mean_vs)")
    put("comb.run_s", c["run_s"], f"{cs} (comb, run, mean_arm)")
    put("comb.run_share", c["run_share"], f"{cs}: -delta / mean_vs of run")
    put("comb.seeds", [1, 3], "thesis-4.3/stack/comb.md section 5 (seeds 1-3)")
    put("comb.commits", 10, "thesis-4.3/stack/comb.md section 2 (ten commits on base2, one per card, timers included)")
    put("comb.gate_input_s", c["gate_input_s"], "data/card-h3h6.csv (h3h6 vs base2, run, delta): the input stack as accepted (thesis-4.3/gate-m2-decisions.md item 2)")
    put("comb.gate_anchor_s", c["gate_anchor_s"], run_src)
    put("comb.gate_sum_s", c["gate_sum_s"], "the two values above summed; thesis-4.3/stack/comb.md section 5 (-337.8 s)")
    put("comb.of_gate_sum", c["of_gate_sum"], f"{cs} (comb, run, delta) / the sum of the two gate values; thesis-4.3/stack/comb.md section 5 (98.8 %)")
    put("comb.additivity_max_s", c["additivity_max_s"], f"{cs}: largest |mean_arm of comb - mean_arm of the stack that changes the phase| over input_load, device_upload, result_readback, patchmatch.readback (input arm), patchmatch.init (anchor arm), and |delta| of comb for patchmatch.propagate and patchmatch.finalize (neither); thesis-4.3/stack/comb.md section 5 (within 0.3 s)")
    put("comb.anchor_arm_input_load_s", c["anchor_arm_input_load_s"], f"{cs} (anchor, input_load, delta): host time that the anchor stack does not touch; the anchor stack runs paired with s43-base2-native-s1..3")
    put("comb.anchor_arm_fusion_s", c["anchor_arm_fusion_s"], f"{cs} (anchor, fusion, delta): host time that the anchor stack does not touch")
    n.put_stat("comb.anchor_arm_patchmatch", c["anchor_arm_patchmatch"], f"{cs} (anchor, patchmatch: delta, ci_lo, ci_hi)")
    n.put_stat("comb.anchor_arm_run", c["anchor_arm_run"], f"{cs} (anchor, run: delta, ci_lo, ci_hi; the anchor stack runs paired with s43-base2-native-s1..3 only)")
    put("comb.drift.base_run_s", c["drift"]["base_run_s"], f"{cs} (drift, run: mean_vs = the stored base2 run of seed 1, mean_arm = the base2 run repeated in the session of the comb runs)")
    put("comb.drift.base_input_load_s", c["drift"]["base_input_load_s"], f"{cs} (drift, input_load: mean_vs, mean_arm)")
    put("comb.drift.run_s", c["drift"]["run_s"], f"{cs} (drift, run, delta)")
    put("comb.drift.input_load_s", c["drift"]["input_load_s"], f"{cs} (drift, input_load, delta)")
    put("comb.drift.patchmatch_s", c["drift"]["patchmatch_s"], f"{cs} (drift, patchmatch, delta)")
    put("comb.drift.base_patchmatch_s", c["drift"]["base_patchmatch_s"], f"{cs} (drift, patchmatch: mean_vs, mean_arm)")
    put("comb.drift.vs_fresh_s1_s", c["drift"]["vs_fresh_s1_s"], f"data/phases-stack.csv (comb, seed 1, run) - {cs} (drift, run, mean_arm); thesis-4.3/stack/comb.md section 5 (-321.2 s)")
    put("comb.e0_native_seeds", 3, "thesis-4.3/stack/comb.md section 4 (native, seeds 1-3: md5 of base2)")
    put("comb.e0_small_seeds", 3, "thesis-4.3/stack/comb.md section 4 (1024, seeds 1-3: md5 of base2)")
    put("comb.memory_mb", 59, "thesis-4.3/stack/comb.md section 5 \"Device memory\" (26 MB + 33 MB at native)")
    put("comb.office_gpu_peak_mib", [9714, 9774], "thesis-4.3/stack/comb.md section 5 \"Device memory\" (samplers/gpu.csv of s43-input-h3h6-office-s1 and s43-comb-office-s1)")
    put("comb.bench_gpu_memory_gb", 12, "PLAN-4.3.md decision D1")
    # ---- what the stage does
    put("window.radius", 100, "thesis-4.3/stage-anchor/cards/K1c.md section 2 (|dy| <= 100; x = -100 ... 100)")
    put("window.side", 201, "thesis-4.3/stage-anchor/cards/K1c.md section 1 (201 x 201 window)")
    put("window.samples", 201 * 201, "201 x 201; thesis-4.3/stage-anchor/cards/K1c.md section 1 (40,401)")
    put("window.two_pass_samples", 201 + 201, "thesis-4.3/stage-anchor/cards/K1c.md section 5 (at most 201 + 201 loads per pixel)")
    put("window.none_share", 0.047, "thesis-4.3/stage-anchor/cards/K1c.md section 1; thesis-4.3/stage-anchor/analysis.md section 1 (4.7 % of unreliable pixels have no reliable pixel in the window)")
    put("window.median_px", 8, "thesis-4.3/stage-anchor/analysis.md section 1 (distance to the nearest reliable pixel: median 8 px, native round)")
    put("window.sqrt_values", 3737, "thesis-4.3/stage-anchor/cards/K1c.md section 2 (sqrtmono test: 3737 distinct squared distances, none not increasing)")
    put("spokes.max", 32, "thesis-4.3/stage-anchor/analysis.md \"Terms\" (up to 32 spokes)")
    put("spokes.tries", 4, "thesis-4.3/stage-anchor/cards/K3.md section 1 (up to 4 tries per radius step)")
    put("spokes.draws_per_try", 4, "thesis-4.3/stage-anchor/cards/K3.md section 2 (each try consumes exactly 4 draws)")
    put("spokes.draws_skipped", 12, "thesis-4.3/stage-anchor/cards/K3.md section 2 (the 12 draws of tries 1-3)")
    put("spokes.tries_per_step", 3.6, "thesis-4.3/stage-anchor/cards/K3.md section 1; thesis-4.3/stage-anchor/analysis.md section 1 (3.6 tries per radius step)")
    put("spokes.shift_ranges_coarse", [8, 3], "thesis-4.3/stage-anchor/cards/K3.md section 1 (shift_range 8 and 3 in the two coarsest rounds)")
    put("spokes.fine_rounds", [3, 4], "thesis-4.3/stage-anchor/cards/K3.md section 1 (rounds i = 2, 3 of the code: the two finest; numbered from 1 here)")
    put("spokes.cone_deg", 11.25, "thesis-4.3/stage-anchor/analysis.md \"Terms\" (11.25 degree cone)")
    put("ransac.iterations", 50, "thesis-4.3/stage-anchor/analysis.md \"Terms\" (50-iteration RANSAC)")
    put("anchors.kept", 8, "thesis-4.3/stage-anchor/analysis.md \"Terms\" (8 anchors)")
    put("sort.moves", 250, "thesis-4.3/stage-anchor/cards/GN-L.md section 3 (about n^2/4 = 250 element moves)")
    put("sort.registers", 16, "thesis-4.3/stage-anchor/cards/GN-L.md section 3 (8 pairs in 16 registers)")
    put("sort.stall_share", 0.137, ".dev/findings/genneighbours-local-memory.md (sort_small_weighted: 13.7 % of stall samples)")
    put("sort.local_l1_hit", 0.50, ".dev/findings/genneighbours-local-memory.md (local loads: 50 % L1 hit)")
    put("k12.ncu.l2_busy", [0.91, 0.46], "thesis-4.3/stage-anchor/cards/K12.md section 5 (L2 busy 91 -> 46 %, one native launch, on the unfixed base, with the K10 change also present)")
    put("k12.ncu.launch_ms", [747, 290], "thesis-4.3/stage-anchor/cards/K12.md section 5 (launch duration 747 -> 290 ms, same launch)")
    w, h = 6220, 4141   # .dev/findings/native-nondeterminism.md (native size)
    put("init.pixels_millions", w * h / 1e6, "6220 x 4141 px; thesis-4.3/stage-anchor/cards/IRS.md section 1 (25.8 M native pixels)")
    put("init.state_bits", 160, "thesis-4.3/stage-anchor/cards/IRS.md section 1 (160-bit state)")
    put("init.products_before", 20, "thesis-4.3/stage-anchor/cards/IRS.md section 3 (about 20 matrix-vector products per thread)")
    put("init.products_after", 2, "thesis-4.3/stage-anchor/cards/IRS.md section 3 (two products)")
    put("init.table_mb", 33, "thesis-4.3/stage-anchor/cards/IRS.md section 2 (33 MB at native)")
    put("init.table_builds", 4, "thesis-4.3/stage-anchor/cards/IRS.md section 2, section 5 (4 launches, once per round)")
    put("init.table_build_s", 0.007, "thesis-4.3/stage-anchor/cards/IRS.md section 5 (BuildSkipaheadTables, 4 launches, 0.007 s)")
    put("init.stall_share", 0.86, "thesis-4.3/stage-anchor/cards/IRS.md section 1 (86 % of the stall samples in the skip-ahead loop, on the unfixed base)")
    # ---- exactness evidence
    put("e0.small_px", 1024, "thesis-4.3/stage-anchor/cards/*.md section 4")
    put("e0.mid_px", 2048, "thesis-4.3/stage-anchor/cards/*.md section 4")
    put("e0.small_seeds", 3, "thesis-4.3/stage-anchor/cards/*.md section 4 (1024: seeds 1-3 for K1c, GN-L, IRS and for the trees they sit on)")
    put("e0.reorder_seeds", 1, "thesis-4.3/stage-anchor/cards/K12.md section 7 \"Reordered\" (K3 on base2 and K12 on K3: 1024 seed 1 and native seed 1, each = base2)")
    put("e0.tree_mid_seeds", 3, "thesis-4.3/stage-anchor/cards/K3.md section 4 (2048: seeds 1-3 = base2 for the tree 8f13b35, which is the tree of the third build 1f81056: K12.md section 7)")
    put("e0.k12_old_seeds", 20, "thesis-4.3/stage-anchor/cards/K12.md section 4 (20/20 seeds at 1024 on the unfixed base)")
    put("e0.k12_alone_mid_seeds", 2, "thesis-4.3/stage-anchor/cards/K12.md section 7 (K12 alone on base2 at 2048: seeds 1-2 = base2)")
    put("e0.stack_native_seeds", 3, "thesis-4.3/stage-anchor/cards/IRS.md section 4 (native: seeds 1-3); thesis-4.3/gate-m3-decisions.md item 1")
    put("e0.small_rounds", 2, "thesis-4.3/stage-anchor/cards/K3.md section 4 (2 rounds at 1024)")
    put("e0.mid_rounds", 3, "thesis-4.3/stage-anchor/cards/K3.md section 4 (3 rounds at 2048)")
    put("k12.alone_runs", 2, "thesis-4.3/stage-anchor/cards/K12.md section 7 (native seed 1: 0eb33545 in the nsys and in the plain run)")
    put("k12.f1_2cm", [0.875291, 0.875238], "thesis-4.3/stage-anchor/cards/K12.md section 7 (native seed 1, F1 at 2 cm: with the change alone on the fixed base, fixed base)")
    put("k12.sass", {"ffma": [151, 211], "fmul": [292, 348], "fadd": [198, 196], "rsq": [12, 25], "rcp": [13, 18]},
        ".dev/findings/k12-native-codegen.md (instruction counts of GenNeighbours: fixed base, with the register change alone; with the probe change also present they are those of the fixed base again)")
    put("tol.decides_cm", 2, "thesis-4.3/acceptance.md, decision D2 (all at 2 cm F1)")
    # ---- what is left
    put("left.rs1_s", [1, 2], "thesis-4.3/README.md M3 table (RS1: about 1-2 s left after K3)")
    return n


# =================================================================================================
# The stacks combined: run time of the fixed base, of the input and anchor stacks together, and
# of that stack with the propagation changes (plain seeded native runs, seeds 1-3, paired by seed)
# =================================================================================================
STACK_ARMS = [  # arm in phases-stack.csv, commit
    ("base2", "6c1f7b1"),
    ("comb", "0e63a9e"),        # src: thesis-4.3/stack/comb.md (input stack + reordered anchor stack)
    ("prop-comb", "714ed21"),   # src: thesis-4.3/README.md M4 (comb + the first five propagation changes)
    ("prop-comb-cu2", "5cf8608"),   # src: thesis-4.3/README.md M4 (the sixth propagation change as one more commit); thesis-4.3/stage-prop/data/wall-propcomb-cu2-vs-714ed21.csv
    ("prop-8bit", "ee07854"),       # src: thesis-4.3/stage-prop/cards/8bit.md (8-bit image textures at native scale, on 5cf8608)
    ("class-comb", "1069a53"),      # src: thesis-4.3/stack/class-comb.md (the five classification changes, on ee07854)
]
# the file of the card files that pairs the run spans of a build with those of the build before
# (the last has five seeds; the rows of this figure use the first three, as the builds above it)
STACK_WALL = {"prop-comb": "wall-propcomb-vs-comb.csv", "prop-comb-cu2": "wall-propcomb-cu2-vs-714ed21.csv", "prop-8bit": "tier1-8bit-vs-comb-cu2.csv",
              "class-comb": "wall-comb-vs-ee07854.csv"}
STACK_PARTS = [  # key, phases summed
    ("initialization", ["patchmatch.init"]),
    ("propagation", ["patchmatch.propagate", "prior_build"]),
    ("finalization", ["patchmatch.finalize"]),
    ("input_load", ["input_load"]),
    ("transfers", ["device_upload", "result_readback", "patchmatch.readback"]),
]
COMB_PHASES_INPUT = ["input_load", "device_upload", "result_readback", "patchmatch.readback"]   # what the input stack changes
COMB_PHASES_ANCHOR = ["patchmatch.init"]                                                        # what the anchor stack changes
COMB_PHASES_NEITHER = ["patchmatch.propagate", "patchmatch.finalize"]


def stack_run(data, stack, anc):
    per = defaultdict(lambda: defaultdict(dict))
    for r in read_csv(data / "phases-stack.csv"):
        per[r["arm"]][int(r["seed"])][r["phase"]] = float(r["seconds"])
    seeds = [1, 2, 3]
    arms = []
    for i, (key, commit) in enumerate(STACK_ARMS):
        assert sorted(per[key]) == seeds, key
        mean = lambda ph: st.mean(per[key][k][ph] for k in seeds)
        parts = [{"key": pk, "phases": ph, "s": sum(mean(x) for x in ph)} for pk, ph in STACK_PARTS]
        parts.append({"key": "rest", "phases": [], "s": mean("run") - sum(x["s"] for x in parts)})   # fusion, setup, output, untimed parts of a pass
        run = [per[key][k]["run"] for k in seeds]
        arm = {"key": key, "commit": commit, "run_s": st.mean(run), "run_by_seed": run, "parts": parts,
               "phase_s": {ph: mean(ph) for ph in per[key][1]}, "vs_parent": None, "vs_base": None}
        if i:
            d = lambda other: {k: v for k, v in paired([a - b for a, b in zip(run, other["run_by_seed"])]).items() if k in ("mean", "lo", "hi")}
            arm["vs_parent"], arm["vs_base"] = d(arms[-1]), d(arms[0])
        arms.append(arm)
    base, comb, prop, prop6, prop8, cls = arms

    # ---- the input and anchor stacks combined, against the file of the card
    rows = {(r["arm"], r["phase"]): r for r in read_csv(data / "comb-vs-base2.csv")}
    assert all(r["vs"] == "base2" for r in rows.values())
    c = rows[("comb", "run")]
    # The differences that are printed are those of the card files, which pair run spans rounded
    # to 0.1 s; the unrounded spans of phases-stack.csv give the same within 0.06 s.
    card = {k2: float(c[k1]) for k1, k2 in (("delta", "mean"), ("ci_lo", "lo"), ("ci_hi", "hi"))}
    for k in card:
        close(comb["vs_base"][k], card[k], 0.06, f"comb against base2, run {k}: phases-stack.csv against comb-vs-base2.csv")
    comb["vs_base"] = comb["vs_parent"] = card
    close(base["run_s"], float(c["mean_vs"]), 0.03, "base2 run"), close(comb["run_s"], float(c["mean_arm"]), 0.03, "comb run")
    # thesis-4.3/stack/comb.md section 5; thesis-4.3/README.md M6
    for k, exp in zip(("mean", "lo", "hi"), (-333.9, -338.4, -329.4)):
        close(comb["vs_base"][k], exp, 0.051, "comb against base2")
    ma = lambda arm, ph: float(rows[(arm, ph)]["mean_arm"])
    add = max([abs(ma("comb", ph) - ma("input", ph)) for ph in COMB_PHASES_INPUT]
              + [abs(ma("comb", ph) - ma("anchor", ph)) for ph in COMB_PHASES_ANCHOR]
              + [abs(float(rows[("comb", ph)]["delta"])) for ph in COMB_PHASES_NEITHER])
    assert add <= 0.3 + 1e-9, add
    gate_input = stack["arms"][-1]["vs_base"]["run"]["mean"]
    gate_anchor = anc["run"]["mean"]
    close(gate_input + gate_anchor, -337.8, 0.07, "sum of the two gate values")   # the card sums the rounded values, -180.1 and -157.7
    close(float(c["delta"]) / (gate_input + gate_anchor), 0.988, 0.0005, "comb as a share of the summed gates")
    fresh = float(rows[("drift", "run")]["mean_arm"])
    vs_fresh = per["comb"][1]["run"] - fresh
    close(vs_fresh, -321.2, 0.051, "comb seed 1 against the base2 run of its session")
    assert rows[("drift", "patchmatch")]["n"] == "1"
    comb_out = {
        "run": comb["vs_base"], "base_run_s": float(c["mean_vs"]), "run_s": float(c["mean_arm"]),
        "run_share": -float(c["delta"]) / float(c["mean_vs"]),
        "gate_input_s": gate_input, "gate_anchor_s": gate_anchor, "gate_sum_s": gate_input + gate_anchor,
        "of_gate_sum": float(c["delta"]) / (gate_input + gate_anchor),
        "additivity_max_s": add,
        "anchor_arm_input_load_s": float(rows[("anchor", "input_load")]["delta"]),
        "anchor_arm_fusion_s": float(rows[("anchor", "fusion")]["delta"]),
        "anchor_arm_patchmatch": {k2: float(rows[("anchor", "patchmatch")][k1]) for k1, k2 in (("delta", "mean"), ("ci_lo", "lo"), ("ci_hi", "hi"))},
        "anchor_arm_run": {k2: float(rows[("anchor", "run")][k1]) for k1, k2 in (("delta", "mean"), ("ci_lo", "lo"), ("ci_hi", "hi"))},
        "drift": {"base_run_s": [float(rows[("drift", "run")]["mean_vs"]), fresh],
                  "base_input_load_s": [float(rows[("drift", "input_load")]["mean_vs"]), float(rows[("drift", "input_load")]["mean_arm"])],
                  "run_s": float(rows[("drift", "run")]["delta"]), "input_load_s": float(rows[("drift", "input_load")]["delta"]),
                  "patchmatch_s": float(rows[("drift", "patchmatch")]["delta"]), "vs_fresh_s1_s": vs_fresh,
                  "base_patchmatch_s": [float(rows[("drift", "patchmatch")]["mean_vs"]), float(rows[("drift", "patchmatch")]["mean_arm"])]},
    }
    # ---- the propagation changes on top, against the file of the card
    base_span = {int(r["seed"]): float(r["ref_span_s"]) for r in read_csv(data / "tier1-k2stack-vs-base2.csv")}   # the same base2 runs, s43-base2-native-s1..3
    md5 = {}
    for arm, parent in ((prop, comb), (prop6, prop), (prop8, prop6), (cls, prop8)):
        wall = [r for r in read_csv(data / STACK_WALL[arm["key"]]) if int(r["seed"]) in seeds]
        assert [int(r["seed"]) for r in wall] == seeds
        for r in wall:
            close(base_span[int(r["seed"])], per["base2"][int(r["seed"])]["run"], 0.051, "base2 span")
            close(float(r["ref_span_s"]), parent["run_by_seed"][int(r["seed"]) - 1], 0.051, f"{arm['key']}: span of the build before")
        for key, d in (("vs_parent", paired([float(r["cand_span_s"]) - float(r["ref_span_s"]) for r in wall])),
                       ("vs_base", paired([float(r["cand_span_s"]) - base_span[int(r["seed"])] for r in wall]))):
            for k in ("mean", "lo", "hi"):
                close(arm[key][k], d[k], 0.1, f"{arm['key']}, run {key} {k}: phases-stack.csv against {STACK_WALL[arm['key']]}")   # 0.1 s rounding of three spans, times t / sqrt(3)
            arm[key] = {k: d[k] for k in ("mean", "lo", "hi")}
        md5[arm["key"]] = [r["cand_md5"] for r in wall]
    # thesis-4.3/README.md M4 (772.9 -> 620.1 s, -152.8 s [-153.2, -152.5]; -486.7 s against base2)
    close(comb["run_s"], 772.9, 0.051, "comb run"), close(prop["run_s"], 620.1, 0.051, "prop-comb run")
    for got, exp in zip((prop["vs_parent"][k] for k in ("mean", "lo", "hi")), (-152.8, -153.2, -152.5)):
        close(got, exp, 0.051, "prop-comb against comb")
    close(prop["vs_base"]["mean"], -486.7, 0.051, "prop-comb against base2")
    return {"n": len(seeds), "seeds": [seeds[0], seeds[-1]], "ci_level_pct": 95, "t975": T975[len(seeds) - 1],
            "arms": arms, "parts": [k for k, _ in STACK_PARTS] + ["rest"], "comb": {**comb_out, "run": card},
            "last_five_seeds": {k: v for k, v in paired([float(r["cand_span_s"]) - float(r["ref_span_s"]) for r in read_csv(data / STACK_WALL["prop-8bit"])]).items() if k in ("n", "mean", "lo", "hi")},   # src: data/tier1-8bit-vs-comb-cu2.csv, all five seeds
            "prop_changes": 5,   # src: thesis-4.3/README.md M4 (714ed21: the first five propagation changes on the combined stack)
            "prop_md5": md5["prop-comb"], "prop6_md5": md5["prop-comb-cu2"]}
    # (the row of the 8-bit textures has no clouds to compare with: its clouds are its own)


# =================================================================================================
# The propagation stack: kernel seconds per build (one profiled run each, seed 1), the run time
# and F1 of each build against the one before (plain seeded runs, paired by seed), and the
# counters of one native launch per build
# =================================================================================================
PROP_GROUPS = [  # key, group in the kern files, stage
    ("weak", "weak (Black+Red)", "propagation"),
    ("strong", "strong (Black+Red)", "propagation"),
    ("fit", "RANSACToGetFitPlane", "propagation"),
    ("depth_to_weak", "DepthToWeak", "finalization"),
    ("local_refine", "LocalRefine", "finalization"),
    ("gen_neighbours", "GenNeighbours", "initialization"),
]
# The builds in the order they were stacked on the fixed base. `cls` is the exactness class against
# the build before; `changed` the kernels whose code or whose textures the change touches; `pair`
# the profiled runs paired by launch; `runs` the plain seeded runs of the build and of its parent
# (run span, md5, and for an E1 change F1 of both sides); `tier1` whether that file is the Tier 1
# test of the change.
PROP_ARMS = [  # key, commit, class, kernels changed, pair file, runs file, tier 1
    ("base2", "6c1f7b1", None, (), None, None, False),
    ("k10", "fceb9da", "E1", ("weak", "strong", "depth_to_weak", "local_refine"), "kern-k10-2-vs-base2.csv", "tier1-k10-2-vs-base2.csv", True),          # src: thesis-4.3/stage-prop/cards/K10.md section 7
    ("reftex", "b58418d", "E0", ("weak", "strong", "depth_to_weak", "local_refine"), "kern-reftex-2-vs-k10-2.csv", "wall-reftex-2-vs-k10-2.csv", False),  # src: thesis-4.3/stage-prop/cards/reftex.md section 7
    ("k2", "3f4ee3b", "E1", ("weak", "strong"), "kern-k2-vs-reftex-2.csv", "tier1-k2-vs-reftex-2.csv", True),                                             # src: thesis-4.3/stage-prop/cards/K2.md
    ("k11", "994ca07", "E0", ("weak",), "kern-k11-vs-k2.csv", "wall-k11-vs-k2.csv", False),                                                               # src: thesis-4.3/stage-prop/cards/K11.md
    ("k7lite", "6a05fa5", "E0", ("weak", "strong"), "kern-k7lite-vs-k11.csv", "wall-k7lite-vs-k11.csv", False),                                           # src: thesis-4.3/stage-prop/cards/K7lite.md
    ("cu2", "1da29de", "E1", ("weak", "strong", "depth_to_weak", "local_refine"), "kern-cu2-vs-k7lite.csv", "tier1-cu2-vs-k7lite.csv", True),             # src: thesis-4.3/stage-prop/cards/CU2.md
]
# the cards: run difference against the parent (s), and for the E1 changes F1 at 2 cm
EXPECTED_PROP = {
    "k10": {"run": (-74.6, -81.8, -67.4), "f1": (0.0006, -0.0007, 0.0018), "weak": -11.84, "strong": -25.75},
    "reftex": {"run": (-13.5, -19.3, -7.7), "weak": -3.92, "strong": -0.78},
    "k2": {"run": (-42.9, -44.2, -41.7), "f1": (-0.0007, -0.0016, 0.0002), "weak": -39.29, "strong": -3.40},
    "k11": {"run": (-15.0, -23.3, -6.7), "weak": -15.27, "strong": -0.00},
    "k7lite": {"run": (-13.7, -20.6, -6.9), "weak": -6.40, "strong": -4.38},
    "cu2": {"run": (-5.6, -10.8, -0.4), "f1": (0.0002, -0.0005, 0.0009), "weak": -3.58, "strong": -1.14},
}


def f1_pairs(rows):
    s = paired([float(r["cand_f1_2"]) - float(r["ref_f1_2"]) for r in rows])
    assert -MARGIN_TIER1 < s["lo"] and s["hi"] < MARGIN_TIER1, "Tier 1 at 2 cm"
    return {k: s[k] for k in ("n", "mean", "lo", "hi")}


def prop_stack(data):
    arms, e0_untouched, e1_untouched = [], [], []
    for i, (key, commit, cls, changed, pair_file, runs_file, tier1) in enumerate(PROP_ARMS):
        arm = {"key": key, "commit": commit, "class": cls, "changed": list(changed), "vs_parent": None, "run": None, "f1_2cm": None}
        if i == 0:
            arms.append(arm)
            continue
        parent = arms[-1]
        pair = {r["group"]: r for r in read_csv(data / pair_file)}
        if i == 1:
            parent["kernels"] = {k: float(pair[g]["base_s"]) for k, g, _ in PROP_GROUPS}
            parent["prop_s"], parent["all_kernels_s"] = float(pair["propagation"]["base_s"]), float(pair["run (all kernels)"]["base_s"])
        arm["kernels"] = {k: float(pair[g]["cand_s"]) for k, g, _ in PROP_GROUPS}
        arm["prop_s"], arm["all_kernels_s"] = float(pair["propagation"]["cand_s"]), float(pair["run (all kernels)"]["cand_s"])
        for k, g, _ in PROP_GROUPS:   # the candidate of one pair is the base of the next: the same profiled run
            close(float(pair[g]["base_s"]), parent["kernels"][k], 0.00011, f"{key}: base of {g} against the build before")
        for a in (parent, arm):
            close(sum(a["kernels"][k] for k, _, stg in PROP_GROUPS if stg == "propagation"), a["prop_s"], 0.001, f"{a['key']}: propagation kernels")
        arm["vs_parent"] = {k: float(pair[g]["delta_s"]) for k, g, _ in PROP_GROUPS}
        arm["vs_parent"]["prop"] = float(pair["propagation"]["delta_s"])
        arm["vs_parent"]["all_kernels"] = float(pair["run (all kernels)"]["delta_s"])
        (e0_untouched if cls == "E0" else e1_untouched).extend(abs(arm["vs_parent"][k]) for k, _, _ in PROP_GROUPS if k not in changed)
        runs = read_csv(data / runs_file)
        same = [r["cand_md5"] == r["ref_md5"] for r in runs]
        assert all(same) if cls == "E0" else not any(same), f"{key}: md5 against the class {cls}"
        arm["run"] = {k: v for k, v in paired([float(r["cand_span_s"]) - float(r["ref_span_s"]) for r in runs]).items() if k in ("n", "mean", "lo", "hi")}
        arm["run_s"] = st.mean(float(r["cand_span_s"]) for r in runs)
        arm["md5_seeds"] = len(runs)
        if tier1:
            arm["f1_2cm"] = f1_pairs(runs)
        exp = EXPECTED_PROP[key]
        for got, e in zip((arm["run"][k] for k in ("mean", "lo", "hi")), exp["run"]):
            close(got, e, 0.051, f"{key}: run against the parent")
        if tier1:
            for got, e in zip((arm["f1_2cm"][k] for k in ("mean", "lo", "hi")), exp["f1"]):
                close(round(got, 4), e, 1e-9, f"{key}: F1 at 2 cm against the parent")
        close(arm["vs_parent"]["weak"], exp["weak"], 0.0051, f"{key}: weak"), close(arm["vs_parent"]["strong"], exp["strong"], 0.0051, f"{key}: strong")
        arms.append(arm)
    # the first five changes against the fixed base: F1 (the seeds of the third change; the two after it are E0)
    stack_f1 = f1_pairs(read_csv(data / "tier1-k2stack-vs-base2.csv"))
    for got, e in zip((stack_f1[k] for k in ("mean", "lo", "hi")), (-0.0001, -0.0015, 0.0012)):   # thesis-4.3/gate-m4-decisions.md item 1
        close(round(got, 4), e, 1e-9, "F1 at 2 cm of the five changes against base2")
    # all six changes against the fixed base: F1 of the runs of the sixth build against that of the
    # base2 runs of the same seeds (the two columns are in different files; no note quotes this one)
    base_f1 = {r["seed"]: (r["ref_run"], r["ref_f1_2"]) for r in read_csv(data / "tier1-k2stack-vs-base2.csv")}
    six_rows = [{"cand_f1_2": r["cand_f1_2"], "ref_f1_2": base_f1[r["seed"]][1]} for r in read_csv(data / "tier1-cu2-vs-k7lite.csv")]
    assert len(six_rows) == 5 and all(v[0] == f"s43-base2-native-s{k}" for k, v in base_f1.items())
    six_f1 = f1_pairs(six_rows)
    k2_md5 = [r["cand_md5"] for r in read_csv(data / "tier1-k2stack-vs-base2.csv")]
    assert [r["cand_md5"] for r in read_csv(data / "tier1-k2-vs-reftex-2.csv")] == k2_md5
    # thesis-4.3/README.md M4 (propagation kernels 555.0 -> 444.0 s, all kernels 820.7 -> 666.2 s)
    by = {a["key"]: a for a in arms}
    close(by["base2"]["prop_s"], 555.0, 0.051, "propagation kernels, base"), close(by["k7lite"]["prop_s"], 444.0, 0.051, "propagation kernels, five changes")
    close(by["base2"]["all_kernels_s"], 820.7, 0.051, "all kernels, base"), close(by["k7lite"]["all_kernels_s"], 666.15, 0.0051, "all kernels, five changes")   # K7lite.md section 5 table (666.15)
    assert max(e0_untouched) <= 0.1
    arms.append(prop_u8(data, by["cu2"]))
    return {"arms": arms, "cheap": len(PROP_ARMS) - 1, "groups": [{"key": k, "kernel": g, "stage": stg} for k, g, stg in PROP_GROUPS],
            "launches": 672, "passes": 224, "seed": 1, "margin": MARGIN_TIER1, "ci_level_pct": 95,
            "repeatability_s": max(e0_untouched), "e1_untouched_max_s": max(e1_untouched),
            "stack_f1_2cm": stack_f1, "six_f1_2cm": six_f1, "stack_md5": k2_md5}


# The seventh change, 8-bit image textures at native scale (ee07854), was built and measured on the
# combined stack (5cf8608 = input and anchor stacks + the six changes above), not on the fixed base
# alone. Its profiled run is paired with the profiled run of 5cf8608, in which the propagation
# kernels are those of the sixth build above (the same code; the anchor kernels differ).
# src: thesis-4.3/stage-prop/cards/8bit.md
def prop_u8(data, sixth):
    pair = {r["group"]: r for r in read_csv(data / "kern-8bit-vs-comb-cu2.csv")}
    arm = {"key": "u8", "commit": "ee07854", "class": "E2", "on_stack": "5cf8608",
           "changed": ["weak", "strong", "depth_to_weak", "local_refine"],
           "kernels": {k: float(pair[g]["cand_s"]) for k, g, _ in PROP_GROUPS},
           "prop_s": float(pair["propagation"]["cand_s"]), "all_kernels_s": None,
           "stack_all_kernels_s": [float(pair["run (all kernels)"]["base_s"]), float(pair["run (all kernels)"]["cand_s"])],
           "parent": {"kernels": {k: float(pair[g]["base_s"]) for k, g, _ in PROP_GROUPS}, "prop_s": float(pair["propagation"]["base_s"])}}
    arm["vs_parent"] = {k: float(pair[g]["delta_s"]) for k, g, _ in PROP_GROUPS}
    arm["vs_parent"]["prop"] = float(pair["propagation"]["delta_s"])
    arm["vs_parent"]["all_kernels"] = float(pair["run (all kernels)"]["delta_s"])
    # the parent on the combined stack against the sixth build on the fixed base: the same kernels, another run
    arm["parent_vs_sixth_max_s"] = max(abs(arm["parent"]["kernels"][k] - sixth["kernels"][k]) for k in ("weak", "strong", "fit", "depth_to_weak", "local_refine"))
    assert arm["parent_vs_sixth_max_s"] < 1.0, arm["parent_vs_sixth_max_s"]
    runs = read_csv(data / "tier1-8bit-vs-comb-cu2.csv")
    assert not any(r["cand_md5"] == r["ref_md5"] for r in runs)
    arm["run"] = {k: v for k, v in paired([float(r["cand_span_s"]) - float(r["ref_span_s"]) for r in runs]).items() if k in ("n", "mean", "lo", "hi")}
    arm["run_s"] = st.mean(float(r["cand_span_s"]) for r in runs)
    arm["parent_run_s"] = st.mean(float(r["ref_span_s"]) for r in runs)
    arm["md5_seeds"] = len(runs)
    arm["f1_2cm"] = f1_pairs(runs)
    # thesis-4.3/stage-prop/cards/8bit.md sections 4, 5
    for got, e in zip((arm["run"][k] for k in ("mean", "lo", "hi")), (-75.0, -77.5, -72.5)):
        close(got, e, 0.051, "8-bit textures: run against the parent")
    for got, e in zip((arm["f1_2cm"][k] for k in ("mean", "lo", "hi")), (0.0001, -0.0005, 0.0007)):
        close(round(got, 4), e, 1e-9, "8-bit textures: F1 at 2 cm against the parent")
    close(arm["vs_parent"]["weak"], -73.25, 0.0051, "8-bit textures: weak"), close(arm["vs_parent"]["strong"], -0.78, 0.0051, "8-bit textures: strong")
    assert arm["f1_2cm"]["lo"] >= -MARGIN_TIER2, "Tier 2 at 2 cm"
    return arm


PROP_NCU = [  # build, run, file in which the build is the candidate (the base of the next file is checked against it)
    ("reftex", "s43-prop-reftex-2-ncu-s1", "ncu-k2-vs-reftex-2.csv"),
    ("k2", "s43-prop-k2-ncu-s1", "ncu-k2-vs-reftex-2.csv"),
    ("k11", "s43-prop-k11-ncu-s1", "ncu-k11-vs-k2.csv"),
    ("k7lite", "s43-prop-k7lite-ncu-s1", "ncu-k7lite-vs-k11.csv"),
    ("cu2", "s43-prop-cu2-ncu-s1", "ncu-cu2-vs-k7lite.csv"),
    ("u8", "s43-prop-8bit-ncu-s1", "ncu-8bit-vs-comb-cu2.csv"),   # on the combined stack; its parent there is NCU_U8_PARENT
]
NCU_U8_PARENT = "s43-prop-comb-cu2-ncu-s1"   # 5cf8608: the kernels of the sixth build, profiled again on the combined stack
NCU_FILES = ["ncu-k2-vs-reftex-2.csv", "ncu-k11-vs-k2.csv", "ncu-k7lite-vs-k11.csv", "ncu-cu2-vs-k7lite.csv", "ncu-8bit-vs-comb-cu2.csv"]
NCU_U8_COLS = ["dur_ms", "l2_req", "l2_sect", "tex_sect_l1", "tex_req_l1"]
NCU_KERNELS = {"weak": "BlackPixelUpdateWeak", "strong": "BlackPixelUpdateStrong"}
NCU_COLS = ["dur_ms", "warp_inst", "lanes", "tex_inst", "l1_hit_pct", "l2_req", "l2_sect", "sect_per_req", "l2_tag_pct", "l2_sect_pct",
            "dram_pct", "issue_pct", "lsb_per_issue", "local_ld_sect", "local_st_sect", "global_ld_sect", "tex_req_l1", "tex_sect_l1"]
# what the third change (views of zero weight skipped) moves, in the order drawn
SKIP_METRICS = ["l2_req", "dur_ms", "warp_inst", "tex_inst", "lanes"]
ZERO_WEIGHT_CALLS = [0.28, 0.30]   # src: thesis-4.3/stage-prop/cards/K2.md section 1; thesis-4.3/stage-prop/analysis.md section 1 (28-30 % of the NCC calls are multiplied by a zero weight)


def prop_ncu(data):
    seen = {}
    for f in NCU_FILES:
        for r in read_csv(data / f):
            k = next(kk for kk, name in NCU_KERNELS.items() if name in r["kernel"])   # the templated kernels are named "void <name><...>"
            row = {c: float(r[c]) for c in NCU_COLS}
            assert seen.setdefault((r["run"], k), row) == row, f"{f}: {r['run']} {k} differs between the ncu files"
    builds = [{"key": key, "run": run, **{k: seen[(run, k)] for k in NCU_KERNELS}} for key, run, _ in PROP_NCU]
    u8_parent = {"key": "comb-cu2", "run": NCU_U8_PARENT, **{k: seen[(NCU_U8_PARENT, k)] for k in NCU_KERNELS}}
    assert len(seen) == 2 * (len(builds) + 1)
    rel = lambda a, b, k, c: b[k][c] / a[k][c] - 1
    by = {b["key"]: b for b in builds}
    skip = {k: [{"metric": c, "before": by["reftex"][k][c], "after": by["k2"][k][c], "rel": rel(by["reftex"], by["k2"], k, c)} for c in SKIP_METRICS]
            for k in NCU_KERNELS}
    w = skip["weak"]
    # thesis-4.3/stage-prop/cards/K2.md section 5 (weak: requests -9.2 %, duration -7.2 %, warp TEX -4.3 %, warp instructions -5.2 %)
    for m, e in zip(w, (-0.092, -0.072, -0.052, -0.043)):
        close(round(m["rel"], 3), e, 1e-9, f"third change, weak launch, {m['metric']}")
    cheap = [b for b in builds[1:] if b["key"] != "u8"]   # the builds of the third to the sixth change
    tags = [b["weak"]["l2_tag_pct"] for b in cheap]
    # the parent of the 8-bit build on the combined stack repeats the launch of the sixth build
    repeat = max(abs(u8_parent["weak"][c] / by["cu2"]["weak"][c] - 1) for c in ("dur_ms", "l2_req", "l2_tag_pct", "l1_hit_pct"))
    assert repeat < 0.002, repeat
    u8 = by["u8"]
    # thesis-4.3/stage-prop/cards/8bit.md section 5 (weak launch: requests -60 %, tag-request rate 69.4 -> 34.1 %, L1/TEX hit 65.1 -> 83.3 %)
    close(round(rel(u8_parent, u8, "weak", "l2_req"), 2), -0.60, 1e-9, "8-bit textures, weak launch, requests")
    close(round(u8_parent["weak"]["l2_tag_pct"], 1), 69.4, 1e-9, "tag rate before"), close(round(u8["weak"]["l2_tag_pct"], 1), 34.1, 1e-9, "tag rate after")
    close(round(u8_parent["weak"]["l1_hit_pct"], 1), 65.1, 1e-9, "L1 hit before"), close(round(u8["weak"]["l1_hit_pct"], 1), 83.3, 1e-9, "L1 hit after")
    return {"builds": builds, "u8_parent": u8_parent, "u8_parent_repeat": repeat, "kernels": NCU_KERNELS, "skip": skip, "skip_metrics": SKIP_METRICS,
            "zero_weight_calls": ZERO_WEIGHT_CALLS,
            "tag_range_pct": [min(tags), max(tags)], "tag_builds": [b["key"] for b in cheap]}


# =================================================================================================
# The reliability classification: stall map and counters of the kernels before the changes, kernel
# seconds per build, run time and F1 per change, the offline study of cheaper sweeps, and two
# cost profiles
# =================================================================================================
CLASS_GROUPS = [("depth_to_weak", "DepthToWeak"), ("local_refine", "LocalRefine")]
# The builds in the order they were stacked on the propagation stack 5cf8608 (the combined stack with
# the six propagation changes), then the same five changes as one stack on the 8-bit textures.
# src: thesis-4.3/stage-class/cards/*.md; thesis-4.3/stack/class-comb.md
CLASS_ARMS = [  # key, commit, class, kernels changed, pair file, runs file, tier 1
    ("prop", "5cf8608", None, (), None, None, False),
    ("c2", "2045188", "E1", ("depth_to_weak", "local_refine"), "kern-c2-vs-5cf8608.csv", "tier1-c2-vs-5cf8608.csv", True),
    ("c1", "f223fa9", "E0", ("depth_to_weak",), "kern-c1-vs-c2.csv", "wall-c1-vs-c2.csv", False),
    ("k13", "b921d39", "E1", ("depth_to_weak",), "kern-k13-vs-c1.csv", "tier1-k13-vs-c1.csv", True),
    ("c9", "40da3b4", "E0", ("depth_to_weak",), "kern-c9-vs-k13.csv", "wall-c9-vs-k13.csv", False),
    ("c3", "97809e9", "E0", ("depth_to_weak",), "kern-c3-vs-c9.csv", "wall-c3-vs-c9.csv", False),
]
EXPECTED_CLASS = {  # the cards: run difference against the parent (s), F1 at 2 cm, kernels of the two together
    "c2": {"run": (-6.4, -6.9, -5.9), "f1": (-0.0001, -0.0002, 0.0001), "class": -6.52},
    "c1": {"run": (-1.8, -2.3, -1.3), "class": -1.43},
    "k13": {"run": (-0.6, -1.2, -0.1), "f1": (-0.0000, -0.0001, 0.0001), "class": -0.92},
    "c9": {"run": (-0.5, -1.6, 0.6), "class": -0.02},
    "c3": {"run": (-1.1, -1.9, -0.3), "class": -0.82},
}
# the regions of the stall map, in the order drawn; a region of the files that is not named here is "other"
STALL_REGIONS = [  # key, start of the region name in the stall files
    ("window", "window loop"), ("geometric", "geometric cost"), ("projection", "tap projection"),
    ("body", "LocalRefine body"), ("control", "sweep control"), ("setup", "NCC set-up"),
    ("weights", "view-weight load"), ("homography", "homography"), ("valleys", "valley analysis"),
]
C8_VARIANTS = ["step2", "c2f", "win10", "win15", "win20"]


def class_kernels(pair):
    k = {key: float(pair[g]["cand_s"]) for key, g in CLASS_GROUPS}
    b = {key: float(pair[g]["base_s"]) for key, g in CLASS_GROUPS}
    return b, k


def stat3(rows, a="cand_span_s", b="ref_span_s"):
    return {k: v for k, v in paired([float(r[a]) - float(r[b]) for r in rows]).items() if k in ("n", "mean", "lo", "hi")}


def class_stack(data):
    arms, untouched = [], []
    for i, (key, commit, cls, changed, pair_file, runs_file, tier1) in enumerate(CLASS_ARMS):
        arm = {"key": key, "commit": commit, "class": cls, "changed": list(changed), "group": "prop", "vs_parent": None, "run": None, "f1_2cm": None}
        if i == 0:
            arms.append(arm)
            continue
        parent = arms[-1]
        pair = {r["group"]: r for r in read_csv(data / pair_file)}
        base, arm["kernels"] = class_kernels(pair)
        if i == 1:
            parent["kernels"], parent["all_kernels_s"] = base, float(pair["run (all kernels)"]["base_s"])
        for k in base:
            close(base[k], parent["kernels"][k], 0.00011, f"{key}: base of {k} against the build before")
        arm["all_kernels_s"] = float(pair["run (all kernels)"]["cand_s"])
        arm["vs_parent"] = {k: arm["kernels"][k] - base[k] for k in base}
        untouched.append(abs(float(pair["propagation"]["delta_s"])))
        runs = read_csv(data / runs_file)
        same = [r["cand_md5"] == r["ref_md5"] for r in runs]
        assert all(same) if cls == "E0" else not any(same), f"{key}: md5 against the class {cls}"
        arm["run"], arm["md5_seeds"] = stat3(runs), len(runs)
        if tier1:
            arm["f1_2cm"] = f1_pairs(runs)
        exp = EXPECTED_CLASS[key]
        for got, e in zip((arm["run"][k] for k in ("mean", "lo", "hi")), exp["run"]):
            close(got, e, 0.051, f"{key}: run against the parent")
        if tier1:
            for got, e in zip((arm["f1_2cm"][k] for k in ("mean", "lo", "hi")), exp["f1"]):
                close(round(got, 4) + 0.0, e, 1e-9, f"{key}: F1 at 2 cm against the parent")
        close(sum(arm["vs_parent"].values()), exp["class"], 0.0051, f"{key}: the two kernels")
        arms.append(arm)
    for a in arms:
        a["class_s"] = sum(a["kernels"].values())
    # the chain of the five against 5cf8608; thesis-4.3/stage-class/cards/C3.md, last section
    chain = {r["group"]: r for r in read_csv(data / "kern-c3chain-vs-5cf8608.csv")}
    for key, g in CLASS_GROUPS:
        close(float(chain[g]["cand_s"]), arms[-1]["kernels"][key], 0.00011, f"chain {g}")
    chain_run = stat3(read_csv(data / "wall-c3chain-vs-5cf8608.csv"))
    for got, e in zip((chain_run[k] for k in ("mean", "lo", "hi")), (-10.3, -10.7, -9.9)):
        close(got, e, 0.051, "chain: run against 5cf8608")
    close(arms[-1]["class_s"] - arms[0]["class_s"], -9.71, 0.0061, "chain: the two kernels")   # the card rounds 50.03 - 40.32
    # the same five changes as one stack on the 8-bit textures; thesis-4.3/stack/class-comb.md
    pair = {r["group"]: r for r in read_csv(data / "kern-comb-vs-ee07854.csv")}
    base, kern = class_kernels(pair)
    wall = read_csv(data / "wall-comb-vs-ee07854.csv")
    assert not any(r["cand_md5"] == r["ref_md5"] for r in wall)
    f1 = {k: v for k, v in paired([float(r["cand_f1_2"]) - float(r["ref_f1_2"]) for r in wall]).items() if k in ("n", "mean", "lo", "hi")}
    on8 = [
        {"key": "u8", "commit": "ee07854", "class": None, "changed": [], "group": "u8", "kernels": base, "class_s": sum(base.values()),
         "all_kernels_s": float(pair["run (all kernels)"]["base_s"]), "vs_parent": None, "run": None, "f1_2cm": None},
        {"key": "comb", "commit": "1069a53", "class": "E1", "changed": [k for k, _ in CLASS_GROUPS], "group": "u8", "kernels": kern, "class_s": sum(kern.values()),
         "all_kernels_s": float(pair["run (all kernels)"]["cand_s"]), "vs_parent": {k: kern[k] - base[k] for k in base},
         "run": stat3(wall), "run_s": st.mean(float(r["cand_span_s"]) for r in wall), "parent_run_s": st.mean(float(r["ref_span_s"]) for r in wall),
         "f1_2cm_informative": f1, "f1_2cm": None, "md5_seeds": len(wall),
         "untouched_s": abs(float(pair["propagation"]["delta_s"]))},
    ]
    close(on8[1]["class_s"] - on8[0]["class_s"], -9.38, 0.011, "stack on 8-bit: the two kernels")   # the card subtracts the rounded 48.52 and 39.14; the file gives -9.371
    for got, e in zip((on8[1]["run"][k] for k in ("mean", "lo", "hi")), (-8.9, -15.6, -2.2)):
        close(got, e, 0.051, "stack on 8-bit: run")
    for got, e in zip((f1[k] for k in ("mean", "lo", "hi")), (0.0000, -0.0003, 0.0003)):
        close(round(got, 4) + 0.0, e, 1e-9, "stack on 8-bit: F1 at 2 cm, n = 3")
    # ---- per round, before any change
    rounds = defaultdict(dict)
    for r in read_csv(data / "rounds-5cf8608-c2.csv"):
        if r["run"] == "s43-prop-comb-cu2-nsys-s1" and r["state"] == "all":
            rounds[r["kernel"]][r["round"]] = float(r["seconds"])
    per_round = {key: [rounds[g][str(i)] for i in range(4)] for key, g in CLASS_GROUPS}
    for key, g in CLASS_GROUPS:
        close(sum(per_round[key]), arms[0]["kernels"][key], 0.001, f"rounds of {g}")
    native_share = sum(v[-1] for v in per_round.values()) / arms[0]["class_s"]
    # ---- stall map
    stall = {}
    for key, g in CLASS_GROUPS:
        rows = read_csv(data / f"stall-5cf8608-{g}.csv")
        reg = {k: {"stall": 0.0, "inst": 0.0} for k, _ in STALL_REGIONS}
        reg["other"] = {"stall": 0.0, "inst": 0.0}
        for r in rows:
            k = next((k for k, start in STALL_REGIONS if r["region"].startswith(start)), "other")
            reg[k]["stall"] += float(r["stall_pct"]); reg[k]["inst"] += float(r["inst_pct"])
        assert abs(sum(x["stall"] for x in reg.values()) - 100) < 0.1 and abs(sum(x["inst"] for x in reg.values()) - 100) < 0.1, g
        stall[key] = reg
        if key == "depth_to_weak":
            stall["weights_global_sectors"] = next(float(r["l2_sect_global"]) for r in rows if r["region"].startswith("view-weight load"))
            stall["global_sectors"] = sum(float(r["l2_sect_global"]) for r in rows)
    close(stall["depth_to_weak"]["window"]["stall"], 51.6, 0.051, "window loop"), close(stall["depth_to_weak"]["homography"]["stall"], 2.8, 0.051, "homography")
    # ---- counters, all passes
    cnt = next(r for r in read_csv(data / "counters-5cf8608-native-s1.csv") if r["round"] == "all" and r["state"] == "all")
    counters = {k: float(cnt[k]) for k in ("weak_pct", "sel_per_px", "views_per_warp_union", "w0_share_pct", "w0_share_warp_pct", "c11_pct", "c11_w_pct", "edge_pct", "lr_pct", "lane_eff_pct")}
    counters["wn0_share_pct"] = 100 * float(cnt["wn0_px"]) / float(cnt["swept_px"])
    counters["passes"] = int(cnt["passes"])
    close(counters["w0_share_pct"], 5.35, 0.0051, "weight-0 calls, lane level"), close(counters["w0_share_warp_pct"], 0.74, 0.0051, "weight-0 calls, warp level")
    close(counters["c11_pct"], 0.13, 0.0051, "C11"), close(counters["wn0_share_pct"], 1.1, 0.051, "weight sum 0")
    # ---- one launch of each kernel before the changes, and of DepthToWeak around the change of the weights
    ncu = {}
    for f in ("ncu-5cf8608.csv", "ncu-k13-vs-c1.csv"):
        for r in read_csv(data / f):
            key = next(k for k, g in CLASS_GROUPS if r["kernel"].startswith(g))
            ncu[(r["run"], key)] = {c: float(r[c]) for c in NCU_COLS}
    return {"arms": arms + on8, "groups": [{"key": k, "kernel": g} for k, g in CLASS_GROUPS], "seed": 1, "passes": 224,
            "repeatability_s": max(untouched), "chain_run": chain_run, "per_round": per_round, "native_share": native_share,
            "stall": stall, "stall_regions": [k for k, _ in STALL_REGIONS] + ["other"], "counters": counters,
            "ncu": {"base": {k: ncu[("s43-class-base-ncu-s1", k)] for k, _ in CLASS_GROUPS},
                    "c1": ncu[("s43-class-c1-ncu-s1", "depth_to_weak")], "k13": ncu[("s43-class-k13-ncu-s1", "depth_to_weak")]},
            "margin": MARGIN_TIER1, "ci_level_pct": 95}


def class_profiles(data):
    d = json.loads((data / "fig1-profiles.json").read_text())
    assert d["samples"] == list(range(-30, 31)) and all(len(d[k]["cost"]) == 61 for k in ("reliable", "unreliable"))
    return {"samples": d["samples"], "image": d["image"], "pass": d["pass"], "width": d["width"],
            "profiles": [{"key": k, "pixel": [d[k]["pixel_x"], d[k]["pixel_y"]], "cost": d[k]["cost"], "min": min(d[k]["cost"]), "max": max(d[k]["cost"])}
                         for k in ("reliable", "unreliable")],
            "clamp": 2.0,            # src: thesis-4.3/stage-class/cards/C8.md section 2 (the 61 clamped costs); .dev/findings/classification-sweep-m5.md item 2 (MIN(2.0f, .))
            "refine_radius": 5,      # src: thesis-4.3/stage-class/cards/C2.md section 1 (LocalRefine's 11 depths, p_disp = -5..5 = sweep samples 25..35)
            "unread": [-30, 30]}     # src: thesis-4.3/stage-class/cards/C1.md section 1 (samples 0 and 60 are never read)


def numbers_class(cl, prof, data, sr):
    n = Numbers()
    put = n.put
    arms = {a["key"] if a["group"] == "prop" else "on8." + a["key"]: a for a in cl["arms"]}
    files = {a[0]: (a[4], a[5]) for a in CLASS_ARMS}
    put("seed", cl["seed"], "thesis-4.3/stage-class/analysis.md section 7 (nsys and ncu, native, APD_SEED=1)")
    put("changes", len(CLASS_ARMS) - 1, "thesis-4.3/gate-5-decisions.md item 1 (C2, C1, K13, C9, C3)")
    put("e1.changes", sum(a[2] == "E1" for a in CLASS_ARMS), "CLASS_ARMS (class E1): thesis-4.3/gate-5-decisions.md item 1 (C2, K13)")
    put("ci_level_pct", cl["ci_level_pct"], "thesis-4.3/stage-class/cards/C2.md section 4 (95 % CI)")
    put("margin", cl["margin"], "thesis-4.3/gate-m2-decisions.md item 1 (Tier 1 margin)")
    put("tol.decides_cm", 2, "thesis-4.3/acceptance.md, decision D2 (all at 2 cm F1)")
    put("repeatability_s", cl["repeatability_s"], "data/kern-c2-vs-5cf8608.csv ... kern-c3-vs-c9.csv (propagation, |delta_s|): the propagation kernels, which no classification change touches")
    for key, a in arms.items():
        f = "data/kern-comb-vs-ee07854.csv" if a["group"] == "u8" else "data/" + files["c2" if key == "prop" else key][0]
        side = "base_s" if a["vs_parent"] is None else "cand_s"
        for k, g in CLASS_GROUPS:
            put(f"{key}.{k}_s", a["kernels"][k], f"{f} ({g}, {side})")
        put(f"{key}.class_s", a["class_s"], f"{f} (DepthToWeak + LocalRefine, {side})")
        put(f"{key}.all_kernels_s", a["all_kernels_s"], f"{f} (run (all kernels), {side})")
        if a["vs_parent"]:
            for k, g in CLASS_GROUPS:
                put(f"{key}.gain.{k}_s", -a["vs_parent"][k], f"{f} ({g}, -delta_s)")
            put(f"{key}.gain.class_s", -sum(a["vs_parent"].values()), f"{f} (DepthToWeak + LocalRefine, -delta_s)")
            rf = "data/wall-comb-vs-ee07854.csv" if a["group"] == "u8" else "data/" + files[key][1]
            n.put_stat(f"{key}.run", a["run"], f"{rf} (cand_span_s - ref_span_s, paired by seed, t n-1 dof)")
            put(f"{key}.run_n", a["run"]["n"], f"{rf} (rows)")
            put(f"{key}.md5_seeds", a["md5_seeds"], f"{rf} (cand_md5 against ref_md5 at native)")
            if a["f1_2cm"]:
                n.put_stat(f"{key}.f1_2cm", a["f1_2cm"], f"{rf} (cand_f1_2 - ref_f1_2, paired by seed, t 4 dof)")
                put(f"{key}.f1_n", a["f1_2cm"]["n"], f"{rf} (rows)")
    b, c2, last = arms["prop"], arms["c2"], arms["c3"]
    put("c2.depth_to_weak_growth_share", (c2["kernels"]["depth_to_weak"] - b["kernels"]["depth_to_weak"]) / b["kernels"]["depth_to_weak"], "data/kern-c2-vs-5cf8608.csv (DepthToWeak: delta_s / base_s)")
    put("c2.share_of_chain", (b["class_s"] - c2["class_s"]) / (b["class_s"] - last["class_s"]), "data/kern-c2-vs-5cf8608.csv, data/kern-c3chain-vs-5cf8608.csv: gain of the first change / gain of all five (the two kernels)")
    put("c1.gain.depth_to_weak_share", -arms["c1"]["vs_parent"]["depth_to_weak"] / c2["kernels"]["depth_to_weak"], "data/kern-c1-vs-c2.csv (DepthToWeak: -delta_s / base_s)")
    put("k13.gain.depth_to_weak_share", -arms["k13"]["vs_parent"]["depth_to_weak"] / arms["c1"]["kernels"]["depth_to_weak"], "data/kern-k13-vs-c1.csv (DepthToWeak: -delta_s / base_s)")
    put("c3.gain.depth_to_weak_share", -arms["c3"]["vs_parent"]["depth_to_weak"] / arms["c9"]["kernels"]["depth_to_weak"], "data/kern-c3-vs-c9.csv (DepthToWeak: -delta_s / base_s)")
    put("chain.gain.class_s", b["class_s"] - last["class_s"], "data/kern-c3chain-vs-5cf8608.csv (DepthToWeak + LocalRefine, -delta_s)")
    put("chain.gain.class_share", 1 - last["class_s"] / b["class_s"], "data/kern-c3chain-vs-5cf8608.csv (DepthToWeak + LocalRefine: 1 - cand_s / base_s)")
    n.put_stat("chain.run", cl["chain_run"], "data/wall-c3chain-vs-5cf8608.csv (cand_span_s - ref_span_s, paired by seed, t 2 dof)")
    put("chain.run_n", cl["chain_run"]["n"], "data/wall-c3chain-vs-5cf8608.csv (rows)")
    put("prop.class_share_of_kernels", b["class_s"] / b["all_kernels_s"], "data/kern-c2-vs-5cf8608.csv: (DepthToWeak + LocalRefine) / run (all kernels), base_s")
    put("prop.native_share", cl["native_share"], "data/rounds-5cf8608-c2.csv (s43-prop-comb-cu2-nsys-s1: round 3, both kernels) / their totals")
    put("prop.round_s", cl["per_round"], "data/rounds-5cf8608-c2.csv (s43-prop-comb-cu2-nsys-s1, state all, rounds 0-3)")
    # ---- the stack on the 8-bit textures
    o = arms["on8.comb"]
    put("on8.comb.run_s", o["run_s"], "data/wall-comb-vs-ee07854.csv (cand_span_s, mean of 3 seeds)")
    put("on8.comb.parent_run_s", o["parent_run_s"], "data/wall-comb-vs-ee07854.csv (ref_span_s, mean of 3 seeds)")
    put("on8.comb.untouched_s", o["untouched_s"], "data/kern-comb-vs-ee07854.csv (propagation, |delta_s|)")
    n.put_stat("on8.comb.f1_2cm", o["f1_2cm_informative"], "data/wall-comb-vs-ee07854.csv (cand_f1_2 - ref_f1_2, paired by seed, n = 3, t 2 dof: informative, not the Tier 1 test)")
    put("on8.comb.f1_n", o["f1_2cm_informative"]["n"], "data/wall-comb-vs-ee07854.csv (rows)")
    put("on8.comb.gain.all_kernels_s", arms["on8.u8"]["all_kernels_s"] - o["all_kernels_s"], "data/kern-comb-vs-ee07854.csv (run (all kernels), -delta_s)")
    put("on8.nofma_md5_native", "2aace1c9", "thesis-4.3/stack/class-comb.md \"FMA-off identity on 8-bit\" (--fmad=false builds of ee07854 and 1069a53 at native, seed 1: s43-class-8bit-nofma-native-s1, s43-class-comb-nofma-native-s1); thesis-4.3/gate-5-decisions.md item 1")
    put("on8.e0_steps", 3, "thesis-4.3/stack/class-comb.md \"Exactness re-checked on 8-bit\" (C1, C9, C3: md5 identical to the step before at native, seed 1)")
    arm = {a["key"]: a for a in sr["arms"]}
    cc, p8 = arm["class-comb"], arm["prop-8bit"]
    put("stack.run_s", cc["run_s"], "data/phases-stack.csv (class-comb, run: mean of seeds 1-3)")
    n.put_stat("stack.vs_base", cc["vs_base"], "data/wall-comb-vs-ee07854.csv (cand_span_s) - data/tier1-k2stack-vs-base2.csv (ref_span_s of base2), seeds 1-3, paired by seed, t 2 dof")
    put("stack.vs_base_share", -cc["vs_base"]["mean"] / arm["base2"]["run_s"], "data/phases-stack.csv: -(class-comb - base2) / base2, run")
    put("stack.base_run_s", arm["base2"]["run_s"], "data/phases-stack.csv (base2, run: mean of seeds 1-3)")
    part = lambda a, k: next(x["s"] for x in a["parts"] if x["key"] == k)
    put("stack.finalization_phase_s", [part(p8, "finalization"), part(cc, "finalization")], "data/phases-stack.csv (patchmatch.finalize: prop-8bit, class-comb; mean of seeds 1-3)")
    # ---- e1 evidence
    put("e1.nofma_md5_native", "37bd00b8", "thesis-4.3/stage-class/cards/C2.md section 4, K13.md section 4 (--fmad=false builds of 5cf8608, C2, C1 and K13 at native, seed 1: the md5 of the --fmad=false build of base2)")
    put("e1.nofma_seeds", 1, "the same: native seed 1, one run per build")
    put("e1.small_px", 1024, "thesis-4.3/stage-class/cards/C2.md section 4, K13.md section 4 (md5 identical to the parent at 1024)")
    put("e1.small_seeds", 3, "thesis-4.3/stage-class/cards/C2.md section 4, K13.md section 4 (1024, seeds 1-3)")
    put("c2.ffma", [531, 991], "thesis-4.3/stage-class/cards/C2.md section 4 (static FFMA count of DepthToWeak: parent, with the change)")
    put("k13.ffma", [991, 994], "thesis-4.3/stage-class/cards/K13.md section 4 (static FFMA count of DepthToWeak: parent, with the change)")
    # ---- what the stage does
    put("sweep.samples", len(prof["samples"]), "data/fig1-profiles.json (samples); thesis-4.3/stage-class/cards/C1.md section 1 (61 depths, p_disp = -30..30)")
    put("sweep.radius", max(prof["samples"]), "data/fig1-profiles.json (samples)")
    put("sweep.refine_samples", 2 * prof["refine_radius"] + 1, "thesis-4.3/stage-class/cards/C2.md section 1 (LocalRefine's 11 depths = sweep samples 25..35)")
    put("sweep.refine_radius", prof["refine_radius"], "thesis-4.3/stage-class/cards/C2.md section 1 (p_disp = -5..5)")
    put("sweep.unread_samples", 2, "thesis-4.3/stage-class/cards/C1.md section 1 (samples 0 and 60)")
    put("sweep.read_range", [1, 59], "thesis-4.3/stage-class/cards/C1.md section 1 (the valley analysis reads samples 1..59)")
    put("sweep.margin_px", 6, "thesis-4.3/stage-class/cards/C2.md section 2 (the 6-pixel margin)")
    put("profile.width_px", prof["width"], "data/fig1-profiles.json (width)")
    for p in prof["profiles"]:
        put(f"profile.{p['key']}.min", p["min"], f"data/fig1-profiles.json ({p['key']}, cost: minimum)")
        put(f"profile.{p['key']}.max", p["max"], f"data/fig1-profiles.json ({p['key']}, cost: maximum)")
    put("tex_sites", {"depth_to_weak": [93, 186], "local_refine": 186, "per_cost": 93}, "thesis-4.3/stage-class/analysis.md section 7.1 (TEX sites in SASS on 5cf8608: DepthToWeak 93, LocalRefine 186, one cost call site 93); thesis-4.3/stage-class/cards/C2.md section 3 (DepthToWeak 93 -> 186 with the change)")
    put("c2.estimate_s", [7, 8.5], "thesis-4.3/stage-class/cards/C2.md section 5 (plan estimate 7-8.5 s)")
    put("k13.weight_bytes", 32, "thesis-4.3/stage-class/cards/K13.md section 2 (the pixel's 32 weight bytes, loaded as two 16-byte words)")
    put("k13.loads", 2, "thesis-4.3/stage-class/cards/K13.md section 2, section 3 (two 16-byte loads per pixel)")
    put("c9.fetches_per_view", 74, "thesis-4.3/stage-class/cards/C9.md section 5 (one of about 74 fetches per sample and view)")
    put("c3.trigger_pct", 5, "thesis-4.3/stage-class/analysis.md section 7.6 (the plan's 5 %)")
    # ---- stall map, counters, launches
    s = cl["stall"]
    for k in ("depth_to_weak", "local_refine"):
        for r in cl["stall_regions"]:
            put(f"stall.{k}.{r}", s[k][r], f"data/stall-5cf8608-{dict(CLASS_GROUPS)[k]}.csv (stall_pct, inst_pct of the region; regions not named in STALL_REGIONS summed as other)")
    put("stall.weights_sector_share", s["weights_global_sectors"] / s["global_sectors"], "data/stall-5cf8608-DepthToWeak.csv (l2_sect_global of the view-weight region / sum over the regions)")
    for k, v in cl["counters"].items():
        put(f"counters.{k}", v, f"data/counters-5cf8608-native-s1.csv (round all, state all: {k}; wn0_share_pct = wn0_px / swept_px)")
    for k, _ in CLASS_GROUPS:
        for c in ("dur_ms", "issue_pct", "l1_hit_pct", "l2_tag_pct", "lanes", "dram_pct"):
            put(f"ncu.base.{k}.{c}", cl["ncu"]["base"][k][c], f"data/ncu-5cf8608.csv ({dict(CLASS_GROUPS)[k]}, {c})")
    for c in ("dur_ms", "global_ld_sect", "l2_req"):
        put(f"ncu.k13.drop.{c}", 1 - cl["ncu"]["k13"][c] / cl["ncu"]["c1"][c], f"data/ncu-k13-vs-c1.csv (DepthToWeak, {c}: 1 - after / before)")
    put("untaken.c11_ceiling_s", 0.05, "thesis-4.3/stage-class/analysis.md section 7.6 (C11: ceiling about 0.05 s)")
    put("untaken.cu3_ceiling_s", 1, "thesis-4.3/stage-class/analysis.md section 7.6 (CU-3: part of 2.8 % of the stall samples, < 1 s)")
    # ---- the offline study of cheaper sweeps
    c8 = json.loads((data / "c8-summary.json").read_text())["all"]
    assert c8["gate_agree"] == 1.0
    put("c8.passes", c8["passes"], "data/c8-summary.json (all, passes)")
    put("c8.swept_millions", c8["swept"] / 1e6, "data/c8-summary.json (all, swept)")
    put("c8.px", 1024, "thesis-4.3/stage-class/cards/C8.md (run s43-class-dump-1024-s1)")
    for v in C8_VARIANTS:
        for q in ("agree", "w2s", "s2w", "samples"):
            put(f"c8.{v}.{q}", c8[f"{v}_{q}"], f"data/c8-summary.json (all, {v}_{q}: pooled over all passes, weighted by swept pixels)")
    best = [c8[f"{v}_agree"] for v in ("step2", "c2f", "win20")]
    close(round(100 * min(best)), 90, 1e-9, "label agreement, low"), close(round(100 * max(best)), 94, 1e-9, "label agreement, high")
    put("c8.agree_range", [min(best), max(best)], "data/c8-summary.json (all: smallest and largest agreement of step2, c2f and win20, the variants that keep at least half of the samples)")
    put("c8.weak_px_per_s", 7, "thesis-4.3/stage-class/cards/C8.md section 5 (one percentage point of weak fraction moves the weak update kernels by about 7 s)")
    put("div0.status", "open", "thesis-4.3/gate-5-decisions.md item 3 (bug fix in M6, not in these builds)")
    return n


# =================================================================================================
# Numbers of the text
# =================================================================================================
def numbers_method(base, prof, aa, sn, inp):
    n = Numbers()
    put = n.put
    b = inp["arms"][0]
    # ---- machine and runs
    put("machine.gpu_memory_gb", 16, "thesis-4.3/m0/baseline.md:3")  # src: RTX 5070 Ti 16 GB
    put("machine.gpu_clock_max_mhz", 3090, "~/thesis-data/bench/diag/production-apd-mvs/s43-m0-base-aa-s1/context.txt (clocks.max.sm)")
    put("machine.bench_gpu_memory_gb", 12, "PLAN-4.3.md decision D1")
    put("scene.images", 14, "thesis-4.3/stage-input/analysis.md section 1 (14 images)")
    put("scene.width", 6220, ".dev/findings/native-nondeterminism.md (native 6220x4141)")
    put("scene.height", 4141, ".dev/findings/native-nondeterminism.md (native 6220x4141)")
    put("run.max_image_size", 8192, "tools/perf_run_env.sh:20 (MAXSIZE 8192)")
    scales = sorted({int(r["scale_size"]) for r in read_csv(DATA / INPUT_ARMS[0][1]) if r["scale_size"]}, reverse=True)
    put("run.round_scales", scales, BEFORE + " (scale_size of the rounds)")
    put("run.rounds", len(scales), BEFORE + " (rounds)")
    put("run.passes", b["passes"], BEFORE + " (n of input_load inside image_pass, summed)")
    sweeps = b["passes"] // (14 * len(scales))
    assert sweeps * 14 * len(scales) == b["passes"] == 224
    put("run.sweeps_per_round", sweeps, BEFORE + ": passes / (images x rounds); the unfixed-base value is in thesis-4.3/stage-input/analysis.md section 1")
    put("scene.office_seeds", 3, "thesis-4.3/acceptance.md, decision D2")
    put("scene.playground.sizes", 5, "thesis-4.3/m0/baseline.md section 3 (lines 90-95)")
    put("scene.playground.size_min", [6209, 4137], "thesis-4.3/m0/baseline.md section 3 (lines 90-95)")
    put("scene.playground.size_max", [6221, 4146], "thesis-4.3/m0/baseline.md section 3 (lines 90-95)")
    # ---- harness and timers
    put("harness.gpu_sample_ms", 100, "tools/perf_run_env.sh:6, :46 (nvidia-smi -lms 100)")
    put("harness.host_sample_s", 1, "tools/perf_run_env.sh:6, :65 (perf stat -I 1000)")
    put("profiled.phase_kernel_sum_s", prof["phase_kernel_sum_s"], "thesis/generated/baseline-run/data/perf-nsys-r1/phases.txt (patchmatch.init + .propagate + prior_build + .finalize); thesis-4.3/m0/baseline.md:51-53")
    put("profiled.nsys_kernel_sum_s", prof["nsys_kernel_sum_s"], "thesis/generated/baseline-run/data/perf-nsys-r1/kernel-totals-base.csv (sum of total_ns)")
    put("timers.regions", len(TOP_REGIONS), "thesis-4.3/stage-input/analysis.md section 2 (six region timers)")
    put("timers.unaccounted_share", (b["input_load_s"] - sum(b["regions"][k]["s"] for k in TOP_REGIONS)) / b["input_load_s"],
        BEFORE + ": (input_load - its six regions) / input_load, the 224 passes; the unfixed-base value is in thesis-4.3/stage-input/analysis.md section 2a")
    assert 0 <= b["input_load_s"] - sum(b["regions"][k]["s"] for k in TOP_REGIONS) < 0.2, "regions add up"
    put("timers.run_span_s", 1102.0, "~/thesis-data/bench/diag/production-apd-mvs/s43-input-manifest.tsv (s43-input-timers2-native-s1, 1102.0 s; phases.txt: 1102.03 s)")
    b2 = [float(r["span_b2"]) for r in read_csv(DATA / "base2.csv")]
    put("base2.runs", len(b2), "data/base2.csv (rows)")
    put("base2.span_mean_s", st.mean(b2), "data/base2.csv (span_b2, mean); thesis-4.3/m0/determinism.md:21")
    put("base2.span_sd_s", st.stdev(b2), "data/base2.csv (span_b2, sd); thesis-4.3/m0/determinism.md:21")
    assert abs(1102.0 - st.mean(b2)) <= st.stdev(b2), "the timer run is not inside the spread of the fixed base"
    put("base.runs", base["runs"], "data/m0_phases.csv (tags)")
    put("base.span_mean_s", base["span"]["mean_s"], "data/m0_phases.csv (phase run, mean of the 10 runs); thesis-4.3/m0/baseline.md:47")
    put("base.span_sd_s", base["span"]["sd_s"], "data/m0_phases.csv (phase run, sd of the 10 runs); thesis-4.3/m0/baseline.md:47")
    put("base.kernel_sd_s", base["kernel"]["sd_s"], "data/m0_phases.csv (sum of the four kernel phases per run, sd); thesis-4.3/m0/baseline.md:60")
    put("base.input_load_sd_s", next(s["sd_s"] for s in base["stages"] if s["key"] == "input_load"),
        "data/m0_phases.csv (phase input_load, all calls of a run, sd of the 10 runs); thesis-4.3/m0/baseline.md:61")
    # ---- seeds, exactness, acceptance rule
    put("seeds.first", min(aa["seeds"]), "data/aa.csv (seed)")
    put("seeds.last", max(aa["seeds"]), "data/aa.csv (seed)")
    put("protocol.e0_size_px", 1024, "thesis-4.3/acceptance.md \"Exactness classes\"")
    put("protocol.e0_seeds", 3, "thesis-4.3/acceptance.md \"Exactness classes\"")
    put("protocol.ci_level_pct", 95, "thesis-4.3/acceptance.md, decision D2")
    put("protocol.t_quantile", 0.975, "thesis-4.3/acceptance.md \"How the paired CI is computed\"")
    put("protocol.margin_tier1", MARGIN_TIER1, "thesis-4.3/gate-m2-decisions.md item 1 (Tier 1 margin, widened)")
    put("protocol.margin_tier1_former", MARGIN_TIER1_FORMER, "thesis-4.3/acceptance.md, decision D2 as frozen 2026-11-15 (Tier 1 margin before Gate M2)")
    put("protocol.margin", 0.002, "thesis-4.3/acceptance.md, decision D2 (bound of Tier 2 and of the final test; unchanged by thesis-4.3/gate-m2-decisions.md item 1)")
    put("protocol.e0_native_seeds", 3, "thesis-4.3/stage-input/cards/H1.md section 7 (md5 at native, seeds 1-3)")
    put("protocol.scene_floor", -0.01, "thesis-4.3/acceptance.md, decision D2 (final test, per-scene mean)")
    put("protocol.decides_cm", 2, "thesis-4.3/acceptance.md, decision D2 (all at 2 cm F1)")
    put("protocol.other_cm", [1, 5], "thesis-4.3/acceptance.md, decision D2 (reported, do not decide)")
    put("protocol.seeds_pipes", 5, "thesis-4.3/acceptance.md, decision D2")
    put("protocol.seeds_office", 3, "thesis-4.3/acceptance.md, decision D2")
    put("protocol.final_scenes", 2, "thesis-4.3/acceptance.md \"Final test, M6\" (J = 2)")
    # ---- A/A arm
    put("aa.days_apart", [4, 5], "thesis-4.3/m0/baseline.md:12-14 (A 2026-11-10/11, B 2026-11-15)")
    put("aa.n", aa["n"], "data/aa.csv (rows)")
    for s in aa["tols"]:
        n.put_stat(f"aa.f1.at{s['tol']}", s, f"data/aa.csv (f1_{s['tol']}_b - f1_{s['tol']}_a, paired, t 4 dof); thesis-4.3/m0/baseline.md:26-30")
    two = aa["tols"][1]
    put("aa.f1.at2cm.halfwidth", two["halfwidth"], "data/aa.csv (half-width of the 2 cm interval, unrounded)")
    put("aa.f1.at2cm.halfwidth_of_margin", two["halfwidth"] / MARGIN_TIER1_FORMER, "data/aa.csv: half-width / former Tier 1 margin (0.002); thesis-4.3/m0/baseline.md:35-37 gives 0.0012 and about 60 % from the rounded bounds")
    n.put_stat("aa.comp.at2cm", two["comp"], "data/rescale_split_runs.csv (comp_2cm, arm old2 - old1 = B - A); thesis-4.3/m0/baseline.md:32-33")
    n.put_stat("aa.acc.at2cm", two["acc"], "data/rescale_split_runs.csv (acc_2cm, arm old2 - old1 = B - A); thesis-4.3/m0/baseline.md:32-33")
    put("aa.seed_sd_2cm", two["a_sd"], "data/aa.csv (sd of f1_2cm_a over the 5 seeds); thesis-4.3/acceptance.md \"Reference numbers\"")
    put("aa.clouds", 2 * aa["n"], "data/aa.csv (md5_a, md5_b)")
    put("aa.clouds_distinct", aa["md5_distinct"], "data/aa.csv (distinct md5); thesis-4.3/m0/baseline.md:38-39")
    assert aa["md5_distinct"] == 2 * aa["n"] and aa["md5_same_seed_equal"] == 0
    # ---- seed-noise arm on the fixed base
    put("sn.n", sn["n"], "data/runs.csv (s43-base2-native-s1..s10)")
    put("sn.seeds_a", [sn["seeds_a"][0], sn["seeds_a"][-1]], "thesis-4.3/m0/determinism.md \"Seed noise on base2\" (existing runs, seeds 1-5)")
    put("sn.seeds_b", [sn["seeds_b"][0], sn["seeds_b"][-1]], "thesis-4.3/m0/determinism.md \"Seed noise on base2\" (new runs, seeds 6-10)")
    for t in sn["tols"]:
        n.put_stat(f"sn.f1.at{t['tol']}", t, f"data/runs.csv (f1 at {t['tol']}, seed k+5 minus seed k, paired formula, t 4 dof); checked against data/seednoise-base2-tier1.csv")
    s2 = sn["tols"][1]
    put("sn.f1.at2cm.halfwidth", s2["halfwidth"], "data/runs.csv (half-width of the index-paired 2 cm interval)")
    n.put_stat("sn.welch.at2cm", s2["welch"], "data/seednoise-base2.csv (f1, 2cm: diff_b_minus_a, lo, hi; Welch)")
    n.put_stat("sn.comp.at2cm", s2["comp"], "data/seednoise-base2.csv (comp, 2cm; Welch)")
    n.put_stat("sn.acc.at2cm", s2["acc"], "data/seednoise-base2.csv (acc, 2cm; Welch)")
    put("sn.pairings", s2["pairings"], "data/runs.csv: 5! ways of pairing seeds 6-10 with seeds 1-5")
    put("sn.pass_former", s2["pass_former"], "data/runs.csv: share of the 120 pairings whose 2 cm interval lies inside the former margin; data/seednoise-base2-tier1.csv (frac_pass_all_120_pairings)")
    put("sn.pass_now", s2["pass_now"], "data/runs.csv: share of the 120 pairings whose 2 cm interval lies inside the widened margin")
    put("sn.sd_pooled", s2["sd_pooled"], "data/seednoise-base2.csv (f1, 2cm, sd_pooled)")
    put("sn.expected_halfwidth", s2["expected_halfwidth"], "data/seednoise-base2.csv (f1, 2cm, tier1_hw_n5 = t(0.975, 4) x sqrt(2) x sd_pooled / sqrt(5))")
    put("sn.expected_halfwidth_of_former", s2["expected_halfwidth"] / MARGIN_TIER1_FORMER, "data/seednoise-base2.csv: tier1_hw_n5 / former margin")
    put("sn.mc_null_pass_former", s2["mc_null_pass_former"], "data/seednoise-base2.csv (f1, 2cm, p_pass_eff0: simulated pass rate of a true null at the former margin)")
    put("sn.expected_null_pass_now", [0.90, 0.95], "thesis-4.3/gate-m2-decisions.md item 1 (a null is expected to pass about 90-95 % of the time at 0.003)")
    # ---- placebo arm, dropped
    put("placebo.size_px", 1024, "thesis-4.3/m0/determinism.md \"Placebo arm dropped\" (Q6)")
    put("placebo.seeds", 20, "thesis-4.3/m0/determinism.md \"Placebo arm dropped\" (Q6)")
    put("placebo.f1_2cm.mean", 0.0012, "thesis-4.3/m0/determinism.md \"Placebo arm dropped\" (Q6: +0.0012 [+0.0004, +0.0020])")
    put("placebo.f1_2cm.lo", 0.0004, "thesis-4.3/m0/determinism.md \"Placebo arm dropped\" (Q6)")
    put("placebo.f1_2cm.hi", 0.0020, "thesis-4.3/m0/determinism.md \"Placebo arm dropped\" (Q6)")
    return n


def numbers_baseline(base, prof, resc, data):
    n = Numbers()
    put = n.put
    src = "data/m0_phases.csv (mean of the 10 runs of the unfixed base); thesis-4.3/m0/baseline.md section 2"
    put("base.runs", base["runs"], "data/m0_phases.csv (tags)")
    put("base.span_mean_s", base["span"]["mean_s"], src)
    put("base.span_sd_s", base["span"]["sd_s"], "data/m0_phases.csv (phase run, sd of the 10 runs)")
    put("base.kernel_s", base["kernel"]["mean_s"], src)
    put("base.kernel_sd_s", base["kernel"]["sd_s"], "data/m0_phases.csv (sum of the four kernel phases per run, sd)")
    put("base.kernel_share", base["kernel"]["share"], src + ": kernel sum / run span, both 10-run means")
    put("base.host_s", base["host"]["mean_s"], src + ": run span - kernel sum")
    put("base.host_share", base["host"]["share"], src + ": (run span - kernel sum) / run span")
    for s in base["stages"]:
        k = s["key"].replace(".", "_")
        put(f"base.stage.{k}.s", s["mean_s"], src + f" ({' + '.join(s['phases']) or 'run - all stages'}; all calls of the phase in a run)")
        put(f"base.stage.{k}.share", s["share"], src + ": stage mean / run span mean (denominator 1101.5 s)")
    # the profiled run, for the shares that <apd-mvs-analysis> quotes
    psrc = "thesis/generated/baseline-run/data/perf-nsys-r1/phases.txt (one run, Nsight Systems attached)"
    put("profiled.span_s", prof["span_s"], psrc + "; thesis-4.3/stage-input/analysis.md section 1")
    put("profiled.input_load_s", prof["input_load_s"], psrc + f" (input_load, all {prof['input_load_calls']} calls)")
    for k, v in prof["share"].items():
        put(f"profiled.share.{k}", v, (psrc if k != "depth_to_weak" else "thesis/generated/baseline-run/data/perf-nsys-r1/kernel-totals-base.csv (DepthToWeak total_ns)")
            + ": / run span of the profiled run (denominator 1106.5 s)")
    # the defect and its evidence
    put("tol.decides_cm", 2, "thesis-4.3/acceptance.md, decision D2 (all at 2 cm F1)")
    put("tol.strict_cm", 1, "thesis-4.3/acceptance.md, decision D2 (F1 at 1 cm is reported)")
    put("pyramid.sizes", [[1555, 1035], [3110, 2071], [6220, 4141]], ".dev/findings/native-nondeterminism.md \"Code facts\" (native 1555x1035 -> 3110x2071 -> 6220x4141)")
    put("sizes.differ", [1554, 2048, 3104, 3200, 4096], ".dev/findings/native-nondeterminism.md \"Evidence\"; thesis-4.3/m0/determinism.md:2, :5 (plus native)")
    put("sizes.identical", [1024, 1555, 1556, 2047, 3112], ".dev/findings/native-nondeterminism.md \"Evidence\"; thesis-4.3/m0/determinism.md:2, :5")
    put("sizes.tested", 11, ".dev/findings/native-nondeterminism.md \"Evidence\" (all 11 sizes: 5 + native differ, 5 identical)")
    put("sizes.hash_pair_px", 2048, "thesis-4.3/m0/determinism.md:6 (hash dump, 2048 pair)")
    put("sizes.e0_px", 1024, "thesis-4.3/m0/determinism.md:11-13 (1024 md5 e093b909 for both commits)")
    put("aa.clouds", 10, "data/aa.csv (md5_a, md5_b: 10 distinct)")
    # the fix, per commit
    put("fix.n", resc["n"], "data/rescale_split.csv (n of the three comparisons)")
    for s in resc["series"]:
        k = s["key"].replace("-", "_")
        for r in s["f1"]:
            n.put_stat(f"fix.{k}.f1.at{r['tol']}", r, f"data/rescale_split.csv ({s['key']}, f1, {r['tol']}); thesis-4.3/m0/determinism.md")
        for m in ("acc", "comp"):
            n.put_stat(f"fix.{k}.{m}.at2cm", s[m]["2cm"], f"data/rescale_split.csv ({s['key']}, {m}, 2cm)")
        n.put_stat(f"fix.{k}.span_s", s["span_s"], f"data/rescale_split.csv ({s['key']}, span_s)")
    # "negative in every pairing that was tried": zi-base, zi-fresh, zi-old1, zi-old2 (not independent)
    assert resc["pairings_negative_2cm"] == resc["pairings_2cm"]
    put("drift.n", resc["drift"]["2cm"]["n"], "data/rescale_split.csv (fresh-base (drift), n)")
    n.put_stat("drift.f1.at2cm", resc["drift"]["2cm"], "data/rescale_split.csv (fresh-base (drift), f1, 2cm); thesis-4.3/m0/determinism.md:36")
    # the fixed base
    b2 = read_csv(data / "base2.csv")
    span = [float(r["span_b2"]) for r in b2]
    put("base2.runs", len(b2), "data/base2.csv (rows)")
    put("base2.span_mean_s", st.mean(span), "data/base2.csv (span_b2, mean); thesis-4.3/m0/determinism.md:21")
    put("base2.span_sd_s", st.stdev(span), "data/base2.csv (span_b2, sd); thesis-4.3/m0/determinism.md:21")
    close(st.mean(span), 1104.7, 0.05, "base2 span"), close(st.stdev(span), 3.3, 0.05, "base2 span sd")
    f1 = st.mean(float(r["f1_2cm_b2"]) for r in b2)
    close(round(f1, 4), 0.8764, 1e-9, "base2 F1 2 cm")
    put("base2.f1_2cm", f1, "data/base2.csv (f1_2cm_b2, mean over seeds 1-5); thesis-4.3/m0/determinism.md:19")
    put("base2.seeds", [int(b2[0]["seed"]), int(b2[-1]["seed"])], "data/base2.csv (seed)")
    put("base2.same_seed_runs", 2, "thesis-4.3/m0/determinism.md:13 (s43-base2-native-s1 = -s1-rep2 = c8d3718c)")
    return n


def numbers_input(inp, stack, data):
    n = Numbers()
    put = n.put
    arms = {a["key"]: a for a in inp["arms"]}
    st_arms = {a["key"]: a for a in stack["arms"]}
    b = arms["base2"]
    cards = "data/card-h2h12-h14.csv, data/card-h3h6.csv"
    # ---- run shape
    put("run.passes", b["passes"], BEFORE + " (n of input_load inside image_pass)")
    put("scene.images", 14, "thesis-4.3/stage-input/analysis.md section 1 (14 images)")
    rounds = len({c["round"] for c in b["convert_by_state"]})
    close(b["views_uploaded"] / b["passes"], 10.7, 0.05, "views per pass")
    put("views.per_pass", b["views_uploaded"] / b["passes"], BEFORE + " (n of up.texobj under up.images / passes); thesis-4.3/stage-input/cards/H1.md section 1")
    put("views.conversions_per_image_per_round", b["views_uploaded"] / rounds / 14, BEFORE + ": views uploaded / rounds / images; thesis-4.3/stage-input/analysis.md section 1 \"Redundancy\"")
    put("views.conversions_per_run", b["views_uploaded"], BEFORE + " (n of up.texobj under up.images: one per converted view); thesis-4.3/stage-input/cards/H1.md section 1")
    put("views.per_round", b["views_uploaded"] // rounds, BEFORE + ": views uploaded / rounds; thesis-4.3/stage-input/cards/H3H6.md section 3 (about 600 uploads per round)")
    assert b["views_uploaded"] == 2400
    put("timers.regions", len(TOP_REGIONS), "thesis-4.3/stage-input/analysis.md section 2")
    put("timers.unaccounted_share", (b["input_load_s"] - sum(b["regions"][k]["s"] for k in TOP_REGIONS)) / b["input_load_s"],
        BEFORE + ": (input_load - its six regions) / input_load")
    put("seeds.n", stack["n"], cards + " (n)")
    put("seeds.range", stack["seeds"], "thesis-4.3/stage-input/cards/H1.md section 7 (seeds 1-3)")
    put("tol.decides_cm", 2, "thesis-4.3/acceptance.md, decision D2 (all at 2 cm F1)")
    put("ci_level_pct", stack["ci_level_pct"], "thesis-4.3/stage-input/cards/H1.md section 7 (95 % CI with t(0.975, 2))")

    # ---- per build: phase totals (three seeded runs each) and regions (one timed run, seed 1)
    # Two measurements of a build, and the key says which:
    #   <build>.phase.<phase>_s      phase total of a run (all calls), mean of the three seeded runs
    #   <build>.<region>_s           region inside the passes, the one timed run with seed 1
    for key, arm in arms.items():
        f, sa, r = ARM_FILE[key], st_arms[key], arm["regions"]
        for ph in ["run"] + stack["phases"]:
            put(f"{key}.phase.{ph}_s", sa["phase_s"][ph], f"{cards} ({sa['key']}, {ph}: mean of 3 seeded runs, all calls of the phase)")
        put(f"{key}.phase.input_load_share", sa["phase_s"]["input_load"] / sa["phase_s"]["run"], f"{cards}: input_load / run, both 3-run means of this build")
        if sa["vs_parent"]:
            for ph in ["run"] + stack["phases"]:
                n.put_stat(f"{key}.vs_parent.{ph}", sa["vs_parent"][ph], f"{cards} ({ph}: paired by seed against the build before, t 2 dof)")
                n.put_stat(f"{key}.vs_base.{ph}", sa["vs_base"][ph], f"{cards} ({ph}: paired by seed against base2, t 2 dof)")
            put(f"{key}.vs_base.run_share", sa["vs_base"]["run"]["mean"] / st_arms["base2"]["phase_s"]["run"], f"{cards}: run difference against base2 / base2 run mean")
        put(f"{key}.in_pass_s", arm["input_load_s"], f"{f} (input_load inside image_pass, 224 calls, one timed run)")
        put(f"{key}.convert_s", r["in.convert"]["s"], f"{f} (in.convert)")
        put(f"{key}.resize_s", r["in.resize"]["s"], f"{f} (in.resize)")
        put(f"{key}.images_s", r["in.convert"]["s"] + r["in.resize"]["s"], f"{f} (in.convert + in.resize)")
        put(f"{key}.images_share", (r["in.convert"]["s"] + r["in.resize"]["s"]) / arm["input_load_s"], f"{f}: (in.convert + in.resize) / input_load in passes")
        put(f"{key}.planes_s", r["in.planes"]["s"], f"{f} (in.planes)")
        put(f"{key}.plane_fill_s", r["in.plane_fill"]["s"], f"{f} (in.plane_fill)")
        put(f"{key}.geom_depths_s", r["in.geom_depths"]["s"], f"{f} (in.geom_depths)")
        put(f"{key}.weak_s", r["in.weak"]["s"], f"{f} (in.weak)")
        put(f"{key}.maps_s", r["in.planes"]["s"] + r["in.geom_depths"]["s"] + r["in.weak"]["s"], f"{f} (in.planes + in.geom_depths + in.weak)")
        put(f"{key}.upsample_s", sum(r[k]["s"] for k in ("in.upsample.depth_normal", "in.upsample.views", "in.upsample.weak")), f"{f} (in.upsample.depth_normal + .views + .weak)")
        put(f"{key}.upsample_weak_s", r["in.upsample.weak"]["s"], f"{f} (in.upsample.weak, inside in.weak)")
        put(f"{key}.input_load_faults", r["input_load"]["faults"], f"{f} (input_load in passes, minflt)")
        put(f"{key}.convert_faults", r["in.convert"]["faults"], f"{f} (in.convert, minflt)")
        put(f"{key}.convert_fault_gb", r["in.convert"]["fault_gb"], f"{f} (in.convert, fault_gb)")
        put(f"{key}.planes_faults", r["in.planes"]["faults"], f"{f} (in.planes, minflt)")
        put(f"{key}.plane_fill_faults", r["in.plane_fill"]["faults"], f"{f} (in.plane_fill, minflt)")
        put(f"{key}.geom_depths_faults", r["in.geom_depths"]["faults"], f"{f} (in.geom_depths, minflt)")
        put(f"{key}.convert_ms_per_pass", 1e3 * r["in.convert"]["s"] / arm["passes"], f"{f}: in.convert / 224 passes")
        put(f"{key}.convert_faults_per_pass", r["in.convert"]["faults"] / arm["passes"], f"{f}: in.convert minflt / 224 passes")
        put(f"{key}.resize_ms_per_pass", 1e3 * r["in.resize"]["s"] / arm["passes"], f"{f}: in.resize / 224 passes")
        put(f"{key}.upload_s", r["device_upload"]["s"], f"{f} (device_upload)")
        put(f"{key}.upload_images_s", r["up.images"]["s"], f"{f} (up.images)")
        put(f"{key}.upload_depths_s", r["up.depths"]["s"], f"{f} (up.depths)")
        put(f"{key}.upload_buffers_s", r["up.buffers"]["s"], f"{f} (up.buffers)")
        put(f"{key}.upload_copies", r["up.copy"]["calls"], f"{f} (up.copy, n summed)")
        put(f"{key}.unpack_s", r["result_readback"]["s"], f"{f} (result_readback)")
        put(f"{key}.unpack_faults", r["result_readback"]["faults"], f"{f} (result_readback, minflt)")
        put(f"{key}.kernel_readback_s", r["patchmatch.readback"]["s"], f"{f} (patchmatch.readback)")
        put(f"{key}.pass_free_s", r["pass.free"]["s"], f"{f} (pass.free)")
    put("base2.convert_fault_share", b["regions"]["in.convert"]["faults"] / b["regions"]["input_load"]["faults"], BEFORE + ": in.convert minflt / input_load minflt")
    put("base2.in_pass_outside_calls", b["outside"]["calls"], BEFORE + " (input_load, round outside, n)")
    put("base2.in_pass_with_outside_s", b["input_load_s"] + b["outside"]["s"], BEFORE + " (in-pass + outside)")
    # conversion per pass by round: rounds below native against the native passes after the first
    low = [c for c in b["convert_by_state"] if c["round"] < rounds - 1]
    nat = [c for c in b["convert_by_state"] if c["round"] == rounds - 1 and c["refine_iter"]]
    lp, npass = sum(c["n"] for c in low), sum(c["n"] for c in nat)
    put("base2.convert_low_rounds", [1, rounds - 1], BEFORE + " (rounds 0-2 of the file; numbered from 1 as in <fig-run-breakdown>)")
    put("base2.convert_low_ms_per_pass", 1e3 * sum(c["s"] for c in low) / lp, BEFORE + ": in.convert, rounds 0-2, seconds / 168 passes")
    put("base2.convert_low_faults_per_pass", sum(c["flt"] for c in low) / lp, BEFORE + ": in.convert, rounds 0-2, minflt / 168 passes")
    put("base2.convert_native_iter_ms_per_pass", 1e3 * sum(c["s"] for c in nat) / npass, BEFORE + ": in.convert, round 3 REFINE_ITER, seconds / 42 passes")
    put("base2.convert_native_iter_faults_per_pass", sum(c["flt"] for c in nat) / npass, BEFORE + ": in.convert, round 3 REFINE_ITER, minflt / 42 passes")
    # differences between successive builds, in the one timed run each
    for a, c, name in (("base2", "h1", "h1"), ("h1", "h2h12", "h2h12"), ("h2h12", "h14", "h14"), ("h14", "h3h6", "h3h6")):
        ra, rc = arms[a]["regions"], arms[c]["regions"]
        f = f"{ARM_FILE[a]} - {ARM_FILE[c]}"
        for k, reg in (("geom_depths", "in.geom_depths"), ("plane_fill", "in.plane_fill"), ("planes", "in.planes"), ("weak", "in.weak"),
                       ("upload_images", "up.images"), ("upload_depths", "up.depths"), ("upload_buffers", "up.buffers"),
                       ("unpack", "result_readback"), ("kernel_readback", "patchmatch.readback")):
            put(f"{name}.gain.{k}_s", ra[reg]["s"] - rc[reg]["s"], f"{f} ({reg})")
        put(f"{name}.gain.in_pass_s", arms[a]["input_load_s"] - arms[c]["input_load_s"], f"{f} (input_load in passes)")
        put(f"{name}.gain.upsample_s", sum(ra[k]["s"] - rc[k]["s"] for k in ("in.upsample.depth_normal", "in.upsample.views", "in.upsample.weak")), f"{f} (in.upsample.*)")
    put("h14.gain.upsample_share", 1 - sum(arms["h14"]["regions"][k]["s"] for k in ("in.upsample.depth_normal", "in.upsample.views", "in.upsample.weak"))
        / sum(arms["h2h12"]["regions"][k]["s"] for k in ("in.upsample.depth_normal", "in.upsample.views", "in.upsample.weak")),
        "data/breakdown-h2h12.csv, data/breakdown-h14.csv: 1 - in.upsample.* after / before; thesis-4.3/stage-input/cards/H14.md section 5 (-89 %)")
    put("h14.upsample_threshold_s", 3, "thesis-4.3/gate2-decisions.md item 3 (H14 only if in.upsample.* is above 3 s)")
    put("h3h6.transfers_before_s", st_arms["h14"]["phase_s"]["device_upload"] + st_arms["h14"]["phase_s"]["result_readback"] + arms["h14"]["regions"]["patchmatch.readback"]["s"],
        f"{cards} (h14: device_upload + result_readback) + data/breakdown-h14.csv (patchmatch.readback); thesis-4.3/stage-input/cards/H3H6.md section 6 (40 s)")
    put("h3h6.transfers_after_s", st_arms["h3h6"]["phase_s"]["device_upload"] + st_arms["h3h6"]["phase_s"]["result_readback"] + arms["h3h6"]["regions"]["patchmatch.readback"]["s"],
        f"{cards} (h3h6: device_upload + result_readback) + data/breakdown-h3h6.csv (patchmatch.readback); thesis-4.3/stage-input/cards/H3H6.md section 6 (9 s)")
    # ---- memory
    w, hgt = 6220, 4141   # .dev/findings/native-nondeterminism.md (native size)
    put("image.float_mb", w * hgt * 4 / 1e6, "6220 x 4141 px x 4 B; thesis-4.3/stage-input/cards/H1.md section 3 (103 MB)")
    put("cache.full_gb", 14 * w * hgt * 4 / 1e9, "14 images x 6220 x 4141 px x 4 B; thesis-4.3/stage-input/cards/H1.md section 2 (1.44 GB)")
    put("cache.round_max_gb", 14 * 3110 * 2071 * 4 / 1e9, "14 images x 3110 x 2071 px x 4 B (round at 1/2); thesis-4.3/stage-input/cards/H1.md section 2 (0.36 GB)")
    put("planes.buffer_mb", w * hgt * 16 / 1e6, "6220 x 4141 px x 16 B; thesis-4.3/stage-input/cards/H2h12.md section 1 (412 MB)")
    put("planes.column_stride_kb", w * 16 / 1e3, "6220 px x 16 B; thesis-4.3/stage-input/cards/H2h12.md section 3 (about 100 kB between writes)")
    put("planes.plane_bytes", 16, "thesis-4.3/stage-input/cards/H2h12.md section 3 (float4, stride 16 B)")
    put("h2h12.fresh_gb_per_native_pass", 2.4, "thesis-4.3/stage-input/cards/H2h12.md section 3 (about 2.4 GB of new memory per native pass)")
    put("h14.threads", 32, "thesis-4.3/stage-input/cards/H14.md section 2 (32 logical CPUs; the default of the pool, not a measured thread count)")
    put("h3h6.bus_gb_per_native_pass", 2.9, "thesis-4.3/stage-input/cards/H3H6.md section 3 (about 2.9 GB across PCIe per native pass)")
    put("h3h6.device_cache_gb", 2 * 14 * w * hgt * 4 / 1e9, "2 x 14 views x 6220 x 4141 px x 4 B; thesis-4.3/stage-input/cards/H3H6.md section 3 (2.9 GB for pipes)")
    put("h3h6.gpu_peak_mib", [7090, 7172], "thesis-4.3/stage-input/cards/H3H6.md section 3 (samplers/gpu.csv of the seed-1 runs, before and after)")
    put("h3h6.office.images", 26, "thesis-4.3/stage-input/cards/H3H6.md section 3 (office, N = 26)")
    put("h3h6.office.gpu_peak_mib", [8634, 9714], "thesis-4.3/stage-input/cards/H3H6.md section 3 \"Office check\" (samplers/gpu.csv: the office run of the unfixed base b228c67, s43-input-h3h6-office-s1)")
    put("h3h6.office.gpu_total_mib", 16303, "thesis-4.3/stage-input/cards/H3H6.md section 3 \"Office check\" (9714 MiB of 16303 MiB)")
    put("h3h6.office.bench_gpu_memory_gb", 12, "PLAN-4.3.md decision D1")
    # ---- exactness evidence
    put("e0.size_px", 1024, "thesis-4.3/stage-input/cards/H1.md section 7; H2h12.md, H14.md, H3H6.md section 4")
    put("e0.seeds", 3, "thesis-4.3/stage-input/cards/H1.md section 7 (native, seeds 1-3); H2h12.md, H14.md, H3H6.md section 4 (seeds 1-3, native and 1024)")
    put("e0.first_change_small_seeds", 1, "thesis-4.3/stage-input/cards/H1.md section 7 (H1 on base2 at 1024: seed 1 only, s43-input-h1-2-1024-s1)")
    put("cards", len(arms) - 1, "thesis-4.3/gate-m2-decisions.md item 2 (four accepted input cards)")
    b2 = read_csv(data / "base2.csv")
    put("base2.f1_2cm_by_seed", [float(r["f1_2cm_b2"]) for r in b2[:3]], "data/base2.csv (f1_2cm_b2, seeds 1-3); thesis-4.3/stage-input/cards/H1.md section 7 (0.8752 / 0.8771 / 0.8758)")
    # ---- the stack and what is left
    last = st_arms["h3h6"]
    put("stack.residual_s", stack["residual_s"], f"{cards} (h3h6: input_load + device_upload + result_readback, 3-run means); thesis-4.3/stage-input/analysis.md \"Residual after H3/H6\" (16.3 s)")
    put("stack.hideable_s", last["phase_s"]["input_load"], f"{cards} (h3h6, input_load); thesis-4.3/gate-m2-decisions.md item 3 and thesis-4.3/stage-input/analysis.md \"Residual after H3/H6\" (a prefetch could hide only the next pass's input loading, about 9 s)")
    put("stack.hide_threshold_s", 10, "thesis-4.3/gate2-decisions.md item 3 (hiding only if the residual is at least about 10 s)")
    put("stack.host_before_s", st_arms["base2"]["host_s"], f"{cards} (base2: run - patchmatch)")
    put("stack.host_after_s", last["host_s"], f"{cards} (h3h6: run - patchmatch)")
    return n


def numbers_prop(prop, ncu, sr):
    n = Numbers()
    put = n.put
    arms = {("base" if a["key"] == "base2" else a["key"]): a for a in prop["arms"] if a["key"] != "u8"}
    u8 = next(a for a in prop["arms"] if a["key"] == "u8")
    files = {a[0]: (a[4], a[5]) for a in PROP_ARMS}
    b = arms["base"]
    put("seed", prop["seed"], "thesis-4.3/stage-prop/cards/K2.md section 5 (nsys, native, APD_SEED=1)")
    put("changes", prop["cheap"], "thesis-4.3/gate-m4-decisions.md item 1 (K10, reftex, K2, K11, K7-lite, CU-2); the 8-bit textures are the seventh, v.u8")
    put("passes", prop["passes"], "data/kern-*-vs-*.csv (n_launches of the per-pass kernels)")
    put("iterations_per_pass", prop["launches"] // prop["passes"], "data/kern-*-vs-*.csv: n_launches of an update kernel / passes")
    put("ci_level_pct", prop["ci_level_pct"], "thesis-4.3/stage-prop/cards/K2.md section 4 (95 % CI, t(0.975, n - 1))")
    put("margin", prop["margin"], "thesis-4.3/gate-m2-decisions.md item 1 (Tier 1 margin)")
    put("tol.decides_cm", 2, "thesis-4.3/acceptance.md, decision D2 (all at 2 cm F1)")
    put("repeatability_s", prop["repeatability_s"], "data/kern-reftex-2-vs-k10-2.csv, kern-k11-vs-k2.csv, kern-k7lite-vs-k11.csv: largest |delta_s| of a kernel that an E0 change does not touch")
    put("e1_untouched_max_s", prop["e1_untouched_max_s"], "data/kern-k10-2-vs-base2.csv, kern-k2-vs-reftex-2.csv, kern-cu2-vs-k7lite.csv: largest |delta_s| of a kernel that an E1 change does not touch (GenNeighbours)")
    for key, a in arms.items():
        f = "data/" + (files["k10" if key == "base" else a["key"]][0])
        side = "base_s" if key == "base" else "cand_s"
        for k, g, _ in PROP_GROUPS:
            put(f"{key}.{k}_s", a["kernels"][k], f"{f} ({g}, {side})")
        put(f"{key}.prop_s", a["prop_s"], f"{f} (propagation, {side}: the two updates and RANSACToGetFitPlane)")
        put(f"{key}.all_kernels_s", a["all_kernels_s"], f"{f} (run (all kernels), {side})")
        if a["vs_parent"]:
            parent = prop["arms"][[x["key"] for x in prop["arms"]].index(a["key"]) - 1]
            for k in [g[0] for g in PROP_GROUPS] + ["prop", "all_kernels"]:
                put(f"{key}.gain.{k}_s", -a["vs_parent"][k], f"{f} ({k}, -delta_s)")
            for k in ("weak", "strong", "depth_to_weak", "local_refine"):
                put(f"{key}.gain.{k}_share", -a["vs_parent"][k] / parent["kernels"][k], f"{f} ({k}: -delta_s / base_s)")
            rf = "data/" + files[a["key"]][1]
            n.put_stat(f"{key}.run", a["run"], f"{rf} (cand_span_s - ref_span_s, paired by seed, t n-1 dof)")
            put(f"{key}.run_n", a["run"]["n"], f"{rf} (rows)")
            put(f"{key}.md5_seeds", a["md5_seeds"], f"{rf} (cand_md5 against ref_md5 at native: {'equal' if a['class'] == 'E0' else 'different'} for every seed)")
            if a["f1_2cm"]:
                n.put_stat(f"{key}.f1_2cm", a["f1_2cm"], f"{rf} (cand_f1_2 - ref_f1_2, paired by seed, t 4 dof)")
                put(f"{key}.f1_n", a["f1_2cm"]["n"], f"{rf} (rows)")
    put("base.prop_share_of_kernels", b["prop_s"] / b["all_kernels_s"], "data/kern-k10-2-vs-base2.csv: propagation / run (all kernels), base_s")
    put("base.weak_share_of_prop", b["kernels"]["weak"] / b["prop_s"], "data/kern-k10-2-vs-base2.csv: weak (Black+Red) / propagation, base_s")
    five, six = arms["k7lite"], arms["cu2"]
    put("five.prop_gain_s", b["prop_s"] - five["prop_s"], "data/kern-k10-2-vs-base2.csv (propagation, base_s) - data/kern-k7lite-vs-k11.csv (propagation, cand_s)")
    put("five.all_kernels_gain_s", b["all_kernels_s"] - five["all_kernels_s"], "data/kern-k10-2-vs-base2.csv (run (all kernels), base_s) - data/kern-k7lite-vs-k11.csv (cand_s); thesis-4.3/stage-prop/cards/K7lite.md section 5 (-154.6 s)")
    put("six.prop_gain_s", b["prop_s"] - six["prop_s"], "data/kern-k10-2-vs-base2.csv (propagation, base_s) - data/kern-cu2-vs-k7lite.csv (propagation, cand_s)")
    put("six.prop_gain_share", 1 - six["prop_s"] / b["prop_s"], "the same: 1 - cand_s / base_s")
    put("six.weak_gain_share", 1 - six["kernels"]["weak"] / b["kernels"]["weak"], "data/kern-k10-2-vs-base2.csv (weak, base_s), data/kern-cu2-vs-k7lite.csv (weak, cand_s)")
    put("six.strong_gain_share", 1 - six["kernels"]["strong"] / b["kernels"]["strong"], "data/kern-k10-2-vs-base2.csv (strong, base_s), data/kern-cu2-vs-k7lite.csv (strong, cand_s)")
    put("six.weak_share_of_prop", six["kernels"]["weak"] / six["prop_s"], "data/kern-cu2-vs-k7lite.csv: weak (Black+Red) / propagation, cand_s")
    put("six.finalization_gain_s", sum(b["kernels"][k] - six["kernels"][k] for k in ("depth_to_weak", "local_refine")), "data/kern-k10-2-vs-base2.csv (base_s) - data/kern-cu2-vs-k7lite.csv (cand_s): DepthToWeak + LocalRefine")
    n.put_stat("five.f1_2cm", prop["stack_f1_2cm"], "data/tier1-k2stack-vs-base2.csv (cand_f1_2 - ref_f1_2, paired by seed, t 4 dof: the third build against base2; the fourth and fifth give its clouds); thesis-4.3/gate-m4-decisions.md item 1")
    put("five.f1_n", prop["stack_f1_2cm"]["n"], "data/tier1-k2stack-vs-base2.csv (rows)")
    n.put_stat("six.f1_2cm", prop["six_f1_2cm"], "data/tier1-cu2-vs-k7lite.csv (cand_f1_2: the sixth build) - data/tier1-k2stack-vs-base2.csv (ref_f1_2: base2), paired by seed, seeds 1-5, t 4 dof; computed here, not quoted in a note")
    # ---- counters of one native launch per build
    for bld in ncu["builds"] + [ncu["u8_parent"]]:
        if bld["key"] == "comb-cu2":
            for k in NCU_KERNELS:
                for c in NCU_COLS:
                    put(f"ncu.u8.{k}.before.{c}", bld[k][c], f"data/ncu-8bit-vs-comb-cu2.csv ({bld['run']}, {NCU_KERNELS[k]}, {c})")
                for c in NCU_U8_COLS:
                    put(f"ncu.u8.{k}.drop.{c}", 1 - next(x for x in ncu["builds"] if x["key"] == "u8")[k][c] / bld[k][c], f"data/ncu-8bit-vs-comb-cu2.csv ({NCU_KERNELS[k]}, {c}: 1 - after / before)")
            continue
        f = "data/" + next(x[2] for x in PROP_NCU if x[0] == bld["key"])
        for k in NCU_KERNELS:
            for c in NCU_COLS:
                put(f"ncu.{bld['key']}.{k}.{c}", bld[k][c], f"{f} ({bld['run']}, {NCU_KERNELS[k]}, {c})")
    by = {x["key"]: x for x in ncu["builds"]}
    for key, parent, cols in (("k2", "reftex", ("dur_ms", "l2_req", "l2_sect", "tex_inst", "warp_inst")),
                              ("k11", "k2", ("dur_ms", "l2_req", "l2_sect", "global_ld_sect")),
                              ("k7lite", "k11", ("dur_ms", "l2_req", "l2_sect", "local_st_sect")),
                              ("cu2", "k7lite", ("dur_ms", "l2_req", "global_ld_sect"))):
        f = "data/" + next(x[2] for x in PROP_NCU if x[0] == key)
        for k in NCU_KERNELS:
            for c in cols:
                put(f"ncu.{key}.{k}.drop.{c}", 1 - by[key][k][c] / by[parent][k][c], f"{f} ({NCU_KERNELS[k]}, {c}: 1 - after / before)")
    put("ncu.k11.weak.local_ld_added", by["k11"]["weak"]["local_ld_sect"] - by["k2"]["weak"]["local_ld_sect"], "data/ncu-k11-vs-k2.csv (BlackPixelUpdateWeak, local_ld_sect: after - before)")
    put("ncu.tag_range_pct", ncu["tag_range_pct"], "data/ncu-*.csv (BlackPixelUpdateWeak, l2_tag_pct: smallest and largest over the builds of the third to the sixth change)")
    put("ncu.launch", {"image": 4, "pass": 15, "iteration": 0}, "thesis-4.3/stage-prop/cards/K2.md section 5 (scale 0, image 4, REFINE_ITER pass 15, iteration 0, seed 1)")
    zw = ncu["zero_weight_calls"]
    put("k2.zero_weight_calls", zw, "thesis-4.3/stage-prop/cards/K2.md section 1; thesis-4.3/stage-prop/analysis.md section 1 (28-30 % of the calls are multiplied by a zero weight)")
    drop = 1 - by["k2"]["weak"]["l2_req"] / by["reftex"]["weak"]["l2_req"]
    put("k2.request_drop_of_zero_weight", [drop / zw[1], drop / zw[0]], "data/ncu-k2-vs-reftex-2.csv (BlackPixelUpdateWeak, l2_req: 1 - after / before) / the share of calls with zero weight; thesis-4.3/stage-prop/cards/K2.md section 5 (about a third)")
    assert 0.28 < drop / zw[1] and drop / zw[0] < 0.38, "about a third"
    # ---- the seventh change: 8-bit image textures, on the combined stack
    uf, ur = "data/kern-8bit-vs-comb-cu2.csv", "data/tier1-8bit-vs-comb-cu2.csv"
    for k, g, _ in PROP_GROUPS:
        put(f"u8.{k}_s", u8["kernels"][k], f"{uf} ({g}, cand_s)")
        put(f"u8.before.{k}_s", u8["parent"]["kernels"][k], f"{uf} ({g}, base_s: 5cf8608)")
        put(f"u8.gain.{k}_s", -u8["vs_parent"][k], f"{uf} ({g}, -delta_s)")
    for k in ("weak", "strong"):
        put(f"u8.gain.{k}_share", -u8["vs_parent"][k] / u8["parent"]["kernels"][k], f"{uf} ({k}: -delta_s / base_s)")
    put("u8.prop_s", u8["prop_s"], f"{uf} (propagation, cand_s)")
    put("u8.before.prop_s", u8["parent"]["prop_s"], f"{uf} (propagation, base_s)")
    put("u8.gain.all_kernels_s", -u8["vs_parent"]["all_kernels"], f"{uf} (run (all kernels), -delta_s)")
    put("u8.stack_all_kernels_s", u8["stack_all_kernels_s"], f"{uf} (run (all kernels): base_s, cand_s; both on the combined stack)")
    put("u8.parent_vs_sixth_max_s", u8["parent_vs_sixth_max_s"], f"{uf} (base_s) against data/kern-cu2-vs-k7lite.csv (cand_s): largest difference of a propagation or finalization kernel between 5cf8608 and the sixth build on the fixed base")
    n.put_stat("u8.run", u8["run"], f"{ur} (cand_span_s - ref_span_s, paired by seed, seeds 1-5, t 4 dof)")
    put("u8.run_n", u8["run"]["n"], f"{ur} (rows)")
    put("u8.run_s", u8["run_s"], f"{ur} (cand_span_s, mean of 5 seeds)")
    put("u8.before.run_s", u8["parent_run_s"], f"{ur} (ref_span_s, mean of 5 seeds)")
    put("u8.run_share", -u8["run"]["mean"] / u8["parent_run_s"], f"{ur}: -mean difference / mean ref_span_s")
    put("u8.md5_seeds", u8["md5_seeds"], f"{ur} (cand_md5 against ref_md5 at native: different for every seed)")
    n.put_stat("u8.f1_2cm", u8["f1_2cm"], f"{ur} (cand_f1_2 - ref_f1_2, paired by seed, t 4 dof)")
    put("u8.f1_n", u8["f1_2cm"]["n"], f"{ur} (rows)")
    put("u8.tier2_margin", MARGIN_TIER2, "thesis-4.3/acceptance.md, decision D2 (Tier 2: lower bound at least -0.002)")
    put("u8.texel_bytes", [4, 1], "thesis-4.3/stage-prop/cards/8bit.md section 1 (4-byte float texels, 1-byte texels)")
    put("u8.native_rounds_only", 1, "thesis-4.3/stage-prop/cards/8bit.md section 2 (APD.h:99: 8-bit only at scale_size == 1; rounds 0-2 keep R32F)")
    put("u8.refonly.small_seeds", 3, "thesis-4.3/stage-prop/cards/8bit.md section 4 (reference-only DIAGNOSTIC build: md5 = parent at 1024, seeds 1-3)")
    put("u8.refonly.native_seeds", 1, "thesis-4.3/stage-prop/cards/8bit.md section 4 (reference-only DIAGNOSTIC build: md5 = parent at native, seed 1)")
    put("u8.scale", 255, "thesis-4.3/stage-prop/cards/8bit.md section 2 (FetchSrc: tex2D<float> x 255.0f)")
    put("u8.pipes_gpu_peak_mib", [[7238, 7240], [6172, 6176]], "thesis-4.3/stage-prop/cards/8bit.md section 5 \"GPU memory\" (samplers/gpu.csv, peak memory.used over the five seed pairs: before, after)")
    put("u8.pipes_gpu_saved_mib", 1064, "thesis-4.3/stage-prop/cards/8bit.md section 5 \"GPU memory\" (-1064 MiB)")
    put("u8.office_gpu_peak_mib", [9782, 7806], "thesis-4.3/stage-prop/cards/8bit.md section 5 \"GPU memory\" (office native, seed 1: s43-prop-comb-cu2-office-s1, s43-prop-8bit-office-s1)")
    put("u8.office_seeds", 1, "thesis-4.3/stage-prop/cards/8bit.md section 5 (one seed each, informative only)")
    put("u8.office_base_gpu_peak_mib", 8634, "thesis-4.3/stage-prop/cards/8bit.md section 5 (the M0 office base, b228c67)")
    put("u8.bench_gpu_memory_gb", 12, "PLAN-4.3.md decision D1")
    # ---- what the stage does (not in a CSV file)
    put("calls.deformable_per_view", 15, "thesis-4.3/stage-prop/analysis.md section 1 \"Calls per weak pixel per launch\" (15 S deformable calls)")
    put("calls.plain_per_view", 1, "thesis-4.3/stage-prop/analysis.md section 1 (S plain calls: the final rewrite)")
    put("calls.selection_per_view", 8, "thesis-4.3/stage-prop/analysis.md section 1 (8 S: the anchor-plane cost vectors of the view selection, all views needed)")
    put("calls.weighted_only_per_view", 8, "thesis-4.3/stage-prop/cards/K2.md section 1 (8 S: current plane, fit plane, 5 refinement planes, final plain rewrite)")
    put("calls.refinement_planes", 5, "thesis-4.3/stage-prop/cards/K2.md section 1 (5 refinement planes)")
    put("calls.strong_per_view", 14, "thesis-4.3/stage-prop/cards/K2.md section 1 (strong update: 14 S plain calls)")
    put("calls.strong_weighted_only_per_view", 6, "thesis-4.3/stage-prop/cards/K2.md section 1 (strong update: current plane and 5 refinement planes, 6 S)")
    put("views.weighted", 3.79, "thesis-4.3/stage-prop/cards/K2.md section 1 (instr-counters.md (a), round 3: 3.79 of 9.71 source views with weight > 0)")
    put("views.total", 9.71, "thesis-4.3/stage-prop/cards/K2.md section 1 (the same)")
    put("anchors", 8, "thesis-4.3/stage-prop/analysis.md \"Sources and conventions\" (a 3 x 3 window at each of the 8 anchors)")
    put("window.centre", 6, "thesis-4.3/stage-prop/analysis.md \"Sources and conventions\" (6 x 6 centre window)")
    put("window.anchor", 3, "thesis-4.3/stage-prop/analysis.md \"Sources and conventions\" (3 x 3 window per anchor)")
    put("window.sizes", 2, "thesis-4.3/stage-prop/cards/K10.md section 2 (dispatched for the two configured windows: radius 5 with increment 2 and with increment 5)")
    # the profile of the weak update before any change: one launch, on the unfixed base (the same kernel code)
    fnd = ".dev/findings/l2-throughput-is-tag-requests.md (perf-ncu-native-r1 row 11: BlackPixelUpdateWeak, scale 0, image 4, pass 15, iteration 0; kernels of 95c9294)"
    put("profile.l1_hit", 0.622, fnd + ": l1tex__t_sector_hit_rate")
    put("profile.l2_tag", 0.7085, fnd + ": lts__t_tag_requests, percent of peak, equal to lts__throughput")
    put("profile.l2_sector_use", 0.477, fnd + ": lts__t_sectors, percent of peak")
    put("profile.sectors_per_request", 1.35, fnd + ": lts__t_sectors.sum / lts__t_requests.sum")
    put("profile.sector_bytes", 32, "thesis-4.3/stage-prop/deep-8bit-design.md section 1 (a 32 B sector)")
    put("profile.window_loop_stall_share", 0.75, "thesis-4.3/stage-prop/analysis.md section 1 \"Stalls\" (75 % of weak stall samples in the NCC window loop)")
    put("profile.strong_l2", 0.31, "thesis-4.3/stage-prop/analysis.md section 1 (strong, at L2 31 %, before the first change)")
    # the first change, profiled on the unfixed base in a build that also has the register change of the anchor stack
    k10 = "thesis-4.3/stage-prop/cards/K10.md section 5 (ncu, one native launch, perf-ncu-ncc-r1; unfixed base)"
    put("k10.ncu.weak_inst", [2.05e11, 1.63e11], k10 + ": warp instructions of the weak launch")
    put("k10.ncu.weak_ms", [1354, 1319], k10 + ": duration of the weak launch")
    put("k10.ncu.weak_stall_cycles", [2.47e12, 2.52e12], k10 + ": long-scoreboard stall cycles of the weak launch")
    put("k10.ncu.strong_ms", [156, 83], k10 + ": duration of the strong launch")
    put("k10.ncu.strong_stall_drop", 0.64, k10 + ": long-scoreboard stall cycles of the strong launch, 2.28e11 -> 0.82e11")
    put("k2.ffma", {"weak": [2678, 2666], "strong": [4481, 4458]}, "thesis-4.3/stage-prop/cards/K2.md section 4 (static FFMA count, tools/s43_prop_ptxas.sh: parent, with the change)")
    put("k11.anchors_read", 9, "thesis-4.3/stage-prop/cards/K11.md section 1 (the pixel's own centre and 8 strong points)")
    put("k11.record_bytes", 36, "thesis-4.3/stage-prop/cards/K11.md section 1 (36 B per weak pixel)")
    put("k11.excessive_share", 0.57, "thesis-4.3/stage-prop/cards/K11.md section 1 (57 % of global-load sectors at L1 excessive, on the base)")
    put("k11.excessive_from_anchors", 0.77, "thesis-4.3/stage-prop/cards/K11.md section 1 (77 % of that excess from the anchor re-reads)")
    put("k11.stack_bytes", [1488, 1536], "thesis-4.3/stage-prop/cards/K11.md section 3 (stack per thread, tools/s43_prop_ptxas.sh)")
    put("k11.request_bytes", 128, "thesis-4.3/stage-prop/cards/K11.md section 3 (one fully used 128 B request per warp)")
    put("k7lite.array", [8, 32], "thesis-4.3/stage-prop/cards/K7lite.md section 1 (float cost_array[8][32])")
    put("k7lite.array_floats", 8 * 32, "8 x 32; thesis-4.3/stage-prop/cards/K7lite.md section 1 (256 floats)")
    put("k7lite.vectors", [6, 7], "thesis-4.3/stage-prop/cards/K7lite.md section 1 (six or seven cost vectors of 32 floats)")
    put("k7lite.filled_kb", [1.2, 1.4], "thesis-4.3/stage-prop/cards/K7lite.md section 3 (about 1.2-1.4 KB of stack per launch)")
    put("cu2.camera_bytes", 112, "thesis-4.3/stage-prop/cards/CU2.md section 1 (two 112-byte structs)")
    put("cu2.loads_per_call", 40, "thesis-4.3/stage-prop/cards/CU2.md section 1 (about 40 loads per call)")
    put("cu2.table_cameras", 32, "thesis-4.3/stage-prop/cards/CU2.md section 2 (c_cameras[MAX_IMAGES], 32 x 112 B)")
    put("cu2.table_kb", 32 * 112 / 1e3, "32 x 112 B; thesis-4.3/stage-prop/cards/CU2.md section 2 (3.5 KB)")
    put("cu2.registers", [128, 122], "thesis-4.3/stage-prop/cards/CU2.md section 3 (weak kernel, tools/s43_prop_ptxas.sh)")
    put("cu2.ffma", {"weak": [2666, 2678], "strong": [4458, 4376]}, "thesis-4.3/stage-prop/cards/CU2.md section 4 (static FFMA count: parent, with the change)")
    # ---- exactness evidence that is not in a CSV file
    put("e1.changes", sum(a["class"] == "E1" for a in prop["arms"]), "PROP_ARMS (class E1): thesis-4.3/gate-m4-decisions.md item 1 (K10, K2, CU-2)")
    put("e1.nofma_md5_native", "37bd00b8", "thesis-4.3/stage-prop/cards/K10.md section 7, K2.md section 4, CU2.md section 4 (--fmad=false builds of base2, K10-2, K2 and CU-2 at native, seed 1: runs s43-anchor-base2-nofma-native-s1, s43-prop-k10-2-nofma-native-s1, s43-prop-k2-nofma-native-s1, s43-prop-cu2-nofma-native-s1); thesis-4.3/gate-m4-decisions.md item 1")
    put("e1.nofma_builds", 4, "the same: the fixed base and the three E1 builds")
    put("e1.nofma_seeds", 1, "the same: native seed 1, one run per build")
    put("e1.nofma_small_px", 1024, "thesis-4.3/stage-prop/cards/K2.md section 4, K7lite.md section 4, CU2.md section 4 (--fmad=false builds identical at 1024, seed 1: 994c5b3b)")
    put("e0.small_px", 1024, "thesis-4.3/stage-prop/cards/reftex.md section 7, K11.md section 4, K7lite.md section 4 (md5 identical to the parent at 1024)")
    put("e0.small_seeds", 3, "thesis-4.3/stage-prop/cards/reftex.md section 7, K11.md section 4, K7lite.md section 4 (1024, seeds 1-3)")
    put("seednoise.f1_2cm.lo", -0.0016, "thesis-4.3/m0/determinism.md \"Seed noise on base2\" (index pairing, 2 cm: +0.0004 [-0.0016, +0.0024]); numbers-method.json sn.f1.at2cm")
    put("seednoise.f1_2cm.hi", 0.0024, "the same")
    # ---- the stack
    arm = {a["key"]: a for a in sr["arms"]}
    comb, pc = arm["comb"], arm["prop-comb"]
    ps = "data/phases-stack.csv"
    put("stack.changes", 5, "thesis-4.3/README.md M4 (exp/s43-prop-comb 714ed21: K10, reftex, K2, K11, K7-lite on the combined stack)")
    put("stack.seeds", sr["seeds"], f"{ps} (seeds)")
    put("stack.n", sr["n"], f"{ps} (seeds)")
    put("stack.comb_run_s", comb["run_s"], f"{ps} (comb, run: mean of 3 seeds); data/wall-propcomb-vs-comb.csv (ref_span_s)")
    put("stack.run_s", pc["run_s"], f"{ps} (prop-comb, run: mean of 3 seeds); data/wall-propcomb-vs-comb.csv (cand_span_s)")
    n.put_stat("stack.run", pc["vs_parent"], "data/wall-propcomb-vs-comb.csv (cand_span_s - ref_span_s, paired by seed, t 2 dof)")
    put("stack.run_share", -pc["vs_parent"]["mean"] / comb["run_s"], f"{ps}: -(prop-comb - comb) / comb, run")
    n.put_stat("stack.vs_base", pc["vs_base"], "data/wall-propcomb-vs-comb.csv (cand_span_s) - data/tier1-k2stack-vs-base2.csv (ref_span_s of base2, seeds 1-3), paired by seed, t 2 dof; thesis-4.3/README.md M4 (-486.7 s)")
    put("stack.base_run_s", arm["base2"]["run_s"], f"{ps} (base2, run: mean of 3 seeds)")
    put("stack.vs_base_share", -pc["vs_base"]["mean"] / arm["base2"]["run_s"], f"{ps}: -(prop-comb - base2) / base2, run")
    part = lambda a, k: next(x["s"] for x in a["parts"] if x["key"] == k)
    put("stack.propagation_phase_s", [part(comb, "propagation"), part(pc, "propagation")], f"{ps} (patchmatch.propagate + prior_build: comb, prop-comb)")
    put("stack.finalization_phase_s", [part(comb, "finalization"), part(pc, "finalization")], f"{ps} (patchmatch.finalize: comb, prop-comb)")
    put("stack.kernel_share", sum(part(pc, k) for k in ("initialization", "propagation", "finalization")) / pc["run_s"], f"{ps} (prop-comb: patchmatch.init + .propagate + prior_build + .finalize) / run")
    put("stack.propagation_share", part(pc, "propagation") / pc["run_s"], f"{ps} (prop-comb: patchmatch.propagate + prior_build) / run")
    assert sr["prop_md5"] == prop["stack_md5"][:len(sr["prop_md5"])], "the stack gives the clouds of the fifth build"
    # the sixth change on the combined stack
    p6 = arm["prop-comb-cu2"]
    w6 = "data/wall-propcomb-cu2-vs-714ed21.csv"
    put("stack.six.run_s", p6["run_s"], f"{ps} (prop-comb-cu2, run: mean of 3 seeds); {w6} (cand_span_s)")
    n.put_stat("stack.six.run", p6["vs_parent"], f"{w6} (cand_span_s - ref_span_s, paired by seed, t 2 dof)")
    n.put_stat("stack.six.vs_base", p6["vs_base"], f"{w6} (cand_span_s) - data/tier1-k2stack-vs-base2.csv (ref_span_s of base2, seeds 1-3), paired by seed, t 2 dof")
    put("stack.six.vs_base_share", -p6["vs_base"]["mean"] / arm["base2"]["run_s"], f"{ps}: -(prop-comb-cu2 - base2) / base2, run")
    put("stack.six.propagation_phase_s", part(p6, "propagation"), f"{ps} (prop-comb-cu2: patchmatch.propagate + prior_build)")
    put("stack.six.kernel_share", sum(part(p6, k) for k in ("initialization", "propagation", "finalization")) / p6["run_s"], f"{ps} (prop-comb-cu2: patchmatch.init + .propagate + prior_build + .finalize) / run")
    put("stack.six.propagation_share", part(p6, "propagation") / p6["run_s"], f"{ps} (prop-comb-cu2: patchmatch.propagate + prior_build) / run")
    p8 = arm["prop-8bit"]
    put("stack.u8.run_s", p8["run_s"], f"{ps} (prop-8bit, run: mean of seeds 1-3)")
    n.put_stat("stack.u8.run", p8["vs_parent"], "data/tier1-8bit-vs-comb-cu2.csv (cand_span_s - ref_span_s, seeds 1-3 only, paired by seed, t 2 dof: the seeds of <fig-perf-stack-run>)")
    n.put_stat("stack.u8.vs_base", p8["vs_base"], "data/tier1-8bit-vs-comb-cu2.csv (cand_span_s, seeds 1-3) - data/tier1-k2stack-vs-base2.csv (ref_span_s of base2), paired by seed, t 2 dof")
    put("stack.u8.vs_base_share", -p8["vs_base"]["mean"] / arm["base2"]["run_s"], f"{ps}: -(prop-8bit - base2) / base2, run")
    put("stack.u8.propagation_phase_s", [part(p6, "propagation"), part(p8, "propagation")], f"{ps} (patchmatch.propagate + prior_build: prop-comb-cu2, prop-8bit)")
    put("stack.u8.kernel_share", sum(part(p8, k) for k in ("initialization", "propagation", "finalization")) / p8["run_s"], f"{ps} (prop-8bit: patchmatch.init + .propagate + prior_build + .finalize) / run")
    cu2_md5 = [r["cand_md5"] for r in read_csv(DATA / "tier1-cu2-vs-k7lite.csv")]
    assert sr["prop6_md5"] == cu2_md5[:len(sr["prop6_md5"])], "the stack gives the clouds of the sixth build"
    put("stack.six.md5_seeds", len(sr["prop6_md5"]), f"{w6} (cand_md5) = data/tier1-cu2-vs-k7lite.csv (cand_md5), seeds 1-3: the clouds of the sixth build on the fixed base")
    put("stack.md5_seeds", len(sr["prop_md5"]), "data/wall-propcomb-vs-comb.csv (cand_md5) = data/tier1-k2stack-vs-base2.csv (cand_md5), seeds 1-3: the clouds of the third to fifth build on the fixed base")
    return n


# =================================================================================================
# M6: the final stack exp/s43-stack (c20e935, 23 commits on the fixed base): the ablation (one row
# per commit, in stack order), the stack by stage, the final test on two scenes and the run
# breakdown of the fixed base against the stack. All from snapshots of thesis-4.3/stack/data.
# =================================================================================================
ABL_KEYS = {  # row in ablation.csv -> key
    "base2": "base2", "timers": "timers", "H1": "h1", "H2'+H12": "h2h12", "H14": "h14", "H3/H6": "h3h6",
    "K3": "k3", "K12": "k12", "K1c": "k1c", "GN-L": "gnl", "IRS": "irs",
    "K10": "k10", "reftex": "reftex", "K2": "k2", "K11": "k11", "K7-lite": "k7lite", "CU-2": "cu2", "8-bit": "u8",
    "C2": "c2", "C1": "c1", "K13": "k13", "C9": "c9", "C3": "c3", "fix-d2w": "fix", "stack": "stack",
}
ABL_STAGES = [  # key, last row, rows; the run-time change of a stage is that of its last row against the last row of the stage before
    ("input", "h3h6", ["timers", "h1", "h2h12", "h14", "h3h6"]),
    ("anchor", "irs", ["k3", "k12", "k1c", "gnl", "irs"]),
    ("prop", "cu2", ["k10", "reftex", "k2", "k11", "k7lite", "cu2"]),
    ("u8", "u8", ["u8"]),
    ("class", "fix", ["c2", "c1", "k13", "c9", "c3", "fix"]),
]
ABL_STAGE_EXPECTED = {"input": -180.8, "anchor": -153.1, "prop": -157.7, "u8": -75.5, "class": -9.1}   # src: thesis-4.3/stack/ablation.md section 2 "By stage"
ABL = "data/ablation.csv"
ABL_F1 = "data/ablation-f1.csv"


def _t_pdf(x, nu):
    return math.gamma((nu + 1) / 2) / (math.sqrt(nu * math.pi) * math.gamma(nu / 2)) * (1 + x * x / nu) ** (-(nu + 1) / 2)


def t_quantile(p, nu):
    """Quantile of Student's t for a fractional number of degrees of freedom (Simpson's rule and bisection)."""
    def cdf(x, steps=4000):
        h = x / steps
        return 0.5 + h / 3 * sum((1 if i in (0, steps) else 4 if i % 2 else 2) * _t_pdf(i * h, nu) for i in range(steps + 1))
    lo, hi = 0.0, 200.0
    for _ in range(80):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if cdf(mid) < p else (lo, mid)
    return (lo + hi) / 2


T975_5, T975_6 = t_quantile(0.975, 5), t_quantile(0.975, 6)
for _dof, _t in T975.items():
    close(t_quantile(0.975, _dof), _t, 6e-4, f"t quantile, {_dof} dof")


def _mlh(s):
    return {k: s[k] for k in ("mean", "lo", "hi")}


HASH_MAP = "data/main-hash-map.md"


def main_hashes(data):
    """Gate 6 item 4: the stack was replayed onto main commit by commit. For every stack commit, its commit on main
    (the same change plus main's rename of one function) and the tag on it; and the check of the new tip."""
    text = (data / "main-hash-map.md").read_text()
    tick = lambda c: c.strip().strip("`")
    by_stack, order = {}, []
    for line in text.splitlines():
        c = [x.strip() for x in line.strip().strip("|").split("|")]
        if len(c) == 8 and c[0].isdigit():
            row = {"n": int(c[0]), "card": c[1], "stack": tick(c[3]), "main": tick(c[4]), "main_full": tick(c[5]), "tag": tick(c[7]) or None}
            assert len(row["stack"]) == len(row["main"]) == 7 and row["main_full"].startswith(row["main"]) and len(row["main_full"]) == 40, line
            by_stack[row["stack"]] = row
            order.append(row)
    assert [r["n"] for r in order] == list(range(1, 28)), len(order)
    tags = {r["tag"]: r["main"] for r in order if r["tag"]}
    assert list(tags) == ["s43-base2", "s43-input", "s43-anchor", "s43-propagation", "s43-classification"], tags
    tip = order[-1]
    # the paragraph "Verification scope": the md5s of the rebuilt tip at native, seeds 1-3
    para = next(p for p in text.split("\n\n") if p.startswith("**Verification scope.**"))
    import re
    md5 = re.findall(r"`([0-9a-f]{8})`", para)[:3]
    assert f"`{tip['main']}`" in para and f"`{tip['stack']}`" in para and len(md5) == 3, para
    return {"by_stack": by_stack, "tags": tags, "tip": tip, "tip_md5": md5, "verified_seeds": len(md5)}


def ablation(data):
    hm = main_hashes(data)
    # ---- F1 of the rows that change the result: five seeds, paired with the row before
    f1 = defaultdict(dict)
    for r in read_csv(data / "ablation-f1.csv"):
        per = [float(x) for x in r["per_seed"].split()]
        s = {"mean": float(r["dF1"]), "lo": float(r["lo"]), "hi": float(r["hi"]), "n": int(r["n"]), "per_seed": per, "vs": ABL_KEYS[r["vs"]]}
        assert s["n"] == len(per) == 5, r
        rec = paired(per)   # the per-seed differences are rounded to 1e-4
        close(rec["mean"], s["mean"], 1.01e-4, f"ablation F1 {r['row']} {r['tol']} mean"), close(rec["lo"], s["lo"], 2e-4, f"ablation F1 {r['row']} {r['tol']} lo")
        if round(s["mean"], 4) == 0:
            s["mean"] = rec["mean"]   # a mean that rounds to zero keeps the sign that the file prints
            assert (rec["mean"] < 0) == r["dF1"].startswith("-"), r
        s["tier1"] = -MARGIN_TIER1 < s["lo"] and s["hi"] < MARGIN_TIER1
        s["tier2"] = s["lo"] >= -MARGIN_TIER2
        assert s["tier1"] == (r["tier1_pm0.003"] == "pass") and s["tier2"] == (r["tier2_lo_ge_-0.002"] == "pass"), r
        # seeds whose F1 is not from a run of this row but from a row with the same cloud (class E0 in between)
        bridged = {"row": {}, "prev": {}}
        for tok in r["sources(row/prev)"].split():
            seed, rest = tok.split(":", 1)
            for side, part in zip(("row", "prev"), rest.split("/")):
                if part.startswith("bridged:"):
                    bridged[side][seed[1:]] = ABL_KEYS[part.split(":")[1]]
                else:
                    assert part == "measured", tok
        s["bridged"] = bridged
        f1[ABL_KEYS[r["row"]]]["at" + r["tol"]] = s
    # ---- one row per commit
    rows, by = [], {}
    for r in read_csv(data / "ablation.csv"):
        key = ABL_KEYS[r["row"]]
        spans = [float(x) for x in r["span_per_seed"].split()]
        md5 = dict(x.split(":") for x in r["md5"].split())
        row = {"key": key, "row": r["row"], "stage": r["stage"], "commit": r["stack_commit"], "original": r["run_commit"],
               "class": r["class_vs_prev"], "n": int(r["n_time"]), "run_s": float(r["span_mean_s"]), "run_by_seed": spans,
               "f1_2cm_mean": float(r["f1_2cm_mean_s1_3"]), "md5": md5, "runs": r["runs"].split(), "vs_prev": None, "vs_base": None,
               "f1": f1.get(key)}
        # the commit on main and its tag; every measurement of the row belongs to the stack commit (or its original)
        row["main"], row["tag"] = hm["by_stack"][row["commit"]]["main"], hm["by_stack"][row["commit"]]["tag"]
        assert row["n"] == len(spans) == 3, r
        close(st.mean(spans), row["run_s"], 0.051, f"ablation {key}: mean span")
        if rows:
            prev = rows[-1]
            for name, other, cols in (("vs_prev", prev, ("d_prev_s", "d_prev_lo", "d_prev_hi")), ("vs_base", rows[0], ("d_base2_s", "d_base2_lo", "d_base2_hi"))):
                d = dict(zip(("mean", "lo", "hi"), (float(r[c]) for c in cols)))
                rec = paired([a - b for a, b in zip(spans, other["run_by_seed"])])   # from spans rounded to 0.1 s
                close(rec["mean"], d["mean"], 0.11, f"ablation {key} {name} mean"), close(rec["lo"], d["lo"], 0.35, f"ablation {key} {name} lo"), close(rec["hi"], d["hi"], 0.35, f"ablation {key} {name} hi")
                row[name] = d
            assert int(r["n_pair_prev"]) == 3
            # the class of a row against the clouds: E0 (and the stack image, the same tree) has the md5 of the row before on every seed both have
            shared = [k for k in md5 if k in prev["md5"]]
            same = [md5[k] == prev["md5"][k] for k in shared]
            assert len(shared) >= 3 and (all(same) if row["class"] in ("E0", "=") else not any(same)), (key, same)
            assert r["md5_eq_prev"].startswith("all" if row["class"] in ("E0", "=") else "differs"), r
            row["md5_seeds"] = len(shared)
            assert (row["f1"] is not None) == (row["class"] in ("E1", "E2")), key
            if row["f1"]:
                assert row["f1"]["at2cm"]["vs"] == prev["key"] and r["tier1_2cm"].endswith("pass") == row["f1"]["at2cm"]["tier1"], key
        rows.append(row)
        by[key] = row
    assert [r["key"] for r in rows] == list(ABL_KEYS.values())
    commits = rows[1:-1]   # without the base and without the row of the stack image (the tree of the last commit)
    assert by["stack"]["commit"] == by["fix"]["commit"] and by["stack"]["class"] == "="
    # ---- by stage, from the spans of the file (0.1 s)
    stages, start = [], by["base2"]
    for key, last, members in ABL_STAGES:
        end = by[last]
        assert [r["key"] for r in commits if r["key"] in members] == members
        d = paired([a - b for a, b in zip(end["run_by_seed"], start["run_by_seed"])])
        close(round(end["run_s"] - start["run_s"], 1), ABL_STAGE_EXPECTED[key], 1e-9, f"ablation stage {key}")
        close(d["mean"], ABL_STAGE_EXPECTED[key], 0.051, f"ablation stage {key}, paired")
        stages.append({"key": key, "last": last, "rows": members, "from_s": start["run_s"], "to_s": end["run_s"],
                       "d": {**_mlh(d), "mean": end["run_s"] - start["run_s"]}, "commit": end["commit"], "main": end["main"], "tag": end["tag"]})
        start = end
    tip, base = by["fix"], by["base2"]
    assert hm["tip"]["stack"] == tip["commit"] and [tip["md5"][f"s{k}"] for k in (1, 2, 3)] == hm["tip_md5"], "the rebuilt tip on main has the clouds of the stack tip"
    assert [by[last]["tag"] for _, last, _ in ABL_STAGES] == ["s43-input", "s43-anchor", None, "s43-propagation", "s43-classification"] and base["tag"] == "s43-base2"
    close(tip["vs_base"]["mean"], -576.3, 0.051, "ablation total"), close(base["run_s"], 1106.8, 0.051, "ablation base2"), close(tip["run_s"], 530.6, 0.051, "ablation tip")
    close(sum(x["d"]["mean"] for x in stages), tip["run_s"] - base["run_s"], 1e-6, "the stages add up")
    share = -tip["vs_base"]["mean"] / base["run_s"]
    close(share, 0.521, 0.0005, "ablation total share")
    ranked = sorted(commits, key=lambda r: r["vs_prev"]["mean"])
    assert [r["key"] for r in ranked[:4]] == ["k1c", "h1", "u8", "k10"], [r["key"] for r in ranked[:4]]   # src: thesis-4.3/stack/ablation.md section 2
    top_share = sum(r["vs_prev"]["mean"] for r in ranked[:4]) / tip["vs_base"]["mean"]
    close(top_share, 0.57, 0.006, "share of the four largest steps")
    count = lambda c: sum(r["class"] == c for r in commits)
    assert len(commits) == 23 and count("E0") + count("E1") + count("E2") == 23
    return {"n": 3, "seeds": [1, 3], "f1_n": 5, "f1_seeds": [1, 5], "ci_level_pct": 95, "margin": MARGIN_TIER1, "decides_cm": 2,
            "rows": rows, "by": by, "stages": stages, "commits": len(commits),
            "classes": {c: count(c) for c in ("E0", "E1", "E2")},
            "total": {"base_run_s": base["run_s"], "run_s": tip["run_s"], "vs_base": tip["vs_base"], "share": share, "commit": tip["commit"],
                      "main": tip["main"], "tag": tip["tag"], "base_main": base["main"], "base_tag": base["tag"], "base_commit": base["commit"]},
            "main_verified_seeds": hm["verified_seeds"], "tags": hm["tags"],
            "top": {"keys": [r["key"] for r in ranked[:4]], "share": top_share},
            "resolved": [r["key"] for r in commits if r["vs_prev"]["hi"] < 0],
            "unresolved": [r["key"] for r in commits if r["vs_prev"]["lo"] <= 0 <= r["vs_prev"]["hi"]],
            "image_run_s": by["stack"]["run_s"], "image_vs_tip": by["stack"]["vs_prev"]}


def put_abl(n, abl, keys, stage=None):
    """The ablation rows of one stage, for the text of its subsection."""
    for k in keys:
        r = abl["by"][k]
        src = f"{ABL} (row {r['row']}: stack commit {r['commit']}, original {r['original']}; runs {' '.join(r['runs'][:3])})"
        n.put(f"abl.{k}.commit", r["commit"], f"{ABL} (row {r['row']}, stack_commit)")
        n.put(f"abl.{k}.main", r["main"], f"{HASH_MAP} (stack SHA {r['commit']}: main SHA)")
        if r["tag"]:
            n.put(f"abl.{k}.tag", r["tag"], f"{HASH_MAP} (tag on {r['main']})")
        n.put(f"abl.{k}.run_s", r["run_s"], f"{src}: span_mean_s, seeds 1-3")
        if r["vs_prev"]:
            n.put_stat(f"abl.{k}.run", r["vs_prev"], f"{src}: d_prev_s, d_prev_lo, d_prev_hi (paired by seed with the row before, n = 3, t 2 dof)")
            n.put_stat(f"abl.{k}.vs_base", r["vs_base"], f"{src}: d_base2_s, d_base2_lo, d_base2_hi (paired by seed with base2, n = 3)")
            n.put(f"abl.{k}.resolved", r["vs_prev"]["hi"] < 0, f"{ABL} (row {r['row']}): d_prev_hi < 0")
            n.put(f"abl.{k}.md5_seeds", r["md5_seeds"], f"{ABL} (row {r['row']}): seeds whose md5 is compared with the row before (md5, md5_eq_prev)")
        if r["f1"]:
            t = r["f1"]["at2cm"]
            n.put_stat(f"abl.{k}.f1_2cm", t, f"{ABL_F1} (row {r['row']} against {t['vs']}, 2cm: dF1, lo, hi; n = 5, paired by seed)")
            n.put(f"abl.{k}.tier1", t["tier1"], f"{ABL_F1} (row {r['row']}, 2cm): the interval lies inside +-{MARGIN_TIER1}")
    n.put("abl.n", abl["n"], f"{ABL} (n_time: seeds 1-3 for every row)")
    n.put("abl.f1_n", abl["f1_n"], f"{ABL_F1} (n: seeds 1-5)")
    n.put("abl.tip_commit", abl["total"]["commit"], f"{ABL} (row fix-d2w, stack_commit): the tip of exp/s43-stack")
    if stage:
        s = next(x for x in abl["stages"] if x["key"] == stage)
        n.put_stat("abl.stage.run", s["d"], f"{ABL} (span_per_seed of row {s['last']} minus that of the last row of the stage before, paired by seed, n = 3, t 2 dof; mean = difference of span_mean_s); thesis-4.3/stack/ablation.md section 2 \"By stage\"")
        n.put("abl.stage.from_s", s["from_s"], f"{ABL} (span_mean_s of the last row of the stage before)")
        n.put("abl.stage.to_s", s["to_s"], f"{ABL} (span_mean_s of row {s['last']})")
        n.put("abl.stage.share", -s["d"]["mean"] / s["from_s"], f"{ABL}: -(change of the stage) / span_mean_s of the row before it")


# ---- the stack by stage: the rows of the ablation at which a stage ends, with their phase totals
FINAL_ARMS = [  # key, arm in phases-stack.csv, row of the ablation
    ("base2", "base2", "base2"), ("input", "input", "h3h6"), ("anchor", "comb", "irs"), ("prop", "prop-comb-cu2", "cu2"),
    ("u8", "prop-8bit", "u8"), ("tip", "fix", "fix"),
]


def _phase_table(data):
    per = defaultdict(lambda: defaultdict(dict))
    for r in read_csv(data / "phases-stack.csv"):
        per[r["arm"]][int(r["seed"])][r["phase"]] = float(r["seconds"])
    return per


def stack_final(data, abl):
    per, seeds, arms = _phase_table(data), [1, 2, 3], []
    stage = {s["last"]: s for s in abl["stages"]}
    for key, arm_key, row_key in FINAL_ARMS:
        row = abl["by"][row_key]
        assert sorted(per[arm_key]) == seeds, arm_key
        mean = lambda ph: st.mean(per[arm_key][k][ph] for k in seeds)
        parts = [{"key": pk, "phases": ph, "s": sum(mean(x) for x in ph)} for pk, ph in STACK_PARTS]
        parts.append({"key": "rest", "phases": [], "s": mean("run") - sum(x["s"] for x in parts)})
        for k, exp in zip(seeds, row["run_by_seed"]):
            close(per[arm_key][k]["run"], exp, 0.051, f"{arm_key} seed {k}: phases-stack.csv against ablation.csv")
        arm = {"key": key, "commit": row["commit"], "main": row["main"], "tag": row["tag"], "run_s": mean("run"), "parts": parts, "vs_parent": None, "vs_base": None, "row": row["row"]}
        if arms:
            arm["vs_parent"], arm["vs_base"] = stage[row_key]["d"], row["vs_base"]
        arms.append(arm)
    return {"n": 3, "seeds": [1, 3], "ci_level_pct": 95, "t975": T975[2], "arms": arms, "parts": [k for k, _ in STACK_PARTS] + ["rest"],
            "commits": abl["commits"], "share": abl["total"]["share"], "main_verified_seeds": abl["main_verified_seeds"],
            "changes": {s["key"]: len([k for k in s["rows"] if k != "timers"]) for s in abl["stages"]}}


# ---- the final test: the stack against the fixed base on pipes (5 seeds) and office (3 seeds)
FT_METRICS = ["f1", "acc", "comp"]


def final_test(data):
    runs = read_csv(data / "final-test-runs.csv")
    summ = {(r["scene"], r["metric"]): r for r in read_csv(data / "final-test.csv")}
    out = {"scenes": [], "ci_level_pct": 95, "margin": MARGIN_TIER1, "margin_tier2": MARGIN_TIER2, "scene_floor": -0.01}   # src: thesis-4.3/acceptance.md "Final test, M6" (no scene mean below -0.01)
    for scene, n in (("pipes", 5), ("office", 3)):
        arm = lambda a: sorted((r for r in runs if r["scene"] == scene and r["arm"] == a), key=lambda r: int(r["seed"]))
        b, s = arm("base2"), arm("stack")
        assert [int(r["seed"]) for r in b] == [int(r["seed"]) for r in s] == list(range(1, n + 1)), scene
        assert all(x["md5"] != y["md5"] for x, y in zip(b, s)) and {r["image"] for r in s} == {"s43-stack-c20e935"} and {r["image"] for r in b} == {"s43-base2-6c1f7b1"}

        def stat(col, tol, name):
            x, y = [float(r[col]) for r in b], [float(r[col]) for r in s]
            d = paired([q - p for p, q in zip(x, y)])
            ref = summ[(scene, name)]
            assert int(ref["n"]) == n
            close(st.mean(x), float(ref["base2"]), tol, f"final test {scene} {name} base"), close(st.mean(y), float(ref["stack"]), tol, f"final test {scene} {name} stack")
            for k, c in (("mean", "delta"), ("lo", "lo"), ("hi", "hi")):
                close(d[k], float(ref[c]), tol, f"final test {scene} {name} {k}")
            return {"base": st.mean(x), "stack": st.mean(y), "mean": d["mean"], "lo": d["lo"], "hi": d["hi"], "sd": d["sd"], "per_seed": d and [q - p for p, q in zip(x, y)]}
        sc = {"key": scene, "n": n, "seeds": [1, n], "span": stat("span_s", 0.051, "span_s")}
        sc["span"]["share"] = -sc["span"]["mean"] / sc["span"]["base"]
        sc["span"]["stack_range_s"] = [min(float(r["span_s"]) for r in s), max(float(r["span_s"]) for r in s)]
        for m in FT_METRICS:
            sc[m] = {f"at{t}": stat(f"{m}_{t}", 5.1e-5, f"{m}_{t}") for t in TOLS}
        peak = lambda rows: max(int(r["gpu_peak_mib"]) for r in rows)
        ref = summ[(scene, "gpu_peak_mib(max over seeds)")]
        assert (peak(b), peak(s)) == (int(ref["base2"]), int(ref["stack"]))
        sc["gpu_peak_mib"] = [peak(b), peak(s)]
        two = sc["f1"]["at2cm"]
        sc["tier1_inside"] = -MARGIN_TIER1 < two["lo"] and two["hi"] < MARGIN_TIER1
        sc["tier2"] = two["lo"] >= -MARGIN_TIER2
        sc["excludes_zero"] = two["lo"] > 0 or two["hi"] < 0
        sc["above_band"] = two["hi"] > MARGIN_TIER1
        assert sc["tier2"] == (summ[(scene, "f1_2cm")]["tier2_lo_ge_-0.002"] == "pass")
        out["scenes"].append(sc)
    pipes, office = out["scenes"]
    # what the text says in words
    assert pipes["tier1_inside"] and not pipes["excludes_zero"] and not office["tier1_inside"] and office["excludes_zero"] and office["above_band"] and office["f1"]["at2cm"]["lo"] > -MARGIN_TIER1
    close(pipes["span"]["share"], 0.521, 0.0005, "pipes share"), close(office["span"]["share"], 0.510, 0.0005, "office share")
    # ---- the final rule of decision D2: equal-weight mean over the scenes, Welch-Satterthwaite
    v = [sc["f1"]["at2cm"]["sd"] ** 2 / sc["n"] for sc in out["scenes"]]
    j = len(v)
    d = sum(sc["f1"]["at2cm"]["mean"] for sc in out["scenes"]) / j
    se = math.sqrt(sum(v)) / j
    nu = sum(v) ** 2 / sum(x * x / (sc["n"] - 1) for x, sc in zip(v, out["scenes"]))
    t = t_quantile(0.975, nu)
    ref = summ[("equal-weight mean (D2 final)", "f1_2cm")]
    note = dict(zip(*[iter(ref["per_seed"].split(";")[0].split())] * 2))   # "SE 0.00035 nu 5.36 t 2.527": cross-check only
    close(se, float(note["SE"]), 6e-6, "D2 SE"), close(nu, float(note["nu"]), 0.006, "D2 nu")
    # The file's t (2.527) is the linear interpolation between 5 and 6 degrees of freedom; the quantile itself is 2.520.
    # The lower bound rounds to the same +0.0004 with either.
    close(t, float(note["t"]), 0.008, "D2 t"), close(T975_5 + (nu - 5) * (T975_6 - T975_5), float(note["t"]), 0.0015, "D2 t, interpolated as in the file")
    close(d, float(ref["delta"]), 5.1e-5, "D2 D"), close(d - t * se, float(ref["lo"]), 5.1e-5, "D2 lower bound")
    out["d2"] = {"scenes": j, "mean": d, "se": se, "nu": nu, "t": t, "lower": d - t * se,
                 "pass": d - t * se >= -MARGIN_TIER2 and all(sc["f1"]["at2cm"]["mean"] >= out["scene_floor"] for sc in out["scenes"])}
    assert out["d2"]["pass"]
    # ---- the null on pipes: the seed-noise arm of the fixed base (seeds 6-10 against seeds 1-5)
    base = {r["tag"]: float(r["f1_2"]) for r in read_csv(data / "runs.csv")}
    a, bb = [base[f"s43-base2-native-s{k}"] for k in range(1, 6)], [base[f"s43-base2-native-s{k}"] for k in range(6, 11)]
    for k, r in enumerate(x for x in runs if x["scene"] == "pipes" and x["arm"] == "base2"):
        close(a[k], float(r["f1_2cm"]), 1e-9, "base2 F1: runs.csv against final-test-runs.csv")
    idx = paired([y - x for x, y in zip(a, bb)])
    cross = [y - x for x in a for y in bb]
    perms = [paired([bb[p[i]] - a[i] for i in range(5)]) for p in itertools.permutations(range(5))]
    null_rows = read_csv(data / "final-null.csv")
    assert len(null_rows) == len(perms) == 120
    close(min(float(r["lo"]) for r in null_rows), min(x["lo"] for x in perms), 6e-6, "null: smallest lower bound")
    close(max(float(r["lo"]) for r in null_rows), max(x["lo"] for x in perms), 6e-6, "null: largest lower bound")
    pooled = math.sqrt((st.stdev(a) ** 2 + st.stdev(bb) ** 2) / 2)
    stack_d = pipes["f1"]["at2cm"]["per_seed"]
    out["null"] = {"n": 5, "seeds_a": [1, 5], "seeds_b": [6, 10], "pairings": len(perms),
                   "index": {**_mlh(idx), "sd": idx["sd"], "per_seed": [y - x for x, y in zip(a, bb)]},
                   "lo_range": [min(x["lo"] for x in perms), max(x["lo"] for x in perms)],
                   "cross": {"n": len(cross), "min": min(cross), "max": max(cross), "sd": st.stdev(cross)},
                   "sd_no_benefit": math.sqrt(2) * pooled,
                   "stack_sd": pipes["f1"]["at2cm"]["sd"], "stack_range": [min(stack_d), max(stack_d)],
                   "stack_inside_cross": all(min(cross) <= x <= max(cross) for x in stack_d),
                   "all_pass_tier1": all(-MARGIN_TIER1 < x["lo"] and x["hi"] < MARGIN_TIER1 for x in perms)}
    nl = out["null"]
    # thesis-4.3/stack/final-test.md section 2
    for got, exp in ((nl["index"]["mean"], 0.0004), (nl["index"]["sd"], 0.0016), (nl["cross"]["min"], -0.0018), (nl["cross"]["max"], 0.0026), (nl["cross"]["sd"], 0.0012),
                     (nl["lo_range"][0], -0.0018), (nl["lo_range"][1], 0.0001), (nl["sd_no_benefit"], 0.0013), (nl["stack_sd"], 0.0011)):
        close(round(got, 4), exp, 1e-9, "null arm against final-test.md")
    assert nl["stack_inside_cross"] and abs(pipes["f1"]["at2cm"]["mean"]) < abs(nl["index"]["mean"])
    # ---- drift of the base between sessions (pipes, seed 1)
    dr, vs = summ[("pipes", "drift check base2 s1 (fresh vs stored)")], summ[("pipes", "span_s stack s1 vs fresh base2 s1")]
    md5 = dr["per_seed"].split(";")[0].split()   # "md5 fresh <x> stored <y>"
    assert md5[0] == "md5" and md5[2] == md5[4] == next(r["md5"] for r in runs if r["tag"] == "s43-base2-native-s1")
    out["drift"] = {"stored_s": float(dr["base2"]), "fresh_s": float(dr["stack"]), "d_s": float(dr["delta"]), "same_cloud": md5[2] == md5[4],
                    "stack_s1_s": float(vs["stack"]), "stack_vs_fresh_s": float(vs["delta"])}
    close(out["drift"]["fresh_s"] - out["drift"]["stored_s"], out["drift"]["d_s"], 0.051, "drift")
    return out


# ---- the run breakdown: fixed base against the stack image, by stage (seeds 1-3) and by kernel (nsys, seed 1)
KERNEL_ROWS = [  # key, kernels of breakdown-kernels.csv
    ("weak", ["BlackPixelUpdateWeak", "RedPixelUpdateWeak"]),
    ("strong", ["BlackPixelUpdateStrong", "RedPixelUpdateStrong"]),
    ("depth_to_weak", ["DepthToWeak"]),
    ("gen_neighbours", ["GenNeighbours"]),
    ("nearest", ["FindNearestStrongPoint", "FindNearestStrongPointColumn"]),
    ("init_states", ["InitRandomStates", "BuildSkipaheadTables"]),
    ("fit", ["RANSACToGetFitPlane"]),
    ("local_refine", ["LocalRefine"]),
    ("random_init", ["RandomInitialization"]),
    ("other", ["BlackPixelFilterStrong", "RedPixelFilterStrong", "GetDepthandNormal", "NeigbourUpdate"]),
]


def final_breakdown(data):
    per, seeds = _phase_table(data), [1, 2, 3]
    ref = {r["phase"]: r for r in read_csv(data / "breakdown-phases.csv") if not r["phase"].startswith("#")}
    runs = next(r for r in read_csv(data / "breakdown-phases.csv") if r["phase"].startswith("#"))
    assert runs["base2_s"].split() == [f"s43-base2-native-s{k}" for k in seeds] and runs["stack_s"].split() == [f"s43-m6-stack-native-s{k}" for k in seeds]
    val = lambda arm, k, phases: sum(per[arm][k][p] for p in phases)
    for ph in ("run", "input_load", "device_upload", "patchmatch.init", "patchmatch.propagate", "patchmatch.finalize", "patchmatch.readback", "result_readback", "fusion", "prior_build"):
        # breakdown-phases.csv averages phase totals rounded to 0.1 s per run, so it can differ from the mean of phases.txt by 0.1 s in the last digit
        close(st.mean(per["base2"][k][ph] for k in seeds), float(ref[ph]["base2_s"]), 0.1, f"breakdown {ph} base2")
        close(st.mean(per["stack"][k][ph] for k in seeds), float(ref[ph]["stack_s"]), 0.1, f"breakdown {ph} stack")
    drawn = [p for _, ph, _ in BREAKDOWN_STAGES for p in ph]
    defs = [(k, ph, c) for k, ph, c in BREAKDOWN_STAGES] + [("other", None, "other"), ("kernel", KERNEL_PHASES, "group"), ("host", None, "group"), ("run", ["run"], "total")]

    def series(arm, key, phases):
        if key == "other":
            return [per[arm][k]["run"] - val(arm, k, drawn) for k in seeds]
        if key == "host":
            return [per[arm][k]["run"] - val(arm, k, KERNEL_PHASES) for k in seeds]
        return [val(arm, k, phases) for k in seeds]
    rows = []
    run_b, run_s = st.mean(series("base2", "run", ["run"])), st.mean(series("stack", "run", ["run"]))
    for key, phases, cls in defs:
        b, s = series("base2", key, phases), series("stack", key, phases)
        rows.append({"key": key, "class": cls, "phases": phases or [], "base_s": st.mean(b), "stack_s": st.mean(s),
                     "d": _mlh(paired([y - x for x, y in zip(b, s)])), "base_share": st.mean(b) / run_b, "stack_share": st.mean(s) / run_s})
    by = {r["key"]: r for r in rows}
    close(sum(r["stack_s"] for r in rows if r["class"] not in ("group", "total")), run_s, 1e-6, "the stages add up")
    close(by["fusion"]["stack_share"], 0.160, 0.0005, "fusion share"), close(by["run"]["d"]["mean"], -577.2, 0.051, "run change")
    # ---- kernels
    kr = {r["kernel"]: r for r in read_csv(data / "breakdown-kernels.csv")}
    kruns = kr.pop("# runs")
    allk = kr.pop("all kernels")
    assert sorted(kr) == sorted(k for _, ks in KERNEL_ROWS for k in ks), sorted(kr)
    tb, ts = float(allk["base2_s"]), float(allk["stack_s"])
    kernels = []
    for key, ks in KERNEL_ROWS:
        b, s = sum(float(kr[k]["base2_s"]) for k in ks), sum(float(kr[k]["stack_s"]) for k in ks)
        kernels.append({"key": key, "kernels": ks, "base_s": b, "stack_s": s, "d_s": s - b, "base_share": b / tb, "stack_share": s / ts,
                        "launches": [sum(int(kr[k]["base2_launches"]) for k in ks), sum(int(kr[k]["stack_launches"]) for k in ks)]})
    close(sum(k["base_s"] for k in kernels), tb, 0.08, "kernels add up, base"), close(sum(k["stack_s"] for k in kernels), ts, 0.08, "kernels add up, stack")
    kb = {k["key"]: k for k in kernels}
    close(kb["weak"]["stack_share"], 0.807, 0.0005, "weak share, stack"), close(kb["weak"]["base_share"], 0.603, 0.0005, "weak share, base")   # src: thesis-4.3/stack/final-test.md section 4
    close(1 - ts / tb, 0.484, 0.0005, "all kernels")
    return {"n": 3, "seeds": [1, 3], "ci_level_pct": 95, "rows": rows, "base_runs": runs["base2_s"].split(), "stack_runs": runs["stack_s"].split(),
            "kernels": kernels, "all_kernels": {"base_s": tb, "stack_s": ts, "d_s": ts - tb, "share": 1 - ts / tb,
                                                "launches": [int(allk["base2_launches"]), int(allk["stack_launches"])]},
            "kernel_runs": [kruns["base2_s"], kruns["stack_s"]], "kernel_seed": 1}


def numbers_results(abl, ft, fb):
    n = Numbers()
    put = n.put
    put("ci_level_pct", 95, "thesis-4.3/stack/ablation.md section 2; thesis-4.3/stack/final-test.md section 1 (95 % intervals)")
    put("margin", MARGIN_TIER1, "thesis-4.3/gate-m2-decisions.md item 1 (Tier 1: +-0.003)")
    put("margin_tier2", MARGIN_TIER2, "thesis-4.3/acceptance.md, decision D2 (lower bound at least -0.002)")
    put("scene_floor", ft["scene_floor"], "thesis-4.3/acceptance.md \"Final test, M6\" (no scene mean below -0.01)")
    put("decides_cm", 2, "thesis-4.3/acceptance.md, decision D2 (F1 at 2 cm decides)")
    put("other_cm", [1, 5], "thesis-4.3/acceptance.md, decision D2 (F1 at 1 and 5 cm are reported); data/final-test.csv (f1_1cm, f1_5cm)")
    put("bench_gpu_memory_gb", 12, ".dev/perf/PLAN-4.3.md decision D1 (the benchmark card has 12 GB); numbers-method.json machine.bench_gpu_memory_gb")
    put("drift.seed", 1, "data/final-test.csv (pipes: drift check base2 s1)")
    # what the text says in words
    e1r = [r for r in abl["rows"] if r["f1"]]
    assert all(r["f1"]["at2cm"]["tier1"] for r in e1r) and len(e1r) == 6
    assert abl["unresolved"] == ["c1", "k13", "c9", "c3", "fix"], abl["unresolved"]   # the last five commits; of the classification changes only the first is resolved
    assert all(x > 0 for x in ft["scenes"][1]["f1"]["at2cm"]["per_seed"])            # office: positive for every seed
    assert all(peak < 12 * 1024 for sc in ft["scenes"] for peak in sc["gpu_peak_mib"])
    for sc in ft["scenes"]:   # pipes: every interval of the table contains zero; office: accuracy and completeness at 2 cm do
        for m, t in ([(m, t) for m in ("f1",) for t in TOLS] + [("acc", "2cm"), ("comp", "2cm")] if sc["key"] == "pipes" else [("acc", "2cm"), ("comp", "2cm")]):
            assert sc[m][f"at{t}"]["lo"] < 0 < sc[m][f"at{t}"]["hi"], (sc["key"], m, t)
    # ---- the stack and the ablation
    put("stack.commit", abl["total"]["commit"], f"{ABL} (row fix-d2w, stack_commit); thesis-4.3/stack/ablation.md section 1")
    put("stack.base_commit", abl["by"]["base2"]["commit"], f"{ABL} (row base2)")
    put("stack.main", abl["total"]["main"], f"{HASH_MAP} (row 27: main SHA of the tip; main after the rebase)")
    put("stack.tag", abl["total"]["tag"], f"{HASH_MAP} (tag on the tip)")
    put("stack.base_main", abl["total"]["base_main"], f"{HASH_MAP} (row 4: main SHA of the fixed base)")
    put("stack.base_tag", abl["total"]["base_tag"], f"{HASH_MAP} (tag on the fixed base)")
    put("stack.main_verified_seeds", abl["main_verified_seeds"], f"{HASH_MAP} \"Verification scope\" (the tip on main rebuilt and run at native, seeds 1-3: md5 = those of the stack tip in {ABL}, row fix-d2w)")
    put("stack.tags", len(abl["tags"]), f"{HASH_MAP} (Tags)")
    put("stack.commits", abl["commits"], f"{ABL} (rows between base2 and the stack image: one per commit)")
    put("stack.classes", abl["classes"], f"{ABL} (class_vs_prev of these rows)")
    put("stack.changes", abl["commits"] - 2, f"{ABL}: the commits without the timer commit (row timers) and without the bug fix (row fix-d2w)")
    put("stack.native_seeds", abl["by"]["stack"]["md5_seeds"], f"{ABL} (row stack: md5 of the stack image = md5 of the row before, seeds 1-3)")
    put("abl.n", abl["n"], f"{ABL} (n_time)")
    put("abl.seeds", abl["seeds"], f"{ABL} (runs: seeds 1-3)")
    put("abl.f1_n", abl["f1_n"], f"{ABL_F1} (n)")
    put("abl.base_run_s", abl["total"]["base_run_s"], f"{ABL} (row base2, span_mean_s)")
    put("abl.run_s", abl["total"]["run_s"], f"{ABL} (row fix-d2w, span_mean_s)")
    n.put_stat("abl.vs_base", abl["total"]["vs_base"], f"{ABL} (row fix-d2w: d_base2_s, d_base2_lo, d_base2_hi)")
    put("abl.share", abl["total"]["share"], f"{ABL}: -d_base2_s of row fix-d2w / span_mean_s of base2")
    put("abl.image_run_s", abl["image_run_s"], f"{ABL} (row stack, span_mean_s: fresh runs of the stack image, the tree of the last commit)")
    n.put_stat("abl.image_vs_tip", abl["image_vs_tip"], f"{ABL} (row stack: d_prev_s, d_prev_lo, d_prev_hi)")
    put("abl.top.share", abl["top"]["share"], f"{ABL}: sum of the four most negative d_prev_s / d_base2_s of row fix-d2w")
    put("abl.top.n", len(abl["top"]["keys"]), f"{ABL}: the four most negative d_prev_s (K1c, H1, 8-bit, K10)")
    for k in abl["top"]["keys"]:
        put(f"abl.top.{k}_s", abl["by"][k]["vs_prev"]["mean"], f"{ABL} (row {abl['by'][k]['row']}, d_prev_s)")
    put("abl.unresolved", len(abl["unresolved"]), f"{ABL}: commits whose interval [d_prev_lo, d_prev_hi] contains zero ({', '.join(abl['by'][k]['row'] for k in abl['unresolved'])})")
    n.put_stat("abl.timers", abl["by"]["timers"]["vs_prev"], f"{ABL} (row timers: d_prev_s, d_prev_lo, d_prev_hi)")
    for s in abl["stages"]:
        n.put_stat(f"abl.stage.{s['key']}.run", s["d"], f"{ABL} (span of row {s['last']} minus that of the last row of the stage before; interval paired by seed from span_per_seed, n = 3); thesis-4.3/stack/ablation.md section 2 \"By stage\"")
        put(f"abl.stage.{s['key']}.to_s", s["to_s"], f"{ABL} (row {s['last']}, span_mean_s)")
        put(f"abl.stage.{s['key']}.commits", len(s["rows"]), f"{ABL} (rows of the stage: {', '.join(abl['by'][k]['row'] for k in s['rows'])})")
    e1 = [r for r in abl["rows"] if r["f1"]]
    put("abl.f1_rows", len(e1), f"{ABL_F1} (rows at 2cm: {', '.join(r['row'] for r in e1)})")
    put("abl.f1_all_pass", all(r["f1"]["at2cm"]["tier1"] for r in e1), f"{ABL_F1} (2cm: every interval inside +-{MARGIN_TIER1})")
    put("abl.f1_range", [min(r["f1"]["at2cm"]["lo"] for r in e1), max(r["f1"]["at2cm"]["hi"] for r in e1)], f"{ABL_F1} (2cm: smallest lo, largest hi)")
    put("abl.f1_mean_range", [min(r["f1_2cm_mean"] for r in abl["rows"]), max(r["f1_2cm_mean"] for r in abl["rows"])], f"{ABL} (f1_2cm_mean_s1_3: smallest and largest over the rows)")
    put("abl.bridged_rows", len([r for r in e1 if r["f1"]["at2cm"]["bridged"]["row"] or r["f1"]["at2cm"]["bridged"]["prev"]]), f"{ABL_F1} (sources: rows with a bridged seed)")
    # ---- the final test
    ftr, fts = "data/final-test-runs.csv", "data/final-test.csv"
    for sc in ft["scenes"]:
        k = sc["key"]
        put(f"{k}.n", sc["n"], f"{ftr} ({k}: seeds)")
        put(f"{k}.span.base_s", sc["span"]["base"], f"{ftr} ({k}, base2: mean span_s); {fts} ({k}, span_s)")
        put(f"{k}.span.stack_s", sc["span"]["stack"], f"{ftr} ({k}, stack: mean span_s); {fts} ({k}, span_s)")
        n.put_stat(f"{k}.span.d", sc["span"], f"{ftr} ({k}: span_s of stack - base2, paired by seed, t {sc['n'] - 1} dof); {fts} ({k}, span_s: delta, lo, hi)")
        put(f"{k}.span.share", sc["span"]["share"], f"{ftr} ({k}): -(mean difference) / mean span_s of base2")
        put(f"{k}.span.stack_range_s", sc["span"]["stack_range_s"], f"{ftr} ({k}, stack: smallest and largest span_s)")
        for m in FT_METRICS:
            for t in TOLS:
                x = sc[m][f"at{t}"]
                n.put_stat(f"{k}.{m}.at{t}", x, f"{ftr} ({k}: {m}_{t} of stack - base2, paired by seed, t {sc['n'] - 1} dof); {fts} ({k}, {m}_{t})")
                if m == "f1":
                    put(f"{k}.f1.at{t}.base", x["base"], f"{ftr} ({k}, base2: mean f1_{t})")
                    put(f"{k}.f1.at{t}.stack", x["stack"], f"{ftr} ({k}, stack: mean f1_{t})")
        put(f"{k}.f1.at2cm.per_seed", sc["f1"]["at2cm"]["per_seed"], f"{ftr} ({k}: f1_2cm of stack - base2 per seed)")
        put(f"{k}.gpu_peak_mib", sc["gpu_peak_mib"], f"{ftr} ({k}: largest gpu_peak_mib over the seeds, base2 and stack); {fts} ({k}, gpu_peak_mib)")
        put(f"{k}.gpu_saved_mib", sc["gpu_peak_mib"][0] - sc["gpu_peak_mib"][1], f"{ftr} ({k}): difference of the two peaks")
    d2 = ft["d2"]
    for k in ("scenes", "mean", "se", "nu", "t", "lower"):
        put(f"d2.{k}", d2[k], f"{ftr}: equal-weight mean of the two scene means of the f1_2cm differences, SE = 1/J sqrt(sum s_j^2/n_j), Welch-Satterthwaite nu, t(0.975, nu); {fts} (equal-weight mean (D2 final))")
    nl = ft["null"]
    put("null.n", nl["n"], "data/runs.csv (s43-base2-native-s1..5 and s6..10)")
    put("null.seeds_a", nl["seeds_a"], "data/runs.csv (s43-base2-native-s1..5)")
    put("null.seeds_b", nl["seeds_b"], "data/runs.csv (s43-base2-native-s6..10)")
    n.put_stat("null.index", nl["index"], "data/runs.csv (f1_2 of s43-base2-native-s(k+5) minus s(k), k = 1..5, paired interval); thesis-4.3/stack/final-test.md section 2")
    put("null.index.sd", nl["index"]["sd"], "data/runs.csv: standard deviation of these five differences")
    put("null.pairings", nl["pairings"], "data/final-null.csv (rows: every way of pairing the two sets)")
    put("null.lo_range", nl["lo_range"], "data/final-null.csv (lo: smallest and largest), recomputed from data/runs.csv")
    put("null.cross.n", nl["cross"]["n"], "data/runs.csv: differences of single runs, every seed 6-10 against every seed 1-5")
    put("null.cross.range", [nl["cross"]["min"], nl["cross"]["max"]], "data/runs.csv: smallest and largest of these differences; data/final-test.csv (null: single-run diffs)")
    put("null.cross.sd", nl["cross"]["sd"], "data/runs.csv: their standard deviation")
    put("null.sd_no_benefit", nl["sd_no_benefit"], "data/runs.csv: sqrt(2) times the pooled standard deviation of f1_2 over seeds 1-5 and 6-10; data/final-test.csv (stack paired-diff sd vs null)")
    put("null.stack_sd", nl["stack_sd"], f"{ftr} (pipes: standard deviation of the five f1_2cm differences)")
    put("null.stack_range", nl["stack_range"], f"{ftr} (pipes: smallest and largest f1_2cm difference)")
    dr = ft["drift"]
    for k in ("stored_s", "fresh_s", "d_s", "stack_s1_s", "stack_vs_fresh_s"):
        put(f"drift.{k}", dr[k], f"{fts} (pipes: drift check base2 s1 (fresh vs stored); span_s stack s1 vs fresh base2 s1)")
    # ---- the breakdown
    ps = "data/phases-stack.csv"
    put("phases.n", fb["n"], f"{ps} (arms base2 and stack, seeds 1-3); data/breakdown-phases.csv (# runs)")
    for r in fb["rows"]:
        k = r["key"].replace("patchmatch.readback", "depth_readback")
        src = f"{ps} (arms base2, stack: {' + '.join(r['phases']) or 'run minus the phases named'}; mean of seeds 1-3), checked against data/breakdown-phases.csv"
        put(f"phases.{k}.base_s", r["base_s"], src)
        put(f"phases.{k}.stack_s", r["stack_s"], src)
        n.put_stat(f"phases.{k}.d", r["d"], src + "; paired by seed, t 2 dof")
        put(f"phases.{k}.base_share", r["base_share"], src + " / run")
        put(f"phases.{k}.stack_share", r["stack_share"], src + " / run")
    bk = "data/breakdown-kernels.csv"
    for k in fb["kernels"]:
        for f in ("base_s", "stack_s", "base_share", "stack_share"):
            put(f"kernels.{k['key']}.{f}", k[f], f"{bk} ({' + '.join(k['kernels'])}: base2_s, stack_s; shares of the row all kernels)")
    for f in ("base_s", "stack_s", "share"):
        put(f"kernels.all.{f}", fb["all_kernels"][f], f"{bk} (all kernels: base2_s, stack_s; share = 1 - stack_s / base2_s)")
    put("kernels.seed", fb["kernel_seed"], f"{bk} (# runs: {' and '.join(fb['kernel_runs'])}); thesis-4.3/stack/final-test.md section 4 (nsys, native, seed 1)")
    put("kernels.rest_share", 1 - sum(k["stack_share"] for k in fb["kernels"] if k["key"] in ("weak", "depth_to_weak")), f"{bk}: 1 - (weak + DepthToWeak) stack_s / all kernels")
    return n


# =================================================================================================
def write(out, name, meta, body):
    out.mkdir(parents=True, exist_ok=True)
    (out / name).write_text(json.dumps({"meta": meta, **body}, indent=1, sort_keys=True) + "\n")


def main():
    global DATA
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--data", type=Path, default=HERE.parent / "data")
    ap.add_argument("--baseline-run", type=Path, default=HERE.parent.parent / "baseline-run" / "data" / "perf-nsys-r1")
    ap.add_argument("--out", type=Path, default=HERE.parent / "derived")
    a = ap.parse_args()
    DATA = a.data

    def meta(*files, extra=()):
        paths = [a.data / f for f in files] + [a.baseline_run / f for f in extra]
        return {"generator": "generated/perf-4.3/scripts/perf43_json.py",
                "sources": {p.name: {"sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
                                     "origin": SOURCES.get(p.name, "generated/baseline-run/data/perf-nsys-r1/" + p.name)} for p in paths},
                "runs": "analysis runs: development machine, RTX 5070 Ti, unlocked clocks"}

    base = base_runs(a.data)
    prof = profiled_run(a.baseline_run)
    aa = aa_arm(a.data)
    sn = seednoise_arm(a.data)
    resc = rescale_split(a.data)
    inp = input_regions(a.data)
    stack = input_stack(a.data)
    anc = anchor_stack(a.data)
    sr = stack_run(a.data, stack, anc)
    prop = prop_stack(a.data)
    ncu = prop_ncu(a.data)
    anchor_files = ("anchor-run-spans.csv", *ANCHOR_PER_ROUND, *(x[4] for x in ANCHOR_ARMS[1:]), "kern-irs-vs-base2.csv", *ANCHOR_FIRST_ORDER.values())
    stack_files = ("phases-stack.csv", "comb-vs-base2.csv", *STACK_WALL.values(), "tier1-k2stack-vs-base2.csv")
    cl = class_stack(a.data)
    profiles = class_profiles(a.data)
    class_files = (*(x[4] for x in CLASS_ARMS[1:]), *(x[5] for x in CLASS_ARMS[1:]), "kern-c3chain-vs-5cf8608.csv", "wall-c3chain-vs-5cf8608.csv",
                   "kern-comb-vs-ee07854.csv", "wall-comb-vs-ee07854.csv", "rounds-5cf8608-c2.csv", "stall-5cf8608-DepthToWeak.csv",
                   "stall-5cf8608-LocalRefine.csv", "counters-5cf8608-native-s1.csv", "ncu-5cf8608.csv", "ncu-k13-vs-c1.csv")
    prop_files = (*(x[4] for x in PROP_ARMS[1:]), *(x[5] for x in PROP_ARMS[1:]), "tier1-k2stack-vs-base2.csv", "kern-8bit-vs-comb-cu2.csv", "tier1-8bit-vs-comb-cu2.csv")
    seed_files = ("runs.csv", "seednoise-base2.csv", "seednoise-base2-tier1.csv")
    card_files = (*CARD_FILES, "card-h1-2.csv")
    nsys = ("phases.txt", "kernel-totals-base.csv")

    write(a.out, "baseline-breakdown.json", meta("m0_phases.csv"), base)
    write(a.out, "aa-margin.json", meta("aa.csv", "rescale_split_runs.csv", *seed_files), {
        "arms": [{"key": "aa", **aa}, {"key": "seednoise", **sn}],
        "margin": MARGIN_TIER1, "former_margin": MARGIN_TIER1_FORMER, "decides": "2cm", "ci_level_pct": 95,
        "days_apart": [4, 5]})   # src: thesis-4.3/m0/baseline.md:12-14 (A 2026-11-10/11, B 2026-11-15)
    write(a.out, "rescale-split.json", meta("rescale_split.csv", "rescale_split_runs.csv"), resc)
    write(a.out, "input-regions.json", meta(*(x[1] for x in INPUT_ARMS)), inp)
    write(a.out, "input-stack.json", meta(*card_files), stack)
    write(a.out, "anchor-kernels.json", meta(*anchor_files), anc)
    write(a.out, "prop-kernels.json", meta(*prop_files), prop)
    write(a.out, "prop-ncu.json", meta(*NCU_FILES), ncu)
    # M6: the final stack. `sr` (the stacks as they were combined, before M6) still feeds numbers of the stage subsections;
    # stack-run.json now holds the final stack by stage.
    abl = ablation(a.data)
    sf = stack_final(a.data, abl)
    ft = final_test(a.data)
    fb = final_breakdown(a.data)
    m6_files = ("ablation.csv", "ablation-f1.csv", "main-hash-map.md")
    write(a.out, "stack-run.json", meta("phases-stack.csv", *m6_files), sf)
    write(a.out, "ablation.json", meta(*m6_files), {k: v for k, v in abl.items() if k != "by"})
    write(a.out, "final-test.json", meta("final-test.csv", "final-test-runs.csv", "final-null.csv", "runs.csv"), ft)
    write(a.out, "final-breakdown.json", meta("phases-stack.csv", "breakdown-phases.csv", "breakdown-kernels.csv"), fb)
    write(a.out, "class-kernels.json", meta(*class_files), cl)
    write(a.out, "class-profiles.json", meta("fig1-profiles.json"), profiles)
    n_input, n_anchor, n_prop, n_class = numbers_input(inp, stack, a.data), numbers_anchor(anc, sr), numbers_prop(prop, ncu, sr), numbers_class(cl, profiles, a.data, sr)
    put_abl(n_input, abl, ["base2", "timers", "h1", "h2h12", "h14", "h3h6"], "input")
    put_abl(n_anchor, abl, ["k3", "k12", "k1c", "gnl", "irs"], "anchor")
    put_abl(n_prop, abl, ["k10", "reftex", "k2", "k11", "k7lite", "cu2", "u8"], "prop")
    put_abl(n_class, abl, ["c2", "c1", "k13", "c9", "c3", "fix", "stack"], "class")
    n_input.put("abl.base_drift_s", ft["drift"]["d_s"], "data/final-test.csv (pipes: drift check base2 s1 (fresh vs stored), delta)")
    n_class.put("abl.total_share", abl["total"]["share"], f"{ABL}: -d_base2_s of row fix-d2w / span_mean_s of base2")
    n_class.put("abl.base_run_s", abl["total"]["base_run_s"], f"{ABL} (row base2, span_mean_s)")
    hm = main_hashes(a.data)
    n_base = numbers_baseline(base, prof, resc, a.data)
    for key, stack_sha in (("zero_init", "024808a"), ("scales", "6c1f7b1")):
        n_base.put(f"commit.{key}.measured", stack_sha, ".dev/deviations-from-apd.md D6; thesis-4.3/m0/determinism.md (the commit whose image was measured)")
        n_base.put(f"commit.{key}.main", hm["by_stack"][stack_sha]["main"], f"{HASH_MAP} (stack SHA {stack_sha}: main SHA)")
    n_base.put("commit.base_tag", hm["by_stack"]["6c1f7b1"]["tag"], f"{HASH_MAP} (tag on the rebased 6c1f7b1)")
    n_base.put("commit.tip_main", hm["tip"]["main"], f"{HASH_MAP} (row 27)")
    n_base.put("commit.verified_seeds", hm["verified_seeds"], f"{HASH_MAP} \"Verification scope\"")
    n_class.put("fix.small_px", 1024, "thesis-4.3/stack/ablation.md section 1 \"Step 0\"; .dev/production-improvements.md entry 5 (md5 identical to 1069a53 at 1024 px: runs s43-m6-fix-1024-s1..3, s43-m6-tip-1024-s1..3)")
    n_class.put("fix.small_seeds", 3, "the same (1024 px, seeds 1-3)")
    for name, n, files, extra in (
        ("numbers-method.json", numbers_method(base, prof, aa, sn, inp), ("m0_phases.csv", "aa.csv", "rescale_split_runs.csv", "base2.csv", INPUT_ARMS[0][1], *seed_files), nsys),
        ("numbers-baseline.json", n_base, ("m0_phases.csv", "aa.csv", "rescale_split.csv", "base2.csv", "main-hash-map.md"), nsys),
        ("numbers-input.json", n_input, ("base2.csv", *(x[1] for x in INPUT_ARMS), *card_files, *m6_files, "final-test.csv"), ()),
        ("numbers-anchor.json", n_anchor, (*anchor_files, *stack_files, "card-h3h6.csv", *m6_files), ()),
        ("numbers-prop.json", n_prop, (*prop_files, *NCU_FILES, *stack_files, *m6_files), ()),
        ("numbers-class.json", n_class, (*class_files, "c8-summary.json", "fig1-profiles.json", "phases-stack.csv", *m6_files), ()),
        ("numbers-results.json", numbers_results(abl, ft, fb), (*m6_files, "final-test.csv", "final-test-runs.csv", "final-null.csv", "runs.csv", "phases-stack.csv", "breakdown-phases.csv", "breakdown-kernels.csv"), ()),
    ):
        write(a.out, name, meta(*files, extra=extra), {"v": n.v, "src": n.src})
    print(f"wrote 21 files to {a.out}")


if __name__ == "__main__":
    main()
