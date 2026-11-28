// Appendix of the benchmark (section 5.2): the per-cell interval figure, the runtime per phase class
// in seconds with the comparisons of HPM-MVS++ with HPM-MVS and of ACMM with CUMVS, and at the end
// the large per-scene tables: runtime, and F1, accuracy and completeness at 1, 2, 5 and 10 cm. Every value from generated/bench-5.2/derived/numbers-bench.json
// (generated/bench-5.2/scripts/bench_json.py).
#import "../template/elteikthesis.typ": *
#import "figures/bench-common.typ": *

#let B = bench
#let _cols = B.registry.order.filter(a => has(a) or a in AC)
#let _val(a, s, f) = {
  let blk = if has(a) { A.at(a) } else { AC.at(a) }
  let d = f(blk)
  if s in d { d.at(s) } else { none }
}
#let _tab(f, digits, caption, short, lbl) = [#figure(
  kind: table,
  caption: flex-caption(caption, short),
  {
    set text(size: 7pt)
    set par(justify: false, leading: 0.45em)
    table(
      columns: (auto,) + (1fr,) * _cols.len(),
      align: (left,) + (right,) * _cols.len(),
      stroke: none,
      inset: (x: 2.5pt, y: 2.6pt),
      table.hline(stroke: 0.8pt),
      table.header([*Scene*], .._cols.map(a => rotate(-60deg, reflow: true, text(size: 6.5pt, strong(lab(a)))))),
      table.hline(stroke: 0.5pt),
      ..B.scene_order.map(s => (emph(s), .._cols.map(a => {
        let x = _val(a, s, f)
        if x == none { [--] } else if digits == none { big(x) } else { fix(x, digits) }
      }))).flatten(),
      table.hline(stroke: 0.8pt),
    )
  },
) #label(lbl)]

= Detailed benchmark results <app-bench>

#ref(<table-bench-phase-seconds>) gives the phase classes of #ref(<fig-bench-phases>) in seconds, #ref(<table-bench-phase-hpmpp>) compares HPM-MVS++ with HPM-MVS on the scenes HPM-MVS++ completed, and #ref(<table-bench-acmm-cumvs>) uses the phase classes to compare ACMM with CUMVS. #ref(<fig-bench-cumvs-apd>) compares CUMVS(APD) \@ native with APD-MVS scene by scene. The per-scene tables close the appendix: #ref(<table-bench-scene-time>) gives the runtime of every method on every scene, and #ref(<table-bench-scene-quality>) splits the F1-score of #ref(<fig-bench-scenes>) into accuracy and completeness at 2~cm, with the same split at 1~cm in #ref(<table-bench-scene-quality-1cm>), at 5~cm in #ref(<table-bench-scene-quality-5cm>) and at 10~cm in #ref(<table-bench-scene-quality-10cm>).


#let _w = B.rep.worst_wall
Every runtime cell of #labs(B.rep.wall_all_le1_arms) meets the #(1)% target of #ref(<sec:benchmark-dimensioning>)\; the cells that miss it belong to the capped methods, the widest being #lab(_w.arm) on #scene(_w.scene) with #sym.plus.minus#fix(_w.wall_hw_pct, 1)% (#ref(<fig-bench-repeatability>)). // src: v.rep (runs.csv, ok cells with 5 runs)

#bench-figure("bench-repeatability",
  [Half-width of the #B.ci_level_pct% confidence interval of every cell ($n = #B.n_rep$) relative to the cell mean, for (a) the runtime and (b) F1 at 2~cm; the line marks the #(1)% target of #ref(<sec:benchmark-dimensioning>).],
  [Repeatability of the benchmark cells], "fig-bench-repeatability")


