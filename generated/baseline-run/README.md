# The baseline run of production APD-MVS

Data behind two figures of the methodology chapter. Both show the same run: production APD-MVS
on ETH3D *pipes* at native resolution, before any optimization (run tag `perf-nsys-r1`).

| Figure | File | Reads |
|---|---|---|
| Run time by pass and by stage (`<fig-run-breakdown>`) | `chapters/figures/run-breakdown.typ` | `pass-timeline.json`, `stage-timings.json` |
| Kernel time by kernel (`<table-kernel-breakdown>`) | `chapters/figures/kernel-breakdown.typ` | `kernel-breakdown.json`, `stage-timings.json` |

The run is an **analysis run**, not a benchmark measurement: development machine, RTX 5070 Ti,
unlocked clocks, Nsight Systems attached, one repeat. The captions say so. Section 4 is about
replacing it with a measurement.

## Files

`data/<run>/` holds the run files. They are the primary data and are committed.

| File | What it is |
|---|---|
| `data/perf-nsys-r1/phases.txt` | Phase-timer output of the run (`PHASE <name> BEGIN\|END <CLOCK_MONOTONIC ns> [key=value …]`). |
| `data/perf-nsys-r1/context.txt` | Context written by the run script: date, host, mode, container image, commit, GPU and driver, command line, method wall time. |
| `data/perf-nsys-r1/launches.tsv` | One row per kernel launch of the run (5600 rows; `pass_idx, scale, image, state, seq, kernel, iter, ms, width, height`). An extract of the kernel activity records of the run's Nsight Systems trace. Durations are rounded to 0.01 ms. |
| `data/perf-nsys-r1/kernel-totals-base.csv` | Per-kernel launch counts and totals in nanoseconds from the same trace, with registers per thread and block size. Used only as a cross-check. It is the `base` rows of the performance study's `p10_kernel_table.csv`. |

`scripts/` holds the scripts that turn the run files into the JSON the figures read (Python
standard library only).

| File | Writes | From |
|---|---|---|
| `scripts/stage_timings.py` | `stage-timings.json`: per stage, the calls, the total and the seconds per round | `phases.txt`, `context.txt` |
| `scripts/pass_timeline.py` | `pass-timeline.json`: per pass, the start, the end and the seconds per stage | `phases.txt`, `context.txt`; checks its sums against `stage-timings.json` |
| `scripts/kernel_breakdown.py` | `kernel-breakdown.json`: per kernel, the launches, the total, the seconds per round and the stage | `launches.tsv`, `stage-timings.json`; checks against `phases.txt` and `kernel-totals-base.csv` |
| `scripts/run_files.py` | — | Readers of `phases.txt` and `context.txt`, shared by the scripts. |

`derived/<run>/` holds the three JSON files. They are **generated and not committed**
(`generated/.gitignore`). `make figures` writes them, and `make build` and `make watch` run it
first, locally and in CI. Compiling with `typst` directly needs one `make figures` before.

## 1. Regenerate the JSON from the run files

From `thesis/`:

```sh
make figures        # rebuilds what is missing or older than a script or a run file
```

The commands it runs, in this order (the second and third read the output of the first):

```sh
R=generated/baseline-run
python3 $R/scripts/stage_timings.py \
    --phases $R/data/perf-nsys-r1/phases.txt --context $R/data/perf-nsys-r1/context.txt \
    --run perf-nsys-r1 --out $R/derived/perf-nsys-r1/stage-timings.json
python3 $R/scripts/pass_timeline.py \
    --phases $R/data/perf-nsys-r1/phases.txt --context $R/data/perf-nsys-r1/context.txt \
    --stage-timings $R/derived/perf-nsys-r1/stage-timings.json \
    --run perf-nsys-r1 --out $R/derived/perf-nsys-r1/pass-timeline.json
python3 $R/scripts/kernel_breakdown.py \
    --launches $R/data/perf-nsys-r1/launches.tsv \
    --stages $R/derived/perf-nsys-r1/stage-timings.json \
    --phases $R/data/perf-nsys-r1/phases.txt \
    --kernel-table $R/data/perf-nsys-r1/kernel-totals-base.csv \
    --run perf-nsys-r1 --out $R/derived/perf-nsys-r1/kernel-breakdown.json
```

The output is byte-identical for the same inputs. Each script stops with an error instead of
writing numbers it cannot account for:

- `stage_timings.py`: if spans do not nest, if reference image passes overlap, if the loop is
  not `images × passes` with the same number of passes in each round, or if time lies between
  two reference image passes.
- `pass_timeline.py`: if a pass is interleaved with another, misses an image or straddles two
  rounds, if stages overlap inside a reference image pass, if a stage it does not know runs
  inside the loop, or if its sums disagree with the stage totals.
