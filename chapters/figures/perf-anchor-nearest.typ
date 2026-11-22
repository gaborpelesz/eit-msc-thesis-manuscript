// How the nearest table is built, as a simplified sketch, drawn to show what the change "nearest
// table in two passes" removes:
//   (a) before: every pixel of the window is read for one unreliable pixel,
//   (b) pass 1: every pixel finds the nearest reliable pixel in its own column,
//   (c) pass 2: an unreliable pixel reads one result per column, along its row, and keeps the nearest,
//   (d) the reads per pixel before and after.
// (a) to (c) are sketches: a window of 11 x 11 pixels instead of 201 x 201, with made-up reliable
// pixels. In (b) only the pixels of one row are shown doing their column search, and the pixels
// that this search reads are not marked.
//
// Every measured or counted number is read from
//   ../../generated/perf-4.3/derived/numbers-anchor.json
// which generated/perf-4.3/scripts/perf43_json.py writes. Do not type numbers into this file.
//
// Use:  #import "figures/perf-anchor-nearest.typ": perf-anchor-nearest-figure
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _w = json("../../generated/perf-4.3/derived/numbers-anchor.json").v.window

// ---- colours and text ------------------------------------------------------------------------------
#let _c-waste = rgb("#eb6834")
#let _c-read-before = _c-waste.transparentize(72%)
#let _c-read-after = c-kernel.transparentize(72%)
#let _c-reliable = luma(38%)
#let _lab(body, ..args) = chart-label(8.5pt, body, ..args)
// a count with a thousands separator
#let _count(n) = {
  let s = str(n)
  if s.len() > 3 { s.slice(0, s.len() - 3) + "," + s.slice(s.len() - 3) } else { s }
}

// ---- the made-up window ----------------------------------------------------------------------------
#let _half = 5                                     // the sketch window is 11 x 11
// reliable pixels, as (column, row) relative to p; rows grow downwards
#let _reliable = ((-4, -3), (-4, 2), (-2, 4), (-1, -5), (2, -2), (3, 3), (4, 1), (5, -4))
// pass 1 for the pixels of p's row: the nearest reliable pixel of each column, or none
#let _column-nearest(x) = {
  let own = _reliable.filter(q => q.at(0) == x).sorted(key: q => calc.abs(q.at(1)))
  if own.len() > 0 { own.first() } else { none }
}
#let _candidates = range(-_half, _half + 1).map(_column-nearest).filter(q => q != none)
#let _dist2(q) = q.at(0) * q.at(0) + q.at(1) * q.at(1)
#let _nearest = _candidates.sorted(key: _dist2).first()
#assert(_candidates.filter(q => _dist2(q) == _dist2(_nearest)).len() == 1, message: "the sketch must have one nearest pixel")

// One window. `mode` is "scan" (a), "columns" (b) or "row" (c).
#let _panel(size, mode) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let n = 2 * _half + 1
  let cell = size / n
  let corner(x, y) = ((x + _half) * cell, (_half - y) * cell)          // lower left corner of a cell
  let mid(q) = ((q.at(0) + _half + 0.5) * cell, (_half - q.at(1) + 0.5) * cell)
  let fill-cell(q, fill) = rect(corner(..q), (corner(..q).at(0) + cell, corner(..q).at(1) + cell), fill: fill, stroke: none)
  // which pixels are read
  for x in range(-_half, _half + 1) {
    for y in range(-_half, _half + 1) {
      let read = if mode == "scan" { _c-read-before } else if mode == "row" and y == 0 { _c-read-after } else { none }
      if read != none { fill-cell((x, y), read) }
    }
  }
  // the grid
  for i in range(n + 1) {
    line((i * cell, 0), (i * cell, size), stroke: 0.3pt + luma(70%))
    line((0, i * cell), (size, i * cell), stroke: 0.3pt + luma(70%))
  }
  rect((0, 0), (size, size), stroke: 0.5pt + luma(45%))
  // the reliable pixels
  for q in _reliable { fill-cell(q, _c-reliable) }
  let inset(q, fill) = rect((corner(..q).at(0) + 0.5, corner(..q).at(1) + 0.5), (corner(..q).at(0) + cell - 0.5, corner(..q).at(1) + cell - 0.5), fill: fill, stroke: none)
  if mode == "columns" {
    // the row of p, whose pixels are shown doing their column search
    rect(corner(-_half, 0), (size, corner(-_half, 0).at(1) + cell), fill: none, stroke: 0.9pt + c-ink)
    // every pixel of p's row points at the nearest reliable pixel of its column
    for c in _candidates {
      line(mid((c.at(0), 0)), mid(c), stroke: 0.9pt + c-kernel-dark, mark: (end: ">", fill: c-kernel-dark, scale: 0.45))
    }
  }
  if mode == "row" {
    // p compares the candidates of the columns
    for c in _candidates.filter(c => c != _nearest) { line(mid((0, 0)), mid(c), stroke: 0.5pt + luma(40%)) }
  }
  if mode != "columns" {
    inset(_nearest, c-kernel)
    line(mid((0, 0)), mid(_nearest), stroke: 1.3pt + c-kernel)
  }
  inset((0, 0), c-ink)
})

