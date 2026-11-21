# Typst build of the thesis. Requires Typst 0.15.1 (`typst --version`).
TYPST ?= typst
# Latin Modern fonts shipped with the template (GUST Font License)
TYPSTFLAGS = --font-path template/fonts
# Build stamp in the bottom margin (hidden with `final: true`); CI overrides it.
REV ?= $(shell git describe --always --dirty 2>/dev/null)
ifneq ($(REV),)
TYPSTFLAGS += --input rev="rev $(REV)"
endif

# Figures rendered from checked-in data by checked-in scripts (needs uv).
FIGURES = generated/figures/dimensioning_run_statistics.png

# Data files that chapters read with json(): the baseline run of production APD-MVS. They are
# generated from the checked-in run files by checked-in scripts (needs python3, standard library
# only) and are not committed; see generated/baseline-run/README.md.
BASELINE_RUN = perf-nsys-r1
BASELINE = generated/baseline-run
BASELINE_RAW = $(BASELINE)/data/$(BASELINE_RUN)
BASELINE_OUT = $(BASELINE)/derived/$(BASELINE_RUN)
STAGE_JSON = $(BASELINE_OUT)/stage-timings.json
PASS_JSON = $(BASELINE_OUT)/pass-timeline.json
KERNEL_JSON = $(BASELINE_OUT)/kernel-breakdown.json

# Data files of section 4.3 (performance optimizations): the figures chapters/figures/perf-*.typ
# and the numbers of the 4.3 text. One script writes all of them from the CSV snapshots in
# generated/perf-4.3/data and from the baseline run files (python3, standard library only); they
# are not committed. numbers-method.json stands for the set.
PERF43 = generated/perf-4.3
PERF43_JSON = $(PERF43)/derived/numbers-method.json

DATA = $(STAGE_JSON) $(PASS_JSON) $(KERNEL_JSON) $(PERF43_JSON)

.PHONY: build watch clean figures

figures: $(FIGURES) $(DATA)

$(STAGE_JSON): $(BASELINE)/scripts/stage_timings.py $(BASELINE)/scripts/run_files.py $(BASELINE_RAW)/phases.txt $(BASELINE_RAW)/context.txt
	python3 $< --phases $(BASELINE_RAW)/phases.txt --context $(BASELINE_RAW)/context.txt --run $(BASELINE_RUN) --out $@

# --stage-timings only checks the per-pass sums against the stage totals.
$(PASS_JSON): $(BASELINE)/scripts/pass_timeline.py $(BASELINE)/scripts/run_files.py $(BASELINE_RAW)/phases.txt $(BASELINE_RAW)/context.txt $(STAGE_JSON)
	python3 $< --phases $(BASELINE_RAW)/phases.txt --context $(BASELINE_RAW)/context.txt --stage-timings $(STAGE_JSON) --run $(BASELINE_RUN) --out $@

$(KERNEL_JSON): $(BASELINE)/scripts/kernel_breakdown.py $(BASELINE)/scripts/run_files.py $(BASELINE_RAW)/launches.tsv $(BASELINE_RAW)/kernel-totals-base.csv $(BASELINE_RAW)/phases.txt $(STAGE_JSON)
	python3 $< --launches $(BASELINE_RAW)/launches.tsv --stages $(STAGE_JSON) --phases $(BASELINE_RAW)/phases.txt --kernel-table $(BASELINE_RAW)/kernel-totals-base.csv --run $(BASELINE_RUN) --out $@

$(PERF43_JSON): $(PERF43)/scripts/perf43_json.py $(wildcard $(PERF43)/data/*.csv) $(wildcard $(PERF43)/data/*.json) $(wildcard $(PERF43)/data/*.md) $(BASELINE_RAW)/phases.txt $(BASELINE_RAW)/kernel-totals-base.csv
	python3 -B $< --data $(PERF43)/data --baseline-run $(BASELINE_RAW) --out $(PERF43)/derived

generated/figures/dimensioning_run_statistics.png: generated/dimensioning/scripts/dimensioning_run_statistics.py generated/dimensioning/data/runs-dev2.csv
	uv run $<

build: figures
	mkdir -p build
	$(TYPST) compile $(TYPSTFLAGS) main.typ build/thesis.pdf

watch: figures
	mkdir -p build
	$(TYPST) watch $(TYPSTFLAGS) main.typ build/thesis.pdf

# Removes only the Typst output; other files in build/ are left alone.
clean:
	rm -f build/thesis.pdf
