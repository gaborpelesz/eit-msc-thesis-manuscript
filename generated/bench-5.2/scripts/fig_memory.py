# /// script
# requires-python = ">=3.12"
# dependencies = ["matplotlib==3.10.*", "numpy==2.*"]
# ///
"""Figure D: peak device memory per scene (mean of the repeats of a cell) for every arm, against
the 12 GB card. The failed HPM-MVS++ cells are drawn at the device memory held at the crash.
Every value from derived/numbers-bench.json. The reserved CUMVS(APD) columns are empty,
labelled slots until their runs are in the data."""
import numpy as np

import style as S

S.setup()
v = S.load()
r, colour, marker = S.reg(v)
F, C = v["arms"], v["arms_common"]
cols = r["order"]
card = v["card_mib"]

fig, ax = S.plt.subplots(figsize=(S.TEXT_W, 2.7))
ax.axhline(card, color=S.RED, lw=0.9)
ax.text(len(cols) - 0.5, card + 150, f"device memory of the card, {v['card_mib']:,} MiB".replace(",", " "),
        ha="right", va="bottom", fontsize=6.5, color=S.RED)
rng = np.random.default_rng(0)
for j, a in enumerate(cols):
    b = F[a] if a in F and not F[a]["reserved"] else C.get(a)
    if b is None:
        ax.add_patch(S.plt.Rectangle((j - 0.32, 200), 0.64, card - 400, fill=False, edgecolor=S.GREYS[2], lw=0.6, ls=(0, (2, 2))))
        ax.text(j, card / 2, "pending", rotation=90, ha="center", va="center", fontsize=6.5, color=S.MUTED, style="italic")
        continue
    vals = np.array(list(b["scene_mem_mib"].values())) 
    jit = (rng.random(len(vals)) - 0.5) * 0.36
    ax.scatter(j + jit, vals, s=12, marker=marker(a) if marker(a) != "*" else "o", facecolor=colour(a), edgecolor="white", lw=0.4, zorder=3)
    if a == "HPM-MVS_plusplus@3200-capped":
        fm = np.array(list(v["hpmpp"]["failed_scene_mem"].values())) 
        jit = (rng.random(len(fm)) - 0.5) * 0.36
        ax.scatter(j + jit, fm, s=16, marker="x", color=S.INK, lw=0.8, zorder=4)
ax.set_xticks(range(len(cols)), [r["labels"][a] for a in cols], rotation=30, ha="right")
ax.set_xlim(-0.6, len(cols) - 0.4)
ax.set_ylim(0, 13300)
ax.yaxis.set_major_formatter(S.matplotlib.ticker.FuncFormatter(lambda x, _: f"{int(x):,}".replace(",", "\u2009")))
ax.set_ylabel("Peak device memory (MiB)")
ax.grid(True, axis="y")
ax.scatter([], [], marker="x", color=S.INK, label="failed run: memory at the crash")
ax.legend(loc="upper left", frameon=False, fontsize=6.5, bbox_to_anchor=(0.0, 0.93))
S.save(fig, "bench-memory")
