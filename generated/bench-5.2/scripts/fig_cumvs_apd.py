# /// script
# requires-python = ">=3.12"
# dependencies = ["matplotlib==3.10.*", "numpy==2.*"]
# ///
"""Figure E: CUMVS(APD) @ native against APD-MVS per scene. (a) Speedup: the runtime of APD-MVS over
that of CUMVS(APD) (ratio of cell means, delta-method 95 % interval), with the ratio of the 13-scene
totals as a dashed line. (b) F1 at 2 cm, CUMVS(APD) minus APD-MVS (pp), with the 95 % Welch interval,
and the difference of the 13-scene means as a dashed line. Scenes ordered by the speedup. Every value
from derived/numbers-bench.json (v.ours)."""
import style as S

S.setup()
v = S.load()
r, colour, marker = S.reg(v)
O = v["ours"]
on = "production-apd-mvs@native"
col = colour(on)
rows = O["scene_order_x"]  # lowest speedup first -> bottom
y = range(len(rows))

fig, (ax, bx) = S.plt.subplots(1, 2, figsize=(S.TEXT_W, 2.9), sharey=True,
                               gridspec_kw=dict(width_ratios=[1, 1], wspace=0.08))
# (a) speedup
for i, s in enumerate(rows):
    x = O["scene"][s]["x"]
    ax.plot([x["lo"], x["hi"]], [i, i], color=S.INK, lw=0.7, zorder=2)
    ax.scatter([x["mean"]], [i], s=22, marker="o", facecolor=col, edgecolor=col, zorder=3)
sp = O["speedup"]["mean"]
ax.axvline(sp, color=S.MUTED, lw=0.9, ls=(0, (4, 2)), zorder=1)
ax.text(sp + 0.003, len(rows) - 0.25, f"13-scene total {sp:.2f}×", ha="left", va="bottom", fontsize=6.5, color=S.MUTED)
ax.set_yticks(list(y), [f"{s} ({v['n_images'][s]})" for s in rows])
ax.tick_params(axis="y", length=0)
ax.set_xlim(1.90, 2.11)
ax.set_xticks([1.90, 1.95, 2.00, 2.05, 2.10], ["1.90×", "1.95×", "2.00×", "2.05×", "2.10×"])
ax.set_ylim(-0.6, len(rows) + 0.5)
ax.grid(True, axis="x")
ax.set_xlabel("Speedup: APD-MVS time / CUMVS(APD) time")
ax.set_title("(a) Speedup at native resolution", loc="left")
# (b) F1 difference
for i, s in enumerate(rows):
    d = O["scene"][s]["d_f1_2cm"]
    resolved = d["lo"] > 0 or d["hi"] < 0
    bx.plot([d["lo"], d["hi"]], [i, i], color=S.INK, lw=0.7, zorder=2)
    bx.scatter([d["mean"]], [i], s=22, marker="o", facecolor=col if resolved else "white", edgecolor=col, lw=1.0, zorder=3)
dm = O["d_f1_13"]["2cm"]["mean"]
bx.axvline(0, color=S.INK, lw=0.6, zorder=1)
bx.axvline(dm, color=S.MUTED, lw=0.9, ls=(0, (4, 2)), zorder=1)
bx.text(dm - 0.015, len(rows) - 0.25, f"13-scene mean {dm:+.2f} pp", ha="right", va="bottom", fontsize=6.5, color=S.MUTED, bbox=dict(facecolor="white", edgecolor="none", pad=0.6), zorder=4)
lim = max(abs(O["scene"][s]["d_f1_2cm"][k]) for s in rows for k in ("lo", "hi")) * 1.1
bx.set_xlim(-lim, lim)
bx.grid(True, axis="x")
bx.tick_params(axis="y", length=0)
bx.set_xlabel("F1 at 2 cm: CUMVS(APD) − APD-MVS (pp)")
bx.set_title("(b) F1 difference (filled: interval excludes 0)", loc="left")
for a in (ax, bx):
    a.spines["left"].set_visible(False)
S.save(fig, "bench-cumvs-apd")
