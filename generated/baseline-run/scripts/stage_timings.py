#!/usr/bin/env python3
"""Stage timings of one run, for the stage table of chapters/figures/run-breakdown.typ.

Reads the phase-timer spans of one run and writes, per stage of the thesis timing table
(methodology, table-timing-measurements): the number of spans, their summed duration, its
split over the rounds, the share of every reference image pass spent in the stage, and the
spans that lie outside the reconstruction loop. The Typst figure reads that JSON and the one of
pass_timeline.py and nothing else, so no number in it is typed by hand.

Two inputs are accepted:

  --phases PATH       the run's phases.txt (primary source; lines
                      "PHASE <name> BEGIN|END <CLOCK_MONOTONIC ns> [key=value ...]")
  --spans-csv PATH    a span extract of phases.txt as written by the performance study
                      (.dev/perf/thesis-plots/scripts/p05_timeline_before_after.py; columns
                      run,record,stage,part,scale,image,pass_,iter,t_start_s,t_end_s,...),
                      together with --run TAG

Time zero is the BEGIN of the `run` span in both cases. --context PATH adds the facts of
the run's context.txt (commit, GPU, profiler mode, method wall time) to the JSON, so that the
caption does not have to type them.

Run (from thesis/, standard library only; `make figures` does this when an input changed):

  python3 generated/baseline-run/scripts/stage_timings.py \
      --phases generated/baseline-run/data/perf-nsys-r1/phases.txt \
      --context generated/baseline-run/data/perf-nsys-r1/context.txt \
      --run perf-nsys-r1 \
      --out generated/baseline-run/derived/perf-nsys-r1/stage-timings.json
"""
import argparse
import csv
import json
import sys
from collections import defaultdict
from pathlib import Path

from run_files import read_context, read_phases, sha256

LOOP_STAGE = "image_pass"   # one span per reference image pass
ROUND_STAGE = "scale"       # one span per round (APD-MVS) or pyramid level (ACM family)


def read_spans_csv(path, run):
    """Span extract of the performance study -> [(stage, t0, t1, attrs)]."""
    spans = []
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            if r["run"] != run or r["record"] != "span":
                continue
            attrs = {k.rstrip("_"): r[k] for k in ("scale", "image", "pass_", "iter", "part") if r.get(k)}
            spans.append((r["stage"], float(r["t_start_s"]), float(r["t_end_s"]), attrs))
    if not spans:
        sys.exit(f"no spans of run {run!r} in {path}")
    runs = [s for s in spans if s[0] == "run"]
    if len(runs) != 1 or abs(runs[0][1]) > 1e-9:
        sys.exit("the extract must hold exactly one `run` span starting at 0")
    return spans