// ---- runtime per phase class, in seconds -----------------------------------------------------------
// src: v.arms.*.class_s (phase-categories.csv, self_s summed over the scenes, mean of the repeats;
// the classes of bench_json.py CLASSES, as in <fig-bench-phases>), v.arms.*.passes_per_image
// (runs.csv image_pass_count / n_images), v.arms.*.wall_total_s.
// (key, name, short name for a column header)
#let _classes = (
  ("input_load", [Input loading], [Input\ loading]), ("transfer", [Host--device transfers], [Transfers]),
  ("patchmatch", [PatchMatch], [Patch-\ Match]), ("prior_aux", [Priors and auxiliary passes], [Priors,\ auxiliary]),
  ("fusion", [Fusion], [Fusion]), ("write", [Writing], [Writing]), ("other", [Other], [Other]),
)
#let _phase-row(key) = {
  let a = arm(key)
  (lab(key), str(a.passes_per_image), .._classes.map(((c, ..)) => big(a.class_s.at(c))), strong(big(a.wall_total_s.mean)))
}
#let _capped = (k.acmh, k.acmp, k.acmm, k.acmmp, k.mp, k.hpm, k.cumvs, k.ours3200).filter(has)
#let _native = (k.apd, k.dpe, k.oursnat).filter(has)
#let _head(body) = align(bottom, strong(body))

#figure(
  kind: table,
  caption: flex-caption(
    [Runtime per phase class in seconds, summed over the #B.n_scenes scenes (phase timers, self time, mean of #spell(B.n_rep) repeats), with the number of image passes that a method makes per image. The classes are those of #ref(<fig-bench-phases>): transfers are the host--device transfers, and priors and auxiliary passes differ by method. HPM-MVS++ is not listed (#spell(B.common_scenes.len()) of #B.n_scenes scenes); #ref(<table-bench-phase-hpmpp>) compares it with HPM-MVS on its scenes.],
    [Runtime per phase class in seconds]),
  {
    set text(size: 8pt)
    set par(justify: false, leading: 0.5em)
    table(
      columns: (auto,) + (1fr,) * (_classes.len() + 2),
      align: (left,) + (right,) * (_classes.len() + 2),
      stroke: none,
      inset: (x: 3pt, y: 3pt),
      table.hline(stroke: 0.8pt),
      table.header(_head[Method], _head[Passes\ per image], .._classes.map(((_, _, short)) => _head(short)), _head[Total]),
      table.hline(stroke: 0.5pt),
      table.cell(colspan: _classes.len() + 3, inset: (top: 5pt, bottom: 2pt), emph[Capped at 3200 px]),
      .._capped.map(_phase-row).flatten(),
      table.cell(colspan: _classes.len() + 3, inset: (top: 5pt, bottom: 2pt), emph[Native resolution]),
      .._native.map(_phase-row).flatten(),
      table.hline(stroke: 0.8pt),
    )
  },
) <table-bench-phase-seconds>

// ---- HPM-MVS++ against HPM-MVS on the scenes HPM-MVS++ completed --------------------------------
// src: v.arms_common.{hpm,hpmpp}.{class_s, wall_total_s, passes_per_image, n_scenes}
// (as above, restricted to v.common_scenes); divided by n_scenes for the mean per scene.
#let _common-row(key) = {
  let a = AC.at(key)
  let n = a.n_scenes
  (lab(key), str(a.passes_per_image), .._classes.map(((c, ..)) => big(a.class_s.at(c) / n)), strong(big(a.wall_total_s.mean / n)))
}
#let (_hp, _hpp) = (AC.at(k.hpm), AC.at(k.hpmpp))
#assert(_hp.n_scenes == _hpp.n_scenes, message: "HPM-MVS and HPM-MVS++ no longer cover the same scenes")
#let _ratio(x, y) = if x > 0 { times(y / x, 1) } else { [--] }

#figure(
  kind: table,
  caption: flex-caption(
    [Runtime per phase class of HPM-MVS++ and HPM-MVS in seconds, averaged over the #spell(B.common_scenes.len()) scenes that HPM-MVS++ completed (#enumerate-and(B.common_scenes.map(scene))), with the ratio of the two. Phase timers, self time, mean of #spell(B.n_rep) repeats; classes as in #ref(<table-bench-phase-seconds>).],
    [Runtime per phase class of HPM-MVS++ against HPM-MVS]),
  {
    set text(size: 8pt)
    set par(justify: false, leading: 0.5em)
    table(
      columns: (auto,) + (1fr,) * (_classes.len() + 2),
      align: (left,) + (right,) * (_classes.len() + 2),
      stroke: none,
      inset: (x: 3pt, y: 3pt),
      table.hline(stroke: 0.8pt),
      table.header(_head[Method], _head[Passes\ per image], .._classes.map(((_, _, short)) => _head(short)), _head[Total]),
      table.hline(stroke: 0.5pt),
      .._common-row(k.hpm), .._common-row(k.hpmpp),
      table.hline(stroke: 0.5pt),
      [HPM-MVS++ / HPM-MVS], times(_hpp.passes_per_image / _hp.passes_per_image, 0),
      .._classes.map(((c, ..)) => _ratio(_hp.class_s.at(c), _hpp.class_s.at(c))),
      strong(_ratio(_hp.wall_total_s.mean, _hpp.wall_total_s.mean)),
      table.hline(stroke: 0.8pt),
    )
  },
) <table-bench-phase-hpmpp>

