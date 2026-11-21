// Host work of the passes by region timer, for the fixed base and after each change of the input
// stack: one bar per build, divided into the regions of input loading and the two transfers, and
// underneath a table of the same regions with their seconds per build. The table is also the key
// to the bars: a region carries the colour chip of the segment it is drawn in.
//
// Every number and every mark is computed from
//   ../../generated/perf-4.3/derived/input-regions.json
// which generated/perf-4.3/scripts/perf43_json.py writes from the region breakdowns of the builds
// in generated/perf-4.3/data/ (INPUT_ARMS of the script; one timed run each).
// Do not type numbers into this file.
//
// Use:  #import "figures/perf-input-regions.typ": perf-input-regions-figure   then   #perf-input-regions-figure
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _d = json("../../generated/perf-4.3/derived/input-regions.json")

// ---- the builds (one bar and one table column each): named in perf-common.typ ----------------
#for a in _d.arms { assert(a.key in input-builds, message: "no description for build " + a.key) }
#assert(_d.arms.map(a => a.passes).dedup().len() == 1, message: "the builds do not have the same passes")

// ---- segments of a bar, in the order drawn: thesis term, fill, colour of a number on the fill ---
// Image work has the orange of host computation in <fig-run-breakdown>, in two steps. Work on the
// maps is grey. The transfers have its green of host-device copies, in two steps. Neighbouring fills differ in lightness (by more than 20 L* in the order drawn), so
// that they stay apart in a greyscale print. Two chips can still look alike without colour (the
// orange and a mid grey), so the caption says that the segments follow the order of the table,
// and the numbers on the segments are those of the table.
#let _seg = (
  "convert": (label: [uint8 to float32], fill: c-host, on: c-ink),
  "resize": (label: [resize to current scale], fill: rgb("#f8c4ad"), on: c-ink),
  "plane_fill": (label: [fill plane array], fill: luma(22%), on: white),
  "plane_upsample": (label: [upscaling depth, normal and views], fill: luma(44%), on: white),
  "plane_rest": (label: [other buffers], fill: luma(74%), on: c-ink),
  "geom_depths": (label: [depths of the source views], fill: luma(33%), on: white),
  "weak": (label: [unreliable-pixel map], fill: luma(93%), on: c-ink),
  "untimed": (label: [cameras and untimed], fill: white, on: c-ink),
  "upload": (label: [device upload], fill: c-copy, on: c-ink),
  "unpack": (label: [result unpacking], fill: c-copy-light, on: c-ink),
)
// a group of segments has a row of its own with their sum
#let _group = (
  "images": [images],
  "planes": [plane hypotheses],
  "transfers": [transfers around the kernels],
)
#for a in _d.arms { for s in a.segments { assert(s.key in _seg, message: "no description for segment " + s.key) } }
#assert(_d.arms.all(a => a.segments.map(s => s.key) == _d.arms.first().segments.map(s => s.key)),
  message: "the builds do not have the same segments")

// one decimal; anything that would print as 0.0 is given as an upper bound
#let _one(x) = if x < 0.05 { [< #fix(0.1, 1)] } else { fix(x, 1) }

// ---- the bars -----------------------------------------------------------------------------------
#let _h-row = 21
#let _bar = 12
#let _h-axis = 24
#let _x-bar = 104
#let _pad-r = 40   // room for the total after the longest bar

#let _chart(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let t-max = calc.max(.._d.arms.map(a => a.total_s))
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
    content((19, yc), anchor: "west", small(input-build-label(i, a.key)))
    let t = 0
    for s in a.segments {
      let (l, r) = (x(t), x(t + s.s))
      t += s.s
      rect((l, yc - _bar / 2), (r, yc + _bar / 2), fill: _seg.at(s.key).fill, stroke: none)
      // the lightest fills get the outline of their chip, so that the end of a bar shows on white
      if r - l > 0.5 and _seg.at(s.key).fill in (white, luma(93%)) {
        rect((l, yc - _bar / 2), (r, yc + _bar / 2), fill: none, stroke: 0.3pt + luma(45%))
      }
      // a white line between segments keeps them apart in a greyscale print
      if t < a.total_s - 1e-6 { line((r, yc - _bar / 2), (r, yc + _bar / 2), stroke: 0.5pt + white) }
      let num = chart-label(6.5pt, fix(s.s, 1), fill: _seg.at(s.key).on)
      if measure(num).width + 4pt <= (r - l) * 1pt { content(((l + r) / 2, yc), anchor: "center", num) }
    }
    content((x(t) + 4, yc), anchor: "west", small[#fix(a.total_s, 1) s])
  }
})

