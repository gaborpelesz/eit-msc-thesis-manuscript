# MSc thesis manuscript

*High-Performance Patch-Match Multi-View Stereo: Separating Algorithmic Cost
from Implementation Overhead* — MSc thesis, Computer Science, Eötvös Loránd
University, Faculty of Informatics, 2026.

This repository holds the manuscript, written in [Typst](https://typst.app).
It is a submodule of the thesis monorepo, whose `benchmark/` directory produces
the measurements and generated tables quoted here.

## Layout

| Path | Content |
|---|---|
| `main.typ` | entry point: metadata, front matter, chapters, back matter |
| `chapters/*.typ` | the chapters |
| `thesis.bib` | bibliography (BibTeX) |
| `generated/` | tables generated in the superproject, and data with the scripts that turn it into figures (see below); never edited by hand |
| `images/` | figures; `elte_cimer_szines.pdf` is the ELTE logo |
| `template/` | the ELTE FI thesis template (Typst port of elteikthesis, see below) |
| `template/fonts/` | Latin Modern fonts used by the template |

## Build

Requires **Typst 0.15.1** (`typst --version`).

```sh
make build    # main.typ -> build/thesis.pdf
make watch    # recompile on every change
make clean    # remove build/thesis.pdf
```

The template uses the Latin Modern fonts in `template/fonts/`, so every Typst
call needs `--font-path template/fonts`; the Makefile passes it. Without it,
Typst warns about unknown font families and falls back to New Computer Modern
for text and to DejaVu Sans Mono for code. Mathematics is always set in
New Computer Modern Math (Typst's bundled Computer Modern math font).
For direct CLI use, `export TYPST_FONT_PATHS=template/fonts` has the same effect.

### Revision stamp and CI

Every page carries a small revision stamp in the bottom-right margin
(`git describe --always --dirty`, or `make build REV=...`); it is hidden when
`final: true` is set in `main.typ`. `.github/workflows/build.yml` builds the PDF
on every push and pull request:

- push to `main`: the PDF replaces `thesis.pdf` on the rolling **`latest`**
  pre-release (stable link: `releases/download/latest/thesis.pdf`);
- tag `draft-*` or `v*` (e.g. `git tag draft-ch3 && git push origin draft-ch3`):
  a permanent release holding `thesis-<tag>.pdf`, for drafts sent for review;
- pull request: a workflow artifact only.

Review notes go in issues ("Review notes" template), quoting the stamp.

### Editor setup (Tinymist)

With the [Tinymist](https://github.com/Myriad-Dreamin/tinymist) language server
(VS Code extension "Tinymist Typst", or any LSP client), point it at the
fonts and the entry file, e.g. in `.vscode/settings.json`:

```json
{
  "tinymist.fontPaths": ["${workspaceFolder}/template/fonts"],
  "tinymist.systemFonts": false
}
```

Open `main.typ` and pin it as the main file ("Typst: Pin the main file") so
previews of chapter files render the whole document.

## Formal requirements

The faculty's formal requirements for the thesis (retrieved from its website on
2026-10-06) take precedence over the template:

- white A4 paper, 12 pt type, justified lines, 1.5 line spacing;
- margins of 2.5 cm inside, outside, top and bottom;
- Arabic page numbers, continuous from the contents to the bibliography;
- every main chapter (level-1 heading) starts on a new page;
- about 50 pages.

The template follows them. Where the original class differed (a 35 mm inner
margin), the requirement wins; the template header and `_margin-inside` in
`template/elteikthesis.typ` record the deviation. With the 2.5 cm margin,
margin todos are narrow: use `#todo(inline: true)[…]` for long ones, since a
long margin note near the foot of a page runs off it (drafts only; `final:
true` hides all todos).

## Template

`template/elteikthesis.typ` is a Typst port of the LaTeX class
[mcserep/elteikthesis](https://github.com/mcserep/elteikthesis) v2.4
(tag `v2.4`, commit `4f0162d9b7`), © 2013–2024 Máté Cserép, Bálint Bognár.
It reproduces the class's page layout, headings, running header, contents and
lists, captions, theorem-like environments, todo notes, title page and
bibliography style, in English and Hungarian (`lang: "en" | "hu"`), with the
class options `parspace`, `noindent`, `nohyp`, `twoside`, `draft` and
`final`. The function signature and helpers are documented at the top of
`template/elteikthesis.typ`.

The port was checked page by page against the upstream example PDFs. The
ported example documents (`elteikthesis_en.typ`, `elteikthesis_hu.typ` and
their `samples_*` chapters) were added in commit `1a915c0` and removed again
when this repository became thesis-only; their last version is in the parent
of the commit that removed them. The upstream repository has the original
LaTeX examples.

Title-page lines that are too long (department, supervisor, affiliation) run
into the margin, as in LaTeX; break them by hand with `\`.

## Bibliography

`thesis.bib` is rendered by `template/biblatex-numeric-{en,hu}.csl`,
which imitate biblatex's `numeric` style (regenerate them with
`python3 template/tools/gen_csl.py` after editing the generator).
The styles mark the type field and Hungarian chapter numbers with private-use
characters that the template's bibliography rules translate, so they work only
inside this template.
Typst's bibliography engine (hayagriva, as bundled with Typst 0.15.1) has a
few limits that no style can work around:

- `version` is never passed to the style, nor an `@inproceedings`'
  `organization` (so e.g. "IEEE." is not printed).
- `howpublished` arrives only if the entry has no `note` (it is then printed
  where biblatex prints `howpublished`); with both, only `note` is printed.
- `subtitle` is not passed either; put it into `title` ("Title: Subtitle")
  if it must appear.
- LaTeX markup such as `\emph{…}` or ``` ``…'' ``` is printed literally
  (accent commands like `\"o` are converted); write plain Unicode text.

For the method forks on GitHub, put the version or commit in `note` and give
the URL with its access date. This pattern renders as
"Given Surname. *ACMH (fork for the thesis benchmark).* Fork of Xu and Tao's
ACMH release, commit 0123abc. 2026. url: https://github.com/gaborpelesz/ACMH
(visited on 10/06/2026)." (in Hungarian: "… (elérés dátuma 2026. 10. 06.)"):

```bibtex
@software{fork_acmh,
  author  = {Surname, Given},
  title   = {{ACMH} (fork for the thesis benchmark)},
  note    = {Fork of Xu and Tao's ACMH release, commit 0123abc},
  url     = {https://github.com/gaborpelesz/ACMH},
  urldate = {2026-10-06},
  year    = {2026},
}
```

`@online` works the same way. Do not rely on `publisher` for `@software`:
biblatex treats `@software` as `@misc`, which does not print a publisher.

## Generated tables

Tables in `generated/` come from the superproject and are never edited here:

- `deviations.*` and `methods-provenance.*` — from the method manifest and the
  forks: `uv run deviations render` (in the superproject's `benchmark/`).
- `results-<campaign>-*` — result tables from a campaign's result store:
  `uv run python -m report render <campaign dir>`. These are git-ignored by
  `generated/.gitignore` and committed deliberately (`git add -f`) only for the
  campaign the thesis quotes.
- Figures: the renderer currently writes pgfplots (LaTeX) figure sources under
  `generated/figures/`, which Typst cannot use. Generated figures are not yet
  available for the Typst manuscript; how they will be produced is pending
  the author's decision. Do not commit those `.tex` figure sources here.

Workflow: render in the superproject, commit the files here, then bump this
submodule in the superproject.

## Generated figure data

Some figures are drawn by Typst from data, and their data is generated here, not
in the superproject. `make figures` runs the scripts; `make build` and
`make watch` run it first, and so does the CI build. The outputs are git-ignored
and never committed; the inputs and the scripts are.

- `generated/dimensioning/` — `data/` and `scripts/` for the plot written to
  `generated/figures/` (needs `uv`).
- `generated/baseline-run/` — the baseline run of production APD-MVS: run files
  in `data/<run>/`, scripts in `scripts/` (needs `python3`, standard library
  only), JSON for `chapters/figures/run-breakdown.typ` and
  `chapters/figures/kernel-breakdown.typ` in `derived/<run>/`. Its `README.md`
  says how the run was made and how to repeat it.

## Licences

- Template (`template/`, except fonts): MIT, see `LICENSE`.
- Fonts (`template/fonts/`): Latin Modern, GUST Font License (LPPL 1.3c),
  see `template/fonts/GUST-FONT-LICENSE.txt` and `template/fonts/README.txt`.
- ELTE logo: shipped with the upstream template (as `elte_cimer_szines.eps`);
  the PDF here is a vector conversion of it.
