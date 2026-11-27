// The ablation of the performance changes of the optimization chapter as a table: one row per
// commit, in the order in which the changes are applied, with the commit, the exactness class, the
// mean run time, the change of the run time against the row before (mean and confidence interval,
// paired by seed) and, for the rows that change the result, the difference in F1.
// Ported from the draft of the engineering notes (production-apd-mvs
// .dev/perf/thesis-4.3/thesis/chapters/figures/perf-ablation.typ, the table only; the bar chart
// of the same rows, perf-ablation-figure, is not ported).
//
// Every number and every mark is computed from
//   ../../generated/perf-4.3/derived/ablation.json
// which generated/perf-4.3/scripts/perf43_json.py writes from generated/perf-4.3/data/ablation.csv
// and ablation-f1.csv. Do not type numbers into this file.
// src: thesis-4.3/stack/data/ablation.csv (d_prev_s, d_prev_lo, d_prev_hi, span_mean_s, class_vs_prev, stack_commit); thesis-4.3/stack/main-hash-map.md (main SHA, tag)
//
// Use:  #import "figures/perf-ablation.typ": perf-ablation-table
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _d = json("../../generated/perf-4.3/derived/ablation.json")
#let _rows = _d.rows.filter(r => r.vs_prev != none and r.key != "stack")   // the commits
#let _image = _d.rows.find(r => r.key == "stack")
#let _base = _d.rows.first()
#assert(_rows.len() == _d.commits)
#for r in _d.rows { assert(r.key in ablation-rows, message: "no description for row " + r.key) }
#for s in _d.stages { assert(s.key in final-stages, message: "no description for stage " + s.key) }
#let _number(key) = _rows.position(r => r.key == key) + 1

// ---- the same rows as a table, with the commits and the F1 differences ---------------------------
#let _dagger(r) = if r.f1 != none and (r.f1.at2cm.bridged.row.len() > 0 or r.f1.at2cm.bridged.prev.len() > 0) { super[†] }
#let perf-ablation-table = [#figure(
  kind: table,
  caption: flex-caption([
    Ablation of the performance changes of this work on ETH3D _pipes_ at native resolution: one row per commit, in the order in which the changes are applied. The columns are explained in the text. Run times are means over seeds #_d.seeds.first() to #_d.seeds.last(), and changes are against the row before, with their #_d.ci_level_pct% confidence interval. Measured on the development machine with unlocked clocks.
  ], [Ablation of the performance changes]),
  {
    set text(size: 7.5pt)
    show raw: set text(size: 7pt)
    set par(justify: false, leading: 0.4em)
    let cells = ()
    for s in _d.stages {
      cells.push(table.cell(colspan: 8, align: left, inset: (top: 5pt, bottom: 2pt), [#emph(strong(final-stages.at(s.key)))#if s.tag != none [ (ends at tag #raw(s.tag))]]))
      for r in _rows.filter(r => r.key in s.rows) {
        cells += (
          [#_number(r.key)], ablation-rows.at(r.key), raw(r.main), raw(r.commit), [#r.class], fix(r.run_s, 1), diff-ci(r.vs_prev, 1),
          if r.f1 != none [#diff-ci(r.f1.at2cm, 4)#_dagger(r)] else [],
        )
      }
    }
    table(
      columns: (auto, 1fr, auto, auto, auto, auto, auto, auto),
      align: (right, left, left, left, center, right, right, right),
      stroke: none,
      inset: (x: 3pt, y: 2.4pt),
      table.hline(stroke: 0.8pt),
      table.header([], [*Change*], [*Commit*], [*Measured as*], [*Class*], [*Run (s)*], [*Change (s)*], [*$bold(Delta)$F1 at #_d.decides_cm cm*]),
      table.hline(stroke: 0.5pt),
      [], [#ablation-rows.at("base2") (tag #raw(_base.tag))], raw(_base.main), raw(_base.commit), [], fix(_base.run_s, 1), [], [],
      ..cells,
      table.hline(stroke: 0.5pt),
      [], ablation-rows.at("stack"), raw(_image.main), raw(_image.commit), [], fix(_image.run_s, 1), diff-ci(_image.vs_prev, 1), [],
      table.hline(stroke: 0.8pt),
    )
  },
) <table-perf-ablation>]
