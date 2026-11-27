# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.*", "scipy==1.*"]
# ///
"""Test statistics of the dimensioning run: lag-1 autocorrelation and drift per cell, for wall time and F1 at 2 cm.

Reads ../data/runs-dev0.csv (the dimensioning run on one machine); writes
../derived/run-statistics.json, which chapters/figures/dimensioning-run-statistics.typ draws.
Run: `make figures` from the thesis root, or `uv run scripts/dimensioning_run_statistics.py`.
"""
import csv
import json
import math
from collections import defaultdict
from pathlib import Path

import numpy as np
from scipy import stats

HERE = Path(__file__).resolve().parent.parent
SOURCE = HERE / "data" / "runs-dev0.csv"
OUT = HERE / "derived" / "run-statistics.json"
METHODS = ["ACMH", "ACMM", "ACMP", "ACMMP", "MP-MVS", "HPM-MVS", "HPM-MVS_plusplus", "APD-MVS", "DPE-MVS", "CUMVS"]
SCENES = ["pipes", "meadow", "office"]
LABEL = {"HPM-MVS_plusplus": "HPM-MVS++", "CUMVS": "CUMVS†"}
# column of the CSV, key in the JSON, unit of the drift
QUANT = [("wall_time_s", "wall", "%"), ("f1_primary", "f1", "pp")]


def load():
    cells = defaultdict(list)
    for r in csv.DictReader(open(SOURCE)):
        if r["status"] == "ok":
            cells[(r["method"], r["scene"])].append(r)
    for v in cells.values():
        v.sort(key=lambda r: r["started_at"])
    keys = [(m, s) for m in METHODS for s in SCENES if (m, s) in cells]
    return cells, keys


def deviation(rows, col):
    """Wall time in percent of the cell median; F1 in percentage points from the cell median."""
    x = np.array([float(r[col]) for r in rows])
    med = np.median(x)
    return (x / med - 1) * 100 if col == "wall_time_s" else (x - med) * 100


def tests(d):
    """Lag-1 autocorrelation with its ±2/√n band, and drift b·(n−1) with its 95 % half-width."""
    n = len(d)
    z = d - d.mean()
    r1 = float(np.sum(z[:-1] * z[1:]) / np.sum(z * z))
    band = 2 / math.sqrt(n)
    lr = stats.linregress(np.arange(n), d)
    drift = float(lr.slope * (n - 1))
    half = float(stats.t.ppf(0.975, n - 2) * lr.stderr * (n - 1))
    return {"n": n, "r1": r1, "band": band, "r1_fails": abs(r1) > band,
            "drift": drift, "half": half, "drift_fails": abs(drift) > half}


def main():
    cells, keys = load()
    rows = [{"method": m, "scene": s, "label": LABEL.get(m, m),
             **{key: tests(deviation(cells[(m, s)], col)) for col, key, _ in QUANT}}
            for m, s in keys]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"source": SOURCE.name, "units": {key: u for _, key, u in QUANT},
                               "scenes": SCENES, "rows": rows}, indent=1))
    flagged = [(f"{r['label']} · {r['scene']}", key, test)
               for _, key, _ in QUANT for r in rows
               for test in ("r1", "drift") if r[key][f"{test}_fails"]]
    print(f"{len(rows)} cells, {len(flagged)} of {4 * len(rows)} tests flagged:")
    for f in flagged:
        print("  ", *f)


if __name__ == "__main__":
    main()
