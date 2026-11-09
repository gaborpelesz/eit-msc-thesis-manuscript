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

.PHONY: build watch clean figures

figures: $(FIGURES)

generated/figures/dimensioning_run_statistics.png: generated/dimensioning/scripts/dimensioning_run_statistics.py generated/dimensioning/data/runs-dev2.csv
	uv run $<

build: figures
	mkdir -p build
	$(TYPST) compile $(TYPSTFLAGS) main.typ build/thesis.pdf

watch:
	mkdir -p build
	$(TYPST) watch $(TYPSTFLAGS) main.typ build/thesis.pdf

# Removes only the Typst output; other files in build/ are left alone.
clean:
	rm -f build/thesis.pdf