- `kernel_breakdown.py`: if the run is of another commit than the one its kernel-to-stage
  mapping was read at, if a pass deviates from the launch sequence, if the kernels of a stage or
  of a single phase-timer span take longer than that stage or span, or if a kernel total differs
  from `kernel-totals-base.csv` by more than the rounding of the extract.

Which kernel belongs to which stage is read from the source, not from the names: the script
holds the launch sequence of `APD::RunPatchMatch` (`apd/APD.cu`, commit `95c9294`) and requires
every one of the 224 reference image passes to follow it.

## 2. Repeat the analysis run

These are the steps the run was made with. They are known exactly, because the run script wrote
them to `context.txt`.

**Requirements**

- A CUDA machine with Docker and the NVIDIA container toolkit. The run used an RTX 5070 Ti with
  driver 615.71.09 on a Ryzen 9 5900XT.
- Nsight Systems 2026.3.2 on the host under `/opt/nvidia/nsight-systems/2026.3.2` (mounted into
  the container as `/nsys`).
- ETH3D *pipes*, undistorted DSLR images, at `~/thesis-data/eth3d/pipes/pipes_dslr_undistorted/pipes`.
- A checkout of production APD-MVS at `~/production-apd-mvs`, commit `95c9294` (main).

**Steps**

1. Build the image from the checkout. The Dockerfile pins every dependency and targets `sm_120`
   by default, with the phase timer compiled in:

   ```sh
   cd ~/production-apd-mvs && git checkout 95c9294
   docker build -t production-apd-mvs:apd-c1b3ad8 .
   ```

   The run used an image built from commit `c1b3ad8`, whose tree is the same as `95c9294`. The
   exact build command of that image was not recorded; the line above is the Dockerfile's
   documented default.

2. Run. The tag names the result directory and must be new, because the script refuses to
   overwrite:

   ```sh
   ~/production-apd-mvs/.dev/perf/tools/perf_run.sh perf-nsys-r2 production-apd-mvs:apd-c1b3ad8 nsys
   ```

   The run takes about 19 minutes. Start it only on an otherwise idle GPU. The script

   - prepares the scene with `app_initialize_ETH3D /data/scene --output-directory=/work/prepared`,
   - starts 100 ms `nvidia-smi` sampling and 1 s host samplers,
   - runs, with `MVS_BENCH_PHASES=1` and `MVS_BENCH_FILE=/out/phases.txt`,

     ```
     nsys profile -o /out/timeline --trace=cuda,nvtx,osrt,opengl --cuda-memory-usage=true \
          --sample=process-tree --cpuctxsw=process-tree --backtrace=none --stats=false \
       app_patch_match_mvs /work/prepared --output-directory=/out --max-image-size=8192 --apd
     ```

   - evaluates the point cloud with `ETH3DMultiViewEvaluation` at 1, 2, 5, 10 and 20 cm,
   - writes everything to `~/thesis-data/bench/diag/production-apd-mvs/<tag>/`.

   `perf_run.sh` lives in the untracked `.dev/perf/tools/` of the method checkout. Without it,
   the commands above are the whole run. Mode `plain` instead of `nsys` gives the same run
   without the profiler, and then without a trace for `launches.tsv`.

3. Copy `phases.txt` and `context.txt` of the new run to `data/<tag>/` here, and make its
   `launches.tsv` (section 3). Then change the run tag in `thesis/Makefile` (`BASELINE_RUN`)
   and in the `json(…)` paths of `chapters/figures/run-breakdown.typ` and
   `chapters/figures/kernel-breakdown.typ`. `make build` does the rest.

**What to expect.** PatchMatch is seeded from the GPU clock counter, so a repeat does not give
the same numbers. Two runs of this build on the same machine gave reconstruction spans of
1106.5 s (this run, Nsight Systems attached) and 1106.7 s (perf attached). A build with work
counters added gave 1103.4 s without a profiler. At native resolution the method is not
deterministic even with a fixed seed.

## 3. Where `launches.tsv` comes from

The trace is `out/timeline.sqlite` of the run directory
(`~/thesis-data/bench/diag/production-apd-mvs/perf-nsys-r1/` on the development machine), which
Nsight Systems writes when the run is made in mode `nsys` (section 2). The kernel records are
the rows of its `CUPTI_ACTIVITY_KIND_KERNEL` table.

The command that turned the trace into `launches.tsv` was **not recorded**: the performance
study's notes only say that the file is the per-launch table of this run. What is established is
that the file agrees with the trace's per-kernel totals: launch counts are identical for all 15
kernels and the totals differ by 2 ms over 820 s, within the rounding.

To close the gap, this prompt asks the performance-measurement agent for the extraction step:

