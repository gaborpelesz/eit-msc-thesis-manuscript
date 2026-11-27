// The sweep of the reliability classification, drawn to show what the first two changes of the
// classification section remove:
//   (a) the cost profile of a pixel that is labeled reliable, as the sweep samples it,
//   (b) the cost profile of a pixel that is labeled unreliable,
//   (c) the samples that one pass evaluated for a pixel before the changes: the sweep of
//       DepthToWeak, whose two end samples are never read, and the samples that LocalRefine
//       evaluated a second time.
//   (d) the cost evaluations of the sweep over a run: the few that cannot affect the label, and
//       the rest, which the labeling rule needs.
// (a) and (b) are measured: the costs that an instrumented build wrote out for two pixels of one
// pass. (c) is a schematic: one mark per sample, no costs. (d) is counted over all passes of one
// run (numbers-class.json, counters). Orange marks the evaluations that have no effect on the
// result, and is used for nothing else.
//
// Every number and every mark is computed from
//   ../../generated/perf-4.3/derived/class-profiles.json
// which generated/perf-4.3/scripts/perf43_json.py writes from generated/perf-4.3/data/
// fig1-profiles.json. Do not type numbers into this file.
//
// Use:  #import "figures/perf-class-sweep.typ": perf-class-sweep-figure   then   #perf-class-sweep-figure
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _d = json("../../generated/perf-4.3/derived/class-profiles.json")
#let _c = json("../../generated/perf-4.3/derived/numbers-class.json").v.counters   // shares in percent
#let _titles = (
  "reliable": [Reliable: a deep valley at the current depth],
  "unreliable": [Unreliable: no valley is low enough],
)
#for p in _d.profiles { assert(p.key in _titles, message: "no title for profile " + p.key) }
#assert(_d.profiles.all(p => p.max <= _d.clamp), message: "a cost above the limit")
#let _n = _d.samples.len()
#let _refine = 2 * _d.refine_radius + 1
// the valleys as the kernel finds them: a sample lower than both neighbours; the two samples next to
// each end are not tested (APD.cu DepthToWeak, "find peaks")
#let _valleys(cost) = range(2, _n - 2).filter(i => cost.at(i - 1) > cost.at(i) and cost.at(i + 1) > cost.at(i))

#let _c-waste = rgb("#eb6834")
#let _lab(body, ..args) = chart-label(8.5pt, body, ..args)
#let _tag = ("a", "b")
// axis text of the two profiles, a step larger than `tick` so that it stays legible at print size
#let _tick(body) = chart-label(7.5pt, body, fill: c-muted)

// ---- (a), (b) the two profiles ----------------------------------------------------------------------
#let _h-plot = 92
#let _h-title = 15
#let _h-axis = 27
#let _w-y = 24       // room for the cost axis
#let _gap = 14

