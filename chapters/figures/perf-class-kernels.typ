// Time of the two classification kernels before and after the changes of the classification
// section: one bar for the build before them and one for the build with all of them, divided by
// kernel, and underneath a table of the same numbers with the change per kernel. The table is also
// the key to the bars: a kernel carries the colour chip of its segment. The builds in between (one
// per change) are in the data and are not drawn; the section treats the changes as one.
// Panel (b) shows why DepthToWeak changes little: the evaluations of the matching cost that it
// makes in a run, divided into those that the label needs and those that cannot affect it
// (numbers-class.json, counters over all passes of one run). Orange marks the latter only.
//
// The builds drawn are those on which the changes were made and timed: the stack with the
// propagation changes before the 8-bit image textures (5cf8608) and the five builds on top of it
// (2045188, f223fa9, b921d39, 40da3b4, 97809e9). The data also holds the same five changes on the
// 8-bit textures (group "u8"); they are not drawn here, the text gives their two totals.
//
// Every number and every mark is computed from
//   ../../generated/perf-4.3/derived/class-kernels.json
// which generated/perf-4.3/scripts/perf43_json.py writes from generated/perf-4.3/data/kern-*.csv
// (kernel times of one profiled run per build). Do not type numbers into this file.
//
// Use:  #import "figures/perf-class-kernels.typ": perf-class-kernels-figure   then   #perf-class-kernels-figure
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _d = json("../../generated/perf-4.3/derived/class-kernels.json")
#let _all = _d.arms.filter(a => a.group == "prop")
#let _arms = (_all.first(), _all.last())   // before the changes of the section, and with all of them
#let _nc = json("../../generated/perf-4.3/derived/numbers-class.json").v
#let _on8 = _nc.on8
#let _c = _nc.counters                      // shares in percent
#let _c-waste = rgb("#eb6834")
#let _lab(body, ..args) = chart-label(8.5pt, body, ..args)
#let _title(tag, body) = block(below: 3pt, text(size: 8.5pt, top-edge: "cap-height", bottom-edge: "baseline")[*(#tag)* #body])
#for a in _all { assert(a.key in class-builds, message: "no description for build " + a.key) }
#for g in _d.groups { assert(g.key in class-kernels, message: "no description for kernel " + g.key) }
#let _keys = _d.groups.map(g => g.key)

// ---- fills: two steps of the blue of GPU kernels in <fig-run-breakdown>, in the order drawn ------
#let _fills = (c-kernel-dark, c-kernel-light)
#let _on = (white, c-ink)
#assert(_keys.len() == _fills.len(), message: "one fill per kernel")

// the first build is not the baseline of the chapter: it already has the propagation changes
#let _label(i, a) = if i == 0 [before the changes] else [after the changes]
// the kernel name first, what it does after it
#let _names = ("depth_to_weak": [labels the pixels], "local_refine": [refines the depth])
#for k in _keys { assert(k in _names, message: "no word for kernel " + k) }

// ---- the bars -----------------------------------------------------------------------------------
#let _h-row = 21
#let _bar = 12
#let _h-axis = 24
#let _x-bar = 152
#let _pad-r = 44

#let _chart(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let t-max = calc.max(.._arms.map(a => a.class_s))
  let step = nice-step(t-max, 8)
  let axis-max = calc.ceil(t-max / step) * step
  let x(t) = _x-bar + (w - _pad-r - _x-bar) * t / axis-max
  let total-h = _arms.len() * _h-row + _h-axis
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
  for (i, a) in _arms.enumerate() {
    let yc = top - _h-row / 2
    top -= _h-row
    content((19, yc), anchor: "west", small(_label(i, a)))
    let t = 0
    for (j, k) in _keys.enumerate() {
      let sec = a.kernels.at(k)
      let (l, r) = (x(t), x(t + sec))
      t += sec
      rect((l, yc - _bar / 2), (r, yc + _bar / 2), fill: _fills.at(j), stroke: none)
      if j < _keys.len() - 1 { line((r, yc - _bar / 2), (r, yc + _bar / 2), stroke: 0.5pt + white) }
      let num = chart-label(6.5pt, fix(sec, 1), fill: _on.at(j))
      if measure(num).width + 4pt <= (r - l) * 1pt { content(((l + r) / 2, yc), anchor: "center", num) }
    }
    content((x(t) + 4, yc), anchor: "west", small[#fix(a.class_s, 1) s])
  }
})

