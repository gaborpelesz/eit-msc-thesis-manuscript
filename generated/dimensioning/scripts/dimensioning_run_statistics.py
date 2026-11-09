# /// script
# requires-python = ">=3.12"
# dependencies = ["matplotlib==3.10.*", "numpy==2.*", "scipy==1.*"]
# ///
"""Test-statistics figure: lag-1 autocorrelation and drift per cell, for wall time and F1 at 2 cm.

Reads ../data/runs-<run>.csv (the dimensioning run ran on a machine); writes ../../figures/dimensioning_run_statistics.png.
Run: `make figures` from the thesis root, or `uv run scripts/dimensioning_run_statistics.py`.
"""
import csv
import math
from collections import defaultdict
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D
from scipy import stats

HERE = Path(__file__).resolve().parent.parent
SOURCE = HERE / "data" / "runs-dev0.csv"
OUT = HERE.parent / "figures"
METHODS = ["ACMH", "ACMM", "ACMP", "ACMMP", "MP-MVS", "HPM-MVS", "HPM-MVS_plusplus", "APD-MVS", "DPE-MVS", "CUMVS"]
SCENES = ["pipes", "meadow", "office"]
LABEL = {"HPM-MVS_plusplus": "HPM-MVS++", "CUMVS": "CUMVS†"}
QUANT = [("wall_time_s", "wall time", "%"), ("f1_primary", "F1 at 2 cm", "pp")]

plt.rcParams.update({"font.size": 8, "axes.titlesize": 8, "axes.labelsize": 8,
                     "xtick.labelsize": 7, "ytick.labelsize": 7, "legend.fontsize": 7,
                     "axes.spines.top": False, "axes.spines.right": False,
                     "savefig.dpi": 300})
MUTED, GRID = "#6b6b6b", "#dddddd"
PASS, FLAG, BAR = "#2a6fdb", "#d9480f", "#9db8e8"
TEXT_W = 6.3  # inches, ELTE template text width (approx.)


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
    x = np.array([float(r[col]) for r in rows])
    med = np.median(x)
    return (x / med - 1) * 100 if col == "wall_time_s" else (x - med) * 100


def tests(d):
    """Lag-1 autocorrelation with its ±2/√n band, and drift b·(n−1) with its 95 % half-width."""
    n = len(d)
    z = d - d.mean()
    r1 = float(np.sum(z[:-1] * z[1:]) / np.sum(z * z))
    lr = stats.linregress(np.arange(n), d)
    half = stats.t.ppf(0.975, n - 2) * lr.stderr * (n - 1)
    return r1, 2 / math.sqrt(n), lr.slope * (n - 1), half


def main():
    cells, keys = load()
    res = {col: np.array([tests(deviation(cells[k], col)) for k in keys]) for col, *_ in QUANT}
    ys = np.arange(len(keys))
    fig, axes = plt.subplots(1, 4, figsize=(TEXT_W, 5.2), sharey=True, constrained_layout=True)
    for j, (col, title, unit) in enumerate(QUANT):
        r1, band, drift, half = res[col].T
        ax = axes[2 * j]
        ax.fill_betweenx(ys, -band, band, step="mid", color="#e8e8e8", lw=0)
        out = np.abs(r1) > band
        ax.scatter(r1[~out], ys[~out], s=12, color=PASS, zorder=3)
        ax.scatter(r1[out], ys[out], s=12, color=FLAG, marker="D", zorder=3)
        ax.axvline(0, color=MUTED, lw=0.6)
        ax.set_xlim(-0.8, 0.8)
        ax.set_title(f"{title}\nlag-1 autocorrelation", loc="left")
        ax.set_xlabel("r₁ (grey: ±2/√n)")
        ax = axes[2 * j + 1]
        sig = np.abs(drift) > half
        ax.errorbar(drift, ys, xerr=half, fmt="none", ecolor=BAR, elinewidth=1.2, zorder=2)
        ax.scatter(drift[~sig], ys[~sig], s=12, color=PASS, zorder=3)
        ax.scatter(drift[sig], ys[sig], s=12, color=FLAG, marker="D", zorder=3)
        ax.axvline(0, color=MUTED, lw=0.6)
        ax.set_title(f"{title}\ndrift over the series", loc="left")
        ax.set_xlabel(unit)
    axes[0].set_yticks(ys, [f"{LABEL.get(m, m)} · {s}" for m, s in keys])
    axes[0].set_ylim(len(keys) - 0.5, -0.5)
    for ax in axes:
        for y in range(3, len(keys), 3):
            ax.axhline(y - 0.5, color=GRID, lw=0.6)
        ax.tick_params(left=False)
    flag = Line2D([], [], color=FLAG, marker="D", markersize=4, linestyle="none")
    blank = Line2D([], [], linestyle="none")
    fig.legend([flag, blank, blank],
               [": fails the test", "   autocorrelation: outside the ±2/√n band",
                "   drift: interval excludes 0 % or 0 pp"],
               loc="upper right", bbox_to_anchor=(0.995, 0.0), frameon=False, handlelength=0.8,
               handletextpad=0.3, labelspacing=0.2, borderaxespad=0, labelcolor=MUTED)
    OUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT / "dimensioning_run_statistics.png", bbox_inches="tight")
    flagged = [(f"{LABEL.get(k[0], k[0])} · {k[1]}", col, test)
               for col, *_ in QUANT for i, k in enumerate(keys)
               for test, bad in (("r1", abs(res[col][i, 0]) > res[col][i, 1]),
                                 ("drift", abs(res[col][i, 2]) > res[col][i, 3])) if bad]
    print(f"{len(keys)} cells, {len(flagged)} of {4 * len(keys)} tests flagged:")
    for f in flagged:
        print("  ", *f)


if __name__ == "__main__":
    main()
