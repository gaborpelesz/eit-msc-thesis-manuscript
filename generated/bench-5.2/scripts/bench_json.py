# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.*", "pandas==2.*", "scipy==1.*"]
# ///
"""CSV -> JSON for section 5.2 (benchmark results) and the conclusion.

Reads the CSV snapshot in ../data (the aggregation of the 650 runs of the final benchmark and the
130 runs of the M8 campaign, the two CUMVS(APD) arms; see ../README.md) and writes
../derived/numbers-bench.json. Every number that the Typst files or the figures print comes from
that JSON; nothing is typed by hand.

Everything is recomputed here from the per-run rows (runs.csv, phase-categories.csv,
phases-input-load.csv), and the results that aggregate.py also wrote (pareto.csv, cells.csv) are
asserted against, so a refresh that changes a premise stops here instead of in the text.

Statistics, as in section 4.3 and eq. <eq-ci>: a cell is (arm, scene) with n = 5 repeats. A
13-scene figure (mean F1, total time) is computed once per repeat index (the repeats r1..r5 of
the 13 scenes) and reported as the mean of the five values with the 95 % interval
t(0.975, 4) * s / sqrt(5).

CUMVS(APD) against APD-MVS (block `ours`): the two arms' runs are independent (no pairing), so a
difference of two means gets a Welch interval, and a ratio of two means (the speedup) the
delta-method interval on the log scale with Welch-Satterthwaite degrees of freedom. The headline
speedup is the ratio of the 13-scene totals (a decision of the author); as a check, the mean
of the five per-repeat-index ratios with eq. <eq-ci> is computed too and must agree.

Usage: uv run bench_json.py [--perf43 FILE]   (`make figures` from the thesis root runs it)
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

import arms as A

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = ROOT / "data"
OUT = ROOT / "derived" / "numbers-bench.json"
# numbers of section 4.3, written by generated/perf-4.3/scripts/perf43_json.py (`make figures`)
PERF43 = ROOT.parent / "perf-4.3" / "derived" / "numbers-results.json"

TOLS = ["1cm", "2cm", "5cm", "10cm", "20cm"]
N_REP = 5
T975 = float(stats.t.ppf(0.975, N_REP - 1))
CARD_MIB = 12227  # device_mem_total_mib of every run; asserted below

# phase categories of aggregate.py, merged into the classes that Figure C draws
CATS = ["setup", "input_load", "host_device_transfer", "patchmatch", "prior_aux",
        "depthmap_write", "fusion", "output_write", "loop_overhead", "untimed"]
CLASSES = {
    "input_load": ["input_load"],
    "transfer": ["host_device_transfer"],
    "patchmatch": ["patchmatch"],
    "prior_aux": ["prior_aux"],
    "fusion": ["fusion"],
    "write": ["depthmap_write", "output_write"],
    "other": ["setup", "loop_overhead", "untimed"],
}


def ci(vals):
    vals = np.asarray(vals, dtype=float)
    m, s = float(vals.mean()), float(vals.std(ddof=1))
    hw = T975 * s / math.sqrt(len(vals))
    return dict(mean=m, sd=s, lo=m - hw, hi=m + hw, hw=hw, n=len(vals))


def welch(a, b):
    """mean(a) - mean(b) with its 95 % Welch interval (independent samples)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    va, vb = a.var(ddof=1) / len(a), b.var(ddof=1) / len(b)
    se = math.sqrt(va + vb)
    df = (va + vb) ** 2 / (va ** 2 / (len(a) - 1) + vb ** 2 / (len(b) - 1)) if se > 0 else len(a) + len(b) - 2
    hw = float(stats.t.ppf(0.975, df)) * se
    d = float(a.mean() - b.mean())
    return dict(mean=d, lo=d - hw, hi=d + hw, hw=hw, df=float(df))


