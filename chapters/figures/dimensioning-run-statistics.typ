// Run statistics of the dimensioning experiment (<sec:benchmark-dimensioning>): per cell (method
// and scene) the lag-1 autocorrelation of the run series against its ±2/√n band, and the drift
// over the series with its 95 % interval, for wall time and for F1 at 2 cm. Four panels on shared
// rows; a cell that fails a test is drawn as an orange diamond.
//
// Every number and every mark is computed from
//   ../../generated/dimensioning/derived/run-statistics.json
// which `make figures` writes with generated/dimensioning/scripts/dimensioning_run_statistics.py
// from the CSV of the dimensioning run. The file is not committed. Do not type numbers into this
// file.
//
// Use:  #import "figures/dimensioning-run-statistics.typ": dimensioning-run-statistics-figure
//       then   #dimensioning-run-statistics-figure
#import "@preview/cetz:0.4.2"
#import "perf-common.typ": chart-label, small, tick, nice-step, fix, c-ink, c-muted, s-grid, s-axis

#let _d = json("../../generated/dimensioning/derived/run-statistics.json")
#let _rows = _d.rows

// ---- style ---------------------------------------------------------------------------------
#let _pass = rgb("#2a6fdb")   // passes the test
#let _flag = rgb("#d9480f")   // fails the test
#let _bar = rgb("#9db8e8")    // drift interval
#let _band = luma(91%)        // ±2/√n band of the autocorrelation
#let _zero = 0.5pt + luma(45%)

// ---- the panels: quantity, test, title, axis title -------------------------------------------
#let _panels = (
  (q: "wall", test: "r1", title: ([wall time], [lag-1 autocorrelation]), x-title: [$r_1$ (grey: $plus.minus 2 slash sqrt(n)$)]),
  (q: "wall", test: "drift", title: ([wall time], [drift over the series]), x-title: _d.units.wall),
  (q: "f1", test: "r1", title: ([F1 at 2 cm], [lag-1 autocorrelation]), x-title: [$r_1$ (grey: $plus.minus 2 slash sqrt(n)$)]),
  (q: "f1", test: "drift", title: ([F1 at 2 cm], [drift over the series]), x-title: _d.units.f1),
)

// axis range and ticks of a panel
#let _axis(p) = {
  if p.test == "r1" { return (lo: -0.8, hi: 0.8, step: 0.5) }
  let lo = calc.min(0, .._rows.map(r => r.at(p.q).drift - r.at(p.q).half))
  let hi = calc.max(0, .._rows.map(r => r.at(p.q).drift + r.at(p.q).half))
  let pad = 0.06 * (hi - lo)
  (lo: lo - pad, hi: hi + pad, step: nice-step(hi - lo, 4))
}

#let _row-label(r) = small[#r.label #sym.dot.c #r.scene]

#let _chart(width, label-w) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let n = _rows.len()
  let row-h = 10.5
  let gap = 9          // between panels
  let h-title = 22
  let h-axis = 26
  let h-key = 30
  let body-h = n * row-h + 4
  let total-h = h-title + body-h + h-axis + h-key
  let y-top = total-h - h-title          // top of the panels
  let y-bot = y-top - body-h             // the x axes
  let y(i) = y-top - 2 - (i + 0.5) * row-h
  let x-left = label-w + 6
  let pw = (w - x-left - 3 * gap) / 4    // panel width

  rect((0, 0), (w, total-h), stroke: none)   // fixes the canvas to the text width

  // row labels
  for (i, r) in _rows.enumerate() {
    content((label-w, y(i)), anchor: "east", _row-label(r))
  }

  for (j, p) in _panels.enumerate() {
    let x0 = x-left + j * (pw + gap)
    let x1 = x0 + pw
    let ax = _axis(p)
    let x(v) = x0 + pw * (v - ax.lo) / (ax.hi - ax.lo)

    // title
    content((x0, y-top + 4), anchor: "south-west", small(p.title.at(1)))
    content((x0, y-top + 13), anchor: "south-west", small(p.title.at(0)))

    // band of the autocorrelation test (constant n within a panel: one rectangle)
    if p.test == "r1" {
      let b = _rows.at(0).at(p.q).band
      rect((x(-b), y(n - 1)), (x(b), y(0)), fill: _band, stroke: none)
    }
    // separators between the methods
    for k in range(3, n, step: 3) {
      let ys = y(k) + row-h / 2
      line((x0, ys), (x1, ys), stroke: s-grid)
    }
    // zero line
    line((x(0), y-bot), (x(0), y-top), stroke: _zero)

    // marks
    for (i, r) in _rows.enumerate() {
      let s = r.at(p.q)
      let v = if p.test == "r1" { s.r1 } else { s.drift }
      let fails = if p.test == "r1" { s.r1_fails } else { s.drift_fails }
      if p.test == "drift" {
        line((x(s.drift - s.half), y(i)), (x(s.drift + s.half), y(i)), stroke: 1pt + _bar)
      }
      let (xm, ym) = (x(v), y(i))
      if fails {
        let d = 2.9
        line((xm - d, ym), (xm, ym + d), (xm + d, ym), (xm, ym - d), close: true, fill: _flag, stroke: none)
      } else {
        circle((xm, ym), radius: 2.1, fill: _pass, stroke: none)
      }
    }

    // axes: left spine and x axis with ticks
    line((x0, y-bot), (x0, y-top), stroke: s-axis)
    line((x0, y-bot), (x1, y-bot), stroke: s-axis)
    let digits = calc.max(0, -calc.floor(calc.log(ax.step, base: 10.0) + 1e-9))
    for k in range(calc.ceil(ax.lo / ax.step - 1e-9), calc.floor(ax.hi / ax.step + 1e-9) + 1) {
      let v = k * ax.step
      line((x(v), y-bot), (x(v), y-bot - 2.2), stroke: s-axis)
      content((x(v), y-bot - 3.4), anchor: "north", tick(if k == 0 [0] else { fix(v, digits) }))
    }
    content(((x0 + x1) / 2, y-bot - 13), anchor: "north", tick(p.x-title))
  }

  // key, under the two F1 panels
  let xk = x-left + 2 * (pw + gap)
  let yk = y-bot - h-axis - 3
  let d = 2.9
  line((xk, yk - d), (xk + d, yk), (xk, yk + d), (xk - d, yk), close: true, fill: _flag, stroke: none)
  content((xk + 5, yk), anchor: "west", tick[fails the test])
  content((xk + 5, yk - 8), anchor: "west", tick[autocorrelation: outside the $plus.minus 2 slash sqrt(n)$ band])
  content((xk + 5, yk - 16), anchor: "west", tick[drift: interval excludes 0~% or 0~pp])
})

#let dimensioning-run-statistics-figure = layout(size => context {
  let label-w = calc.max(.._rows.map(r => measure(_row-label(r)).width / 1pt))
  _chart(size.width, label-w)
})
