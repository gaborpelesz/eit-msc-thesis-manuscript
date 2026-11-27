# /// script
# requires-python = ">=3.12"
# dependencies = ["matplotlib==3.10.*", "numpy==2.*"]
# ///
"""Shared figure style of section 5.2: 6.3 in text width, 8 pt text, 7 pt ticks, Latin Modern
Roman from the thesis template (template/fonts), recessive axes. Arm colours, markers and labels come
from the registry in the JSON (arms.py), never from here.
"""
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib import font_manager  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FIGURES = ROOT / "derived" / "figures"
JSON = ROOT / "derived" / "numbers-bench.json"
TEXT_W = 6.3

# stage classes of run-breakdown.typ / perf-common.typ (host orange, copy green, kernel blue)
HOST = "#eb6834"
COPY = "#1baf7a"
KERNEL = "#2a78d6"
KERNEL_LIGHT = "#7daee8"
GREYS = ["#3b3b3b", "#6e6e6e", "#a3a3a3", "#d0d0d0"]
INK = "#141414"
MUTED = "#6b6b6b"
GRID = "#dddddd"
RED = "#b2182b"

_FONT_DIR = ROOT.parent.parent / "template" / "fonts"


def setup():
    family = "serif"
    for f in ("lmroman10-regular.otf", "lmroman10-bold.otf", "lmroman10-italic.otf"):
        p = _FONT_DIR / f
        if p.exists():
            font_manager.fontManager.addfont(str(p))
            family = "Latin Modern Roman"
    plt.rcParams.update({
        "font.family": family,
        "font.size": 8, "axes.titlesize": 8, "axes.labelsize": 8,
        "xtick.labelsize": 7, "ytick.labelsize": 7, "legend.fontsize": 7,
        "axes.spines.top": False, "axes.spines.right": False,
        "axes.edgecolor": MUTED, "xtick.color": MUTED, "ytick.color": MUTED,
        "axes.labelcolor": INK, "text.color": INK,
        "axes.grid": False, "grid.color": GRID, "grid.linewidth": 0.6,
        "axes.axisbelow": True, "axes.unicode_minus": True,
        "pdf.fonttype": 42, "svg.fonttype": "path",
        "savefig.dpi": 300,
    })


def load():
    return json.loads(JSON.read_text())["v"]


def reg(v):
    r = v["registry"]
    groups = r["groups"]

    def colour(a):
        return groups[r["arm_group"][a]][1]

    def marker(a):
        return groups[r["arm_group"][a]][2]

    return r, colour, marker


def save(fig, name):
    FIGURES.mkdir(parents=True, exist_ok=True)
    # SVG only: the chapters include the SVG (text as paths, so Typst needs no font for it)
    fig.savefig(FIGURES / f"{name}.svg", bbox_inches="tight", pad_inches=0.02)
    print("wrote", FIGURES / f"{name}.svg")
