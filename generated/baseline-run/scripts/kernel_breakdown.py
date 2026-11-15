#!/usr/bin/env python3
"""Kernel time of one run by kernel, stage and round, for chapters/figures/kernel-breakdown.typ.

Reads the per-launch extract of a run's Nsight Systems trace and writes, per CUDA kernel: the
number of launches, the summed GPU-side duration, the split of that duration over the rounds,
and the stage of the thesis timing table (methodology, table-timing-measurements) the kernel
is launched in. Per stage it sets the kernel time against the host-side phase-timer total of
the stage. The Typst table reads that JSON and nothing else, so no number in the table is
typed by hand.

Inputs (all paths are arguments):

  --launches PATH       launches.tsv: one row per kernel launch (columns pass_idx, scale, image,
                        state, seq, kernel, iter, ms, width, height). An extract of the CUPTI
                        kernel activity records of the run's Nsight Systems trace; durations
                        are rounded to 0.01 ms.
  --stages PATH         stage-timings.json of the run, as written by stage_timings.py (next to
                        this script) from the run's phases.txt: stage totals, rounds, run
                        context.
  --phases PATH         (optional) the run's phases.txt. Adds a check per phase-timer span:
                        the kernels launched inside a span may not take longer than the span.
  --kernel-table PATH   (optional) p10_kernel_table.csv of the performance study (per-kernel
                        totals in ns from the same trace). Cross-check only; --config selects
                        its rows.
  --run TAG             run tag; must be the run of --stages.

Which kernel belongs to which stage is not guessed from the names: PASS_PATTERN below is the
launch sequence of APD::RunPatchMatch, read from the source, and every reference image pass of
the extract must follow it launch by launch.

Checks that stop the script: the launch sequence of every pass; the pass grid (images x passes,
the same number of passes per round, rounds as in --stages); launches per stage against the
phase-timer span counts; kernel time of a stage not above its phase-timer total; with --phases
the same per span; with --kernel-table every kernel total within the rounding of the extract.

Run (from thesis/, standard library only; `make figures` does this when an input changed):

  python3 generated/baseline-run/scripts/kernel_breakdown.py \
      --launches generated/baseline-run/data/perf-nsys-r1/launches.tsv \
      --stages generated/baseline-run/derived/perf-nsys-r1/stage-timings.json \
      --phases generated/baseline-run/data/perf-nsys-r1/phases.txt \
      --kernel-table generated/baseline-run/data/perf-nsys-r1/kernel-totals-base.csv \
      --run perf-nsys-r1 \
      --out generated/baseline-run/derived/perf-nsys-r1/kernel-breakdown.json
"""
import argparse
import csv
import json
import sys
from collections import defaultdict
from pathlib import Path

from run_files import sha256

# Launch sequence of one PatchMatch call, in source order, with the phase-timer scope each
# launch sits in. Read from APD::RunPatchMatch,
# modules/cuda_multi_view_stereo/src/apd/APD.cu of production APD-MVS at commit 95c9294:
#   lines 2419-2452  BENCH_PHASE("patchmatch.init")
#   lines 2457-2461  BENCH_PHASE("patchmatch.propagate", "iter=%d part=strong")   per iteration
#   lines 2465-2467  BENCH_PHASE("prior_build", "iter=%d")                        per iteration
#   lines 2471-2475  BENCH_PHASE("patchmatch.propagate", "iter=%d part=weak")     per iteration
#   lines 2481-2494  BENCH_PHASE("patchmatch.finalize")
# Every launch is followed by cudaDeviceSynchronize() inside its scope, so a kernel runs
# entirely within the span of its stage.
SOURCE = "modules/cuda_multi_view_stereo/src/apd/APD.cu"
SOURCE_COMMIT = "95c9294"
PASS_HEAD = [
    ("InitRandomStates", "patchmatch.init", None),
    ("FindNearestStrongPoint", "patchmatch.init", None),
    ("GenNeighbours", "patchmatch.init", None),
    ("NeigbourUpdate", "patchmatch.init", None),          # spelled as in the code
    ("RandomInitialization", "patchmatch.init", None),
]
PASS_ITER = [
    ("BlackPixelUpdateStrong", "patchmatch.propagate", "strong"),
    ("RedPixelUpdateStrong", "patchmatch.propagate", "strong"),
    ("RANSACToGetFitPlane", "prior_build", None),
    ("BlackPixelUpdateWeak", "patchmatch.propagate", "weak"),
    ("RedPixelUpdateWeak", "patchmatch.propagate", "weak"),
]
PASS_TAIL = [
    ("GetDepthandNormal", "patchmatch.finalize", None),
    ("BlackPixelFilterStrong", "patchmatch.finalize", None),
    ("RedPixelFilterStrong", "patchmatch.finalize", None),
    ("DepthToWeak", "patchmatch.finalize", None),
    ("LocalRefine", "patchmatch.finalize", None),
]
STAGE_LINES = {
    "patchmatch.init": "2419-2452",
    "patchmatch.propagate": "2457-2461, 2471-2475",
    "prior_build": "2465-2467",
    "patchmatch.finalize": "2481-2494",
}
STAGE_ORDER = ["patchmatch.init", "patchmatch.propagate", "prior_build", "patchmatch.finalize"]

