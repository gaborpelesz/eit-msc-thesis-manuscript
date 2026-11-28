// Time of the two classification kernels before and after the changes of the classification
// section: one slim bar for the build before them and one for the build with all of them, divided
// by kernel. The kernel names stand above their segments, the seconds on the segments, and a last
// line gives the change per kernel and of the sum. The builds in between (one per change) are in
// the data and are not drawn; the section treats the changes as one.
//
// The builds drawn are those on which the changes were made and timed: the stack with the
// propagation changes before the 8-bit image textures (5cf8608) and the last of the five builds on
// top of it (97809e9). The data also holds the same five changes on the 8-bit textures (group
// "u8"); they are not drawn here, the text gives their two totals.
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
#let _n = _all.len() - 1                   // the changes of the section
#for a in _all { assert(a.key in class-builds, message: "no description for build " + a.key) }
#for g in _d.groups { assert(g.key in class-kernels, message: "no description for kernel " + g.key) }
#let _keys = _d.groups.map(g => g.key)

// ---- fills: two steps of the blue of GPU kernels in <fig-run-breakdown>, in the order drawn ------
#let _fills = (c-kernel-dark, c-kernel-light)
#let _on = (white, c-ink)
#assert(_keys.len() == _fills.len(), message: "one fill per kernel")

// the two builds by what they contain; the first is not the baseline of the chapter
#let _labels = (
  ([with the propagation changes], [#ref(<sec:perf-prop>), before the 8-bit textures]),
  ([and the #spell(_n) classification changes], [of this section]),
)
#let _drop(from, to) = [#sym.minus#pct(1 - to / from, 0)]

#let _h-head = 13     // the kernel names
#let _h-row = 23
#let _bar = 13
#let _h-foot = 14     // the changes
#let _x-bar = 142
#let _w-sum = 56      // the column of the sum, right of the bars

#let _chart(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let t-max = calc.max(.._arms.map(a => a.class_s))
  let x(t) = _x-bar + (w - _w-sum - _x-bar) * t / t-max
  let x-sum = w
  let total-h = _h-head + _arms.len() * _h-row + _h-foot
  let name(body, ..args) = chart-label(7.5pt, body, ..args)

  rect((0, 0), (w, total-h), stroke: none)   // fixes the canvas to the text width

  // the kernel names, above the segments of the first bar
  let y-head = total-h - _h-head + 4
  let t = 0
  for k in _keys {
    content((x(t), y-head), anchor: "south-west", name(class-kernels.at(k).name))
    t += _arms.first().kernels.at(k)
  }
  content((x-sum, y-head), anchor: "south-east", name[both kernels])

  // the bars
  let top = total-h - _h-head
  for (i, a) in _arms.enumerate() {
    let yc = top - _h-row / 2
    top -= _h-row
    let (main, sub) = _labels.at(i)
    content((0, yc + 4.5), anchor: "west", small(main))
    content((0, yc - 4.5), anchor: "west", chart-label(6.5pt, sub, fill: c-muted))
    let t = 0
    for (j, k) in _keys.enumerate() {
      let sec = a.kernels.at(k)
      let (l, r) = (x(t), x(t + sec))
      t += sec
      rect((l, yc - _bar / 2), (r, yc + _bar / 2), fill: _fills.at(j), stroke: none)
      if j < _keys.len() - 1 { line((r, yc - _bar / 2), (r, yc + _bar / 2), stroke: 0.5pt + white) }
      let num(fill) = chart-label(7pt, [#fix(sec, 1) s], fill: fill)
      // on the segment where it fits, right of it where the segment is a sliver
      if measure(num(white)).width + 6pt <= (r - l) * 1pt {
        content((l + 4, yc), anchor: "west", num(_on.at(j)))
      } else {
        content((r + 4, yc), anchor: "west", num(c-ink))
      }
    }
    content((x-sum, yc), anchor: "east", small(weight: "bold")[#fix(a.class_s, 1) s])
  }

  // the changes, under what they belong to
  let y-foot = _h-foot - 6
  line((0, _h-foot - 1), (w, _h-foot - 1), stroke: s-grid)
  let (b, c) = (_arms.first(), _arms.last())
  content((0, y-foot), anchor: "north-west", small(style: "italic")[change])
  let t = 0
  for k in _keys {
    content((x(t) + 4, y-foot), anchor: "north-west", small(_drop(b.kernels.at(k), c.kernels.at(k))))
    t += b.kernels.at(k)
  }
  content((x-sum, y-foot), anchor: "north-east", small(weight: "bold", _drop(b.class_s, c.class_s)))
})

#let perf-class-kernels-figure = [#figure(
  kind: image,
  caption: flex-caption([
    Time of the two kernels of the reliability classification before and after the #spell(_n) changes of this section. One profiled run per build (Nsight Systems, unlocked clocks) on ETH3D _pipes_ at native resolution.
  ], [Classification kernel times before and after the changes]),
  block(breakable: false, width: 100%, layout(size => _chart(size.width))),
) <fig-perf-class-kernels>]
