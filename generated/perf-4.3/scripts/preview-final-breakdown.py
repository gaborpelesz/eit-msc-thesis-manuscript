#!/usr/bin/env python3
"""PREVIEW ONLY (not the M6 step-4 breakdown): run time by stage, fixed base (base2) against the
final stack, ETH3D pipes at native resolution, plain seeded analysis runs.

Reads the phases.txt, context.txt and manifest of existing run directories (no GPU work) and writes
  data/preview-final-breakdown.csv         one row per stage, the two groups and the run
  data/preview-final-breakdown-runs.csv    every run looked at, its per-stage seconds, used or why not
  data/preview-final-breakdown-phases.csv  the timer names of both arms: in both, new or vanished
The figure chapters/figures/preview-final-breakdown.typ reads these three files.

usage: python3 -B preview-final-breakdown.py   (from anywhere; paths are fixed below)
"""
import csv
import statistics as st
from collections import defaultdict
from pathlib import Path

RUNS = Path.home() / "thesis-data/bench/diag/production-apd-mvs"
DATA = Path(__file__).resolve().parent.parent / "data"
MANIFEST = RUNS / "s43-m6-manifest.tsv"

# src: perf43_json.py:164-173 (BREAKDOWN_STAGES), the stages of <fig-perf-baseline-breakdown>
STAGES = [  # key, phases summed, class
    ("propagation", ["patchmatch.propagate", "prior_build"], "kernel"),
    ("initialization", ["patchmatch.init"], "kernel"),
    ("finalization", ["patchmatch.finalize"], "kernel"),
    ("input_load", ["input_load"], "host"),
    ("fusion", ["fusion"], "host"),
    ("device_upload", ["device_upload"], "copy"),
    ("result_readback", ["result_readback"], "copy"),
    ("patchmatch.readback", ["patchmatch.readback"], "copy"),
]
KERNEL_PHASES = ["patchmatch.init", "patchmatch.propagate", "prior_build", "patchmatch.finalize"]  # src: perf43_json.py:105
DRAWN = [p for _, ph, _ in STAGES for p in ph]

BASE_IMAGE = "production-apd-mvs:s43-base2-6c1f7b1"
STACK_IMAGE = "production-apd-mvs:s43-stack-c20e935"
# base2: one plain native run per seed 1-10; seed 1 from the M6 session (same session as the stack runs)
BASE_USED = ["s43-m6-base2-native-s1"] + [f"s43-base2-native-s{k}" for k in range(2, 11)]
BASE_EXCLUDED = {
    "s43-base2-native-s1": "seed 1 already taken from the M6 session (s43-m6-base2-native-s1)",
    "s43-base2-native-s1-rep2": "seed 1 already taken from the M6 session (s43-m6-base2-native-s1)",
    "s43-input-timers2-native-s1": "instrumented build d9d1bf2 (extra sub-timers), the run behind breakdown-base2.csv; not a plain base2 run",
}


def phases_txt(path):
    """Total seconds and calls per phase, and the intervals of every phase.  src: perf43_json.py:146-160"""
    begin, total, calls, iv = defaultdict(list), defaultdict(float), defaultdict(int), defaultdict(list)
    for line in Path(path).read_text().splitlines():
        p = line.split()
        if len(p) < 4 or p[0] != "PHASE":
            continue
        if p[2] == "BEGIN":
            begin[p[1]].append(int(p[3]))
        else:
            b = begin[p[1]].pop()
            total[p[1]] += (int(p[3]) - b) / 1e9
            calls[p[1]] += 1
            iv[p[1]].append((b, int(p[3])))
    assert not any(begin.values()), f"{path}: unclosed phases {[k for k, v in begin.items() if v]}"
    assert calls["run"] == 1, f"{path}: {calls['run']} run phases"
    return dict(total), dict(calls), iv


def context(tag):
    c = {}
    for line in (RUNS / tag / "context.txt").read_text().splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            c.setdefault(k, v)
    return c


def check_run(tag, image, seed):
    c = context(tag)
    assert c["image"].endswith(f"({image})"), f"{tag}: image {c['image']}"
    assert c["mode"] == "plain", f"{tag}: mode {c['mode']}"
    assert c["app_env"] == f"APD_SEED={seed}", f"{tag}: env {c['app_env']}"
    assert "--max-image-size=8192" in c["app_args"], f"{tag}: not native"
    assert "SCENE" not in c["app_env"]  # pipes only
    assert (RUNS / tag / "exit_code").read_text().strip() == "0", f"{tag}: exit code"
    return c


def no_overlap(iv, tag):
    """The drawn stages are disjoint in time, so their sum is not double counted."""
    spans = sorted((a, b, k) for k in DRAWN for a, b in iv.get(k, []))
    for (a0, b0, k0), (a1, b1, k1) in zip(spans, spans[1:]):
        assert a1 >= b0, f"{tag}: {k0} and {k1} overlap"


def where(p, iv):
    """The drawn stage whose intervals hold every call of timer p; 'other' if it lies outside all of
    them; 'parent' if it holds drawn stages itself (run, scale, image_pass, patchmatch, ...)."""
    stage_of = {ph: k for k, phs, _ in STAGES for ph in phs}
    spans = [(a, b, stage_of[k]) for k in DRAWN for a, b in iv.get(k, [])]
    found = set()
    for a, b in iv[p]:
        inside = [s for a0, b0, s in spans if a0 <= a and b <= b0]
        if inside:
            found.add(inside[0])
        elif any(a <= a0 and b0 <= b for a0, b0, _ in spans):
            found.add("parent")
        else:
            found.add("other")
    assert len(found) == 1, f"{p}: {found}"
    return found.pop()