MS_STEP = 0.01               # resolution of the `ms` column
HALF_STEP_S = MS_STEP / 2 / 1e3   # largest rounding error of one launch, in seconds
EPS = 1e-9


def die(msg):
    sys.exit(f"kernel_breakdown: {msg}")


def row_name(kernel):
    """Black/Red checkerboard kernels share a row: BlackPixelUpdateWeak -> Black/RedPixelUpdateWeak."""
    for colour in ("Black", "Red"):
        if kernel.startswith(colour):
            return "Black/Red" + kernel[len(colour):]
    return kernel


def read_launches(path):
    with open(path, newline="") as fh:
        rd = csv.DictReader(fh, delimiter="\t")
        need = {"pass_idx", "scale", "image", "state", "seq", "kernel", "iter", "ms"}
        if not need <= set(rd.fieldnames or ()):
            die(f"{path}: missing columns {sorted(need - set(rd.fieldnames or ()))}")
        rows = []
        for no, r in enumerate(rd, 2):
            ms = r["ms"]
            # the rounding bound below rests on two decimals
            if "." not in ms or len(ms.split(".")[1]) != 2 or float(ms) < 0:
                die(f"{path}:{no}: duration {ms!r} is not a non-negative value with two decimals")
            rows.append({"pass": int(r["pass_idx"]), "scale": int(r["scale"]), "image": int(r["image"]),
                         "state": r["state"], "seq": int(r["seq"]), "kernel": r["kernel"],
                         "iter": int(r["iter"]), "s": float(ms) / 1e3})
    if not rows:
        die(f"{path}: no launches")
    return rows


