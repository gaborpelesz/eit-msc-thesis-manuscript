#!/usr/bin/env python3
"""Timeline of one run by pass, for the charts of chapters/figures/run-breakdown.typ.

The reconstruction loop of the run is a sequence of passes; one pass makes one reference image
pass for every image. This script reads the phase-timer spans of one run and writes, per pass:
its start and end, and the time of every stage of the thesis timing table (methodology,
table-timing-measurements) summed over the images of the pass. What a pass does not attribute to
a stage is written as `other_s`. Fusion and output writing follow as spans of their own. The
Typst figure reads that JSON and nothing else, so no number in the figure is typed by hand.

  --phases PATH           the run's phases.txt (primary source; lines
                          "PHASE <name> BEGIN|END <CLOCK_MONOTONIC ns> [key=value ...]";
                          `image_pass` lines carry image=, pass=, iter=; `scale` lines scale=)
  --context PATH          the run's context.txt (commit, GPU, profiler mode); optional
  --stage-timings PATH    the JSON of stage_timings.py (next to this script)
                          for the same run; optional. Nothing is read from it into the output:
                          the per-pass sums are checked against its stage totals.

Time zero is the BEGIN of the `run` span.

Run (from thesis/, standard library only; `make figures` does this when an input changed):

  python3 generated/baseline-run/scripts/pass_timeline.py \
      --phases generated/baseline-run/data/perf-nsys-r1/phases.txt \
      --context generated/baseline-run/data/perf-nsys-r1/context.txt \
      --stage-timings generated/baseline-run/derived/perf-nsys-r1/stage-timings.json \
      --run perf-nsys-r1 \
      --out generated/baseline-run/derived/perf-nsys-r1/pass-timeline.json
"""
import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

from run_files import read_context, read_phases, sha256

LOOP_STAGE = "image_pass"   # one span per reference image pass
ROUND_STAGE = "scale"       # one span per round (APD-MVS) or pyramid level (ACM family)
# Stages that are timed inside a reference image pass and do not contain one another. Their
# durations can be added; the rest of the pass is "other".
LEAF_STAGES = (
    "input_load", "device_upload", "prior_build", "patchmatch.init", "patchmatch.propagate",
    "patchmatch.finalize", "patchmatch.readback", "result_readback",
)
# Stages that enclose leaf stages inside a reference image pass. Not added.
ENCLOSING_STAGES = ("patchmatch",)
# Spans after the loop, drawn as rows of their own, with the stages they contain.
TAIL = (("fusion", ("fusion.load", "fusion.consistency")), ("output_write", ()))
EPS = 1e-9