// ---- ACMM against CUMVS ---------------------------------------------------------------------------
#let (_am, _cu) = (arm(k.acmm), arm(k.cumvs))
#let _saved(c) = _am.class_s.at(c) - _cu.class_s.at(c)
#let _saved-total = _am.wall_total_s.mean - _cu.wall_total_s.mean
// premises of the paragraph below
#assert(_am.passes_per_image == _cu.passes_per_image, message: "ACMM and CUMVS no longer make the same number of image passes: rewrite the paragraph")
#assert(_saved("input_load") > _saved("fusion") and _saved("fusion") > _saved("patchmatch") and _saved("patchmatch") > 0, message: "the order of the savings of CUMVS over ACMM changed: rewrite the paragraph")

CUMVS is a simplified reimplementation of ACMH and ACMM, and it makes the same #_am.passes_per_image image passes per image as ACMM, so the phases of the two can be compared directly (#ref(<table-bench-acmm-cumvs>)). The PatchMatch phase of CUMVS takes #big(_cu.class_s.patchmatch)~s against #big(_am.class_s.patchmatch)~s for ACMM, #pct(1 - _cu.class_s.patchmatch / _am.class_s.patchmatch, 0) less, while its whole run is #times(_am.wall_total_s.mean / _cu.wall_total_s.mean, 1) shorter. Of the #big(_saved-total)~s that CUMVS saves over the #B.n_scenes scenes, #pct(_saved("input_load") / _saved-total, 0) are input loading, #pct(_saved("fusion") / _saved-total, 0) fusion and #pct(_saved("patchmatch") / _saved-total, 0) the PatchMatch phase. Most of the speedup of CUMVS therefore comes from the implementation around the kernels, not from the kernels. Two limits apply to this reading. The PatchMatch class is the time of the phase timer around the PatchMatch stage, not a profile of the kernels. And CUMVS simplifies ACMM's algorithm, so the difference in this phase contains algorithmic changes as well as faster kernels.

#figure(
  kind: table,
  caption: flex-caption(
    [ACMM against CUMVS per phase class, in seconds over the #B.n_scenes scenes: the time that CUMVS saves and its share of the whole saving. A negative value is a phase in which CUMVS takes longer.],
    [ACMM against CUMVS per phase class]),
  {
    set text(size: 8.5pt)
    set par(justify: false, leading: 0.5em)
    table(
      columns: (auto, auto, auto, auto, auto),
      align: (left, right, right, right, right),
      stroke: none,
      inset: (x: 7pt, y: 3pt),
      table.hline(stroke: 0.8pt),
      table.header([*Phase class*], [*ACMM (s)*], [*CUMVS (s)*], [*Saved (s)*], [*Share of the saving*]),
      table.hline(stroke: 0.5pt),
      .._classes.map(((c, name, _)) => (name, big(_am.class_s.at(c)), big(_cu.class_s.at(c)), signed(_saved(c), 0).replace("+", ""), pct(_saved(c) / _saved-total, 1))).flatten(),
      table.hline(stroke: 0.5pt),
      [*Total*], strong(big(_am.wall_total_s.mean)), strong(big(_cu.wall_total_s.mean)), strong(big(_saved-total)), [],
      table.hline(stroke: 0.8pt),
    )
  },
) <table-bench-acmm-cumvs>