// ---- (b) the evaluations of the matching cost in DepthToWeak, counted over a run ------------------
// The two shares overlap a little (a view of weight zero is also evaluated at the outermost depths);
// the bar is drawn without the overlap, and the needed part carries no second percentage.
#let _evals(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (bar, y0) = (15, 18)
  let edge = _c.edge_pct / 100
  let zero = _c.w0_share_pct / 100 * (1 - edge)
  let (x1, x2) = (w * (1 - edge - zero), w * (1 - zero))
  rect((0, 0), (w, y0 + bar + 2), stroke: none)
  rect((0, y0), (x1, y0 + bar), fill: c-kernel-dark, stroke: none)
  rect((x1, y0), (w, y0 + bar), fill: _c-waste, stroke: none)
  line((x1, y0), (x1, y0 + bar), stroke: 0.6pt + white)
  line((x2, y0), (x2, y0 + bar), stroke: 0.6pt + white)
  content((x1 / 2, y0 + bar / 2), anchor: "center", _lab(fill: white, weight: "bold")[more than nine in ten are needed for the label])
  line((x1 + 1, y0 - 3), (x1 + 1, y0 - 6), (w - 1, y0 - 6), (w - 1, y0 - 3), stroke: 0.5pt + c-muted)
  content((w, y0 - 8), anchor: "north-east", _lab(fill: c-muted)[cannot affect the label: #fix(_c.edge_pct, 1)% at the two outermost depths, #fix(_c.w0_share_pct, 1)% for views of weight zero])
})

// ---- the table ----------------------------------------------------------------------------------
#let _chip(fill) = box(width: 6pt, height: 6pt, fill: fill)
#let _table = {
  set text(size: 8.5pt, top-edge: 0.7em, bottom-edge: -0.3em)
  set par(justify: false, leading: 0.3em)
  show raw: set text(size: 8pt)
  let n = _arms.len()
  let hd(body, ..args) = table.cell(inset: (x: 5pt, y: 3pt), align: bottom, ..args, strong(body))
  let cells = ()
  for (j, k) in _keys.enumerate() {
    cells += (move(dy: -1.2pt, _chip(_fills.at(j))), [#class-kernels.at(k).name #text(size: 7.5pt, fill: c-muted, _names.at(k))])
    // the number of a kernel that the build changes is set bold
    cells += _arms.map(a => fix(a.kernels.at(k), 1))
    cells += ([#sym.minus#pct(1 - _arms.last().kernels.at(k) / _arms.first().kernels.at(k), 0)],)
  }
  let row(body, value, top: 3.5pt, bottom: 3.5pt, bold: false) = (
    ..([], if bold { strong(body) } else { body }).map(c => table.cell(inset: (x: 5pt, top: top, bottom: bottom), c)),
    .._arms.map(a => table.cell(inset: (x: 5pt, top: top, bottom: bottom), if bold { strong(value(a)) } else { value(a) })),
    table.cell(inset: (x: 5pt, top: top, bottom: bottom), strong[#sym.minus#pct(1 - _arms.last().class_s / _arms.first().class_s, 0)]),
  )
  table(
    columns: (auto, 1fr) + (40pt,) * n + (48pt,),
    rows: (auto, auto) + (12pt,) * _keys.len() + (auto,),
    align: (left + horizon, left + horizon) + (right + horizon,) * (n + 1),
    stroke: none,
    inset: (x: 5pt, y: 0pt),
    table.hline(stroke: 0.8pt),
    table.header(
      hd(colspan: 2, rowspan: 2)[Kernel],
      hd(colspan: n, align: center + bottom)[Time (s)],
      hd(rowspan: 2)[Change],
      table.hline(start: 2, end: 2 + n, stroke: 0.3pt),
      hd[before], hd[after],
    ),
    table.hline(stroke: 0.5pt),
    ..cells,
    table.hline(stroke: 0.5pt),
    ..row([the two kernels], a => fix(a.class_s, 1), bold: true),
    table.hline(stroke: 0.8pt),
  )
}

#let perf-class-kernels-figure = [#figure(
  kind: image,
  caption: flex-caption([
    The two kernels of the reliability classification before and after the #spell(_all.len() - 1) changes of this section.
    *(a)* `LocalRefine` is almost eliminated, while `DepthToWeak`, which accounts for most of the time, changes little.
    *(b)* The reason: of the evaluations of the matching cost that `DepthToWeak` makes in a run, more than nine in ten are needed for the label.
    Measured on ETH3D _pipes_ at native resolution, the kernel times using Nsight Systems on unlocked clocks, before the #box[8-bit] image textures of #ref(<sec:perf-prop>) were added; on top of them the same changes take the two kernels from #fix(_on8.u8.class_s, 1)~s to #fix(_on8.comb.class_s, 1)~s.
  ], [Classification kernel times before and after the changes]),
  block(breakable: false, width: 100%, {
    set align(left)
    _title("a")[Kernel time before and after the changes]
    grid(
      columns: (1fr,), align: left, row-gutter: 6pt,
      layout(size => _chart(size.width)),
      _table,
    )
    v(10pt)
    _title("b")[The evaluations of the matching cost in `DepthToWeak`, counted over a run]
    layout(size => _evals(size.width))
  }),
) <fig-perf-class-kernels>]
