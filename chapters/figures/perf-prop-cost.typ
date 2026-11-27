// One evaluation of the matching cost of an unreliable pixel p, as the fetches it issues.
//
// Two views of the same nine windows, because no single scale shows both facts:
//   the map    the reference image to scale: WHERE the windows of one evaluation lie (the window at
//              p and one at each anchor, tens of pixels apart);
//   the tiles  each window magnified on its pixel grid: WHICH pixels it samples. The tiles are cut
//              out of the map (same reliability mask), not drawn separately.
// The first tile is all that the evaluation of a reliable pixel fetches, so the figure needs no
// panel of its own for the reliable pixel.
//
// What is true to the reference code (upstream = benchmark/methods/APD-MVS at b105b0b):
//   - every window, at p and at an anchor, spans radius 5, i.e. 11 x 11 pixels   main.h:76, :78
//   - the window at p is sampled with step 2 (6 x 6; p itself is not a sample)   main.h:77, APD.cu:460-469
//   - a window at an anchor is sampled with step 5 (3 x 3, the anchor included)  main.h:79, APD.cu:460-469
//   - up to 8 anchors (NEIGHBOUR_NUM 9, entry 0 is p)                            main.h:32, APD.cu:434, :1782, :1966
//   - a sample is one fetch from the reference image at a pixel centre and one
//     from the source image at the point the plane's homography maps it to      APD.cu:471-473
//   - a reliable pixel evaluates the window at p alone                           APD.cu:550-551, :562-570
//   - the anchors come from the search of the reference code, run on this scene
//     (see "the anchor search" below)                                            APD.cu:1798-1836, :2250-2268
// The scene (the shape of the unreliable region, the place of p) is illustrative, and so is which
// 8 of the candidates the plane fit keeps. The counts are read from numbers-prop.json, not typed.
//
// The file also holds perf-prop-zero-figure, at the end.
//
// Use:  #import "figures/perf-prop-cost.typ": perf-prop-cost-figure, perf-prop-zero-figure
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _n = json("../../generated/perf-4.3/derived/numbers-prop.json").v
#let _nc = _n.window.centre     // samples per side of the window at p
#let _na = _n.window.anchor     // samples per side of a window at an anchor
#let _k = _n.anchors            // anchors of an unreliable pixel
#let _r = 5                     // src: upstream main.h:76, :78 (strong_radius, weak_radius)
#let _side = 2 * _r + 1
#let _step-c = int(2 * _r / (_nc - 1))   // 2, src: upstream main.h:77 (strong_increment)
#let _step-a = int(2 * _r / (_na - 1))   // 5, src: upstream main.h:79 (weak_increment)
#assert(_step-c * (_nc - 1) == 2 * _r and _step-a * (_na - 1) == 2 * _r)
#let _s-c = _nc * _nc           // samples of the window at p
#let _s-a = _na * _na           // samples of a window at an anchor
#let _s-all = _s-c + _k * _s-a

// ---- colours -----------------------------------------------------------------------------------
#let _c-p = c-kernel-dark        // the window at p
#let _c-a = c-host               // the windows at the anchors
#let _c-unrel = luma(80%)        // an unreliable pixel
#let _c-edge = luma(35%)         // the outline of the unreliable region
#let _s-cell = 0.25pt + luma(55%)

