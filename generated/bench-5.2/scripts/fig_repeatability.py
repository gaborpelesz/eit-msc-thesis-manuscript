# /// script
# requires-python = ">=3.12"
# dependencies = ["matplotlib==3.10.*", "numpy==2.*"]
# ///
"""Appendix figure: half-width of the 95 % confidence interval of each cell (arm and scene, 5
repeats), relative to the cell mean, for the run time and for F1 at 2 cm, with the 1 % line of
the dimensioning. Every value from derived/numbers-bench.json."""
import numpy as np

import style as S

S.setup()
v = S.load()
r, colour, marker = S.reg(v)
cells = v["rep"]["cells_list"]
cols = [a for a in r["order"] if any(c["arm"] == a for c in cells)]
fig, axes = S.plt.subplots(1, 2, figsize=(S.TEXT_W, 2.5), sharey=False, gridspec_kw=dict(wspace=0.25))
rng = np.random.default_rng(1)
for ax, key, title, le in ((axes[0], "wall_hw_pct", "(a) Run time", v["rep"]["wall_le1"]),
                           (axes[1], "f1_hw_pct", "(b) F1 at 2 cm", v["rep"]["f1_le1"])):
    for j, a in enumerate(cols):
        x = np.array([c[key] for c in cells if c["arm"] == a])
        ax.scatter(j + (rng.random(len(x)) - 0.5) * 0.4, x, s=9, marker=marker(a), facecolor=colour(a), edgecolor="white", lw=0.3, zorder=3)
    ax.axhline(1, color=S.RED, lw=0.8)
    ax.set_xticks(range(len(cols)), [r["labels"][a] for a in cols], rotation=40, ha="right", fontsize=6.5)
    ax.set_ylim(0, 3.4)
    ax.set_yticks([0, 1, 2, 3], ["0", "1%", "2%", "3%"])
    ax.grid(True, axis="y")
    ax.set_title(f"{title}: {le} of {v['rep']['cells']} cells within 1%", loc="left")
axes[0].set_ylabel("95% CI half-width / cell mean")
S.save(fig, "bench-repeatability")
