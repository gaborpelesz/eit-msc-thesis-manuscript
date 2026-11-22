# The final benchmark (section 5.2 and its appendix)

Data behind the benchmark results: the section "Benchmarking" of the results chapter
(`chapters/results.typ`) and the appendix "Detailed benchmark results"
(`chapters/appendix_benchmark.typ`). Every number and every figure of the two is generated from
the files in `data/`; nothing is typed into the chapters.

The benchmark is 650 runs: 10 methods on the 13 ETH3D training scenes with five repeats each, in
the sessions `final-author-r1` to `final-author-r5` (one session per repeat; the column `machine`
says where a session ran). 605 runs succeeded. The 45 failed runs are kept, with their status and
failure class. The two CUMVS(APD) arms are not in the data yet: their keys are reserved in
`scripts/arms.py`, and the tables and figures show them as pending.

## Files

`data/` is the primary data and is committed. It is a snapshot of the aggregation of the result
store of the five sessions; the aggregation script and the store are outside this repository.

| File | What it is |
|---|---|
| `data/runs.csv` | One row per run (650): method, scene, repeat, status, fork commit, image digest, wall time, converter time, F1, accuracy and completeness at five tolerances, peak device and host memory, energy, clock and telemetry summaries. |
| `data/failures.csv` | The 45 failed runs, with the same columns. |
| `data/cells.csv` | Per arm, scene and metric: mean, standard deviation and interval over the repeats. Used only as a cross-check. |
| `data/pareto.csv` | The Pareto front per tolerance, as the aggregation computed it. Used only as a cross-check. |
| `data/phase-categories.csv` | Per run and phase category: the self time of the phase timers and its share of the wall time. |
| `data/phases-input-load.csv` | Per run: the input-loading phases with their span counts. |
| `data/SHA256SUMS` | Checksums of the six files as committed. |
| `data/SHA256SUMS.source` | Checksums of the six files as they left the aggregation. |

`runs.csv` and `failures.csv` differ from their source in one respect: the columns `hostname` and
`gpu_uuid` (identifiers of the two machines) were removed when the snapshot was imported. No
script reads them, and every other field is unchanged. The other four files are byte-identical to
their source.

`scripts/` turns the snapshot into what the chapters read. The scripts are run with `uv`, which
installs the packages pinned in the header of each script.

| File | Writes | From |
|---|---|---|
| `scripts/bench_json.py` | `derived/numbers-bench.json`: every value of the section, the appendix and the figures | `data/*.csv`, and `../perf-4.3/derived/numbers-results.json` for the section 4.3 numbers it quotes; checks its results against `cells.csv` and `pareto.csv` and stops when a premise of the text no longer holds |
| `scripts/fig_tradeoff.py`, `fig_scenes.py`, `fig_phases.py`, `fig_memory.py`, `fig_repeatability.py` | `derived/figures/bench-<name>.svg` | `derived/numbers-bench.json` |
| `scripts/arms.py` | — | The arm registry: key, label, group, order, colour and marker of every arm. |
| `scripts/style.py` | — | The figure style, shared by the figure scripts; it uses the Latin Modern fonts in `template/fonts`. |

`derived/` holds the JSON and the SVG figures. They are **generated and not committed**
(`.gitignore`). `make figures` writes them, and `make build` and `make watch` run it first,
locally and in CI. Compiling with `typst` directly needs one `make figures` before.

## Regenerate

From the thesis root:

```sh
make figures
```

or by hand, after `generated/perf-4.3/derived/numbers-results.json` exists:

```sh
uv run generated/bench-5.2/scripts/bench_json.py
uv run generated/bench-5.2/scripts/fig_tradeoff.py   # and the other fig_*.py
```

## Refreshing the snapshot

When runs are added (the CUMVS(APD) arms), replace the CSV files, keep `hostname` and `gpu_uuid`
out of `runs.csv` and `failures.csv`, update the two checksum files and run `make figures`.
`bench_json.py` asserts the premises that the text relies on (the members of the Pareto front,
the order of the arms, which runs failed); when one of them changes it stops, and the sentence
that depends on it has to be revisited.
