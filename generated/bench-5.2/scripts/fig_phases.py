# /// script
# requires-python = ">=3.12"
# dependencies = ["matplotlib==3.10.*", "numpy==2.*"]
# ///
"""Figure C: where the time goes. (a) Share of the summed run time of each arm per phase class
(the harness's phase timers, self time), with the share of time the GPU was idle (driver
utilisation 0, 2 Hz) as a tick on the same share axis. (b) The GPU-idle share against the share
of run time spent outside the PatchMatch phase, one point per arm that completed all scenes.
Every value from derived/numbers-bench.json. The reserved CUMVS(APD) rows are empty slots
until their runs are in the data."""
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

import style as S

S.setup()
v = S.load()
r, colour, marker = S.reg(v)
F, C = v["arms"], v["arms_common"]

CLASSES = [  # key, label, fill: the stage classes of run-breakdown.typ where they apply
    ("input_load", "Input loading", S.HOST),
    ("transfer", "Host–device transfers", S.COPY),
    ("patchmatch", "PatchMatch", S.KERNEL),
    ("prior_aux", "Priors and auxiliary passes", S.KERNEL_LIGHT),
    ("fusion", "Fusion", S.GREYS[0]),
    ("write", "Depth-map and point-cloud writing", S.GREYS[2]),
    ("other", "Other", S.GREYS[3]),
]
rows = list(reversed(r["order"]))  # top to bottom in registry order


def blk(a):
    if a in F and not F[a]["reserved"]:
        return F[a], False
    if a in C:
        return C[a], True
    return None, False


fig, (ax, bx) = S.plt.subplots(1, 2, figsize=(S.TEXT_W, 3.3), gridspec_kw=dict(width_ratios=[1.55, 1], wspace=0.42))
labels = []
for i, a in enumerate(rows):
    b, partial = blk(a)
    lab = r["labels"][a] + (" (4 scenes)" if partial else "")
    labels.append(lab)
    if b is None:
        ax.barh(i, 1, left=0, height=0.62, color="none", edgecolor=S.GREYS[2], lw=0.6, ls=(0, (2, 2)))
        ax.text(0.5, i, "pending", ha="center", va="center", fontsize=6.5, color=S.MUTED, style="italic")
        continue
    left = 0.0
    for k, _, col in CLASSES:
        w = b["share"][k]
        ax.barh(i, w, left=left, height=0.62, color=col, edgecolor="white", lw=0.4)
        left += w
    ax.plot([b["gpu_idle_share"]] * 2, [i - 0.42, i + 0.42], color=S.INK, lw=1.4, solid_capstyle="butt")
ax.set_yticks(range(len(rows)), labels)
ax.tick_params(axis="y", length=0)
ax.set_xlim(0, 1)
ax.set_xticks([0, 0.25, 0.5, 0.75, 1], ["0", "25%", "50%", "75%", "100%"])
ax.set_xlabel("Share of the run time")
ax.spines["left"].set_visible(False)
ax.set_title("(a) Phase classes and GPU-idle share", loc="left")
handles = [Patch(facecolor=c, edgecolor="none", label=l) for _, l, c in CLASSES]
handles.append(Line2D([], [], color=S.INK, lw=1.4, label="GPU idle (tick)"))
ax.legend(handles=handles, loc="upper center", bbox_to_anchor=(0.62, -0.17), ncol=4, frameon=False,
          handlelength=1.2, columnspacing=0.9, handletextpad=0.4, fontsize=6.5)

# (b) correlation across the arms that completed all scenes
lo, hi = 0, 0.85
bx.plot([lo, hi], [lo, hi], color=S.GREYS[2], lw=0.7, ls=(0, (3, 2)), zorder=1)
off = {"ACMM@3200-capped": (-5, 3, "right"), "ACMH@3200-capped": (5, -5, "left"), "ACMMP@3200-capped": (-5, 3, "right"),
       "ACMP@3200-capped": (5, -3, "left"), "MP-MVS@3200-capped": (5, -1, "left"), "HPM-MVS@3200-capped": (-5, 3, "right"),
       "CUMVS@3200-capped": (5, 2, "left"), "APD-MVS@native": (5, 1, "left"), "DPE-MVS@native": (-5, -1, "right")}
for a in v["full"]:
    b = F[a]
    x, y = b["gpu_idle_share"], b["share_outside_patchmatch"]
    bx.scatter([x], [y], marker=marker(a), s=26 if marker(a) != "*" else 60, facecolor=colour(a), edgecolor="white", lw=0.5, zorder=3)
    dx, dy, ha = off.get(a, (5, 0, "left"))
    bx.annotate(r["labels"][a], (x, y), xytext=(dx, dy), textcoords="offset points", ha=ha, va="center", fontsize=6.5)
bx.set_xlim(lo, hi); bx.set_ylim(lo, hi)
ticks = [0, 0.2, 0.4, 0.6, 0.8]
bx.set_xticks(ticks, [f"{int(t*100)}%" for t in ticks]); bx.set_yticks(ticks, [f"{int(t*100)}%" for t in ticks])
bx.set_aspect("equal")
bx.grid(True)
bx.set_xlabel("GPU idle (share of the run time)")
bx.set_ylabel("Outside PatchMatch (share of the run time)")
bx.set_title(f"(b) Across {v['idle_vs_outside_n']} arms: r = {v['idle_vs_outside_r']:.2f}", loc="left")
S.save(fig, "bench-phases")