#bench-figure("bench-cumvs-apd",
  [CUMVS(APD) \@ native against APD-MVS, per scene, ordered by the speedup. (a) Speedup: the runtime of APD-MVS over that of CUMVS(APD) (ratio of the cell means, with #B.ci_level_pct% intervals); dashed: the ratio of the #(B.n_scenes)-scene totals, #times(B.ours.speedup.mean, 2). (b) Difference in F1 at 2~cm, CUMVS(APD) minus APD-MVS, with its #B.ci_level_pct% interval (Welch, #spell(B.n_rep) repeats each); filled: the interval excludes zero; dashed: the difference of the #(B.n_scenes)-scene means.],
  [CUMVS(APD) against APD-MVS per scene], "fig-bench-cumvs-apd")

// ---- per-scene tables, at the end of the appendix because of their size ---------------------------
#_tab(b => b.scene_wall_s, none,
  [Runtime per scene and method in seconds (method time, converter excluded), mean of #spell(B.n_rep) repeats. --: no successful run.],
  [Runtime per scene and method], "table-bench-scene-time")

// F1, accuracy and completeness per scene: three rows per scene, the best method of each row in bold.
// src: v.arms.*.scene_quality.<t>.{f1, acc, comp} (v.arms_common for HPM-MVS++); runs.csv f1_<t>,
// acc_<t>, comp_<t>, mean of the repeats of a cell; t = 1cm, 2cm, 5cm, 10cm.
#let _metrics(t) = ("f1", "acc", "comp").zip(([F1], [Acc.], [Comp.])).map(((m, name)) => (name, b => b.scene_quality.at(t).at(m)))
#let _quality-rows(t, s) = {
  let cells = ()
  for (i, (name, f)) in _metrics(t).enumerate() {
    let vals = _cols.map(a => _val(a, s, f))
    // compared as printed, so that two arms with the same three decimals are both bold
    let best = calc.round(calc.max(..vals.filter(x => x != none)), digits: 3)
    if i == 0 { cells.push(table.cell(rowspan: _metrics(t).len(), align: left + horizon, emph(s))) }
    cells.push(text(fill: luma(35%), name))
    for x in vals {
      cells.push(if x == none { [--] } else if calc.round(x, digits: 3) >= best { strong(fix(x, 3)) } else { fix(x, 3) })
    }
  }
  cells
}
#let _quality-tab(t, dist, lbl) = [#figure(
  kind: table,
  caption: flex-caption(
    [F1, accuracy and completeness at #dist per scene and method, mean of #spell(B.n_rep) repeats; the best method of each row in bold (ties as printed). Scenes in the order of #ref(<fig-bench-scenes>). --: no successful run.],
    [F1, accuracy and completeness at #dist per scene and method]),
  {
    set text(size: 7pt)
    set par(justify: false, leading: 0.45em)
    table(
      columns: (auto, auto) + (1fr,) * _cols.len(),
      align: (left, left) + (right,) * _cols.len(),
      stroke: none,
      inset: (x: 2.5pt, y: 2.1pt),
      table.hline(stroke: 0.8pt),
      table.header(
        // the tolerance of the table, top left, so that a reader paging through the four tables knows which one is open
        table.cell(colspan: 2, align: left + top, stack(spacing: 6pt,
          box(fill: luma(88%), inset: (x: 4pt, y: 3pt), radius: 2pt, text(size: 9pt, strong(dist))),
          strong[Scene])),
        .._cols.map(a => rotate(-60deg, reflow: true, text(size: 6.5pt, strong(lab(a)))))),
      table.hline(stroke: 0.5pt),
      ..B.scene_order.enumerate().map(((i, s)) => (
        if i > 0 { (table.hline(stroke: 0.3pt + luma(70%)),) } else { () } + _quality-rows(t, s)
      )).flatten(),
      table.hline(stroke: 0.8pt),
    )
  },
) #label(lbl)]

#_quality-tab("1cm", [1~cm], "table-bench-scene-quality-1cm")
#_quality-tab("2cm", [2~cm], "table-bench-scene-quality")
#_quality-tab("5cm", [5~cm], "table-bench-scene-quality-5cm")
#_quality-tab("10cm", [10~cm], "table-bench-scene-quality-10cm")