def ratio(a, b):
    """mean(a) / mean(b) with a 95 % interval: delta method on log(mean), Welch-Satterthwaite df."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    ra, rb = a.var(ddof=1) / len(a) / a.mean() ** 2, b.var(ddof=1) / len(b) / b.mean() ** 2
    se = math.sqrt(ra + rb)
    df = (ra + rb) ** 2 / (ra ** 2 / (len(a) - 1) + rb ** 2 / (len(b) - 1))
    q = float(a.mean() / b.mean())
    f = math.exp(float(stats.t.ppf(0.975, df)) * se)
    return dict(mean=q, lo=q / f, hi=q * f, df=float(df))


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--perf43", default=str(PERF43))
    ap.add_argument("--no-crosscheck", action="store_true",
                    help="skip the checks against aggregate.py's cells.csv/pareto.csv (dry runs only)")
    args = ap.parse_args()

    runs = pd.read_csv(DATA / "runs.csv")
    cells_csv = pd.read_csv(DATA / "cells.csv")
    pareto_csv = pd.read_csv(DATA / "pareto.csv")
    pcat = pd.read_csv(DATA / "phase-categories.csv")
    il = pd.read_csv(DATA / "phases-input-load.csv")

    # ---- validity premises --------------------------------------------------------------------
    # one run per arm x scene x repeat
    assert len(runs) == runs.arm.nunique() * runs.scene.nunique() * N_REP, len(runs)
    assert not runs.duplicated(["arm", "scene", "repeat"]).any()
    unknown = set(runs.arm) - set(A.ORDER)
    assert not unknown, f"arms missing from the registry: {unknown}"
    ok = runs[runs.ok].copy()
    failed = runs[~runs.ok]
    assert set(failed.arm) <= {"HPM-MVS_plusplus@3200-capped"}, set(failed.arm)
    assert (runs.device_mem_total_mib == CARD_MIB).all()
    scenes = sorted(runs.scene.unique())
    assert len(scenes) == 13
    present = [a for a in A.ORDER if a in set(runs.arm)]
    cnt = ok.groupby(["arm", "scene"]).size()
    full = [a for a in present if all(cnt.get((a, s), 0) == N_REP for s in scenes)]
    partial = [a for a in present if a not in full]
    assert partial == ["HPM-MVS_plusplus@3200-capped"], partial
    common = sorted(s for s in scenes if all(cnt.get((a, s), 0) == N_REP for a in present))
    for a in present:
        for s in scenes:
            assert cnt.get((a, s), 0) in (0, N_REP), (a, s)

    nimg = ok.groupby("scene").n_images.first()

    # ---- per arm ------------------------------------------------------------------------------
    def arm_block(a, sset):
        r = ok[(ok.arm == a) & ok.scene.isin(sset)]
        assert len(r) == N_REP * len(sset), (a, len(r))
        by_rep = r.groupby("repeat")
        out = dict(key=a, label=A.LABEL[a], group=A.GROUP[a], n_scenes=len(sset),
                   n_runs=len(r), reserved=False)
        for t in TOLS:
            out[f"f1_{t}"] = ci(by_rep[f"f1_{t}"].mean())
        out["acc_2cm"] = ci(by_rep["acc_2cm"].mean())
        out["comp_2cm"] = ci(by_rep["comp_2cm"].mean())
        out["wall_total_s"] = ci(by_rep["wall_time_s"].sum())
        out["convert_total_s"] = float(r.groupby("scene").preprocess_convert_s.mean().sum())
        out["energy_total_kj"] = float(r.groupby("scene").energy_kj.mean().sum())
        out["power_w"] = float(r.energy_kj.sum() * 1e3 / r.wall_time_s.sum())
        out["peak_dev_mib"] = float(r.peak_device_mem_mib.max())
        out["peak_dev_scene"] = r.loc[r.peak_device_mem_mib.idxmax(), "scene"]
        out["peak_dev_share_card"] = out["peak_dev_mib"] / CARD_MIB
        out["peak_host_gib"] = float(r.peak_host_rss_mib.max() / 1024)
        out["gpu_idle_share"] = float((r.gpu_idle_share * r.wall_time_s).sum() / r.wall_time_s.sum())
        cm = r.groupby("scene").agg(wall=("wall_time_s", "mean"), n=("n_images", "first"),
                                    mem=("peak_device_mem_mib", "mean"), f1=("f1_2cm", "mean"),
                                    acc=("acc_2cm", "mean"), comp=("comp_2cm", "mean"))
        out["scene_wall_s"] = {s: float(cm.wall[s]) for s in cm.index}
        out["scene_f1"] = {s: float(cm.f1[s]) for s in cm.index}
        out["scene_acc"] = {s: float(cm.acc[s]) for s in cm.index}
        out["scene_comp"] = {s: float(cm.comp[s]) for s in cm.index}
        out["scene_mem_mib"] = {s: float(cm.mem[s]) for s in cm.index}
        # F1, accuracy and completeness per scene at the thresholds of the appendix tables
        out["scene_quality"] = {
            t: {m: {s: float(x) for s, x in r.groupby("scene")[f"{m}_{t}"].mean().items()}
                for m in ("f1", "acc", "comp")}
            for t in ("1cm", "2cm", "5cm", "10cm")}
        out["slowest_scene"] = cm.wall.idxmax()
        if len(cm) >= 3:
            out["lin_r"] = float(np.corrcoef(cm.n, cm.wall)[0, 1])
            out["s_per_image"] = float(np.polyfit(cm.n, cm.wall, 1)[0])
        # phase classes: share of the summed wall time
        pc = pcat[(pcat.arm == a) & pcat.ok & pcat.scene.isin(sset) & ~pcat.category.str.startswith("harness")]
        assert set(pc.category) <= set(CATS), set(pc.category) - set(CATS)
        tot = pc.groupby("category").self_s.sum()
        wall = r.wall_time_s.sum()
        out["share"] = {c: float(sum(tot.get(x, 0.0) for x in xs) / wall) for c, xs in CLASSES.items()}
        out["share_sum"] = float(sum(out["share"].values()))
        # the same classes in seconds over the scenes (sum over the scenes, mean of the repeats)
        out["class_s"] = {c: float(sum(tot.get(x, 0.0) for x in xs) / N_REP) for c, xs in CLASSES.items()}
        # image passes per image: the same in every run of an arm
        ppi = (r.image_pass_count / r.n_images).round(9).unique()
        assert len(ppi) == 1 and float(ppi[0]).is_integer(), (a, ppi)
        out["passes_per_image"] = int(ppi[0])
        out["share_outside_patchmatch"] = 1.0 - out["share"]["patchmatch"]
        return out

    v = dict(card_mib=CARD_MIB, t975=T975, n_rep=N_REP, ci_level_pct=95,
             n_runs=len(runs), n_ok=int(runs.ok.sum()), n_failed=int((~runs.ok).sum()),
             n_methods=runs.method.nunique(), n_scenes=len(scenes), scenes=scenes,
             common_scenes=common, n_images={s: int(nimg[s]) for s in scenes})
    v["arms"] = {a: arm_block(a, scenes) for a in full}
    v["arms_common"] = {a: arm_block(a, common) for a in present}
    v["full"] = full
    # the two campaigns: the final session (10 methods) and CUMVS(APD)'s own (M8, both arms)
    is_ours = runs.method == "production-apd-mvs"
    v["campaigns"] = dict(final=dict(n_runs=int((~is_ours).sum()), n_ok=int(runs[~is_ours].ok.sum()),
                                     n_methods=int(runs[~is_ours].method.nunique())),
                          ours=dict(n_runs=int(is_ours.sum()), n_ok=int(runs[is_ours].ok.sum()),
                                    n_arms=int(runs[is_ours].arm.nunique())))
    assert v["campaigns"]["ours"]["n_ok"] == v["campaigns"]["ours"]["n_runs"]
    v["partial"] = partial
    for a in A.RESERVED:
        if a not in v["arms"]:
            v["arms"][a] = dict(key=a, label=A.LABEL[a], group=A.GROUP[a], reserved=True)
    v["registry"] = dict(order=A.ORDER, labels=A.LABEL, groups={k: list(g) for k, g in A.GROUPS.items()},
                         arm_group=A.GROUP, reserved=sorted(A.RESERVED))
    F = {a: v["arms"][a] for a in full}

    # cross-check against aggregate.py (cells.csv: 13-scene sums of cell means)
    cw = cells_csv[cells_csv.metric == "wall_time_s"].groupby("arm")["mean"].sum()
    for a in ([] if args.no_crosscheck else full):
        assert a in cw.index, f"{a} missing from cells.csv: rerun aggregate.py"
        assert abs(cw[a] - F[a]["wall_total_s"]["mean"]) < 1e-6 * cw[a], a

    # ---- quality ------------------------------------------------------------------------------
    by_f1 = sorted(full, key=lambda a: -F[a]["f1_2cm"]["mean"])
    v["rank_2cm"] = by_f1
    v["ranking_same_all_tols"] = all(sorted(full, key=lambda a: -F[a][f"f1_{t}"]["mean"]) == by_f1 for t in TOLS)
    others = [a for a in full if a not in A.RESERVED]
    v["ranking_same_all_tols_excl_ours"] = all(
        sorted(others, key=lambda a: -F[a][f"f1_{t}"]["mean"]) == [a for a in by_f1 if a in others] for t in TOLS)
    v["spread_pp"] = {t: 100 * (F[by_f1[0]][f"f1_{t}"]["mean"] - min(F[a][f"f1_{t}"]["mean"] for a in full)) for t in TOLS}
    gaps = [F[by_f1[i]]["f1_2cm"]["mean"] - F[by_f1[i + 1]]["f1_2cm"]["mean"] for i in range(len(by_f1) - 1)]
    v["min_neighbour_gap_pp"] = 100 * min(gaps)
    v["max_f1_hw_pp"] = 100 * max(F[a]["f1_2cm"]["hw"] for a in full)
    lin = [a for a in full if A.GROUP[a] == "lineage"]
    v["lineage_acc_range"] = [min(F[a]["acc_2cm"]["mean"] for a in lin), max(F[a]["acc_2cm"]["mean"] for a in lin)]
    v["lineage_comp_range"] = [min(F[a]["comp_2cm"]["mean"] for a in lin), max(F[a]["comp_2cm"]["mean"] for a in lin)]
    nat = [a for a in full if a.endswith("@native")]
    v["native_arms"] = nat
    v["native_acc_below_lineage"] = all(F[a]["acc_2cm"]["mean"] < v["lineage_acc_range"][0] for a in nat)
    v["native_comp_top"] = sorted(full, key=lambda a: -F[a]["comp_2cm"]["mean"])[:len(nat)] == \
        sorted(nat, key=lambda a: -F[a]["comp_2cm"]["mean"])
    v["lineage_energy_range"] = [min(F[a]["energy_total_kj"] for a in lin), max(F[a]["energy_total_kj"] for a in lin)]
    v["lineage_energy_minmax"] = [min(lin, key=lambda a: F[a]["energy_total_kj"]), max(lin, key=lambda a: F[a]["energy_total_kj"])]
    # per-scene ranks among the arms that completed all scenes
    ranks = {}
    for s in scenes:
        order = sorted(full, key=lambda a: -F[a]["scene_f1"][s])
        for i, a in enumerate(order):
            ranks.setdefault(a, {})[s] = i + 1
    v["ranks"] = ranks
    v["first_count"] = {a: sum(1 for s in scenes if ranks[a][s] == 1) for a in full}
    v["last_count"] = {a: sum(1 for s in scenes if ranks[a][s] == len(full)) for a in full}
    v["first_scenes"] = {a: [s for s in scenes if ranks[a][s] == 1] for a in full}
    v["mean_rank"] = {a: float(np.mean(list(ranks[a].values()))) for a in full}
    v["rank_range"] = {a: [min(ranks[a].values()), max(ranks[a].values())] for a in full}
    sc = {}
    for s in scenes:
        vals = [F[a]["scene_f1"][s] for a in full]
        sc[s] = dict(mean=float(np.mean(vals)), spread_pp=100 * (max(vals) - min(vals)), n_images=int(nimg[s]))
    v["scene_stats"] = sc
    v["scene_order"] = sorted(scenes, key=lambda s: sc[s]["mean"])  # hardest first
    v["scene_spread_order"] = sorted(scenes, key=lambda s: -sc[s]["spread_pp"])

    # ---- runtime and the trade-off -----------------------------------------------------------
    cum = "CUMVS@3200-capped"
    for a in full:
        F[a]["x_cumvs"] = F[a]["wall_total_s"]["mean"] / F[cum]["wall_total_s"]["mean"]
        F[a]["x_apd"] = F[a]["wall_total_s"]["mean"] / F["APD-MVS@native"]["wall_total_s"]["mean"]
    v["max_wall_hw_pct"] = 100 * max(F[a]["wall_total_s"]["hw"] / F[a]["wall_total_s"]["mean"] for a in full)
    v["facade_slowest_all"] = all(F[a]["slowest_scene"] == "facade" for a in full)
    v["lin_r_range"] = [min(F[a]["lin_r"] for a in full), max(F[a]["lin_r"] for a in full)]

    def front(arms, tol, blocks):
        pts = sorted(arms, key=lambda a: blocks[a]["wall_total_s"]["mean"])
        fr, best = [], -1
        for a in pts:
            f = blocks[a][f"f1_{tol}"]["mean"]
            if f > best:
                fr.append(a)
                best = f
        return fr

    fr = front(full, "2cm", F)
    v["front"] = fr
    v["front_same_all_tols"] = all(front(full, t, F) == fr for t in TOLS)
    pc = pareto_csv[(pareto_csv.scene_set == "all13") & (pareto_csv.group == "pooled") & (pareto_csv.tolerance == "2cm") & pareto_csv.on_front]
    assert args.no_crosscheck or sorted(pc.arm) == sorted(fr), (sorted(pc.arm), fr)
    v["front_steps"] = [dict(a=fr[i], b=fr[i + 1],
                             d_f1_pp=100 * (F[fr[i + 1]]["f1_2cm"]["mean"] - F[fr[i]]["f1_2cm"]["mean"]),
                             x_time=F[fr[i + 1]]["wall_total_s"]["mean"] / F[fr[i]]["wall_total_s"]["mean"])
                        for i in range(len(fr) - 1)]
    dom = {}
    for a in full:
        if a in fr:
            continue
        dom[a] = [b for b in fr if F[b]["wall_total_s"]["mean"] < F[a]["wall_total_s"]["mean"]
                  and F[b]["f1_2cm"]["mean"] > F[a]["f1_2cm"]["mean"]]
        assert dom[a], a
    v["dominated_by"] = dom
    # dominated arms, grouped by the closest front arm that dominates them (the slowest such arm)
    dom_by = {}
    for a, bs in dom.items():
        b = max(bs, key=lambda x: F[x]["wall_total_s"]["mean"])
        dom_by.setdefault(b, []).append(a)
    v["dominated_by_nearest"] = {b: sorted(xs, key=lambda x: F[x]["wall_total_s"]["mean"]) for b, xs in dom_by.items()}
    C = v["arms_common"]
    v["front_by_tol"] = {t: front(full, t, F) for t in TOLS}
    v["rank_by_tol"] = {t: sorted(full, key=lambda a: -F[a][f"f1_{t}"]["mean"]) for t in TOLS}
    # neighbours in the 2 cm order whose difference is not resolved (Welch interval of the
    # difference of the two arms' 13-scene means over the repeats contains 0)
    def rep13(a, col="f1_2cm"):
        return ok[(ok.arm == a)].groupby("repeat")[col].mean().values
    unres = []
    for i in range(len(by_f1) - 1):
        a, b = by_f1[i], by_f1[i + 1]
        d = welch(rep13(a), rep13(b))
        if d["lo"] <= 0:
            unres.append(dict(a=a, b=b, d_pp=100 * d["mean"], lo_pp=100 * d["lo"], hi_pp=100 * d["hi"]))
    v["unresolved_neighbours_2cm"] = unres
    v["front_common"] = front(present, "2cm", C)
    cf = sorted(present, key=lambda a: -C[a]["f1_2cm"]["mean"])
    i = cf.index("HPM-MVS_plusplus@3200-capped")
    v["hpmpp_common_above"] = cf[:i]
    v["hpmpp_common_below_next"] = cf[i + 1]
    j = v["front_common"].index("HPM-MVS_plusplus@3200-capped")
    v["hpmpp_front_between"] = [v["front_common"][j - 1], v["front_common"][j + 1]]
    # the native resolution: what the two native arms cost and buy against the best capped arm
    capped = [a for a in full if a.endswith("3200-capped")]
    native = [a for a in full if a.endswith("@native")]
    best_capped = max(capped, key=lambda a: F[a]["f1_2cm"]["mean"])
    v["best_capped"] = best_capped
    v["native_vs_best_capped"] = {a: dict(d_f1_pp=100 * (F[a]["f1_2cm"]["mean"] - F[best_capped]["f1_2cm"]["mean"]),
                                          x_time=F[a]["wall_total_s"]["mean"] / F[best_capped]["wall_total_s"]["mean"])
                                  for a in native}
    v["capped_fastest"] = min(capped, key=lambda a: F[a]["wall_total_s"]["mean"])
    v["capped_slowest"] = max(capped, key=lambda a: F[a]["wall_total_s"]["mean"])
    v["lowest_acc"] = min(full, key=lambda a: F[a]["acc_2cm"]["mean"])
    v["power_min"] = min(full, key=lambda a: F[a]["power_w"])
    v["power_max"] = max(full, key=lambda a: F[a]["power_w"])
    v["energy_min"] = min(full, key=lambda a: F[a]["energy_total_kj"])
    for a in full:
        F[a]["input_load_s"] = F[a]["share"]["input_load"] * F[a]["wall_total_s"]["mean"]
        F[a]["fusion_s"] = F[a]["share"]["fusion"] * F[a]["wall_total_s"]["mean"]
    v["capped_total_range_s"] = [min(F[a]["wall_total_s"]["mean"] for a in capped), max(F[a]["wall_total_s"]["mean"] for a in capped)]
    v["convert_python_range_s"] = [min(F[a]["convert_total_s"] for a in lin), max(F[a]["convert_total_s"] for a in lin)]

    # ---- where the time goes ------------------------------------------------------------------
    for a in present:
        blk = v["arms"].get(a) if a in full else C[a]
        assert abs(blk["share_sum"] - 1) < 0.04, (a, blk["share_sum"])
    acm4 = ["ACMH@3200-capped", "ACMP@3200-capped", "ACMM@3200-capped", "ACMMP@3200-capped"]
    v["acm4"] = acm4
    v["acm4_idle_range"] = [min(F[a]["gpu_idle_share"] for a in acm4), max(F[a]["gpu_idle_share"] for a in acm4)]
    v["acm4_input_range"] = [min(F[a]["share"]["input_load"] for a in acm4), max(F[a]["share"]["input_load"] for a in acm4)]
    v["acm4_outside_pm_range"] = [min(F[a]["share_outside_patchmatch"] for a in acm4), max(F[a]["share_outside_patchmatch"] for a in acm4)]
    v["lineage_idle_range"] = [min(F[a]["gpu_idle_share"] for a in lin), max(F[a]["gpu_idle_share"] for a in lin)]
    x = [F[a]["gpu_idle_share"] for a in full]
    y = [F[a]["share_outside_patchmatch"] for a in full]
    v["idle_vs_outside_r"] = float(np.corrcoef(x, y)[0, 1])
    v["idle_vs_outside_n"] = len(full)
    v["idle_vs_input_r"] = float(np.corrcoef(x, [F[a]["share"]["input_load"] for a in full])[0, 1])
    # ACMM loads every image several times: input_load spans per image, on every scene
    m = il[(il.arm == "ACMM@3200-capped") & il.ok]
    per = (m.groupby(["scene", "repeat"])["count"].sum() / m.groupby(["scene", "repeat"]).scene.first().map(nimg)).unique()
    assert len(set(np.round(per, 6))) == 1, per
    v["acmm_loads_per_image"] = int(round(per[0]))
    pip = m[m.scene == "pipes"]
    v["acmm_pipes_input_load_spans"] = int(pip.groupby("repeat")["count"].sum().iloc[0])

    # ---- section 4.3 evidence (analysis runs, unlocked clocks) ---------------------------------
    p43 = json.loads(Path(args.perf43).read_text())["v"]
    v["s43"] = dict(
        pipes_base_s=p43["pipes"]["span"]["base_s"], pipes_stack_s=p43["pipes"]["span"]["stack_s"],
        pipes_share=p43["pipes"]["span"]["share"], pipes_n=p43["pipes"]["n"],
        office_base_s=p43["office"]["span"]["base_s"], office_stack_s=p43["office"]["span"]["stack_s"],
        office_share=p43["office"]["span"]["share"], office_n=p43["office"]["n"],
        host_base_s=p43["phases"]["host"]["base_s"], host_stack_s=p43["phases"]["host"]["stack_s"],
        kernel_base_s=p43["phases"]["kernel"]["base_s"], kernel_stack_s=p43["phases"]["kernel"]["stack_s"],
        commits=p43["stack"]["commits"],
        top_n=p43["abl"]["top"]["n"], top_share=p43["abl"]["top"]["share"],
        top_k1c_s=p43["abl"]["top"]["k1c_s"], top_h1_s=p43["abl"]["top"]["h1_s"],
        top_u8_s=p43["abl"]["top"]["u8_s"], top_k10_s=p43["abl"]["top"]["k10_s"],
    )
    s = v["s43"]
    s["host_saved_share"] = 1 - s["host_stack_s"] / s["host_base_s"]
    s["kernel_saved_share"] = 1 - s["kernel_stack_s"] / s["kernel_base_s"]
    s["pipes_x"] = s["pipes_base_s"] / s["pipes_stack_s"]
    s["office_x"] = s["office_base_s"] / s["office_stack_s"]

    # ---- memory and energy --------------------------------------------------------------------
    hp = "HPM-MVS_plusplus@3200-capped"
    hr = runs[runs.arm == hp]
    hf = hr[~hr.ok]
    v["hpmpp"] = dict(
        n_runs=len(hr), n_failed=len(hf), failure_class=sorted(hf.failure_class.unique()),
        status=sorted(hf.status.unique()), crash_scale=sorted(hf.crash_scale.dropna().astype(str).unique()),
        ok_scenes=sorted(hr[hr.ok].scene.unique()), failed_scenes=sorted(hf.scene.unique()),
        ok_max_images=int(hr[hr.ok].n_images.max()), failed_min_images=int(hf.n_images.min()),
        last_mem_range=[float(hf.last_device_mem_mib.min()), float(hf.last_device_mem_mib.max())],
        ok_peak_range=[float(hr[hr.ok].peak_device_mem_mib.min()), float(hr[hr.ok].peak_device_mem_mib.max())],
        failed_scene_mem={s: float(hf[hf.scene == s].last_device_mem_mib.mean()) for s in sorted(hf.scene.unique())},
    )
    assert v["hpmpp"]["ok_max_images"] < v["hpmpp"]["failed_min_images"]
    assert sorted(v["hpmpp"]["ok_scenes"]) == common
    assert v["n_failed"] == v["hpmpp"]["n_failed"]
    v["hpmpp"]["last_mem_share_card"] = [x / CARD_MIB for x in v["hpmpp"]["last_mem_range"]]
    capped_wo = [a for a in capped]
    v["capped_peak_range_mib"] = [min(F[a]["peak_dev_mib"] for a in capped_wo), max(F[a]["peak_dev_mib"] for a in capped_wo)]
    small = [a for a in capped if F[a]["peak_dev_mib"] < 2500 and a != cum]
    v["capped_small_peak_range_mib"] = [min(F[a]["peak_dev_mib"] for a in small), max(F[a]["peak_dev_mib"] for a in small)]
    v["capped_small"] = small
    v["energy_power_r"] = None

    # ---- repeatability (appendix) --------------------------------------------------------------
    rep = []
    for (a, sc_), g in ok.groupby(["arm", "scene"]):
        if len(g) != N_REP:
            continue
        w, f = g.wall_time_s.values, g.f1_2cm.values
        rep.append(dict(arm=a, scene=sc_, wall_hw_pct=100 * T975 * w.std(ddof=1) / math.sqrt(N_REP) / w.mean(),
                        f1_hw_pct=100 * T975 * f.std(ddof=1) / math.sqrt(N_REP) / f.mean(),
                        f1_sd_pp=100 * f.std(ddof=1), f1_distinct=len(set(f))))
    rep = pd.DataFrame(rep)
    v["rep"] = dict(
        cells=len(rep), wall_le1=int((rep.wall_hw_pct <= 1).sum()), f1_le1=int((rep.f1_hw_pct <= 1).sum()),
        wall_all_le1_arms=sorted(a for a, g in rep.groupby("arm") if (g.wall_hw_pct <= 1).all()),
        worst_wall=rep.loc[rep.wall_hw_pct.idxmax()].to_dict(),
        max_f1_sd_pp=float(rep.f1_sd_pp.max()),
        min_f1_distinct=int(rep.f1_distinct.min()), min_f1_sd_pp=float(rep.f1_sd_pp.min()),
        miss_wall_arms=sorted(rep[rep.wall_hw_pct > 1].arm.unique()),
        cells_list=rep.to_dict("records"),
    )
    # cross-check with aggregate.py's cells.csv
    cc = cells_csv[(cells_csv.metric == "wall_time_s") & (cells_csv.n_ok == N_REP)]
    assert args.no_crosscheck or int((cc.ci95_halfwidth_pct <= 1).sum()) == v["rep"]["wall_le1"]

    # ---- CUMVS(APD) against APD-MVS and among the capped arms (section 5.2.5) ------------------
    on, o3, apd = "production-apd-mvs@native", "production-apd-mvs@3200-capped", "APD-MVS@native"
    if on in full and o3 in full:
        def rruns(a):
            return ok[ok.arm == a]
        tot = {a: rruns(a).groupby("repeat").wall_time_s.sum() for a in (on, apd)}
        sp = ratio(tot[apd].values, tot[on].values)
        per_rep = (tot[apd] / tot[on]).values  # pairing by repeat index: a check only
        sp_rep = ci(per_rep)
        assert abs(sp["mean"] - sp_rep["mean"]) < 1e-3 * sp["mean"], (sp, sp_rep)
        # per scene: time ratio and F1 difference, independent samples
        sc_rows = {}
        for s_ in scenes:
            a_ = rruns(apd)[rruns(apd).scene == s_]
            o_ = rruns(on)[rruns(on).scene == s_]
            assert len(a_) == len(o_) == N_REP
            row = dict(x=ratio(a_.wall_time_s, o_.wall_time_s))
            for t in TOLS:
                row[f"d_f1_{t}"] = {k: (100 * x if k in ("mean", "lo", "hi", "hw") else x)
                                    for k, x in welch(o_[f"f1_{t}"], a_[f"f1_{t}"]).items()}
            row["d_acc_2cm_pp"] = 100 * float(o_.acc_2cm.mean() - a_.acc_2cm.mean())
            row["d_comp_2cm_pp"] = 100 * float(o_.comp_2cm.mean() - a_.comp_2cm.mean())
            row["mem_ours"] = float(o_.peak_device_mem_mib.max())
            row["mem_apd"] = float(a_.peak_device_mem_mib.max())
            sc_rows[s_] = row
        xs = {s_: r_["x"]["mean"] for s_, r_ in sc_rows.items()}
        d2 = {s_: r_["d_f1_2cm"] for s_, r_ in sc_rows.items()}
        O = dict(
            speedup=sp, speedup_per_repeat_check=sp_rep,
            time_share=1 / sp["mean"],
            scene=sc_rows,
            x_min=min(xs.values()), x_min_scene=min(xs, key=xs.get),
            x_max=max(xs.values()), x_max_scene=max(xs, key=xs.get),
            scene_order_x=sorted(scenes, key=lambda s_: xs[s_]),
            d_f1_13={t: {k: (100 * x if k in ("mean", "lo", "hi", "hw") else x)
                         for k, x in welch(rep13(on, f"f1_{t}"), rep13(apd, f"f1_{t}")).items()} for t in TOLS},
            d_acc_13_pp=100 * (F[on]["acc_2cm"]["mean"] - F[apd]["acc_2cm"]["mean"]),
            d_comp_13_pp=100 * (F[on]["comp_2cm"]["mean"] - F[apd]["comp_2cm"]["mean"]),
            d_f1_pos=sorted(s_ for s_ in scenes if d2[s_]["lo"] > 0),
            d_f1_neg=sorted(s_ for s_ in scenes if d2[s_]["hi"] < 0),
            d_f1_zero=sorted(s_ for s_ in scenes if d2[s_]["lo"] <= 0 <= d2[s_]["hi"]),
            d_f1_min=min(d["mean"] for d in d2.values()), d_f1_min_scene=min(d2, key=lambda s_: d2[s_]["mean"]),
            d_f1_max=max(d["mean"] for d in d2.values()), d_f1_max_scene=max(d2, key=lambda s_: d2[s_]["mean"]),
            d_f1_absmax_ci=max(max(abs(d["lo"]), abs(d["hi"])) for d in d2.values()),
            mem_higher=sorted(s_ for s_ in scenes if sc_rows[s_]["mem_ours"] > sc_rows[s_]["mem_apd"]),
            mem_lower=sorted(s_ for s_ in scenes if sc_rows[s_]["mem_ours"] < sc_rows[s_]["mem_apd"]),
            energy_ratio=F[on]["energy_total_kj"] / F[apd]["energy_total_kj"],
            power_ratio=F[on]["power_w"] / F[apd]["power_w"],
            host_gib=[F[on]["peak_host_gib"], F[apd]["peak_host_gib"]],
        )
        # where the saving is: seconds per phase class (share x mean total), both arms
        O["class_s"] = {a: {c: F[a]["share"][c] * F[a]["wall_total_s"]["mean"] for c in CLASSES} for a in (apd, on)}
        O["class_saved_s"] = {c: O["class_s"][apd][c] - O["class_s"][on][c] for c in CLASSES}
        saved = F[apd]["wall_total_s"]["mean"] - F[on]["wall_total_s"]["mean"]
        O["saved_s"] = saved
        O["class_saved_share"] = {c: O["class_saved_s"][c] / saved for c in CLASSES}
        O["class_x"] = {c: O["class_s"][apd][c] / O["class_s"][on][c] for c in CLASSES if O["class_s"][on][c] > 0}
        O["convert_s"] = [F[on]["convert_total_s"], F[apd]["convert_total_s"]]
        # the 3200 arm among the capped arms: a position, not a speedup
        capped_f1 = sorted(capped, key=lambda a: -F[a]["f1_2cm"]["mean"])
        O["c3200_rank_capped"] = capped_f1.index(o3) + 1
        O["c3200_n_capped"] = len(capped)
        O["c3200_above"] = capped_f1[:capped_f1.index(o3)]
        O["c3200_x_apd"] = F[o3]["wall_total_s"]["mean"] / F[apd]["wall_total_s"]["mean"]
        O["c3200_x_on"] = F[o3]["wall_total_s"]["mean"] / F[on]["wall_total_s"]["mean"]
        O["c3200_d_f1_on_pp"] = {t: 100 * (F[o3][f"f1_{t}"]["mean"] - F[on][f"f1_{t}"]["mean"]) for t in TOLS}
        O["c3200_d_f1_mp_pp"] = {t: 100 * (F[o3][f"f1_{t}"]["mean"] - F["MP-MVS@3200-capped"][f"f1_{t}"]["mean"]) for t in TOLS}
        O["c3200_x_mp"] = F[o3]["wall_total_s"]["mean"] / F["MP-MVS@3200-capped"]["wall_total_s"]["mean"]
        O["c3200_x_cumvs"] = F[o3]["x_cumvs"]
        O["c3200_slower_than"] = sorted(a for a in capped if a != o3 and F[a]["wall_total_s"]["mean"] < F[o3]["wall_total_s"]["mean"])
        O["c3200_on_front_tols"] = [t for t in TOLS if o3 in v["front_by_tol"][t]]
        O["on_on_front_tols"] = [t for t in TOLS if on in v["front_by_tol"][t]]
        O["apd_on_front_tols"] = [t for t in TOLS if apd in v["front_by_tol"][t]]
        # section 4.3's final test on the same two scenes (analysis runs, against the fixed base)
        O["s43_vs_bench"] = dict(pipes_s43_x=v["s43"]["pipes_x"], office_s43_x=v["s43"]["office_x"],
                                 pipes_bench_x=xs["pipes"], office_bench_x=xs["office"])
        v["ours"] = O

    # ---- validity facts for the corrections file ------------------------------------------------
    v["clock_mode_mhz"] = sorted(int(x) for x in runs.sm_clock_mode_mhz.unique())
    v["clock_held_runs"] = int(runs.clock_held.sum())

    srcs = {p.name: sha(p) for p in sorted(DATA.glob("*.csv"))}
    out = dict(meta=dict(generator="scripts/bench_json.py", sources=srcs,
                         origin="generated/bench-5.2/data (sessions final-author-r1..r5 and m8-author-r1, r2, r3a+r3b, r4, r5, see README.md); "
                                "section 4.3 numbers from generated/perf-4.3/derived/numbers-results.json"),
               v=v)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, indent=1, default=lambda o: o.item() if hasattr(o, "item") else str(o)))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
