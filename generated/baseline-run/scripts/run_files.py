"""Readers of the files of one run, shared by stage_timings.py and pass_timeline.py.

  phases.txt    phase-timer output: lines "PHASE <name> BEGIN|END <CLOCK_MONOTONIC ns> [key=value ...]"
  context.txt   written by the run script: date, host, mode, container image, commit, GPU and
                driver, command line, method wall time

Standard library only. The scripts are run as files, so this module is found next to them.
"""
import hashlib
import sys
from collections import defaultdict
from pathlib import Path


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_phases(path):
    """phases.txt -> [(stage, t0, t1, attrs)], seconds from the BEGIN of `run`."""
    events = []
    for no, line in enumerate(Path(path).read_text().splitlines(), 1):
        f = line.split()
        if not f or f[0] != "PHASE":
            continue
        if len(f) < 4 or f[2] not in ("BEGIN", "END") or not f[3].isdigit():
            sys.exit(f"{path}:{no}: malformed PHASE line: {line!r}")
        attrs = dict(a.split("=", 1) for a in f[4:] if "=" in a)
        events.append((f[1], f[2], int(f[3]), attrs))
    run_begin = [ts for name, ev, ts, _ in events if name == "run" and ev == "BEGIN"]
    if len(run_begin) != 1:
        sys.exit(f"expected exactly one `run` BEGIN, found {len(run_begin)}")
    t0, stack, spans = run_begin[0], defaultdict(list), []
    for name, ev, ts, attrs in events:
        if ev == "BEGIN":
            stack[name].append((ts, attrs))
        else:
            if not stack[name]:
                sys.exit(f"END without BEGIN for {name} at {ts}")
            begin, battrs = stack[name].pop()
            spans.append((name, (begin - t0) / 1e9, (ts - t0) / 1e9, battrs))
    left = {n: len(v) for n, v in stack.items() if v}
    if left:
        sys.exit(f"unclosed spans: {left}")
    return spans


def read_context(path):
    """context.txt of a study run -> the facts the captions need."""
    lines = Path(path).read_text().splitlines()
    kv = dict(l.split("=", 1) for l in lines if "=" in l and not l.startswith(("name,", "pid,")))
    gpu = {}
    for head, row in zip(lines, lines[1:]):
        if head.startswith("name, driver_version"):
            gpu = dict(zip((h.strip() for h in head.split(",")), (c.strip() for c in row.split(","))))
    return {
        "date_utc": kv.get("date_utc"),
        "host": kv.get("host"),
        "mode": kv.get("mode"),
        "commit": (kv.get("repo_head", "").split() or [None])[0],
        "container_image": kv.get("image"),
        "app_args": kv.get("app_args"),
        "method_wall_s": float(kv["method_wall_s"]) if "method_wall_s" in kv else None,
        "gpu": gpu.get("name"),
        "driver": gpu.get("driver_version"),
        "persistence_mode": gpu.get("persistence_mode"),
        "sm_clock_max": gpu.get("clocks.max.sm [MHz]"),
    }
