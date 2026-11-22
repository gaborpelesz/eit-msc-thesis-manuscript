// The matching cost of the propagation kernels as a simplified sketch, drawn to show what the
// change "zero-weight views skipped" removes:
//   (a) one evaluation for a reliable pixel: one window of samples,
//   (b) one evaluation for an unreliable pixel: the same window and a sparser one at each anchor,
//   (c) the evaluations of one update: every candidate plane in every source image, and which of
//       them are multiplied by a view weight of zero,
//   (d) the share of these evaluations for an unreliable pixel, from the counted view weights.
// (a) to (c) are sketches, not to scale: four anchors instead of eight, five source images instead
// of about ten, four candidate planes per group instead of eight. The windows show the real number
// of samples.
//
// Every measured or counted number is read from
//   ../../generated/perf-4.3/derived/numbers-prop.json
// which generated/perf-4.3/scripts/perf43_json.py writes. Do not type numbers into this file.
//
// Use:  #import "figures/perf-prop-cost.typ": perf-prop-cost-figure
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _v = json("../../generated/perf-4.3/derived/numbers-prop.json").v

// ---- colours and text ------------------------------------------------------------------------------
#let _c-reliable = luma(90%)
#let _c-waste = rgb("#eb6834")
#let _s-edge = 0.4pt + luma(55%)
#let _lab(body, ..args) = chart-label(8.5pt, body, ..args)

// ---- the windows -------------------------------------------------------------------------------------
#let _side = 40                                   // a window, in points; both kinds cover the same area
#let _h-win = 112                                 // height of the panels (a) and (b)
// the samples of a window with n x n samples around `c`; the centre of an anchor window is the anchor
#let _window(c, n, at-anchor: false) = {
  import cetz.draw: *
  let (cx, cy) = c
  rect((cx - _side / 2 - 4, cy - _side / 2 - 4), (cx + _side / 2 + 4, cy + _side / 2 + 4), fill: c-kernel.transparentize(86%), stroke: 0.4pt + c-kernel-dark)
  let pitch = _side / (n - 1)
  for i in range(n) {
    for j in range(n) {
      circle((cx - _side / 2 + i * pitch, cy - _side / 2 + j * pitch), radius: 1.5, fill: c-kernel-dark, stroke: none)
    }
  }
  if at-anchor { circle(c, radius: 3.4, fill: c-kernel, stroke: 0.6pt + white) } else { circle(c, radius: 3.2, fill: c-ink, stroke: none) }
}

// (a) a reliable pixel
#let _panel-reliable(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  rect((0, 0), (w, _h-win), fill: _c-reliable, stroke: _s-edge)
  _window((w / 2, _h-win / 2), _v.window.centre)
})

// (b) an unreliable pixel and its anchors; the anchors are given relative to the pixel
#let _anchors = ((-116, 10), (114, -12), (-58, -30), (60, 30))
#let _panel-unreliable(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (cx, cy) = (w / 2, _h-win / 2)
  rect((0, 0), (w, _h-win), fill: _c-reliable, stroke: _s-edge)
  circle((cx, cy), radius: (72, 29), fill: white, stroke: _s-edge)       // the made-up region of unreliable pixels
  for (dx, dy) in _anchors {
    line((cx, cy), (cx + dx, cy + dy), stroke: (paint: luma(40%), thickness: 0.5pt, dash: "dashed"))
  }
  for (dx, dy) in _anchors { _window((cx + dx, cy + dy), _v.window.anchor, at-anchor: true) }
  _window((cx, cy), _v.window.centre)
})

// ---- (c) the evaluations of one update ---------------------------------------------------------------
// One cell is one evaluation: one candidate plane in one source image. The two groups of rows are
// the two halves of an update; the second half is only used multiplied by the view weight.
#let _weights = (true, false, false, true, false)      // sketch: which source images have a weight above zero
#let _rows = 4                                         // rows drawn per group
#let _panel-grid(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (cw, ch, gx, gy) = (24, 10, 3, 3)                // a cell and the gaps
  let x0 = 116                                         // left edge of the cells
  let group-gap = 9
  let h-head = 26
  let h-group = _rows * ch + (_rows - 1) * gy
  let total = h-head + 2 * h-group + group-gap
  let x(i) = x0 + i * (cw + gx)
  let x1 = x(_weights.len()) - gx
  rect((0, 0), (w, total), stroke: none)               // fixes the canvas to the text width
  // head: the source images and their view weights
  content(((x0 + x1) / 2, total), anchor: "north", _lab[source images])
  content((x0 - 8, total - 19), anchor: "east", _lab[view weight])
  for (i, on) in _weights.enumerate() {
    content((x(i) + cw / 2, total - 19), anchor: "center", _lab(if on [$> 0$] else [$0$], fill: if on { c-ink } else { _c-waste }, weight: if on { "regular" } else { "bold" }))
  }
  // the two groups
  let groups = (
    (label: [the candidate planes\ of the anchors], note: [evaluated in every source image:\ the view weights come from these costs], weighted: false),
    (label: [current plane, planar\ prior, refined planes], note: [scored by the weighted mean of their costs:\ a cost with weight zero is discarded], weighted: true),
  )
  let top = total - h-head
  for g in groups {
    for r in range(_rows) {
      let y = top - r * (ch + gy)
      for (i, on) in _weights.enumerate() {
        rect((x(i), y - ch), (x(i) + cw, y), fill: if g.weighted and not on { _c-waste } else { c-kernel }, stroke: none)
      }
    }
    let (ya, yb) = (top, top - h-group)
    line((x0 - 5, ya), (x0 - 8, ya), (x0 - 8, yb), (x0 - 5, yb), stroke: 0.5pt + c-muted)
    content((x0 - 12, (ya + yb) / 2), anchor: "east", { set par(leading: 0.45em, justify: false); set align(right); _lab(g.label) })
    content((x1 + 12, (ya + yb) / 2), anchor: "west", box(width: (w - x1 - 12) * 1pt, { set par(leading: 0.45em, justify: false); set align(left); _lab(g.note, fill: c-muted) }))
    top = yb - group-gap
  }
})