def r6(x):
    return round(x, 6)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--phases", required=True)
    ap.add_argument("--context", help="the run's context.txt (optional)")
    ap.add_argument("--stage-timings", help="stage-timings JSON of the same run, to check the sums against (optional)")
    ap.add_argument("--run", required=True, help="run tag, recorded in the JSON")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    source = Path(a.phases)
    by_stage = defaultdict(list)
    for name, t0, t1, attrs in read_phases(source):
        if t1 < t0:
            sys.exit(f"negative span {name} {t0} {t1}")
        by_stage[name].append((t0, t1, attrs))
    for v in by_stage.values():
        v.sort(key=lambda s: (s[0], s[1]))

    (run_t0, run_t1, _), = by_stage["run"]
    image_passes = by_stage[LOOP_STAGE]
    if not image_passes:
        sys.exit(f"no {LOOP_STAGE} spans")
    for (_, e, _), (s, _, _) in zip(image_passes, image_passes[1:]):
        if s < e - EPS:
            sys.exit("reference image passes overlap; the sums assume a serial loop")
    loop_t0, loop_t1 = image_passes[0][0], image_passes[-1][1]

    # ---- passes: runs of consecutive reference image passes with the same pass= and iter= -----
    passes = []
    for t0, t1, attrs in image_passes:
        key = (attrs.get("pass"), attrs.get("iter"))
        if None in key or "image" not in attrs:
            sys.exit(f"{LOOP_STAGE} span at {t0:.3f} s lacks image=, pass= or iter=")
        if not passes or passes[-1]["key"] != key:
            passes.append({"key": key, "spans": []})
        passes[-1]["spans"].append((t0, t1, attrs["image"]))
    if len({p["key"] for p in passes}) != len(passes):
        sys.exit("a pass is interrupted by another pass; a bar from its start to its end would cover both")
    image_set = {img for _, _, img in passes[0]["spans"]}
    for p in passes:
        imgs = [img for _, _, img in p["spans"]]
        if len(imgs) != len(set(imgs)) or set(imgs) != image_set:
            sys.exit(f"pass {p['key']} does not go through every image exactly once")

    # ---- rounds ------------------------------------------------------------------------------
    rounds = [{"scale": int(attrs["scale"]), "t0": t0, "t1": t1, "passes": []}
              for t0, t1, attrs in by_stage[ROUND_STAGE]]
    if not rounds:
        sys.exit(f"no {ROUND_STAGE} spans")
    for i, p in enumerate(passes):
        p["t0"], p["t1"] = p["spans"][0][0], p["spans"][-1][1]
        home = [k for k, rd in enumerate(rounds) if rd["t0"] - EPS <= p["t0"] and p["t1"] <= rd["t1"] + EPS]
        if len(home) != 1:
            sys.exit(f"pass {p['key']} lies in {len(home)} rounds")
        p["round"] = home[0]
        rounds[home[0]]["passes"].append(i)
    if len({len(rd["passes"]) for rd in rounds}) != 1:
        sys.exit("the rounds do not hold the same number of passes")

    # ---- stage time per pass -------------------------------------------------------------------
    inside = set(LEAF_STAGES) | set(ENCLOSING_STAGES)
    tail_names = {n for name, parts in TAIL for n in (name, *parts)}
    for name, v in by_stage.items():
        if name in inside or name in tail_names or name in ("run", LOOP_STAGE, ROUND_STAGE):
            continue
        # a stage this script does not know must not hide in "other"
        if any(t1 > loop_t0 + EPS and t0 < loop_t1 - EPS for t0, t1, _ in v):
            sys.exit(f"stage {name!r} runs inside the reconstruction loop and is not handled here")

    for p in passes:
        p["stage_s"] = dict.fromkeys(LEAF_STAGES, 0.0)
        p["stage_calls"] = dict.fromkeys(LEAF_STAGES, 0)
    # leaf spans in time order, each assigned to the reference image pass that contains it
    leaves = sorted((t0, t1, name) for name in LEAF_STAGES for t0, t1, _ in by_stage.get(name, ()))
    flat = [(t0, t1, i) for i, p in enumerate(passes) for t0, t1, _ in p["spans"]]
    before_loop = defaultdict(float)
    first_in_loop = {}
    j, last_end = 0, None
    for t0, t1, name in leaves:
        if last_end is not None and t0 < last_end - EPS:
            sys.exit(f"{name} at {t0:.6f} s overlaps the stage before it; the durations could not be added")
        last_end = t1
        if t1 <= loop_t0 + EPS:
            before_loop[name] += t1 - t0
            continue
        while j < len(flat) and flat[j][1] < t0 - EPS:
            j += 1
        if j == len(flat) or not (flat[j][0] - EPS <= t0 and t1 <= flat[j][1] + EPS):
            sys.exit(f"{name} at {t0:.6f} s is not inside a reference image pass")
        p = passes[flat[j][2]]
        first_in_loop.setdefault(name, t1 - t0)
        p["stage_s"][name] += t1 - t0
        p["stage_calls"][name] += 1
    for name in ENCLOSING_STAGES:
        for t0, t1, _ in by_stage.get(name, ()):
            if not any(f0 - EPS <= t0 and t1 <= f1 + EPS for f0, f1, _ in flat):
                sys.exit(f"{name} at {t0:.6f} s is not inside a reference image pass")

    out_passes = []
    for i, p in enumerate(passes):
        span = p["t1"] - p["t0"]
        attributed = sum(p["stage_s"].values())
        between = sum(s - e for (_, e, _), (s, _, _) in zip(p["spans"], p["spans"][1:]))
        other = span - attributed
        if other < -1e-6:
            sys.exit(f"pass {p['key']}: the stages sum to more than the pass")
        out_passes.append({
            "n": i + 1,                       # running number of the pass in the run
            "kind": p["key"][0],              # the method's name for the pass type
            "iter": int(p["key"][1]),         # the method's pass counter
            "round": p["round"],              # index into rounds
            "t0": r6(p["t0"]), "t1": r6(p["t1"]), "span_s": r6(span),
            "images": len(p["spans"]),
            "stage_s": {k: r6(v) for k, v in p["stage_s"].items()},
            "stage_calls": p["stage_calls"],
            # the pass minus the stages above: time inside the reference image passes that no
            # leaf stage covers, plus the time between two reference image passes
            "other_s": r6(max(0.0, other)),
            "between_images_s": r6(between),
        })

    # ---- spans after the loop --------------------------------------------------------------------
    tail = []
    for name, parts in TAIL:
        if len(by_stage.get(name, ())) != 1:
            sys.exit(f"expected exactly one {name} span")
        (t0, t1, _), = by_stage[name]
        if t0 < loop_t1 - EPS:
            sys.exit(f"{name} starts inside the reconstruction loop")
        stage_s = {}
        for part in parts:
            inner = by_stage.get(part, ())
            if any(not (t0 - EPS <= s and e <= t1 + EPS) for s, e, _ in inner):
                sys.exit(f"{part} is not inside {name}")
            stage_s[part] = r6(sum(e - s for s, e, _ in inner))
        tail.append({"key": name, "t0": r6(t0), "t1": r6(t1), "span_s": r6(t1 - t0), "stage_s": stage_s,
                     "other_s": r6(max(0.0, t1 - t0 - sum(stage_s.values())))})

    # ---- the whole run must be accounted for ---------------------------------------------------
    gaps_between_passes = sum(q["t0"] - p["t1"] for p, q in zip(passes, passes[1:]))
    covered = sum(p["t1"] - p["t0"] for p in passes) + sum(t["span_s"] for t in tail)
    not_drawn = (run_t1 - run_t0) - covered
    totals = {k: r6(sum(p["stage_s"][k] for p in passes)) for k in LEAF_STAGES}
    for k in LEAF_STAGES:
        whole = sum(t1 - t0 for t0, t1, _ in by_stage.get(k, ()))
        if abs(whole - totals[k] - before_loop.get(k, 0.0)) > 1e-6:
            sys.exit(f"{k}: {whole:.6f} s in the run, {totals[k]:.6f} s in the passes")

    if a.stage_timings:
        ref = json.loads(Path(a.stage_timings).read_text())
        if ref["meta"]["source_sha256"] != sha256(source):
            sys.exit(f"{a.stage_timings} was made from another phases.txt")
        for k in LEAF_STAGES:
            if abs(ref["stages"][k]["in_loop_s"] - totals[k]) > 2e-6:
                sys.exit(f"{k}: {totals[k]} s in the passes, {ref['stages'][k]['in_loop_s']} s in {a.stage_timings}")
        if abs(ref["run_s"] - (run_t1 - run_t0)) > 2e-6 or len(ref["passes"]) != len(image_passes):
            sys.exit(f"run span or number of reference image passes differ from {a.stage_timings}")
        print(f"stage totals agree with {a.stage_timings}")

    out = {
        "meta": {
            "run": a.run,
            "source": source.name,
            "source_kind": "phases.txt",
            "source_sha256": sha256(source),
            "generated_by": "generated/baseline-run/scripts/pass_timeline.py",
            "context": read_context(a.context) if a.context else None,
        },
        "run_s": r6(run_t1 - run_t0),
        "images": len(image_set),
        "loop": {"t0": r6(loop_t0), "t1": r6(loop_t1)},
        "leaf_stages": list(LEAF_STAGES),
        "rounds": [{"scale": rd["scale"], "t0": r6(rd["t0"]), "t1": r6(rd["t1"]),
                    "span_s": r6(rd["t1"] - rd["t0"]), "passes": rd["passes"]} for rd in rounds],
        "passes": out_passes,
        "tail": tail,
        # stage time summed over all passes, and what the leaf stages take before the loop
        "stage_total_s": totals,
        "before_loop_s": {k: r6(v) for k, v in sorted(before_loop.items())},
        # duration of the first span of every stage inside the loop (the first device upload
        # holds the method's first CUDA call)
        "first_span_s": {k: r6(first_in_loop[k]) for k in LEAF_STAGES if k in first_in_loop},
        # run time that no row of the figure covers: setup before the first pass, the time
        # between passes, between the loop and fusion, between fusion and output, and teardown
        "not_drawn_s": r6(not_drawn),
        "between_passes_s": r6(gaps_between_passes),
    }
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, separators=(",", ":")) + "\n")

    print(f"{a.run}: run {out['run_s']:.3f} s, {len(passes)} passes x {out['images']} images, {len(rounds)} rounds,"
          f" {not_drawn:.3f} s outside the rows")
    head = "".join(f"{k.split('.')[-1][:9]:>10s}" for k in LEAF_STAGES)
    print(f"  {'pass':18s}{'start':>8s}{'end':>8s}{head}{'other':>10s}")
    for p in out_passes:
        cells = "".join(f"{p['stage_s'][k]:10.2f}" for k in LEAF_STAGES)
        print(f"  {p['n']:2d} {p['kind']:15s}{p['t0']:8.1f}{p['t1']:8.1f}{cells}{p['other_s']:10.2f}")
    for t in tail:
        print(f"  {t['key']:18s}{t['t0']:8.1f}{t['t1']:8.1f}   {t['stage_s']}")


if __name__ == "__main__":
    main()