// ---- the scene: a reference image region of _W x _H pixels (y down) ------------------------------
#let (_W, _H) = (206, 50)
#let _blob = (cx: 100, cy: 25, a: 66, b: 13.5)
#let _unrel(x, y) = {
  let dx = (x - _blob.cx) / _blob.a
  let dy = (y - _blob.cy) / _blob.b
  let ang = calc.atan2(dx, dy)
  let lim = 1 + 0.10 * calc.sin(3 * ang + 0.6rad) + 0.07 * calc.sin(5 * ang + 1.9rad) + 0.03 * calc.sin(11 * ang)
  calc.sqrt(dx * dx + dy * dy) < lim
}
#let _p = (88, 26)
// ---- the anchor search of the reference code, run on this scene (upstream APD.cu:1798-1836) ----
// From p, 8 base directions, each turned 4 times by 45/4 degrees (rotate_time 4, the finest round,
// main.cpp:227), are probed at radii 2, 4, 8, 16, 32, 57, 82, ... A probe on an unreliable pixel
// moves to the nearest reliable pixel within 100 pixels (APD.cu:2250-2268), which lies on the edge
// of the region; a probe on a reliable pixel is taken as it is, beyond the edge. The candidate is
// kept if it lies within half a turn of the direction. With rotate_time 4 the random shift of the
// direction is always 0 (shift_range 1), so the search is deterministic. The map stands for the
// whole image: probes leave it at its border, and the 6-pixel margin applies (APD.cu:1766, :1819).
#let _mask = range(_H).map(y => range(_W).map(x => _unrel(x, y)))
#let _is-unrel(x, y) = _mask.at(y).at(x)
#let _nearest-reliable(px, py) = {
  let best = none
  let md = 255.0
  for x in range(calc.max(-100, -px), calc.min(101, _W - px)) {
    for y in range(calc.max(-100, -py), calc.min(101, _H - py)) {
      if not _is-unrel(px + x, py + y) {
        let d = calc.sqrt(x * x + y * y)
        if d < md { md = d; best = (px + x, py + y) }
      }
    }
  }
  best
}
#let _search(rotate-time) = {
  let ang = 45deg / rotate-time
  let thr = calc.cos(ang / 2)
  let (px, py) = _p
  let found = ()
  for ox in (-1, 0, 1) {
    for oy in (-1, 0, 1) {
      if ox == 0 and oy == 0 { continue }
      let n = calc.sqrt(ox * ox + oy * oy)
      let (dx, dy) = (ox / n, oy / n)
      for turn in range(rotate-time) {
        let r = 2
        let hit = none
        while r <= 4096 {
          let (tx, ty) = (px + dx * r, py + dy * r)
          if tx < 0 or ty < 0 or tx >= _W or ty >= _H { break }
          let q = (int(tx), int(ty))
          if q.at(0) >= 6 and q.at(1) >= 6 and q.at(0) < _W - 6 and q.at(1) < _H - 6 {
            let on-edge = _is-unrel(..q)
            if on-edge { q = _nearest-reliable(..q) }
            if q != none {
              let (vx, vy) = (q.at(0) - px, q.at(1) - py)
              if (vx * dx + vy * dy) / calc.sqrt(vx * vx + vy * vy) > thr {
                hit = (pos: q, base: (ox, oy), turn: turn)
                break
              }
            }
          }
          r = calc.min(r * 2, r + 25)
        }
        if hit != none { found.push(hit) }
        let (nx, ny) = (dx * calc.cos(ang) - dy * calc.sin(ang), dx * calc.sin(ang) + dy * calc.cos(ang))
        let m = calc.sqrt(nx * nx + ny * ny)
        (dx, dy) = (nx / m, ny / m)
      }
    }
  }
  found
}
#let _candidates = _search(4)
// A RANSAC plane fit keeps up to 8 candidates, those closest to the fitted plane (APD.cu:1874-1966).
// That depends on the depths, which the scene does not have; the figure keeps the first candidate
// found in each base direction.
#let _anchors = ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)).map(b => {
  let c = _candidates.filter(c => c.base == b)
  assert(c.len() > 0, message: "no candidate in a base direction")
  c.first().pos
})
#assert(_anchors.len() == _k, message: "one anchor per base direction")
#let _others = _candidates.map(c => c.pos).filter(q => q not in _anchors)
// tiles are ordered left to right as the anchors lie in the map
#let _anchors = _anchors.sorted(key: q => q.at(0))
#assert(_unrel(.._p))

#let _lab(body, ..args) = chart-label(7.5pt, body, ..args)
#let _lab-s(body, ..args) = chart-label(6.5pt, body, ..args)