def stage_seconds(tot):
    s = {key: sum(tot.get(p, 0.0) for p in ph) for key, ph, _ in STAGES}
    s["other"] = tot["run"] - sum(tot.get(p, 0.0) for p in DRAWN)
    s["kernel"] = sum(tot.get(p, 0.0) for p in KERNEL_PHASES)
    s["host"] = tot["run"] - s["kernel"]
    s["run"] = tot["run"]
    return s


def stack_tags():
    """Final-stack native pipes runs from the manifest, exit code 0, in seed order."""
    rows = list(csv.DictReader(MANIFEST.open(), delimiter="\t"))
    tags = sorted({r["tag"] for r in rows if r["tag"].startswith("s43-m6-stack-native-s") and r["image"] == STACK_IMAGE
                   and r["exit_code"] == "0" and r["maxsize"] == "8192"}, key=lambda t: int(t.rsplit("-s", 1)[1]))
    return tags


def main():
    looked = []  # (arm, tag, seed, image, used, reason)
    for t in BASE_USED:
        looked.append(("base2", t, int(t.rsplit("-s", 1)[1]), BASE_IMAGE, True, ""))
    for t, why in BASE_EXCLUDED.items():
        img = "production-apd-mvs:s43-input-timers2-d9d1bf2" if "timers2" in t else BASE_IMAGE
        looked.append(("base2", t, 1, img, False, why))
    for t in stack_tags():
        looked.append(("final", t, int(t.rsplit("-s", 1)[1]), STACK_IMAGE, True, ""))

    per = {}      # tag -> stage seconds
    names = {}    # tag -> set of timer names
    ivs = {}      # tag -> intervals per timer
    totals = {}   # tag -> phase totals
    for arm, t, seed, img, used, _ in looked:
        check_run(t, img, seed)
        tot, calls, iv = phases_txt(RUNS / t / "phases.txt")
        no_overlap(iv, t)
        per[t], names[t], totals[t], ivs[t] = stage_seconds(tot), set(tot), tot, iv
        assert abs(sum(per[t][k] for k, _, _ in STAGES) + per[t]["other"] - tot["run"]) < 1e-9

    used = {a: [t for arm, t, _, _, u, _ in looked if arm == a and u] for a in ("base2", "final")}
    assert len(used["base2"]) == 10 and len(set(s for arm, t, s, _, u, _ in looked if arm == "base2" and u)) == 10
    assert len(used["final"]) >= 2, used["final"]
    pair = ("s43-m6-base2-native-s1", "s43-m6-stack-native-s1")  # same session, same seed

    def stat(arm, key):
        x = [per[t][key] for t in used[arm]]
        return st.mean(x), (st.stdev(x) if len(x) > 1 else float("nan")), len(x)

    keys = [(k, c) for k, _, c in STAGES] + [("other", "other"), ("kernel", "group"), ("host", "group"), ("run", "total")]
    with (DATA / "preview-final-breakdown.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["key", "class", "phases", "base2_n", "base2_mean_s", "base2_sd_s", "final_n", "final_mean_s", "final_sd_s",
                    "delta_s", "base2_share", "final_share", "pair_base2_s", "pair_final_s", "pair_delta_s"])
        rb, rf = stat("base2", "run")[0], stat("final", "run")[0]
        ph = {k: " ".join(p) for k, p, _ in STAGES}
        for k, c in keys:
            (mb, sb, nb), (mf, sf, nf) = stat("base2", k), stat("final", k)
            pb, pf = per[pair[0]][k], per[pair[1]][k]
            w.writerow([k, c, ph.get(k, ""), nb, f"{mb:.4f}", f"{sb:.4f}", nf, f"{mf:.4f}", f"{sf:.4f}", f"{mf - mb:.4f}",
                        f"{mb / rb:.6f}", f"{mf / rf:.6f}", f"{pb:.4f}", f"{pf:.4f}", f"{pf - pb:.4f}"])

    with (DATA / "preview-final-breakdown-runs.csv").open("w", newline="") as f:
        w = csv.writer(f)
        cols = [k for k, _ in keys]
        w.writerow(["arm", "tag", "seed", "image", "used", "reason", *[f"{k}_s" for k in cols]])
        for arm, t, seed, img, u, why in looked:
            w.writerow([arm, t, seed, img, "yes" if u else "no", why, *[f"{per[t][k]:.4f}" for k in cols]])

    # timer names: in every used run of both arms, only in one arm (new / vanished)
    nb = set.intersection(*(names[t] for t in used["base2"]))
    nf = set.intersection(*(names[t] for t in used["final"]))
    with (DATA / "preview-final-breakdown-phases.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["phase", "status", "drawn_in", "base2_mean_s", "final_mean_s"])
        for p in sorted(nb | nf):
            status = "both" if p in nb and p in nf else ("new" if p in nf else "vanished")
            drawn = next((k for k, ph, _ in STAGES if p in ph), "") or where(p, ivs[used["final" if p in nf else "base2"][0]])
            mb = st.mean(totals[t].get(p, 0.0) for t in used["base2"])
            mf = st.mean(totals[t].get(p, 0.0) for t in used["final"])
            w.writerow([p, status, drawn, f"{mb:.4f}", f"{mf:.4f}"])

    for k, _ in keys:
        (mb, sb, n1), (mf, sf, n2) = stat("base2", k), stat("final", k)
        print(f"{k:22s} {mb:8.2f} ±{sb:5.2f} (n={n1})  {mf:8.2f} ±{sf:5.2f} (n={n2})  {mf - mb:+8.2f}  {100 * mf / rf:5.1f} %")
    print("final runs:", " ".join(used["final"]))
    print("new:", sorted(nf - nb), "vanished:", sorted(nb - nf))


if __name__ == "__main__":
    main()
