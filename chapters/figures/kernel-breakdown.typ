// Kernel time of the baseline run of production APD-MVS by CUDA kernel: launches, total and
// share per kernel, grouped by the stage of the thesis timing table (<table-timing-measurements>)
// the kernel is launched in, with a bar per kernel that splits its time over the four rounds.
// One level below the stage table (<fig-run-breakdown>), same run.
//
// Every number and every mark is computed from
//   ../../generated/baseline-run/derived/perf-nsys-r1/kernel-breakdown.json
// which `make figures` writes with generated/baseline-run/scripts/kernel_breakdown.py from the
// per-launch extract of the run's Nsight Systems trace (launches.tsv) and from the stage timings
// of the same run. The file is not committed (generated/baseline-run/README.md). Do not type
// numbers into this file.
//
// Use:  #include "figures/kernel-breakdown.typ"
//  or:  #import "figures/kernel-breakdown.typ": kernel-breakdown-table   then   #kernel-breakdown-table
#import "@preview/cetz:0.4.2"
#import "../../template/elteikthesis.typ": flex-caption

#let _d = json("../../generated/baseline-run/derived/perf-nsys-r1/kernel-breakdown.json")
#let _ctx = _d.meta.context

// Descriptions of the run that its files do not hold (source: .dev/perf/runs.md and REPORT.md
// of the production-apd-mvs checkout).
#let _scene = "pipes"
#let _profiler = (nsys: [Nsight Systems attached], plain: [no profiler]).at(_ctx.mode)

// ---- prose for the rows --------------------------------------------------------------------
// Stage names as in <table-timing-measurements>; the kernels of a stage come from the data.
#let _stage-name = (
  "patchmatch.init": [initialization],
  "patchmatch.propagate": [propagation],
  "prior_build": [planar prior],
  "patchmatch.finalize": [finalization],
)
// What a kernel does, in the words of the algorithm description (<alg:apd-imagepass>). Kernel
// names are code identifiers and are printed as the data spells them. Set to false to drop the
// second line of the kernel rows.
#let _show-roles = true
#let _role = (
  "InitRandomStates": [one random generator per pixel],
  "FindNearestStrongPoint": [nearest reliable pixel],
  "GenNeighbours": [anchor selection],
  "NeigbourUpdate": [removes anchorless pixels],
  "RandomInitialization": [initial planes and their costs],
  "Black/RedPixelUpdateStrong": [update of all but unreliable pixels],
  "Black/RedPixelUpdateWeak": [update of the unreliable pixels],
  "RANSACToGetFitPlane": [plane fit to the anchors],
  "GetDepthandNormal": [planes to depth and normal],
  "Black/RedPixelFilterStrong": [median filter of the depths],
  "DepthToWeak": [reliability evaluation],
  "LocalRefine": [local depth search],
)
// kernels that only have work on unreliable pixels (early return or plain copy otherwise)
#let _unreliable-only = ("FindNearestStrongPoint", "GenNeighbours", "NeigbourUpdate", "RANSACToGetFitPlane", "Black/RedPixelUpdateWeak")

// ---- rows: per stage, a stage row and its kernels in launch order -----------------------------
#let _rows = {
  let out = ()
  for s in _d.stages {
    out.push((kind: "stage", s: s))
    for k in _d.kernels.filter(k => k.stage == s.key) { out.push((kind: "kernel", k: k)) }
  }
  out
}
#for k in _d.kernels {
  assert(k.name in _role, message: "no description for kernel " + k.name)
}
#for k in _unreliable-only {
  assert(_d.kernels.any(r => r.name == k), message: "no kernel " + k + " in the data")
}

// ---- style ---------------------------------------------------------------------------------
// The rounds are an ordered quantity: one hue, light to dark, through the blue that marks GPU
// kernels in <fig-run-breakdown>. Adjacent steps stay apart under simulated
// colour-vision deficiency and in greyscale.
#let _ramp = ("#b9d2f3", "#74a6e6", "#2a78d6", "#123a70").map(rgb)
#assert(_d.rounds.len() == _ramp.len(), message: "the ramp has one step per round")
#let _h-stage = 16pt                                  // stage row
#let _h-kernel = if _show-roles { 20pt } else { 14pt }   // kernel row
#let _role-gap = 1pt                                  // between a kernel name and its description
#let _h-axis = 15pt                                   // axis under the bars
#let _bar = 9pt                                       // bar height
#let _chart-w = 170pt                                 // width of the bar column
#let (_pad-l, _pad-r) = (5pt, 9pt)                    // space left of zero and right of the axis end
#let _muted = luma(42%)
#let _axis-ink = luma(35%)