// ---- (d) the evaluations of an unreliable pixel -------------------------------------------------------
// Half of the evaluations per source image serve the view selection. Of the other half, the share
// of the source images without a weight is multiplied by zero (means of the finest round).
#let _calls = _v.calls
#let _selection = _calls.selection_per_view / (_calls.deformable_per_view + _calls.plain_per_view)
#let _zero = (1 - _selection) * (1 - _v.views.weighted / _v.views.total)
#let _panel-share(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (bar, y0) = (15, 15)
  let (x1, x2) = (w * _selection, w * (1 - _zero))
  rect((0, 0), (w, y0 + bar), stroke: none)
  rect((0, y0), (x1, y0 + bar), fill: c-kernel-dark, stroke: none)
  rect((x1, y0), (x2, y0 + bar), fill: c-kernel-light, stroke: none)
  rect((x2, y0), (w, y0 + bar), fill: _c-waste, stroke: none)
  for v in (x1, x2) { line((v, y0), (v, y0 + bar), stroke: 0.6pt + white) }
  content((x1 / 2, y0 + bar / 2), anchor: "center", _lab(fill: white)[#pct(_selection, 0) for the view selection])
  content(((x1 + x2) / 2, y0 + bar / 2), anchor: "center", _lab[#pct(1 - _selection - _zero, 0) with a weight])
  content(((x2 + w) / 2, y0 + bar / 2), anchor: "center", _lab(fill: white, weight: "bold")[#pct(_zero, 0) multiplied by zero])
  let brace(a, b, body) = {
    line((a + 1, y0 - 3), (a + 1, y0 - 6), (b - 1, y0 - 6), (b - 1, y0 - 3), stroke: 0.5pt + c-muted)
    content(((a + b) / 2, y0 - 8), anchor: "north", _lab(fill: c-muted, body))
  }
  brace(0, x2)[used]
  brace(x2, w)[skipped by the third change]
})

#let _title(tag, body) = block(below: 4pt, text(size: 8.5pt, top-edge: "cap-height", bottom-edge: "baseline")[*(#tag)* #body])
#let _legend-items = {
  let dot(r, fill, stroke) = box(baseline: -0.5pt, circle(radius: r, fill: fill, stroke: stroke))
  let sq(fill, stroke) = box(baseline: -1pt, width: 9pt, height: 5.5pt, fill: fill, stroke: stroke)
  let item(mark, body) = box[#mark#h(3pt)#body]
  (
    cost: (
      item(dot(2.6pt, c-ink, none))[the pixel],
      item(dot(2.6pt, c-kernel, none))[anchor],
      item(dot(1.5pt, c-kernel-dark, none))[sample],
      item(sq(white, _s-edge))[unreliable pixels],
      item(sq(_c-reliable, _s-edge))[reliable pixels],
    ),
    zero: (
      item(sq(c-kernel, none))[evaluation],
      item(sq(_c-waste, none))[evaluation multiplied by zero],
    ),
  )
}
#let _legend(items) = {
  set text(size: 8pt, top-edge: "cap-height", bottom-edge: "baseline")
  items.join(h(8pt))
}

// The windows of one evaluation: placed with the paragraph that defines an evaluation.
#let perf-prop-cost-figure = [#figure(
  kind: image,
  caption: flex-caption([
    One evaluation of the matching cost, as a simplified sketch. *(a)* For a reliable pixel it compares one window around the pixel. *(b)* For an unreliable pixel it also compares a smaller window at each anchor, so its fetches are scattered.
  ], [The windows of one evaluation of the matching cost]),
  layout(size => {
    let gap = 16pt
    let wa = 112pt
    let wb = size.width - wa - gap
    block(breakable: false, width: 100%, {
      set align(left)
      set par(leading: 0.3em, spacing: 0pt)
      set block(spacing: 0pt)
      grid(
        columns: (wa, wb), column-gutter: gap,
        [#_title("a")[Reliable pixel: one window]#_panel-reliable(wa)],
        [#_title("b")[Unreliable pixel: its window, and a smaller one at each anchor]#_panel-unreliable(wb)],
      )
      v(8pt)
      _legend(_legend-items.cost)
    })
  }),
) <fig-perf-prop-cost>]

// The evaluations of one update and the share that is multiplied by zero: placed in the
// subsection on the source images of zero weight.
#let perf-prop-zero-figure = [#figure(
  kind: image,
  caption: flex-caption([
    The evaluations of one update of an unreliable pixel, as a simplified sketch. *(a)* Every candidate plane is evaluated in every source image, although the second half of the candidates only uses the source images with a weight above zero. *(b)* Measured in the finest round: #pct(_zero, 0) of all evaluations are multiplied by zero.
  ], [The evaluations of an update and those of zero weight]),
  layout(size => block(breakable: false, width: 100%, {
    set align(left)
    set par(leading: 0.3em, spacing: 0pt)
    set block(spacing: 0pt)
    _title("a")[One update: every candidate plane is evaluated in every source image]
    v(3pt)
    _panel-grid(size.width)
    v(8pt)
    _legend(_legend-items.zero)
    v(12pt)
    _title("b")[Measured: the evaluations of one unreliable pixel in the finest round]
    _panel-share(size.width)
  })),
) <fig-perf-prop-zero>]