#let _drawing(width) = cetz.canvas(length: 1mm, {
  import cetz.draw: *
  let w = width / 1mm
  rect((0, 0), (w, -1), stroke: none)   // fixes the canvas to the text width

  // ================= the map: the reference image, to scale =================
  let s = 0.5                    // mm per pixel
  let (mw, mh) = (_W * s, _H * s)
  let mx = 0
  let my = -4.2                  // top edge of the map
  let P(x, y) = (mx + x * s, my - y * s)            // corner of pixel (x, y)
  let C(x, y) = (mx + (x + 0.5) * s, my - (y + 0.5) * s)   // its centre
  content((mx, 0), anchor: "north-west", _lab(weight: "bold")[Reference image, to scale])
  rect((mx, my), (mx + mw, my - mh), fill: white, stroke: none)
  // the unreliable region, pixel by pixel: runs per row, then its outline
  for y in range(_H) {
    let x = 0
    while x < _W {
      if _unrel(x, y) {
        let x1 = x
        while x1 < _W and _unrel(x1, y) { x1 += 1 }
        rect(P(x, y), P(x1, y + 1.1), fill: _c-unrel, stroke: none)
        x = x1
      } else { x += 1 }
    }
  }
  for y in range(_H) {
    for x in range(_W) {
      if _unrel(x, y) {
        if not _unrel(x, y - 1) { line(P(x, y), P(x + 1, y), stroke: 0.45pt + _c-edge) }
        if not _unrel(x, y + 1) { line(P(x, y + 1), P(x + 1, y + 1), stroke: 0.45pt + _c-edge) }
        if not _unrel(x - 1, y) { line(P(x, y), P(x, y + 1), stroke: 0.45pt + _c-edge) }
        if not _unrel(x + 1, y) { line(P(x + 1, y), P(x + 1, y + 1), stroke: 0.45pt + _c-edge) }
      }
    }
  }
  rect((mx, my), (mx + mw, my - mh), fill: none, stroke: 0.5pt + c-ink)
  // the other candidates of the search
  for q in _others { circle(C(..q), radius: 0.32, fill: none, stroke: 0.35pt + _c-a) }
  // spokes from p to its anchors
  for q in _anchors {
    line(C(.._p), C(..q), stroke: 0.4pt + c-ink)
  }
  // the windows
  for (i, q) in _anchors.enumerate() {
    rect(P(q.at(0) - _r, q.at(1) - _r), P(q.at(0) + _r + 1, q.at(1) + _r + 1), fill: none, stroke: 0.9pt + _c-a)
    circle(C(..q), radius: 0.55, fill: _c-a, stroke: none)
  }
  rect(P(_p.at(0) - _r, _p.at(1) - _r), P(_p.at(0) + _r + 1, _p.at(1) + _r + 1), fill: none, stroke: 0.9pt + _c-p)
  circle(C(.._p), radius: 0.55, fill: _c-p, stroke: none)
  // names of the windows, outside their squares
  let name(q, body, side) = {
    let (dx, anchor) = if side == "w" { (-_r - 1.2, "east") } else { (_r + 2.2, "west") }
    content(P(q.at(0) + dx, q.at(1) + 0.5), anchor: anchor, box(fill: none, _lab(body)))
  }
  content(P(_p.at(0) - _r - 1.4, _p.at(1) + 3.6), anchor: "east", _lab($p$))
  // an anchor's name goes on a side of its window: the sides are tried in the order in which they
  // face away from p, and the first one that stays inside the map and clears every window and every
  // name already placed is taken; if none is, the name goes just below the map (boxes in pixels:
  // x0, y0, x1, y1)
  let wins = (_p, .._anchors).map(q => (q.at(0) - _r - 1, q.at(1) - _r - 1, q.at(0) + _r + 2, q.at(1) + _r + 2))   // 1 pixel of clearance
  let hits(a, b) = a.at(0) < b.at(2) and b.at(0) < a.at(2) and a.at(1) < b.at(3) and b.at(1) < a.at(3)
  let placed = ()
  for (i, q) in _anchors.enumerate() {
    let (x, y) = q
    let others = wins.enumerate().filter(((k, _)) => k != i + 1).map(((_, w)) => w)   // its own window aside
    let (vx, vy) = (x - _p.at(0), y - _p.at(1))
    let sides = (
      (d: (1, 0), box: (x + _r + 1.4, y - 1.5, x + _r + 6, y + 2.5), at: P(x + _r + 1.6, y + 0.5), anchor: "west"),
      (d: (-1, 0), box: (x - _r - 5, y - 1.5, x - _r - 0.4, y + 2.5), at: P(x - _r - 0.6, y + 0.5), anchor: "east"),
      (d: (0, -1), box: (x - 1.5, y - _r - 4.5, x + 2.5, y - _r - 0.4), at: P(x + 0.5, y - _r - 0.6), anchor: "south"),
      (d: (0, 1), box: (x - 1.5, y + _r + 1.4, x + 2.5, y + _r + 5.5), at: P(x + 0.5, y + _r + 1.6), anchor: "north"),
    ).sorted(key: c => -(c.d.at(0) * vx + c.d.at(1) * vy)) + (
      // the last resort: just below the map
      (d: (0, 1), box: (x - 1.5, _H, x + 2.5, _H + 4), at: P(x + 0.5, _H + 0.5), anchor: "north", below: true),
    )
    let ok(c) = {
      let b = c.box
      let inside = b.at(0) >= 0 and b.at(1) >= 0 and b.at(2) <= _W and b.at(3) <= _H
      (inside or c.at("below", default: false)) and (others + placed).all(w => not hits(b, w))
    }
    let free = sides.filter(ok)
    let c = if free.len() > 0 { free.first() } else { sides.first() }
    placed.push(c.box)
    content(c.at, anchor: c.anchor, _lab($a_#(i + 1)$))
  }
  // region names
  content(P(134, 23), anchor: "center", _lab(style: "italic")[unreliable pixels])
  content(P(3, _H - 2.5), anchor: "south-west", _lab(style: "italic")[reliable pixels])
  // scale bar
  let (bx, by) = (_W - 54, _H - 3)
  line(P(bx, by), P(bx + 50, by), stroke: 0.6pt + c-ink)
  for x in (bx, bx + 50) { line(P(x, by - 1), P(x, by + 1), stroke: 0.6pt + c-ink) }
  content(P(bx + 25, by - 1.2), anchor: "south", _lab-s[50 pixels])

  // ================= the key, beside the map =================
  let kx = mx + mw + 5
  // swatches
  let sy = my
  let sw(y, fill, body) = {
    rect((kx + 1, y), (kx + 3.6, y - 2.6), fill: fill, stroke: _s-cell)
    content((kx + 5, y - 1.3), anchor: "west", _lab(body))
  }
  sw(sy, _c-unrel)[unreliable pixel]
  sw(sy - 3.6, white)[reliable pixel]
  circle((kx + 2.3, sy - 7.2 - 1.3), radius: 0.32, fill: none, stroke: 0.35pt + _c-a)   // as drawn in the map
  content((kx + 5, sy - 7.2 - 1.3), anchor: "west", _lab[dropped anchor search candidates])

  // ================= the tiles: the same windows, magnified =================
  let gap0 = 4.6                 // between the window at p and the anchors
  let gapa = 1.9                 // between two anchors
  let c = (w - gap0 - (_k - 1) * gapa) / ((_k + 1) * _side)   // cell
  let tw = _side * c
  let ty = my - mh - 9.2         // top edge of the tiles
  let tx(i) = if i == 0 { 0 } else { tw + gap0 + (i - 1) * (tw + gapa) }
  let tile(i, q, step, col) = {
    let x0 = tx(i)
    for j in range(_side) {
      for k in range(_side) {
        let sampled = calc.rem(j, step) == 0 and calc.rem(k, step) == 0
        let fill = if sampled { col } else if _unrel(q.at(0) - _r + k, q.at(1) - _r + j) { _c-unrel } else { white }
        rect((x0 + k * c, ty - j * c), (x0 + (k + 1) * c, ty - (j + 1) * c), fill: fill, stroke: _s-cell)
      }
    }
    rect((x0, ty), (x0 + tw, ty - tw), fill: none, stroke: 0.9pt + col)
    // the pixel the window is centred on
    let (ccx, ccy) = (x0 + (_r + 0.5) * c, ty - (_r + 0.5) * c)
    if calc.rem(_r, step) == 0 {
      circle((ccx, ccy), radius: 0.27 * c, fill: white, stroke: none)
    } else {
      circle((ccx, ccy), radius: 0.27 * c, fill: col, stroke: none)
    }
  }
  content((0, my - mh - 3.2), anchor: "north-west", _lab(weight: "bold")[The same #(_k + 1) windows on the pixel grid: each spans #_side #sym.times #_side pixels; a filled pixel is a sample for cost calculation])
  tile(0, _p, _step-c, _c-p)
  for (i, q) in _anchors.enumerate() { tile(i + 1, q, _step-a, _c-a) }
  content((tx(0) + tw / 2, ty + 0.9), anchor: "south", _lab[at $p$])
  for i in range(_k) { content((tx(i + 1) + tw / 2, ty + 0.9), anchor: "south", _lab[at $a_#(i + 1)$]) }

  // ================= the ledger =================
  let y1 = ty - tw - 2.6
  let cols = (0, 27, 59)
  let row(y, ..cells) = for (x, body) in cols.zip(cells.pos()) {
    content((x, y), anchor: "north-west", _lab(body))
  }
  row(y1, [], [*Windows*], [*No. Samples*])
  line((0, y1 - 3.3), (84, y1 - 3.3), stroke: 0.4pt + luma(55%))
  row(y1 - 4.4, [*Reliable pixel*], [the window at $p$ alone], [#_s-c])
  row(y1 - 8.4, [*Unreliable pixel*], [all #(_k + 1) windows], [#_s-c + #_k #sym.times #_s-a = #_s-all])
})

#let perf-prop-cost-figure = [#figure(
  kind: image,
  caption: flex-caption([
    The evaluation of the matching cost of an unreliable pixel $p$ and the windows it samples for cost calculation. Top: the windows of the evaluation in the reference image, to scale. One window lies at $p$ and one at each of its anchors $a_1$ to $a_#_k$ (a pixel has at most #spell(_k)). Bottom: the same windows, magnified. All of them span #_side #sym.times #_side pixels. The cost window at $p$ samples every #(if _step-c == 2 [second] else [#_step-c;th]) pixel while the cost window at each anchor is kept sparser for performance reasons.
    ], [One evaluation of the matching cost and its fetches]),
  block(breakable: false, width: 100%, layout(size => _drawing(size.width))),
) <fig-perf-prop-cost>]

// =====================================================================================================
// The evaluations of one update and the share that is multiplied by zero (perf-prop-zero-figure):
//   (a) the evaluations of one update: every candidate plane in every source image, and which of
//       them are multiplied by a view weight of zero,
//   (b) the share of these evaluations for an unreliable pixel, from the counted view weights.
// (a) is a sketch, not to scale: five source images instead of about ten, three candidate planes
// per half instead of eight.
#let _v = json("../../generated/perf-4.3/derived/numbers-prop.json").v
#let _c-waste = rgb("#eb6834")
#let _lab-z(body, ..args) = chart-label(8.5pt, body, ..args)

// ---- (a) the evaluations of one update ---------------------------------------------------------------
// One tile is one evaluation: one candidate plane in one source image. The picture reads from top
// to bottom, as the update runs: the first half, the view weights it yields, the second half. A
// column is a source image. In the second half a column of weight zero is drawn as one hatched
// band: its evaluations are computed and then multiplied by zero.
// The colors are those of (b): dark blue serves the view selection, light blue carries a weight.
#let _weights = (true, false, false, true, false)      // sketch: which source images have a weight above zero
#let _rows = 3                                         // rows drawn per half
#let _c-waste-light = _c-waste.lighten(82%)
#let _panel-grid(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (cw, ch, gx, gy) = (27, 11, 6, 3)                // a tile and the gaps
  let x0 = 118                                         // left edge of the columns
  let (h-head, h-chip, gap) = (17, 13, 15)             // head, weight chips, space around the chips
  let h-half = _rows * ch + (_rows - 1) * gy
  let (h-link, h-step) = (11, 15)                     // the arrow into the view selection, its box
  let total = h-head + 2 * h-half + 2 * gap + h-chip + h-link + h-step
  let x(i) = x0 + i * (cw + gx)
  let x1 = x(_weights.len()) - gx
  let (xl, xr) = (x0 - 12, x1 + 14)                    // where the labels end, where the notes begin
  let label-l(y, body) = content((xl, y), anchor: "east", { set par(leading: 0.5em, justify: false); set align(right); body })
  let note-r(y, body) = content((xr, y), anchor: "west", box(width: (w - xr) * 1pt, { set par(leading: 0.5em, justify: false); set align(left); body }))
  // a band with diagonal hatching, clipped to the band by hand
  let band(xa, ya, xb, yb) = {
    rect((xa, ya), (xb, yb), fill: _c-waste-light, stroke: none)
    let (bw, bh, step) = (xb - xa, yb - ya, 5)
    for k in range(1, int((bw + bh) / step) + 1) {
      let c = k * step                                 // the line x - xa + y - ya = c
      let a = (xa + calc.min(c, bw), ya + c - calc.min(c, bw))
      let b = (xa + c - calc.min(c, bh), ya + calc.min(c, bh))
      line(a, b, stroke: 0.7pt + _c-waste)
    }
    rect((xa, ya), (xb, yb), fill: none, stroke: 0.7pt + _c-waste)
  }
  rect((0, 0), (w, total), stroke: none)               // fixes the canvas to the text width
  // head: the columns are the source images
  content(((x0 + x1) / 2, total), anchor: "north", _lab-z(fill: c-muted)[source images])
  line((x0, total - 10), (x0, total - 12.5), (x1, total - 12.5), (x1, total - 10), stroke: 0.5pt + c-muted)
  // the first half: every tile is used, by the view selection
  let top = total - h-head
  for r in range(_rows) {
    let y = top - r * (ch + gy)
    for i in range(_weights.len()) { rect((x(i), y - ch), (x(i) + cw, y), fill: c-kernel-dark, stroke: none) }
  }
  label-l(top - h-half / 2)[#_lab-z(weight: "bold")[Anchor plane \ candidates]]
  note-r(top - h-half / 2, _lab-z(fill: c-muted)[evaluated in every source image])
  // the costs of the first half feed the pixelwise view selection
  let xm-all = (x0 + x1) / 2
  let yb = top - h-half
  line((x0, yb - 2), (x0, yb - 4.5), (x1, yb - 4.5), (x1, yb - 2), stroke: 0.5pt + c-muted)
  line((xm-all, yb - 4.5), (xm-all, yb - h-link), stroke: 0.5pt + c-muted, mark: (end: (symbol: ">", fill: c-muted, scale: 0.45)))
  let ys = yb - h-link
  rect((x0, ys - h-step), (x1, ys), fill: luma(94%), stroke: 0.5pt + c-muted, radius: 2)
  content((xm-all, ys - h-step / 2), anchor: "center", _lab-z[pixelwise view selection])
  // the view weights, one chip per source image
  let yc = ys - h-step - gap - h-chip / 2
  for (i, on) in _weights.enumerate() {
    let xm = x(i) + cw / 2
    line((xm, yc + h-chip / 2 + gap - 3), (xm, yc + h-chip / 2 + 3), stroke: 0.5pt + c-muted, mark: (end: (symbol: ">", fill: c-muted, scale: 0.45)))
    rect((x(i), yc - h-chip / 2), (x(i) + cw, yc + h-chip / 2), radius: h-chip / 2,
      fill: if on { white } else { _c-waste-light }, stroke: 0.7pt + if on { c-kernel-dark } else { _c-waste })
    content((xm, yc), anchor: "center", _lab-z(if on [$> 0$] else [$0$], fill: if on { c-kernel-dark } else { _c-waste }, weight: if on { "regular" } else { "bold" }))
  }
  label-l(yc, _lab-z(weight: "bold")[View weights])
  // the second half: a column with a weight is used, a column of weight zero is one band
  let top2 = yc - h-chip / 2 - gap
  for (i, on) in _weights.enumerate() {
    if on {
      for r in range(_rows) {
        let y = top2 - r * (ch + gy)
        rect((x(i), y - ch), (x(i) + cw, y), fill: c-kernel-light, stroke: none)
      }
      line((x(i) + cw / 2, yc - h-chip / 2 - 3), (x(i) + cw / 2, top2 + 3), stroke: 0.5pt + c-muted, mark: (end: (symbol: ">", fill: c-muted, scale: 0.45)))
    } else {
      band(x(i), top2 - h-half, x(i) + cw, top2)
      line((x(i) + cw / 2, yc - h-chip / 2 - 3), (x(i) + cw / 2, top2 + 3), stroke: 0.5pt + _c-waste, mark: (end: (symbol: ">", fill: _c-waste, scale: 0.45)))
    }
  }
  label-l(top2 - h-half / 2)[#_lab-z(weight: "bold")[Other candidates]\ #_lab-z[current plane, planar\ prior, refined planes]]
  note-r(top2 - h-half / 2)[#_lab-z(fill: c-muted)[scored by the weighted mean of their costs]\ #_lab-z(fill: _c-waste, weight: "bold")[always computed, then #sym.times 0]]
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
  content((x1 / 2, y0 + bar / 2), anchor: "center", _lab-z(fill: white)[#pct(_selection, 0) for the pixelwise view selection])
  content(((x1 + x2) / 2, y0 + bar / 2), anchor: "center", _lab[#pct(1 - _selection - _zero, 0) with a weight])
  content(((x2 + w) / 2, y0 + bar / 2), anchor: "center", _lab-z(fill: white, weight: "bold")[#pct(_zero, 0) multiplied by zero])
  let brace(a, b, body) = {
    line((a + 1, y0 - 3), (a + 1, y0 - 6), (b - 1, y0 - 6), (b - 1, y0 - 3), stroke: 0.5pt + c-muted)
    content(((a + b) / 2, y0 - 8), anchor: "north", _lab-z(fill: c-muted, body))
  }
  brace(0, x2)[used]
  brace(x2, w)[skipped by the third change]
})

#let _title(tag, body) = block(below: 4pt, text(size: 8.5pt, top-edge: "cap-height", bottom-edge: "baseline")[*(#tag)* #body])
// The evaluations of one update and the share that is multiplied by zero: placed in the
// subsection on the source images of zero weight.
#let perf-prop-zero-figure = [#figure(
  kind: image,
  caption: flex-caption([
    The evaluations of one update of an unreliable pixel. *(a)* Every candidate plane is evaluated in every source image. First the anchor candidates are computed and they yield the view weights. Then, the remaining candidates are computed and scored with the weights. *(b)* From measurements: #pct(_zero, 0) of all evaluations are multiplied by zero in the implementation.
  ], [The evaluations of an update and those of zero weight]),
  layout(size => block(breakable: false, width: 100%, {
    set align(left)
    set par(leading: 0.3em, spacing: 0pt)
    set block(spacing: 0pt)
    _title("a")[One update: every candidate plane is evaluated in every source image]
    v(6pt)
    _panel-grid(size.width)
    v(14pt)
    _title("b")[Measured: the evaluations of one unreliable pixel in the finest round]
    _panel-share(size.width)
  })),
) <fig-perf-prop-zero>]