// axis: the smallest round maximum that holds the longest bar, at most six labelled ticks
#let _t-max = calc.max(.._d.kernels.map(k => k.total_s))
#let _step = (1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000).find(c => _t-max / c <= 5)
#let _axis-max = calc.ceil(_t-max / _step) * _step
#let _pt-per-s = (_chart-w - _pad-l - _pad-r) / 1pt / _axis-max

// booktabs-style rule, as in chapters/methodology.typ
#let _rule(w) = table.hline(stroke: w)

// ---- number formatting ---------------------------------------------------------------------
#let _fix(x, digits) = {
  let s = str(calc.round(x, digits: digits))
  if digits == 0 { return s }
  if not s.contains(".") { s += "." }
  s + "0" * (digits - s.split(".").at(1).len())
}
// one decimal; anything that would print as 0.0 is given as an upper bound
#let _one(x) = if x < 0.05 { [<~0.1] } else { _fix(x, 1) }
// the resolution of a round from its scale index: scale s works at 1/2^s
#let _round-res = _d.rounds.map(r => if r.scale == 0 { "native" } else { "1/" + str(calc.pow(2, r.scale)) })

// ---- numeric columns -----------------------------------------------------------------------
// One entry per column: header and the cell of a stage row, a kernel row and the total row. A
// column for another run (a before/after pair) is one more entry that reads that run's JSON.
#let _cols = (
  (head: [*Launches*], stage: s => [#s.launches], kernel: k => [#k.launches], total: [#_d.launches]),
  (head: [*Total (s)*], stage: s => _one(s.kernel_s), kernel: k => _one(k.total_s), total: _one(_d.kernel_s)),
  (head: [*Share (%)*\ #text(size: 7pt, fill: _muted)[of kernel time]], stage: s => _one(100 * s.kernel_s / _d.kernel_s),
    kernel: k => _one(100 * k.total_s / _d.kernel_s), total: _fix(100, 1)),
)

// ---- the bars: one canvas behind all body rows ----------------------------------------------
#let _bars = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = _chart-w / 1pt
  let total-h = (_rows.map(r => if r.kind == "stage" { _h-stage } else { _h-kernel }).sum() + _h-axis) / 1pt
  let x(t) = _pad-l / 1pt + _pt-per-s * t
  let bar = _bar / 1pt
  let axis-y = _h-axis / 1pt - 3

  rect((0, 0), (w, total-h), stroke: none)   // fixes the canvas to the cell

  let top = total-h
  for r in _rows {
    if r.kind == "stage" {
      // the stage's host-side total, for comparison with the kernel time in the Total column
      let h = _h-stage / 1pt
      content((x(0), top - h / 2), anchor: "west",
        text(size: 7pt, fill: _muted)[phase timer: #_one(r.s.span_s)~s])
      top -= h
      continue
    }
    let h = _h-kernel / 1pt
    let yb = top - h + (h - bar) / 2
    // grid, kernel rows only
    for i in range(1, int(_axis-max / _step) + 1) {
      line((x(i * _step), top - h), (x(i * _step), top), stroke: (paint: luma(72%), thickness: 0.3pt, dash: "dotted"))
    }
    // zero line, drawn left of zero so that it covers no part of a bar
    rect((x(0) - 0.4, top - h), (x(0), top), fill: _axis-ink, stroke: none)
    // the bar: its length is the kernel's total time, its segments are the rounds in order
    let t = 0
    let edges = ()
    for (i, v) in r.k.round_s.enumerate() {
      if v > 0 { rect((x(t), yb), (x(t + v), yb + bar), fill: _ramp.at(i), stroke: none) }
      // a white hairline between two segments that are both wide enough to carry one
      if i > 0 and _pt-per-s * v >= 2 and _pt-per-s * r.k.round_s.at(i - 1) >= 2 { edges.push(x(t)) }
      t += v
    }
    for e in edges { line((e, yb), (e, yb + bar), stroke: 0.3pt + white) }
    top -= h
  }

  // axis
  line((x(0), axis-y), (x(_axis-max), axis-y), stroke: 0.4pt + _axis-ink)
  for i in range(0, 2 * int(_axis-max / _step) + 1) {
    let t = i * _step / 2
    let major = calc.rem(i, 2) == 0
    line((x(t), axis-y), (x(t), axis-y - if major { 2.2 } else { 1.2 }), stroke: 0.4pt + _axis-ink)
    if major {
      content((x(t), axis-y - 3.2), anchor: "north", text(size: 6.5pt, fill: _muted, str(t)))
    }
  }
})

// ---- the table -----------------------------------------------------------------------------
#let _n-body = _rows.len() + 1   // stage and kernel rows, plus the axis row
#let _cells = {
  let out = ()
  let first = true
  for r in _rows {
    if r.kind == "stage" {
      out.push(_stage-name.at(r.s.key))
      out += _cols.map(c => (c.stage)(r.s))
    } else {
      // name and description as one unit; a description never wraps (keep it short)
      out.push(pad(left: 1em, stack(spacing: _role-gap, text(size: 8pt, r.k.name),
        ..if _show-roles { (box(text(size: 7pt, fill: _muted, _role.at(r.k.name))),) })))
      out += _cols.map(c => (c.kernel)(r.k))
    }
    if first {
      out.push(table.cell(rowspan: _n-body, inset: 0pt, align: left + top, _bars))
      first = false
    }
  }
  out.push(table.cell(colspan: 1 + _cols.len(), align: right + horizon,
    text(size: 7pt, fill: _muted)[total time of the kernel (s)]))
  out
}

#let _legend = {
  set text(size: 7.5pt)
  [Rounds, with the time of all kernels in each:#h(0.9em)]
  _d.rounds.enumerate().map(((i, r)) => box[#box(width: 0.75em, height: 0.75em, baseline: 0.05em, fill: _ramp.at(i)) #(i + 1)~(#_round-res.at(i)) #_one(r.kernel_s)~s]).join(h(1.1em))
}

// ---- notes under the table, all counts and durations from the data ---------------------------
#let _n-round = _d.rounds.len()
// references to the two companion tables; a stand-alone preview has neither
#let _stage-ref = context {
  if query(<fig-run-breakdown>).len() > 0 { ref(<fig-run-breakdown>) } else [the run breakdown figure]
}
#let _timing-ref = context {
  if query(<table-timing-measurements>).len() > 0 { ref(<table-timing-measurements>) } else [the timing table]
}
// smallest share of a stage's phase-timer total that its kernels account for, rounded down and
// with the rounding of the extract counted against it
#let _coverage = calc.floor(1000 * calc.min(.._d.stages.map(s => (s.kernel_s - s.rounding_s) / s.span_s))) / 10
// the kernels launched once per iteration are exactly those of the propagation and the planar prior
#let _iter-stages = ("patchmatch.propagate", "prior_build")
#for k in _d.kernels {
  assert((k.per_pass == _d.iterations * k.members.len()) == (k.stage in _iter-stages) and
    (k.per_pass == k.members.len()) == (k.stage not in _iter-stages),
    message: k.name + " is not launched as the Counts note says")
}
#let _round1-idle = _d.kernels.filter(k => k.name in _unreliable-only)
#let _names(ks) = {
  let parts = ks.map(k => raw(k.name))
  if parts.len() > 1 { parts.slice(0, -1).join([, ]) + [ and ] + parts.last() } else { parts.first() }
}
// share of the last round in the time of every kernel above 1 s: smallest and largest, in percent
#let _last-round-share = {
  let v = _d.kernels.filter(k => k.total_s > 1).map(k => 100 * k.round_s.last() / k.total_s)
  (calc.floor(calc.min(..v)), calc.ceil(calc.max(..v)))
}