#let _profiles(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let n = _d.profiles.len()
  let w-plot = (w - _w-y - (n - 1) * _gap - 2) / n
  let total-h = _h-title + _h-plot + _h-axis
  let (y0, y1) = (_h-axis, _h-axis + _h-plot)
  let (s0, s1) = (_d.samples.first(), _d.samples.last())
  let y(c) = y0 + (y1 - y0) * c / _d.clamp
  let y-step = nice-step(_d.clamp, 4)

  rect((0, 0), (w, total-h), stroke: none)   // fixes the canvas to the text width

  for (j, p) in _d.profiles.enumerate() {
    let xl = _w-y + j * (w-plot + _gap)
    let x(s) = xl + 6 + (w-plot - 12) * (s - s0) / (s1 - s0)
    content((xl, y1 + 6), anchor: "south-west", _lab[*(#_tag.at(j))* #_titles.at(p.key)])
    // cost axis: grid in every panel, numbers at the first
    for k in range(0, int(_d.clamp / y-step) + 1) {
      let c = k * y-step
      line((xl, y(c)), (xl + w-plot, y(c)), stroke: s-grid)
      if j == 0 { content((xl - 4, y(c)), anchor: "east", _tick(fix(c, 1))) }
    }
    line((xl, y0), (xl + w-plot, y0), stroke: s-axis)
    line((xl, y0), (xl, y1), stroke: s-axis)
    // the current depth
    line((x(0), y0), (x(0), y1), stroke: (paint: c-muted, thickness: 0.5pt, dash: "dashed"))
    content((x(0) + 3, y1 - 3), anchor: "north-west", _tick[current depth])
    // sample axis
    for s in _d.samples.filter(s => calc.rem(s, 10) == 0) {
      line((x(s), y0), (x(s), y0 - 2.2), stroke: s-axis)
      content((x(s), y0 - 3.4), anchor: "north", _tick(if s == 0 { [0] } else { signed(s, 0) }))
    }
    content((xl + w-plot / 2, y0 - 12.5), anchor: "north", _tick[sample of the sweep (depth steps from the current depth)])
    // the profile, its samples and its valleys
    line(.._d.samples.zip(p.cost).map(((s, c)) => (x(s), y(c))), stroke: 0.6pt + c-kernel-dark)
    for (s, c) in _d.samples.zip(p.cost) { circle((x(s), y(c)), radius: 1.3, fill: c-kernel-dark, stroke: none) }
    for i in _valleys(p.cost) { circle((x(_d.samples.at(i)), y(p.cost.at(i))), radius: 3.3, fill: none, stroke: 0.7pt + c-ink) }
  }
  content((0, (y0 + y1) / 2), anchor: "center", angle: 90deg, _tick[matching cost])
})

// ---- (c) the samples that one pass evaluated for a pixel ---------------------------------------------
#let _strip(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let xl = 132
  let (s0, s1) = (_d.samples.first(), _d.samples.last())
  let x(s) = xl + (w - xl - 6) * (s - s0) / (s1 - s0)
  let (y-sweep, y-refine, y-ax) = (52, 36, 25)
  rect((0, 0), (w, 60), stroke: none)
  let row(y, name, what) = content((0, y + 0.5), anchor: "west", _lab[#name #text(size: 7.5pt, fill: c-muted, what)])
  row(y-sweep)[`DepthToWeak`][the sweep]
  row(y-refine)[`LocalRefine`][the refinement]
  line((x(0), y-ax), (x(0), y-sweep + 7), stroke: (paint: c-muted, thickness: 0.5pt, dash: "dashed"))
  for s in _d.samples {
    if s in _d.unread {
      circle((x(s), y-sweep), radius: 1.7, fill: white, stroke: 1pt + _c-waste)
    } else {
      circle((x(s), y-sweep), radius: 1.7, fill: c-kernel-dark, stroke: none)
    }
    if calc.abs(s) <= _d.refine_radius { circle((x(s), y-refine), radius: 1.7, fill: _c-waste, stroke: none) }
  }
  line((x(s0), y-ax), (x(s1), y-ax), stroke: s-axis)
  for s in _d.samples.filter(s => calc.rem(s, 10) == 0) {
    line((x(s), y-ax), (x(s), y-ax - 2.2), stroke: s-axis)
    content((x(s), y-ax - 3.4), anchor: "north", tick(if s == 0 { [0] } else { signed(s, 0) }))
  }
  content(((x(s0) + x(s1)) / 2, y-ax - 12.5), anchor: "north", tick[sample of the sweep (depth steps from the current depth)])
})

// ---- (d) the cost evaluations of the sweep, counted over a run ---------------------------------------
// The two shares overlap a little (a view of weight zero is also evaluated at the end samples); the
// bar is drawn without the overlap, and the label of the needed part gives no second percentage.
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
  content((x1 / 2, y0 + bar / 2), anchor: "center", _lab(fill: white, weight: "bold")[more than nine in ten: needed for a sample from which the label is read])
  line((x1 + 1, y0 - 3), (x1 + 1, y0 - 6), (w - 1, y0 - 6), (w - 1, y0 - 3), stroke: 0.5pt + c-muted)
  content((w, y0 - 8), anchor: "north-east", _lab(fill: c-muted)[cannot affect the label: #fix(_c.edge_pct, 1)% at the two end samples, #fix(_c.w0_share_pct, 1)% for views of weight zero])
})

#let _legend = {
  set text(size: 8pt, top-edge: "cap-height", bottom-edge: "baseline")
  set par(justify: false, leading: 0.55em, first-line-indent: 0pt)
  let dot(fill, stroke, r: 2.2pt) = box(baseline: -0.5pt, circle(radius: r, fill: fill, stroke: stroke))
  let item(mark, body) = box[#mark#h(3pt)#body]
  (
    item(dot(c-kernel-dark, none))[sample: the cost of the plane of the pixel at one depth],
    item(dot(none, 0.7pt + c-ink, r: 2.8pt))[valley],
    item(dot(_c-waste, none))[evaluated a second time, by the refinement (#_refine samples)],
    item(dot(white, 1pt + _c-waste))[evaluated, never read (#_d.unread.len() samples)],
  ).join(h(9pt))
}

#let perf-class-sweep-figure = [#figure(
  kind: image,
  caption: flex-caption([
    The sweep of the reliability classification, and the share of its cost evaluations that cannot affect the label.
    *(a)*, *(b)* The cost profiles of two pixels, #_n samples each, measured in one pass of a run on ETH3D _pipes_ at #_d.width~px.
    *(c)* The samples that one pass evaluated for every pixel before the changes (schematic): the refinement repeated #_refine samples of the sweep, and the two end samples were never read.
    *(d)* The cost evaluations of the sweep itself, counted over all passes of a run at native resolution.
  ], [The classification sweep and its repeated and unread samples]),
  layout(size => block(breakable: false, width: 100%, {
    set align(left)
    set par(leading: 0.3em, spacing: 0pt)
    set block(spacing: 0pt)
    _profiles(size.width)
    v(9pt)
    block(below: 2pt, text(size: 8.5pt, top-edge: "cap-height", bottom-edge: "baseline")[*(c)* One pass before the changes: the middle samples are evaluated twice, and the end samples are never read])
    _strip(size.width)
    v(6pt)
    _legend
    v(11pt)
    block(below: 2pt, text(size: 8.5pt, top-edge: "cap-height", bottom-edge: "baseline")[*(d)* The cost evaluations of the sweep: almost all of them are needed])
    _evals(size.width)
  })),
) <fig-perf-class-sweep>]