def read_phase_passes(path):
    """phases.txt -> per reference image pass, in order: scale, attrs and the spans inside it."""
    passes, cur, scale, open_ = [], None, None, {}
    for no, line in enumerate(Path(path).read_text().splitlines(), 1):
        f = line.split()
        if not f or f[0] != "PHASE":
            continue
        name, ev, ts = f[1], f[2], int(f[3])
        attrs = dict(a.split("=", 1) for a in f[4:] if "=" in a)
        if name == "scale":
            scale = int(attrs["scale"]) if ev == "BEGIN" else None
        elif name == "image_pass":
            if ev == "BEGIN":
                cur = {"scale": scale, "image": int(attrs["image"]), "state": attrs["pass"], "spans": []}
            else:
                passes.append(cur)
                cur = None
        elif cur is not None:
            if ev == "BEGIN":
                open_[name] = (ts, attrs)
            else:
                t0, a0 = open_.pop(name)
                cur["spans"].append((name, a0.get("part"), int(a0["iter"]) if "iter" in a0 else None,
                                     (ts - t0) / 1e9))
    return passes


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--launches", required=True)
    ap.add_argument("--stages", required=True)
    ap.add_argument("--phases")
    ap.add_argument("--kernel-table")
    ap.add_argument("--config", default="base", help="rows of --kernel-table to compare with (default: base)")
    ap.add_argument("--run", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    rows = read_launches(a.launches)
    st = json.loads(Path(a.stages).read_text())
    if st["meta"]["run"] != a.run:
        die(f"--stages is run {st['meta']['run']!r}, not {a.run!r}")
    run_commit = (st["meta"].get("context") or {}).get("commit") or ""
    if not run_commit.startswith(SOURCE_COMMIT):
        die(f"the kernel-to-stage mapping was read at {SOURCE_COMMIT}, the run is of {run_commit or 'an unrecorded commit'}")

    # ---- the pass grid: rounds, images, passes -------------------------------------------------
    by_pass = defaultdict(list)
    for r in rows:
        by_pass[r["pass"]].append(r)
    n_pass = len(by_pass)
    if sorted(by_pass) != list(range(n_pass)):
        die("pass_idx is not 0..n-1")
    if n_pass != st["stages"]["image_pass"]["calls"]:
        die(f"{n_pass} passes in the extract, {st['stages']['image_pass']['calls']} reference image passes in --stages")
    round_scales = [r["scale"] for r in st["rounds"]]
    n_round = len(round_scales)
    if n_pass % n_round:
        die("passes do not divide evenly over the rounds")
    per_round = n_pass // n_round
    n_iter = max(r["iter"] for r in rows) + 1
    pattern = PASS_HEAD + [(k, s, p, i) for i in range(n_iter) for k, s, p in PASS_ITER] + PASS_TAIL
    pattern = [(e[0], e[1], e[2], e[3] if len(e) == 4 else 0) for e in pattern]

    pass_round = []
    for p in range(n_pass):
        ls = sorted(by_pass[p], key=lambda r: r["seq"])
        by_pass[p] = ls
        k = p // per_round
        pass_round.append(k)
        if {r["scale"] for r in ls} != {round_scales[k]}:
            die(f"pass {p}: scale {sorted({r['scale'] for r in ls})}, expected {round_scales[k]} (round {k + 1})")
        if len({(r["image"], r["state"]) for r in ls}) != 1:
            die(f"pass {p}: more than one image or pass state")
        got = [(r["kernel"], r["iter"]) for r in ls]
        want = [(k_, i) for k_, _, _, i in pattern]
        if got != want:
            die(f"pass {p}: the launch sequence is not that of RunPatchMatch ({SOURCE} @ {SOURCE_COMMIT}):\n"
                f"  got  {got}\n  want {want}")
    images = len({r["image"] for r in rows})
    if images != st["images"] or n_pass != images * st["pass_groups"]:
        die("images x passes of the extract differ from --stages")

    stage_of = {k: s for k, s, _, _ in pattern}

    # ---- sums ---------------------------------------------------------------------------------
    kern = {}       # row name -> record, in launch order
    for k, s, _, _ in pattern:
        kern.setdefault(row_name(k), {"name": row_name(k), "members": [], "stage": s,
                                      "launches": 0, "total_s": 0.0,
                                      "round_launches": [0] * n_round, "round_s": [0.0] * n_round})
        if k not in kern[row_name(k)]["members"]:
            kern[row_name(k)]["members"].append(k)
        if kern[row_name(k)]["stage"] != s:
            die(f"{row_name(k)}: the pair is launched in two stages")
    member_s, member_n = defaultdict(float), defaultdict(int)
    for r in rows:
        rec, k = kern[row_name(r["kernel"])], pass_round[r["pass"]]
        rec["launches"] += 1
        rec["total_s"] += r["s"]
        rec["round_launches"][k] += 1
        rec["round_s"][k] += r["s"]
        member_s[r["kernel"]] += r["s"]
        member_n[r["kernel"]] += 1
    total_s = sum(r["s"] for r in rows)
    for rec in kern.values():
        rec["per_pass"] = rec["launches"] // n_pass
        if rec["per_pass"] * n_pass != rec["launches"]:
            die(f"{rec['name']}: not a whole number of launches per pass")
        rec["rounding_s"] = rec["launches"] * HALF_STEP_S

    # ---- stages: kernel time (GPU side) against the phase-timer total (host side) ---------------
    stages = []
    for key in STAGE_ORDER:
        recs = [rec for rec in kern.values() if rec["stage"] == key]
        ps = st["stages"][key]
        launches = sum(rec["launches"] for rec in recs)
        kernel_s = sum(rec["total_s"] for rec in recs)
        # launches per span, from the source pattern: one span holds this many launches
        spans_expected = {"patchmatch.init": n_pass, "patchmatch.finalize": n_pass,
                          "prior_build": n_pass * n_iter, "patchmatch.propagate": n_pass * n_iter * 2}[key]
        if ps["calls"] != spans_expected:
            die(f"{key}: {ps['calls']} phase-timer spans, the launch pattern needs {spans_expected}")
        if ps["outside_calls"]:
            die(f"{key}: spans outside the reconstruction loop")
        if kernel_s > ps["total_s"] + launches * HALF_STEP_S + EPS:
            die(f"{key}: kernels take {kernel_s:.6f} s, more than the stage's phase-timer total {ps['total_s']:.6f} s")
        stages.append({"key": key, "source_lines": STAGE_LINES[key],
                       "kernels": [rec["name"] for rec in recs],
                       "launches": launches, "kernel_s": kernel_s,
                       "round_s": [sum(rec["round_s"][k] for rec in recs) for k in range(n_round)],
                       "spans": ps["calls"], "span_s": ps["total_s"],
                       "rounding_s": launches * HALF_STEP_S})

    # ---- optional: the same comparison span by span --------------------------------------------
    span_check = None
    if a.phases:
        if sha256(a.phases) != st["meta"]["source_sha256"]:
            die("--phases is not the phases.txt that --stages was generated from")
        pp = read_phase_passes(a.phases)
        if len(pp) != n_pass:
            die(f"{len(pp)} reference image passes in --phases")
        n_span, worst = 0, float("inf")      # worst: smallest (span - kernels) seen
        for p, ph in enumerate(pp):
            ls = by_pass[p]
            if (ph["scale"], ph["image"], ph["state"]) != (ls[0]["scale"], ls[0]["image"], ls[0]["state"]):
                die(f"pass {p}: phases.txt has scale/image/state {ph['scale']}/{ph['image']}/{ph['state']}, "
                    f"the extract {ls[0]['scale']}/{ls[0]['image']}/{ls[0]['state']}")
            inside = defaultdict(lambda: [0.0, 0])
            for r, (_, stage, part, it) in zip(ls, pattern):
                slot = (stage, part, it if stage in ("patchmatch.propagate", "prior_build") else None)
                inside[slot][0] += r["s"]
                inside[slot][1] += 1
            spans = {(n, part, it): d for n, part, it, d in ph["spans"] if n in STAGE_LINES}
            if set(spans) != set(inside):
                die(f"pass {p}: phase-timer spans {sorted(spans, key=str)} do not match the launch pattern")
            for slot, (ks, n) in inside.items():
                n_span += 1
                worst = min(worst, spans[slot] - ks)
                if ks > spans[slot] + n * HALF_STEP_S + EPS:
                    die(f"pass {p} {slot}: kernels take {ks * 1e3:.3f} ms inside a span of {spans[slot] * 1e3:.3f} ms")
        span_check = {"spans": n_span, "min_span_minus_kernels_s": round(worst, 9)}

    # ---- optional: cross-check with the per-kernel totals of the performance study ---------------
    cross = None
    if a.kernel_table:
        ref = {}
        with open(a.kernel_table, newline="") as fh:
            for r in csv.DictReader(fh):
                if r["config"] == a.config and r["run"] == a.run and not r["kernel"].startswith("__"):
                    ref[r["kernel"]] = (int(r["launches"]), int(r["total_ns"]) / 1e9)
        if set(ref) != set(member_s):
            die(f"--kernel-table has kernels {sorted(set(ref) ^ set(member_s))} that differ from the extract")
        worst = 0.0
        for k, (n, s) in ref.items():
            if n != member_n[k]:
                die(f"{k}: {member_n[k]} launches, --kernel-table has {n}")
            diff = abs(member_s[k] - s)
            if diff > n * HALF_STEP_S + EPS:
                die(f"{k}: {member_s[k]:.6f} s, --kernel-table has {s:.6f} s; beyond the rounding of the extract")
            worst = max(worst, diff)
        ref_total = sum(s for _, s in ref.values())
        cross = {"source": Path(a.kernel_table).name, "source_sha256": sha256(a.kernel_table),
                 "config": a.config, "ref_total_s": round(ref_total, 9),
                 "total_diff_s": round(total_s - ref_total, 9), "max_kernel_diff_s": round(worst, 9)}

    rounds = []
    for k, rd in enumerate(st["rounds"]):
        rounds.append({"scale": rd["scale"], "passes": per_round,
                       "launches": sum(rec["round_launches"][k] for rec in kern.values()),
                       "kernel_s": round(sum(rec["round_s"][k] for rec in kern.values()), 6),
                       "span_s": round(rd["t1"] - rd["t0"], 6)})

    def r6(rec, keys):
        for key in keys:
            rec[key] = [round(v, 6) for v in rec[key]] if isinstance(rec[key], list) else round(rec[key], 6)
        return rec

    out = {
        "meta": {
            "run": a.run,
            "source": Path(a.launches).name,
            "source_kind": "per-launch extract of the Nsight Systems trace (CUPTI kernel activity records)",
            "source_sha256": sha256(a.launches),
            "duration_step_ms": MS_STEP,
            "stages_source": Path(a.stages).name,
            "stages_source_sha256": sha256(a.stages),
            "phases_sha256": st["meta"]["source_sha256"],
            "mapping_source": SOURCE,
            "mapping_commit": SOURCE_COMMIT,
            "generated_by": "generated/baseline-run/scripts/kernel_breakdown.py",
            "context": st["meta"]["context"],
        },
        "images": images,
        "pass_groups": st["pass_groups"],
        "passes": n_pass,
        "iterations": n_iter,
        "launches_per_pass": len(pattern),
        "run_s": st["run_s"],
        "patchmatch_s": st["stages"]["patchmatch"]["total_s"],
        "launches": len(rows),
        "kernel_s": round(total_s, 6),
        "rounding_s": round(len(rows) * HALF_STEP_S, 6),
        "rounds": rounds,
        "stages": [r6(s, ("kernel_s", "round_s", "rounding_s")) for s in stages],
        "kernels": [r6(rec, ("total_s", "round_s", "rounding_s")) for rec in kern.values()],
        "checks": {"span_by_span": span_check, "kernel_table": cross},
    }
    if abs(sum(k["total_s"] for k in out["kernels"]) - out["kernel_s"]) > 1e-5:
        die("rows do not add up to the total")
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, separators=(",", ":")) + "\n")

    print(f"{a.run}: {len(rows)} launches in {n_pass} passes, kernel time {total_s:.3f} s "
          f"(+-{len(rows) * HALF_STEP_S:.3f} s rounding), {100 * total_s / st['run_s']:.2f} % of the run span")
    for s in stages:
        print(f"  {s['key']:22s} kernels {s['kernel_s']:9.3f} s  span {s['span_s']:9.3f} s  "
              f"{100 * s['kernel_s'] / s['span_s']:7.3f} %  host remainder {s['span_s'] - s['kernel_s']:.3f} s")
        for rec in kern.values():
            if rec["stage"] == s["key"]:
                print(f"      {rec['name']:28s} {rec['launches']:5d} x {rec['total_s']:9.3f} s  {100 * rec['total_s'] / total_s:6.2f} %"
                      f"   rounds {' '.join(f'{v:8.3f}' for v in rec['round_s'])}")
    for k, rd in enumerate(rounds):
        print(f"  round {k + 1} (scale {rd['scale']}): kernels {rd['kernel_s']:.3f} s of a {rd['span_s']:.3f} s round span")
    if span_check:
        print(f"  span by span: {span_check['spans']} spans, smallest span minus kernels {span_check['min_span_minus_kernels_s'] * 1e3:.3f} ms")
    if cross:
        print(f"  kernel table ({cross['config']}): total differs by {cross['total_diff_s'] * 1e3:+.3f} ms, "
              f"largest kernel difference {cross['max_kernel_diff_s'] * 1e3:.3f} ms")


if __name__ == "__main__":
    main()