/*
#let _notes = {
  // the template's strut, set here too so that the notes look the same in a stand-alone preview
  set text(size: 8pt, top-edge: 0.7em, bottom-edge: -0.3em)
  set par(justify: true, leading: 0.25em, spacing: 0.6em)
  show raw: set text(size: 8pt)
  [
    _Columns._ Launches counts the launches of a kernel, total sums their durations on the GPU as the Nsight Systems trace records them, and share relates the total to the time of all kernels, not to the reconstruction span as the share of #_stage-ref does. A row named #raw("Black/Red…") sums the black and the red kernel of a checkerboard pair. A stage row sums the kernels launched inside the stage. #if _show-roles [The grey line under a kernel name says what the kernel does. ]The trace extract rounds a duration to #_d.meta.duration_step_ms~ms, so a total is exact to #(_d.meta.duration_step_ms / 2)~ms per launch (#calc.round(1000 * _d.rounding_s)~ms over all launches).

    _Bars._ The length of a bar is the total time of the kernel, on one scale for all rows. Its segments are rounds 1 to #_n-round (#_round-res.slice(0, -1).join(", ") and #_round-res.last() resolution), from light to dark. Nothing is widened: a kernel under about #calc.max(1, calc.round(0.35 / _pt-per-s))~s leaves no visible bar, and round 1 is below the line width in every row. Every kernel above 1~s spends #_last-round-share.at(0) to #_last-round-share.at(1)% of its time in round #_n-round.

    _Stages._ The stage times of #_stage-ref are host-side spans of the phase timer around the synchronous kernel calls of a stage. They are repeated in grey in the stage rows, next to the sum of the kernels in the total column. The kernels account for at least #_fix(_coverage, 1)% of every one of them. The planar prior is fitted between the two propagation kernels of an iteration, so it is listed after the propagation. All kernels together take #_one(_d.kernel_s)~s, which is #_one(100 * _d.kernel_s / _d.run_s)% of the reconstruction span of #_one(_d.run_s)~s.

    _Counts._ Each of the #_d.passes reference image passes makes the same #_d.launches_per_pass launches: the kernels of the #_iter-stages.map(s => _stage-name.at(s)).join([ and the ]) once in each of the #_d.iterations iterations, every other kernel once. In round 1 no pixel is unreliable, so #_names(_round1-idle) have no unreliable pixel to work on there: their #_round1-idle.map(k => k.round_launches.at(0)).sum() launches take #_one(_round1-idle.map(k => k.round_s.at(0)).sum())~s together.
  ]
}
*/

