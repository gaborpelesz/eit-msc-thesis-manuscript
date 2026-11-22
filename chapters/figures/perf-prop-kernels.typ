// Time of the propagation kernels for the baseline and after each change of the propagation
// stack: one bar per build, divided by kernel, and underneath a table of the same numbers. The
// table adds, in one row, the two kernels of the reliability classification that evaluate the same
// matching cost, and the exactness class of each change. The table is also the key to the bars: a
// kernel carries the colour chip of its segment.
//
// Every number and every mark is computed from
//   ../../generated/perf-4.3/derived/prop-kernels.json
// which generated/perf-4.3/scripts/perf43_json.py writes from generated/perf-4.3/data/kern-*.csv
// (kernel times of one profiled run per build). Do not type numbers into this file.
//
// Use:  #import "figures/perf-prop-kernels.typ": perf-prop-kernels-figure   then   #perf-prop-kernels-figure
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _d = json("../../generated/perf-4.3/derived/prop-kernels.json")
#for a in _d.arms { assert(a.key in prop-builds, message: "no description for build " + a.key) }
#for g in _d.groups { assert(g.key in prop-kernels, message: "no description for kernel group " + g.key) }

// the kernels of the propagation stage are drawn; those of the finalization stage (the reliability
// classification) are listed as one sum
#let _drawn = _d.groups.filter(g => g.stage == "propagation").map(g => g.key)
#let _listed = _d.groups.filter(g => g.stage == "finalization").map(g => g.key)
// ---- fills: three steps of the blue of GPU kernels in <fig-run-breakdown>, in the order drawn ----
// Neighbouring steps differ in lightness and are separated by a white line.
#let _fills = (c-kernel-dark, c-kernel, c-kernel-light)
#let _on = (white, white, c-ink)
#assert(_drawn.len() == _fills.len(), message: "one fill per drawn kernel")
#for a in _d.arms {
  assert(calc.abs(_drawn.map(k => a.kernels.at(k)).sum() - a.prop_s) < 1e-3, message: "the drawn kernels of " + a.key + " do not add up to its propagation time")
}

// the build that was profiled on top of the changes of the earlier sections (the last one)
#let _on-stack = _d.arms.enumerate().filter(((i, a)) => a.at("on_stack", default: none) != none)
#assert(_on-stack.len() == 1, message: "the caption describes one build that was profiled on the combined stack")
#let (_i-stack, _a-stack) = _on-stack.first()

// ---- the bars -----------------------------------------------------------------------------------
#let _h-row = 21
#let _bar = 12
#let _h-axis = 34
#let _x-bar = 150
#let _pad-r = 44

#let _chart(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let t-max = calc.max(.._d.arms.map(a => a.prop_s))
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
  content(((x(0) + x(axis-max)) / 2, y-ax - 13), anchor: "north", small[kernel time (s)])
  let top = y-top
  for (i, a) in _d.arms.enumerate() {
    let yc = top - _h-row / 2
    top -= _h-row
    content((19, yc), anchor: "west", small(prop-build-label(i, a.key)))
    let t = 0
    for (j, k) in _drawn.enumerate() {
      let sec = a.kernels.at(k)
      let (l, r) = (x(t), x(t + sec))
      t += sec
      rect((l, yc - _bar / 2), (r, yc + _bar / 2), fill: _fills.at(j), stroke: none)
      if j < _drawn.len() - 1 { line((r, yc - _bar / 2), (r, yc + _bar / 2), stroke: 0.5pt + white) }
      let num = chart-label(6.5pt, fix(sec, 1), fill: _on.at(j))
      if measure(num).width + 4pt <= (r - l) * 1pt { content(((l + r) / 2, yc), anchor: "center", num) }
    }
    content((x(t) + 4, yc), anchor: "west", small[#fix(a.prop_s, 1) s])
  }
})

// ---- the table ----------------------------------------------------------------------------------
#let _chip(fill) = box(width: 6pt, height: 6pt, fill: fill)
#let _table = {
  set text(size: 8.5pt, top-edge: 0.7em, bottom-edge: -0.3em)
  set par(justify: false, leading: 0.3em)
  show raw: set text(size: 8pt)
  let n = _d.arms.len()
  let hd(body, ..args) = table.cell(inset: (x: 4pt, y: 3pt), align: bottom, ..args, strong(body))
  let label(k) = [#prop-kernels.at(k).short #text(size: 7.5pt, fill: c-muted, prop-kernels.at(k).what)]
  // the number of a kernel that a build changes is set bold
  let cells = ()
  for (j, k) in _drawn.enumerate() {
    cells += (move(dy: -1.2pt, _chip(_fills.at(j))), label(k))
    cells += _d.arms.map(a => if k in a.changed { strong(fix(a.kernels.at(k), 1)) } else { fix(a.kernels.at(k), 1) })
  }
  let row(first, body, values, top: 3.5pt, bottom: 3.5pt) = (
    ..(first, body).map(c => table.cell(inset: (x: 4pt, top: top, bottom: bottom), c)),
    ..values.map(c => table.cell(inset: (x: 4pt, top: top, bottom: bottom), c)),
  )
  let listed(a) = _listed.map(k => a.kernels.at(k)).sum()
  table(
    columns: (auto, 1fr) + (33pt,) * n,
    rows: (auto, auto) + (12pt,) * _drawn.len() + (auto, auto, auto),
    align: (left + horizon, left + horizon) + (right + horizon,) * n,
    stroke: none,
    inset: (x: 4pt, y: 0pt),
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
    ..row([], strong[the propagation kernels], _d.arms.map(a => strong(fix(a.prop_s, 1)))),
    table.hline(stroke: 0.3pt),
    ..row([], [#_listed.map(k => prop-kernels.at(k).short).join([, ]) #text(size: 7.5pt, fill: c-muted)[classification]],
      _d.arms.map(a => if _listed.any(k => k in a.changed) { strong(fix(listed(a), 1)) } else { fix(listed(a), 1) }), bottom: 1pt),
    ..row([], [exactness class of the change], _d.arms.map(a => if a.class == none [] else { a.class }), top: 1pt),
    table.hline(stroke: 0.8pt),
  )
}

#let perf-prop-kernels-figure = [#figure(
  kind: image,
  caption: flex-caption([
    Time of the propagation kernels for the baseline and after each performance improvement attempt. Each build contains the changes before it. The table adds the two kernels of the reliability classification that evaluate the same matching cost; they are not drawn. A number in bold marks a kernel that the build changes. One profiled run per build on ETH3D _pipes_ at native resolution. Builds 1 to #(_i-stack - 1) hold the propagation changes alone on the baseline. Build #_i-stack was measured on top of the changes of the earlier sections, which leave these kernels unchanged. The baseline times differ slightly from those of #ref(<table-kernel-breakdown>), which come from another profiled run.
  ], [Propagation kernel times per improvement attempt]),
  block(breakable: false, width: 100%, grid(
    columns: (1fr,), align: left, row-gutter: 6pt,
    layout(size => _chart(size.width)),
    _table,
  )),
) <fig-perf-prop-kernels>]