// ---- the table: the regions with their numbers, and the key to the bars -------------------------
// rows: a group row with the sum of its segments before them, then the segments in bar order
#let _rows = {
  let out = ()
  let seen = ()
  for s in _d.arms.first().segments {
    if s.group in _group and s.group not in seen {
      seen.push(s.group)
      out.push((kind: "group", group: s.group))
    }
    out.push((kind: "seg", key: s.key, depth: if s.group in _group { 1 } else { 0 }))
  }
  out
}
#let _seg-of(a, key) = a.segments.find(s => s.key == key)
#let _group-sum(a, group, field) = a.segments.filter(s => s.group == group).map(s => s.at(field)).sum()
#let _chip(fill) = box(width: 6pt, height: 6pt, fill: fill, stroke: 0.3pt + luma(45%))

#let _table = {
  set text(size: 8.5pt, top-edge: 0.7em, bottom-edge: -0.3em)
  set par(justify: false, leading: 0.3em)
  show raw: set text(size: 8pt)
  let n = _d.arms.len()
  let hd(body, ..args) = table.cell(inset: (x: 5pt, y: 3pt), align: bottom, ..args, strong(body))
  let total(body, field) = (
    ..([], strong(body)).map(c => table.cell(inset: (x: 5pt, y: 3.5pt), c)),
    .._d.arms.map(a => table.cell(inset: (x: 5pt, y: 3.5pt), strong(_one(a.at(field))))),
  )
  let cells = ()
  for r in _rows {
    if r.kind == "group" {
      cells += ([], emph(_group.at(r.group)))
      cells += _d.arms.map(a => emph(_one(_group-sum(a, r.group, "s"))))
    } else {
      cells += (move(dy: -1.2pt, _chip(_seg.at(r.key).fill)), [#h(r.depth * 0.9em)#box(_seg.at(r.key).label)])
      cells += _d.arms.map(a => _one(_seg-of(a, r.key).s))
    }
  }
  table(
    columns: (auto, 1fr) + (38pt,) * n,
    rows: (auto, auto) + (11.5pt,) * _rows.len() + (auto, auto),
    align: (left + horizon, left + horizon) + (right + horizon,) * n,
    stroke: none,
    inset: (x: 5pt, y: 0pt),
    table.hline(stroke: 0.8pt),
    table.header(
      hd(colspan: 2, rowspan: 2)[Region],
      hd(colspan: n, align: center + bottom)[Time by build (s)],
      table.hline(start: 2, end: 2 + n, stroke: 0.3pt),
      .._d.arms.enumerate().map(((i, a)) => hd(if i == 0 [base] else [#i])),
    ),
    table.hline(stroke: 0.5pt),
    ..cells,
    table.hline(stroke: 0.5pt),
    ..total([total], "total_s"),
    table.hline(stroke: 0.8pt),
  )
}

#let _outside = _d.arms.first().outside
#let perf-input-regions-figure = [#figure(
  kind: image,
  caption: flex-caption([
    Host work of the image passes by region, showing the baseline and each improvement attempt, measured on ETH3D _pipes_ at native resolution. Times are aggregated across all image passes over the whole run.
  ], [Host work of the image passes by region, per improvement attempt.]),
  block(breakable: false, width: 100%, grid(
    columns: (1fr,), align: left, row-gutter: 6pt,
    layout(size => _chart(size.width)),
    _table,
  )),
) <fig-perf-input-regions>]