// ---- (d) the reads per pixel -------------------------------------------------------------------------
#let _panel-reads(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (bar, y0) = (15, 15)
  let x1 = calc.max(w * _w.two_pass_samples / _w.samples, 4)
  rect((0, 0), (w, y0 + bar + 14), stroke: none)
  rect((0, y0), (x1, y0 + bar), fill: c-kernel, stroke: none)
  rect((x1, y0), (w, y0 + bar), fill: _c-waste, stroke: none)
  line((x1, y0), (x1, y0 + bar), stroke: 0.6pt + white)
  content(((x1 + w) / 2, y0 + bar / 2), anchor: "center", _lab(fill: white, weight: "bold")[#_count(_w.samples) pixels read in the window of #_w.side #sym.times #_w.side])
  line((x1 / 2, y0 + bar), (x1 / 2, y0 + bar + 4), stroke: 0.5pt + c-ink)
  content((0, y0 + bar + 5), anchor: "south-west", _lab[at most #_w.two_pass_samples in the two passes])
  line((x1 + 1, y0 - 3), (x1 + 1, y0 - 6), (w - 1, y0 - 6), (w - 1, y0 - 3), stroke: 0.5pt + c-muted)
  content(((x1 + w) / 2, y0 - 8), anchor: "north", _lab(fill: c-muted)[removed by the change])
})

#let _title(tag, body) = block(below: 4pt, text(size: 8.5pt, top-edge: "cap-height", bottom-edge: "baseline")[*(#tag)* #body])
#let _legend = {
  set text(size: 8pt, top-edge: "cap-height", bottom-edge: "baseline")
  let sq(fill) = box(baseline: -0.6pt, width: 6.5pt, height: 6.5pt, fill: fill, stroke: 0.3pt + luma(60%))
  let item(mark, body) = box[#mark#h(3pt)#body]
  (
    item(sq(c-ink))[the unreliable pixel $p$],
    item(sq(_c-reliable))[reliable pixel],
    item(sq(c-kernel))[nearest reliable pixel of $p$],
    item(sq(_c-read-before))[read by the scan],
    item(sq(_c-read-after))[read by pass 2],
  ).join(h(9pt))
}

#let perf-anchor-nearest-figure = [#figure(
  kind: image,
  caption: flex-caption([
    Building the nearest table, as a simplified sketch with a window of #(2 * _half + 1) #sym.times #(2 * _half + 1) pixels instead of #_w.side #sym.times #_w.side.
    *(a)* Before the change, every pixel of the window is read to find the nearest reliable pixel of one unreliable pixel $p$.
    *(b)* The first pass lets every pixel find the nearest reliable pixel in its own column. The pixels of the row of $p$ are shown; a column without an arrow holds no reliable pixel.
    *(c)* The second pass lets $p$ read these results along its row, one per column, and keep the nearest.
    *(d)* The pixels read for one pixel, before and after.
  ], [Building the nearest table in two passes]),
  layout(size => {
    let gap = 22pt
    let side = calc.min((size.width - 2 * gap) / 3, 130pt)
    block(breakable: false, width: 100%, {
      set align(left)
      set par(leading: 0.3em, spacing: 0pt)
      set block(spacing: 0pt)
      grid(
        columns: (side,) * 3, column-gutter: (size.width - 3 * side) / 2,
        [#_title("a")[Before: the whole window]#_panel(side / 1pt, "scan")],
        [#_title("b")[Pass 1: nearest in each column]#_panel(side / 1pt, "columns")],
        [#_title("c")[Pass 2: nearest along the row]#_panel(side / 1pt, "row")],
      )
      v(7pt)
      _legend
      v(12pt)
      _title("d")[Pixels read to find the nearest reliable pixel of one pixel]
      _panel-reads(size.width)
    })
  }),
) <fig-perf-anchor-nearest>]