```text
Goal: make thesis/generated/baseline-run/data/perf-nsys-r1/launches.tsv reproducible from the
Nsight Systems trace of the run, and write down the exact steps.

The file is the per-launch kernel table of run perf-nsys-r1 (5600 rows; columns pass_idx, scale,
image, state, seq, kernel, iter, ms, width, height). It was produced during the performance
study from ~/thesis-data/bench/diag/production-apd-mvs/perf-nsys-r1/out/timeline.sqlite and
stored as .dev/perf/profiles/launches.tsv, but the command was not recorded.

What I need:
1. A checked-in script (Python standard library, sqlite3) that reads timeline.sqlite and writes
   the same table: kernel name from the trace's string table, duration from the start and end
   of each CUPTI_ACTIVITY_KIND_KERNEL row, and pass_idx, scale, image, state, seq and iter from
   the launch order (and phases.txt if that is how they were assigned). Say how each column is
   derived. Write durations in nanoseconds instead of rounded milliseconds if the table allows
   it, as an extra column, so that the 0.01 ms rounding goes away.
2. Proof that it reproduces the existing file: a row-by-row comparison, with any difference
   explained.
3. The exact command line, and the sha256 of timeline.sqlite it was run on, written so that I
   can paste them into section 3 of thesis/generated/baseline-run/README.md in place of this
   prompt.
4. When a benchmark measurement replaces the analysis run (see the prompt in section 4 of the
   same README): say how per-kernel times are obtained there, since the benchmark protocol runs
   without a profiler. Give me costed options with a recommendation (for example one extra
   profiled repeat that is not timed, or cudaEvent timing per launch behind a flag) and do not
   implement any of them before I have answered.

Constraints: read-only on the run directory; do not delete or overwrite anything in it. Do not
edit files under thesis/ yourself; hand me the script and the text.
```

## 4. Replace the analysis run with a benchmark measurement

The steps for this are **not established**. The thesis protocol (methodology chapter) asks for
the RTX 5070 with the SM clock locked at 2317 MHz, the containers pinned to CPU threads 0–7 and
16–23, governor and EPP set to performance, no profiler, and five repeats in randomized order.
Production APD-MVS is not in `benchmark/methods/methods.yaml` yet, so the harness cannot run it,
and no run of it on the bench exists. With several repeats the figures also have to change: the
scripts read one run.

Until the steps exist, this prompt asks the performance-measurement agent for them:

```text
Goal: replace the analysis-run data behind the thesis figure <fig-run-breakdown>
(thesis/chapters/figures/run-breakdown.typ) with a benchmark measurement, and write down the
exact steps so they can be repeated.

Current data: thesis/generated/baseline-run/data/perf-nsys-r1/{phases.txt,context.txt},
one run of production APD-MVS (commit 95c9294, image production-apd-mvs:apd-c1b3ad8) on ETH3D
pipes at native resolution (--max-image-size=8192 --apd), made on the development machine with
unlocked clocks and Nsight Systems attached. thesis/generated/baseline-run/README.md
section 2 has the exact commands of that run.

What I need:
1. The baseline (commit 95c9294, same arguments, same scene) measured on the thesis bench under
   the protocol of the methodology chapter: RTX 5070, SM clock locked at 2317 MHz, persistence
   mode on, nothing else on the GPU, containers pinned to CPU threads 0-7,16-23, governor and
   EPP performance, no profiler, phase timer on (MVS_BENCH_PHASES=1), five repeats. State
   whether the repeats were interleaved with other runs or run back to back.
2. For every repeat: phases.txt, a context.txt with the same keys as the existing one
   (date_utc, host, mode, image digest and tag, repo_head, app_args, the nvidia-smi line with
   GPU name, driver, persistence mode and clocks, cmd, method_wall_s), the sampled SM clock so
   that "the lock held for the whole run" can be shown, and the F1 scores at 1, 2, 5, 10 and
   20 cm. Put the files under thesis/generated/baseline-run/data/<tag>-r<i>/ and do
   not delete or overwrite any existing run directory.
3. Decide with me first, with costed options and a recommendation, how the method gets onto the
   bench: (a) add production APD-MVS to benchmark/methods/methods.yaml and run it through the
   harness (bench run), which needs a manifest entry, a deviation record and
   `uv run deviations verify` passing; or (b) run it by hand on the bench with a script like
   .dev/perf/tools/perf_run.sh in mode plain, outside the result store. Do not start
   measuring before I have answered.
4. Tell me what must change in the figure for five repeats: which statistic each table cell
   should show (mean with the 95 % confidence interval of the methodology chapter, eq-ci), and
   which run the two timeline charts should be drawn from. Do not edit the thesis files yourself; describe
   the change.
5. The exact commands you ran, in order, including host preparation (clock lock, CPU pinning,
   governor), the image build command and the resulting image digest, written so that I can
   paste them into section 4 of the README in place of this prompt.

Constraints: measurement integrity outranks convenience. Failed runs are results and are kept.
Check what else is running on the bench before starting and never stop work you did not start.
Report the run-to-run spread of the reconstruction span and of F1 at 2 cm, and say plainly if
any repeat ran with the clock lock not held.
```
