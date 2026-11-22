// Time of the three kernels of the anchor stage for the fixed base and after each change of the
// anchor stack: one bar per build, divided by kernel, and underneath a table of the same numbers.
// The table is also the key to the bars: a kernel carries the colour chip of its segment.
//
// Every number and every mark is computed from
//   ../../generated/perf-4.3/derived/anchor-kernels.json
// which generated/perf-4.3/scripts/perf43_json.py writes from generated/perf-4.3/data/kern-*.csv
// (kernel times of one profiled run per build). Do not type numbers into this file.
//
// Use:  #import "figures/perf-anchor-kernels.typ": perf-anchor-kernels-figure   then   #perf-anchor-kernels-figure
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _d = json("../../generated/perf-4.3/derived/anchor-kernels.json")
#for a in _d.arms { assert(a.key in anchor-builds, message: "no description for build " + a.key) }
#for k in _d.kernels { assert(k in anchor-kernels, message: "no description for kernel " + k) }

// ---- fills: three steps of the blue of GPU kernels in <fig-run-breakdown>, in the order drawn ----
// Neighbouring steps differ in lightness and are separated by a white line.
#let _fills = (c-kernel-dark, c-kernel, c-kernel-light)
#let _on = (white, white, c-ink)
#assert(_d.kernels.len() == _fills.len(), message: "one fill per kernel")

#let _one(x) = if x < 0.05 { [< #fix(0.1, 1)] } else { fix(x, 1) }

// ---- the bars -----------------------------------------------------------------------------------
#let _h-row = 21
#let _bar = 12
#let _h-axis = 24
#let _x-bar = 132
#let _pad-r = 44

#let _chart(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let t-max = calc.max(.._d.arms.map(a => a.anchor_s))
  let step = nice-step(t-max, 8)
  let axis-max = calc.ceil(t-max / step) * step
  let x(t) = _x-bar + (w - _pad-r - _x-bar) * t / axis-max
  let total-h = _d.arms.len() * _h-row + _h-axis
  let y-top = total-h

  rect((0, 0), (w, total-h), stroke: none)   // fixes the canvas to the text width

  let y-ax = _h-axis - 2
  for i in range(0, int(axis-max / step) + 1) {
    let t = i * step
    line((x(t), y-ax), (x(t), y-top), stroke: s-grid)
    line((x(t), y-ax), (x(t), y-ax - 2.2), stroke: s-axis)
    content((x(t), y-ax - 3.4), anchor: "north", tick(str(t)))
  }
  line((x(0), y-ax), (x(axis-max), y-ax), stroke: s-axis)
  let top = y-top
  for (i, a) in _d.arms.enumerate() {
    let yc = top - _h-row / 2
    top -= _h-row
    content((19, yc), anchor: "west", small(anchor-build-label(i, a.key)))
    let t = 0
    for (j, k) in _d.kernels.enumerate() {
      let sec = a.kernels.at(k).total_s
      let (l, r) = (x(t), x(t + sec))
      t += sec
      rect((l, yc - _bar / 2), (r, yc + _bar / 2), fill: _fills.at(j), stroke: none)
      if j < _d.kernels.len() - 1 { line((r, yc - _bar / 2), (r, yc + _bar / 2), stroke: 0.5pt + white) }
      let num = chart-label(6.5pt, fix(sec, 1), fill: _on.at(j))
      if measure(num).width + 4pt <= (r - l) * 1pt { content(((l + r) / 2, yc), anchor: "center", num) }
    }
    content((x(t) + 4, yc), anchor: "west", small[#fix(a.anchor_s, 1) s])
  }
})

// ---- the table ----------------------------------------------------------------------------------
#let _chip(fill) = box(width: 6pt, height: 6pt, fill: fill)
#let _table = {
  set text(size: 8.5pt, top-edge: 0.7em, bottom-edge: -0.3em)
  set par(justify: false, leading: 0.3em)
  show raw: set text(size: 8pt)
  let n = _d.arms.len()
  let hd(body, ..args) = table.cell(inset: (x: 5pt, y: 3pt), align: bottom, ..args, strong(body))
  let cells = ()
  for (j, k) in _d.kernels.enumerate() {
    cells += (move(dy: -1.2pt, _chip(_fills.at(j))), [#raw(k) #text(size: 7.5pt, fill: c-muted, anchor-kernels.at(k))])
    // the number of the build that changes the kernel is set bold
    cells += _d.arms.map(a => if a.changed == k { strong(_one(a.kernels.at(k).total_s)) } else { _one(a.kernels.at(k).total_s) })
  }
  table(
    columns: (auto, 1fr) + (36pt,) * n,
    rows: (auto, auto) + (12pt,) * _d.kernels.len() + (auto, auto),
    align: (left + horizon, left + horizon) + (right + horizon,) * n,
    stroke: none,
    inset: (x: 5pt, y: 0pt),
    table.hline(stroke: 0.8pt),
    table.header(
      hd(colspan: 2, rowspan: 2)[Kernel],
      hd(colspan: n, align: center + bottom)[Time by build (s)],
      table.hline(start: 2, end: 2 + n, stroke: 0.3pt),
      .._d.arms.enumerate().map(((i, a)) => hd(if i == 0 [base] else [#i])),
    ),
    table.hline(stroke: 0.5pt),
    ..cells,
    table.hline(stroke: 0.5pt),
    ..([], strong[the three kernels]).map(c => table.cell(inset: (x: 5pt, y: 3.5pt), c)),
    .._d.arms.map(a => table.cell(inset: (x: 5pt, y: 3.5pt), strong(_one(a.anchor_s)))),
    ..([], [all kernels of the run]).map(c => table.cell(inset: (x: 5pt, top: 0pt, bottom: 3.5pt), c)),
    .._d.arms.map(a => table.cell(inset: (x: 5pt, top: 0pt, bottom: 3.5pt), _one(a.all_kernels_s))),
    table.hline(stroke: 0.8pt),
  )
}

#let perf-anchor-kernels-figure = [#figure(
  kind: image,
  caption: flex-caption([
    Time of the anchor stage device kernels for the baseline and after each performance improvement attempt. Measured on ETH3D _pipes_ at native resolution using Nsight Systems on unlocked clocks. Kernel times are summed over the 224 reference image passes of one run.
  ], [Anchor stage kernel times per improvement attempt]),
  block(breakable: false, width: 100%, grid(
    columns: (1fr,), align: left, row-gutter: 6pt,
    layout(size => _chart(size.width)),
    _table,
  )),
) <fig-perf-anchor-kernels>]
