"""The arm registry of section 5.2: one place for the key, the printed label, the group, the
order, the colour and the marker of every arm. bench_json.py writes it into the JSON, so the
figure scripts and the Typst files use the same labels and slots.

An arm is (method, processed resolution), keyed as aggregate.py keys it:
`<harness method id>@<processed_resolution>`. The two CUMVS(APD) arms are reserved here with
the keys their runs carry (harness id `production-apd-mvs`; width 3200 -> 3200-capped, width
native -> native). Their runs are in the data since the M8 refresh (2026-11-23); a reserved arm
without runs would be drawn as an empty, labelled slot.

Colour follows the group, not the arm (twelve arms exceed any colour-blind-safe categorical
set); the marker and a direct label identify the arm. Okabe-Ito hues.
"""

# group -> (printed name, colour, marker)
GROUPS = {
    "lineage": ("Lineage methods, capped at 3200 px", "#0072B2", "o"),
    "native": ("Native resolution", "#D55E00", "s"),
    "cumvs": ("CUMVS, capped at 3200 px", "#009E73", "D"),
    "ours": ("CUMVS(APD)", "#CC79A7", "*"),
}

# key, label, group, scene_set ("all13" or "common_ok" when the arm failed scenes)
ARMS = [
    ("ACMH@3200-capped", "ACMH", "lineage"),
    ("ACMP@3200-capped", "ACMP", "lineage"),
    ("ACMM@3200-capped", "ACMM", "lineage"),
    ("ACMMP@3200-capped", "ACMMP", "lineage"),
    ("MP-MVS@3200-capped", "MP-MVS", "lineage"),
    ("HPM-MVS@3200-capped", "HPM-MVS", "lineage"),
    ("HPM-MVS_plusplus@3200-capped", "HPM-MVS++", "lineage"),
    ("CUMVS@3200-capped", "CUMVS", "cumvs"),
    ("production-apd-mvs@3200-capped", "CUMVS(APD) @ 3200", "ours"),
    ("APD-MVS@native", "APD-MVS", "native"),
    ("DPE-MVS@native", "DPE-MVS", "native"),
    ("production-apd-mvs@native", "CUMVS(APD) @ native", "ours"),
]
RESERVED = {"production-apd-mvs@3200-capped", "production-apd-mvs@native"}
LABEL = {k: l for k, l, _ in ARMS}
GROUP = {k: g for k, _, g in ARMS}
ORDER = [k for k, _, _ in ARMS]


def colour(key):
    return GROUPS[GROUP[key]][1]


def marker(key):
    return GROUPS[GROUP[key]][2]