#let kernel-breakdown-table = [#figure(
  kind: table,
  caption: flex-caption([
    GPU kernel times of the baseline run of CUMVS(APD) on ETH3D _#_scene;_ at native resolution. Results are shown by kernel, stage (#_timing-ref) and round. Same run as #_stage-ref.
  ], [GPU kernel times of the baseline run of CUMVS(APD)]),
  block(breakable: false, {
    // the template's strut, set here too so that rows look the same in a stand-alone preview
    set text(size: 9pt, top-edge: 0.7em, bottom-edge: -0.3em)
    set par(justify: false, leading: 0.3em)
    show raw: set text(size: 8pt)
    table(
      columns: (1fr,) + (auto,) * _cols.len() + (_chart-w,),
      rows: (auto,) + _rows.map(r => if r.kind == "stage" { _h-stage } else { _h-kernel }) + (_h-axis, auto, auto, auto),
      align: (left + horizon,) + (right + horizon,) * _cols.len() + (left + horizon,),
      stroke: none,
      inset: (x: 5pt, y: 0pt),
      _rule(1pt),
      table.header(
        ..([*Stage and kernel*], .._cols.map(c => c.head), [*Time by round*]).map(c => table.cell(inset: (x: 5pt, y: 4pt), c)),
      ),
      _rule(0.5pt),
      .._cells,
      _rule(0.5pt),
      ..([all kernels], .._cols.map(c => c.total), []).map(c => table.cell(inset: (x: 5pt, y: 4pt), c)),
      table.cell(colspan: 2 + _cols.len(), inset: (x: 5pt, top: 1pt, bottom: 4pt), _legend),
      // _rule(0.5pt),
      // table.cell(colspan: 2 + _cols.len(), align: left + top, inset: (x: 5pt, top: 4pt, bottom: 4pt), _notes),
      _rule(1pt),
    )
  }),
) <table-kernel-breakdown>]

#kernel-breakdown-table
