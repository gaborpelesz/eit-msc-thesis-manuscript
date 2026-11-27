# /// script
# requires-python = ">=3.12"
# dependencies = ["matplotlib==3.10.*", "numpy==2.*"]
# ///
"""Figure B: F1 at 2 cm per scene and arm (mean of 5 repeats), as a heat map with the values
printed. Rows: scenes from the hardest (lowest mean F1 over the arms that completed all scenes)
to the easiest. Columns: arms in registry order, the capped group first. A scene an arm failed
is hatched. Every value from derived/numbers-bench.json."""
import numpy as np
from matplotlib.colors import LinearSegmentedColormap

import style as S

S.setup()
v = S.load()
r, colour, marker = S.reg(v)
F, C = v["arms"], v["arms_common"]
cols = [a for a in r["order"] if (a in F and not F[a]["reserved"]) or a in C]
rows = v["scene_order"]


def f1(a, s):
    blk = F.get(a) if a in F and not F[a]["reserved"] else None
    if blk is None:
        blk = C.get(a)
        if a in C and s not in v["common_scenes"]:
            return np.nan
        return C[a]["scene_f1"].get(s, np.nan) if a in C else np.nan
    return blk["scene_f1"][s]


M = np.array([[f1(a, s) for a in cols] for s in rows])
lo, hi = np.nanmin(M), np.nanmax(M)
cmap = LinearSegmentedColormap.from_list("blues", ["#f7fbff", "#c6dbef", "#6baed6", "#2171b5", "#08306b"])
fig, ax = S.plt.subplots(figsize=(S.TEXT_W, 3.9))
im = ax.imshow(np.ma.masked_invalid(M), cmap=cmap, vmin=lo, vmax=hi, aspect="auto")
for i, s in enumerate(rows):
    best = np.nanargmax(M[i])
    for j, a in enumerate(cols):
        x = M[i, j]
        if np.isnan(x):
            ax.add_patch(S.plt.Rectangle((j - 0.5, i - 0.5), 1, 1, fill=False, hatch="////",
                                         edgecolor=S.GREYS[2], linewidth=0))
            continue
        t = (x - lo) / (hi - lo)
        ax.text(j, i, f"{x:.3f}", ha="center", va="center", fontsize=6.5,
                color="white" if t > 0.55 else S.INK, fontweight="bold" if j == best else "normal")
ax.set_xticks(range(len(cols)), [r["labels"][a] for a in cols], rotation=30, ha="right")
ax.set_yticks(range(len(rows)), [f"{s} ({v['n_images'][s]})" for s in rows])
ax.tick_params(length=0)
for sp in ax.spines.values():
    sp.set_visible(False)
# a gap line between the capped and the native group
ncap = sum(1 for a in cols if a.endswith("3200-capped"))
ax.axvline(ncap - 0.5, color="white", lw=3)
cb = fig.colorbar(im, ax=ax, fraction=0.03, pad=0.015)
cb.set_label("F1 at 2 cm")
cb.outline.set_visible(False)
cb.ax.tick_params(length=2)
S.save(fig, "bench-scenes")