def overlap(a0, a1, b0, b1):
    return max(0.0, min(a1, b1) - max(a0, b0))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--phases")
    src.add_argument("--spans-csv")
    ap.add_argument("--context", help="the run's context.txt (optional)")
    ap.add_argument("--run", required=True, help="run tag: recorded in the JSON; selects the rows of --spans-csv")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    source = Path(a.phases or a.spans_csv)
    spans = read_phases(source) if a.phases else read_spans_csv(source, a.run)

    by_stage = defaultdict(list)
    for name, t0, t1, attrs in spans:
        if t1 < t0:
            sys.exit(f"negative span {name} {t0} {t1}")
        by_stage[name].append((t0, t1, attrs))
    for v in by_stage.values():
        v.sort(key=lambda s: (s[0], s[1]))

    (run_t0, run_t1, _), = by_stage["run"]
    passes = by_stage[LOOP_STAGE]
    if not passes:
        sys.exit(f"no {LOOP_STAGE} spans")
    for (_, e, _), (s, _, _) in zip(passes, passes[1:]):
        if s < e - 1e-9:
            sys.exit("reference image passes overlap; the bins assume a serial loop")
    loop_t0, loop_t1 = passes[0][0], passes[-1][1]
    # The pass shares ("occupancy") leave out what lies between two reference image passes. That
    # is only honest while the loop has no work there (another method's upsampling or edge prior
    # would sit there).
    gap = sum(s - e for (_, e, _), (s, _, _) in zip(passes, passes[1:]))
    if gap > 0.05:
        sys.exit(f"{gap:.3f} s lie between reference image passes; these bins would not show them")

    round_spans = [(t0, t1) for t0, t1, _ in by_stage[ROUND_STAGE]]
    stages = {}
    for name, v in by_stage.items():
        # share of every reference image pass spent in this stage (two-pointer sweep)
        occ, j = [], 0
        for p0, p1, _ in passes:
            while j < len(v) and v[j][1] <= p0:
                j += 1
            k, inside = j, 0.0
            while k < len(v) and v[k][0] < p1:
                inside += overlap(v[k][0], v[k][1], p0, p1)
                k += 1
            occ.append(round(inside / (p1 - p0), 5) if p1 > p0 else 0.0)
        # spans (or their parts) before the first and after the last reference image pass
        outside = []
        for t0, t1, _ in v:
            for c0, c1 in ((t0, min(t1, loop_t0)), (max(t0, loop_t1), t1)):
                if c1 > c0:
                    outside.append([round(c0, 6), round(c1, 6)])
        in_loop = sum(overlap(t0, t1, loop_t0, loop_t1) for t0, t1, _ in v)
        round_s = [round(sum(overlap(t0, t1, r0, r1) for t0, t1, _ in v), 6) for r0, r1 in round_spans]
        if abs(sum(round_s) - in_loop) > 0.001:
            sys.exit(f"{name}: the rounds hold {sum(round_s):.3f} s of {in_loop:.3f} s inside the loop")
        drawn = sum(o * (p1 - p0) for o, (p0, p1, _) in zip(occ, passes))
        if abs(drawn - in_loop) > max(0.05, gap):
            sys.exit(f"{name}: the pass shares account for {drawn:.3f} s of {in_loop:.3f} s inside the loop")
        stages[name] = {
            "calls": len(v),
            "total_s": round(sum(t1 - t0 for t0, t1, _ in v), 6),
            "in_loop_s": round(in_loop, 6),
            "outside_calls": sum(1 for t0, t1, _ in v if t1 <= loop_t0 or t0 >= loop_t1),
            "outside_s": round(sum(c1 - c0 for c0, c1 in outside), 6),
            "first_s": round(v[0][1] - v[0][0], 6),
            # time of the stage inside each round, in the order of "rounds"
            "round_s": round_s,
            "outside": outside,
            "occupancy": occ,
        }

    rounds = [{"scale": int(attrs["scale"]), "t0": round(t0, 6), "t1": round(t1, 6)}
              for t0, t1, attrs in by_stage[ROUND_STAGE]]

    images = len({attrs.get("image") for _, _, attrs in passes})
    pass_groups = len({(attrs.get("pass"), attrs.get("iter")) for _, _, attrs in passes})
    if images * pass_groups != len(passes) or pass_groups % len(rounds):
        sys.exit(f"{len(passes)} reference image passes are not {images} images x {pass_groups} passes "
                 f"with the same number of passes in each of the {len(rounds)} rounds")

    out = {
        "meta": {
            "run": a.run,
            "source": source.name,
            "source_kind": "phases.txt" if a.phases else "span extract of phases.txt",
            "source_sha256": sha256(source),
            "generated_by": "generated/baseline-run/scripts/stage_timings.py",
            "context": read_context(a.context) if a.context else None,
        },
        # how the reference image passes are organised: images x passes over all images
        "images": images,
        "pass_groups": pass_groups,
        "run_s": round(run_t1 - run_t0, 6),
        "loop": {"t0": round(loop_t0, 6), "t1": round(loop_t1, 6)},
        "rounds": rounds,
        "passes": [[round(p0, 6), round(p1, 6)] for p0, p1, _ in passes],
        "stages": stages,
    }
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, separators=(",", ":")) + "\n")

    print(f"{a.run}: run {out['run_s']:.3f} s, {len(passes)} reference image passes, {len(rounds)} rounds")
    for name, s in sorted(stages.items(), key=lambda kv: -kv[1]["total_s"]):
        print(f"  {name:22s} {s['calls']:5d} x  {s['total_s']:10.3f} s  {100 * s['total_s'] / out['run_s']:6.2f} %"
              f"   outside loop {s['outside_s']:.3f} s")


if __name__ == "__main__":
    main()
