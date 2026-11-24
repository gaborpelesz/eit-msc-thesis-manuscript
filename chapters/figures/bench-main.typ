// Headline benchmark results per method (section 5.2): quality at 2 cm, runtime, speed relative to
// CUMVS, peak device memory and GPU energy, split into the capped and the native-resolution arms.
//
// Every number is read through bench-common.typ from
//   ../../generated/bench-5.2/derived/numbers-bench.json
// Do not type numbers into this file.
//
// Use:  #import "figures/bench-main.typ": bench-main-table
//       then  #place(auto, float: true, clearance: 22pt, bench-main-table)
#import "bench-common.typ": *

#let B = bench
// The best value of each column is set in bold, compared at the printed precision so that ties are
// all bold: the largest for F1, accuracy and completeness, the smallest for the others.
#let _main_keys = (k.acmh, k.acmp, k.acmm, k.acmmp, k.mp, k.hpm, k.cumvs, k.ours3200, k.apd, k.dpe, k.oursnat)
#let _main_cols = (
  f1:   (a => a.f1_2cm.mean, 3, calc.max),
  acc:  (a => a.acc_2cm.mean, 3, calc.max),
  comp: (a => a.comp_2cm.mean, 3, calc.max),
  time: (a => a.wall_total_s.mean, 0, calc.min),
  x:    (a => a.x_cumvs, 1, calc.min),
  mem:  (a => a.peak_dev_mib, 0, calc.min),
  kj:   (a => a.energy_total_kj, 0, calc.min),
)
#let _best = {
  let present = _main_keys.filter(has)
  for (c, (get, d, pick)) in _main_cols {
    ((c): pick(..present.map(key => calc.round(get(arm(key)), digits: d))))
  }
}
#let _b(a, c, body) = {
  let (get, d, _) = _main_cols.at(c)
  if calc.round(get(a), digits: d) == _best.at(c) { strong(body) } else { body }
}
#let _row(key) = if has(key) {
  let a = arm(key)
  (lab(key), _b(a, "f1", fix(a.f1_2cm.mean, 3)), _b(a, "acc", fix(a.acc_2cm.mean, 3)), _b(a, "comp", fix(a.comp_2cm.mean, 3)),
   _b(a, "time", [#big(a.wall_total_s.mean) #hw(a.wall_total_s, 0)]), _b(a, "x", times(a.x_cumvs, 1)),
   _b(a, "mem", big(a.peak_dev_mib)), _b(a, "kj", big(a.energy_total_kj)))
} else {
  (lab(key), table.cell(colspan: 7, align: center, text(fill: luma(45%), style: "italic")[no runs]))
}
#let bench-main-table = [#figure(
  kind: table,
  caption: flex-caption([
    Headline results per method over the #B.n_scenes scenes. F1-score, accuracy, and completeness are averaged at 2~cm, the total runtime is the method time summed over the scenes (converter excluded), with the half-width of its #B.ci_level_pct% confidence interval. Peak device memory is the largest over all runs; GPU energy is summed over the scenes.
  ], [Headline benchmark results per method]),
  {
    set text(size: 8.5pt)
    set par(justify: false, leading: 0.5em)
    table(
      columns: (auto, auto, auto, auto, auto, auto, auto, auto),
      align: (left, right, right, right, right, right, right, right),
      stroke: none,
      inset: (x: 4pt, y: 3pt),
      table.hline(stroke: 0.8pt),
      table.header([*Method*], [*F1*], [*Acc.*], [*Comp.*], [*Time (s)*], [*Time #sym.times baseline (CUMVS)*], [*Peak GPU mem. (MiB)*], [*Energy (kJ)*]),
      table.hline(stroke: 0.5pt),
      table.cell(colspan: 8, inset: (top: 5pt, bottom: 2pt), emph[Capped at 3200 px]),
      .._row(k.acmh), .._row(k.acmp), .._row(k.acmm), .._row(k.acmmp), .._row(k.mp), .._row(k.hpm), .._row(k.cumvs), .._row(k.ours3200),
      table.cell(colspan: 8, inset: (top: 5pt, bottom: 2pt), emph[Native resolution]),
      .._row(k.apd), .._row(k.dpe), .._row(k.oursnat),
      table.hline(stroke: 0.8pt),
    )
  },
) <table-bench-main>]
// src (the whole table): v.arms.<key>.{f1_2cm, acc_2cm, comp_2cm, wall_total_s, x_cumvs, peak_dev_mib, energy_total_kj} (runs.csv, ok runs)
