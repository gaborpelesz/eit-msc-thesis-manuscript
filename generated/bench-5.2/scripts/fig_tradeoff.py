# /// script
# requires-python = ">=3.12"
# dependencies = ["matplotlib==3.10.*", "numpy==2.*"]
# ///
"""Figure A: mean F1 at 2 cm over the 13 scenes against the total runtime of the 13 scenes, with
the Pareto front. Every point and label from derived/numbers-bench.json. The reserved
CUMVS(APD) arms are drawn when their data is in the JSON; until then they appear only in the
legend, marked as pending."""
from matplotlib.lines import Line2D

import style as S

S.setup()
v = S.load()
r, colour, marker = S.reg(v)
F = v["arms"]
present = [a for a in r["order"] if a in F and not F[a]["reserved"]]

fig, ax = S.plt.subplots(figsize=(S.TEXT_W, 3.1))
# Pareto front as a step line (better F1 only at a longer time)
fr = v["front"]
xs, ys = [], []
for i, a in enumerate(fr):
    x, y = F[a]["wall_total_s"]["mean"], F[a]["f1_2cm"]["mean"]
    if i:
        xs.append(x); ys.append(ys[-1])
    xs.append(x); ys.append(y)
xs.append(F[fr[-1]]["wall_total_s"]["mean"] * 1.6); ys.append(ys[-1])
ax.plot(xs, ys, color=S.MUTED, lw=0.9, ls=(0, (4, 2)), zorder=1)
# labels: offsets in points, chosen so that no label overlaps a point or another label
off = {
    "ACMH@3200-capped": (6, 0, "left"), "ACMP@3200-capped": (-6, 0, "right"),
    "ACMM@3200-capped": (6, 0, "left"), "ACMMP@3200-capped": (6, -4, "left"),
    "MP-MVS@3200-capped": (-6, 4, "right"), "HPM-MVS@3200-capped": (-7, -2, "right"),
    "CUMVS@3200-capped": (0, -10, "center"), "APD-MVS@native": (7, -7, "left"),
    "DPE-MVS@native": (-6, 3, "right"),
    "production-apd-mvs@3200-capped": (8, 1, "left"), "production-apd-mvs@native": (-8, 6, "right"),
}
for a in present:
    b = F[a]
    x, y = b["wall_total_s"]["mean"], b["f1_2cm"]["mean"]
    on = a in fr
    ax.errorbar(x, y, xerr=b["wall_total_s"]["hw"], yerr=b["f1_2cm"]["hw"], fmt="none",
                ecolor=S.INK, elinewidth=0.6, capsize=0, zorder=2)
    ax.scatter([x], [y], s=34 if marker(a) != "*" else 70, marker=marker(a), zorder=3,
               facecolor=colour(a) if on else "white", edgecolor=colour(a), linewidth=1.2)
    dx, dy, ha = off.get(a, (6, 0, "left"))
    ax.annotate(r["labels"][a], (x, y), xytext=(dx, dy), textcoords="offset points",
                ha=ha, va="center", fontsize=7, color=S.INK)
ax.set_xscale("log")
ax.set_xlabel("Total runtime over the 13 scenes (s, log scale)")
ax.set_ylabel("Mean F1 at 2 cm over the 13 scenes")
ax.grid(True, which="major", axis="both")
ax.set_xlim(F[fr[0]]["wall_total_s"]["mean"] / 1.6, F[fr[-1]]["wall_total_s"]["mean"] * 1.6)
# legend: one entry per group, the reserved group marked as pending while it has no data
handles = []
for g, (name, col, mk) in r["groups"].items():
    pending = all(F[a]["reserved"] for a in r["order"] if r["arm_group"][a] == g)
    handles.append(Line2D([], [], ls="none", marker=mk, markersize=6 if mk != "*" else 9, markerfacecolor=col,
                          markeredgecolor=col, label=name + (" (pending)" if pending else "")))
handles.append(Line2D([], [], color=S.MUTED, lw=0.9, ls=(0, (4, 2)), label="Pareto front (filled markers)"))
ax.legend(handles=handles, loc="lower right", frameon=False, handletextpad=0.4, borderaxespad=0.2)
S.save(fig, "bench-tradeoff")
