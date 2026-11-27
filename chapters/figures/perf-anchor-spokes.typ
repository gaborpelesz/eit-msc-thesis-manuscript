// The spoke search of GenNeighbours as a simplified sketch, drawn to show what the first change of
// the anchor stage removes:
//   (a) the search around one unreliable pixel: one spoke per sector, walked outward,
//   (b) one radius step as designed: a random jitter spreads its four tries,
//   (c) the same step where the jitter is zero: the four tries probe the same pixel,
//   (d) the measured tries of an unreliable pixel, split into accepted, rejected and repeated.
// (a) to (c) are sketches, not to scale and not a replay of the kernel: eight sectors instead of
// 16 or 32, a probe is accepted when it lands on a reliable pixel (the kernel also accepts the
// nearest reliable pixel stored for an unreliable probe), and the jitter is drawn larger than it is.
//
// Every measured number is read from ../../generated/perf-4.3/derived/numbers-anchor.json, which
// generated/perf-4.3/scripts/perf43_json.py writes. Do not type numbers into this file.
//
// Use:  #import "figures/perf-anchor-spokes.typ": perf-anchor-spokes-figure
// (perf-anchor-probes-table, the counts and kernel times per round, is defined below and not used
// in the text at present.)
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _v = json("../../generated/perf-4.3/derived/numbers-anchor.json").v
#let _pr = _v.spokes.per_round

// ---- colours and text ------------------------------------------------------------------------------
#let _c-reliable = luma(90%)
#let _c-sector = c-kernel.transparentize(80%)
#let _c-waste = rgb("#eb6834")
#let _s-edge = 0.4pt + luma(55%)
#let _lab(body, ..args) = chart-label(8.5pt, body, ..args)
#let _pt(r, deg) = (r * calc.cos(deg * 1deg), r * calc.sin(deg * 1deg))

// ---- (a) the search around one unreliable pixel ----------------------------------------------------
#let _sectors = 8
#let _radii = (20, 36, 54, 76)                      // the radius steps, in points
// the made-up region of unreliable pixels: its radius around p in the direction `deg`
#let _region(deg) = 46 * (1 + 0.28 * calc.cos((deg - 25) * 1deg) + 0.18 * calc.cos((2 * deg + 60) * 1deg))
#let _panel-search(size) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let c = size / 2
  let at(q) = (c + q.at(0), c + q.at(1))
  let pitch = 360 / _sectors
  rect((0, 0), (size, size), fill: _c-reliable, stroke: _s-edge)
  line(..range(120).map(i => at(_pt(_region(3 * i), 3 * i))), close: true, fill: white, stroke: _s-edge)
  // one sector is shaded; the borders of all sectors are dashed
  line(at((0, 0)), ..range(9).map(j => at(_pt(c - 3, -pitch / 2 + pitch * j / 8))), close: true, fill: _c-sector, stroke: none)
  for k in range(_sectors) {
    line(at((0, 0)), at(_pt(c - 3, pitch * (k + 0.5))), stroke: (paint: luma(45%), thickness: 0.4pt, dash: "dashed"))
  }
  // the spokes: probes are rejected until one lands on a reliable pixel
  for k in range(_sectors) {
    let deg = pitch * k
    let hit = _radii.find(r => r >= _region(deg))
    line(at((0, 0)), at(_pt(hit, deg)), stroke: if k == 0 { 1.2pt + c-ink } else { 0.7pt + luma(35%) })
    for r in _radii.filter(r => r < hit) { circle(at(_pt(r, deg)), radius: 2.7, fill: white, stroke: 0.8pt + c-ink) }
    circle(at(_pt(hit, deg)), radius: 3.4, fill: c-kernel, stroke: 0.5pt + white)
  }
  circle(at((0, 0)), radius: 3.2, fill: c-ink, stroke: none)
})

// ---- (b), (c) the four tries of one radius step ----------------------------------------------------
#let _panel-step(width, jitter) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (half, reach, r) = (17, 132, 104)             // half angle of the sector, its length, the radius step
  let h = 2 * reach * calc.sin(half * 1deg) + 6
  let (x0, y0) = (16, h / 2)
  let at(q) = (x0 + q.at(0), y0 + q.at(1))
  rect((0, 0), (w, h), stroke: none)                // fixes the canvas to the column width
  line(at((0, 0)), ..range(9).map(j => at(_pt(reach, -half + 2 * half * j / 8))), close: true, fill: _c-sector, stroke: none)
  // the radius step: an arc across the sector
  line(..range(13).map(j => at(_pt(r, -half + 2 * half * j / 12))), stroke: (paint: c-kernel-dark, thickness: 0.6pt, dash: "dashed"))
  let tries = if jitter { (11, 4, -4, -11) } else { (0,) }
  for deg in tries {
    line(at((0, 0)), at(_pt(r, deg)), stroke: 0.8pt + c-ink)
    if not jitter { for ring in (6.2, 9, 11.8) { circle(at(_pt(r, deg)), radius: ring, fill: none, stroke: 1pt + _c-waste) } }
    circle(at(_pt(r, deg)), radius: 3.4, fill: c-kernel, stroke: 0.5pt + white)
  }
  circle(at((0, 0)), radius: 3.2, fill: c-ink, stroke: none)
  content((x0 - 9, y0), anchor: "center", chart-label(10pt, $p$))
  let x-text = x0 + reach + 10
  if jitter {
    content((x-text, y0 + 6), anchor: "west", _lab[4 tries,])
    content((x-text, y0 - 6), anchor: "west", _lab[4 different pixels])
  } else {
    content((x-text, y0 + 6), anchor: "west", _lab[4 tries,])
    content((x-text, y0 - 6), anchor: "west", _lab(fill: _c-waste, weight: "bold")[on the same pixel])
  }
})

// ---- (d) the measured tries of one unreliable pixel -------------------------------------------------
// Means per unreliable pixel of the finest round. A radius step that is accepted makes one try; a
// rejected one makes four, of which three repeat the first where the jitter is zero.
#let _panel-tries(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (steps, tries, found) = (_pr.steps.last(), _pr.tries.last(), _pr.found.last())
  let parts = (found, steps - found, tries - steps)
  let (bar, y0) = (15, 15)
  let x(t) = w * t / tries
  rect((0, 0), (w, y0 + bar + 14), stroke: none)
  let (x1, x2) = (x(parts.at(0)), x(steps))
  rect((0, y0), (x1, y0 + bar), fill: c-kernel-dark, stroke: none)
  rect((x1, y0), (x2, y0 + bar), fill: c-kernel-light, stroke: none)
  rect((x2, y0), (w, y0 + bar), fill: _c-waste, stroke: none)
  for v in (x1, x2) { line((v, y0), (v, y0 + bar), stroke: 0.6pt + white) }
  content(((x1 + x2) / 2, y0 + bar / 2), anchor: "center", _lab[#fix(parts.at(1), 0) rejected])
  content(((x2 + w) / 2, y0 + bar / 2), anchor: "center", _lab(fill: white, weight: "bold")[#fix(parts.at(2), 0) repeats of a rejected try (#pct(parts.at(2) / tries, 0))])
  line((x1 / 2, y0 + bar), (x1 / 2, y0 + bar + 4), stroke: 0.5pt + c-ink)
  content((0, y0 + bar + 5), anchor: "south-west", _lab[#fix(parts.at(0), 0) accepted])
  // what the two parts are
  let brace(a, b, body) = {
    line((a + 1, y0 - 3), (a + 1, y0 - 6), (b - 1, y0 - 6), (b - 1, y0 - 3), stroke: 0.5pt + c-muted)
    content(((a + b) / 2, y0 - 8), anchor: "north", _lab(fill: c-muted, body))
  }
  brace(0, x2)[first try of a radius step]
  brace(x2, w)[removed by the first change]
})

#let _title(tag, body) = block(below: 4pt, text(size: 8.5pt, top-edge: "cap-height", bottom-edge: "baseline")[*(#tag)* #body])
#let _legend = {
  set text(size: 8pt, top-edge: "cap-height", bottom-edge: "baseline")
  let dot(fill, stroke) = box(baseline: -0.5pt, circle(radius: 2.6pt, fill: fill, stroke: stroke))
  let item(mark, body) = box[#mark#h(3pt)#body]
  (
    item(dot(c-ink, none))[the unreliable pixel $p$],
    item(box(baseline: -1pt, width: 9pt, height: 5.5pt, fill: white, stroke: _s-edge))[unreliable pixels],
    item(box(baseline: -1pt, width: 9pt, height: 5.5pt, fill: _c-reliable, stroke: _s-edge))[reliable pixels],
    item(dot(white, 0.8pt + c-ink))[rejected probe],
    item(dot(c-kernel, none))[accepted probe],
    item(box(baseline: -1pt, width: 9pt, height: 5.5pt, fill: _c-sector))[one sector],
  ).join(h(8pt))
}

#let perf-anchor-spokes-figure = [#figure(
  kind: image,
  caption: flex-caption([
    The spoke search of `GenNeighbours` as a simplified sketch, showing the removed redundant work.
    *(a)* Every sector around an unreliable pixel $p$ is searched along its spoke, in growing radius steps, until a probe finds a reliable pixel. Eight sectors are drawn; the kernel uses up to #_pr.spokes.last().
    *(b)* A radius step has four tries, and a random jitter spreads them over neighbouring pixels.
    *(c)* In the two finest rounds the jitter is zero in the implementation, and the four tries probe the same pixel.
    *(d)* The measured result: #pct((_pr.tries.last() - _pr.steps.last()) / _pr.tries.last(), 0) of finest round tries are redundant.
  ], [The spoke search and its redundant neighbor searches]),
  layout(size => {
    let gap = 16pt
    let wa = 168pt
    let wb = size.width - wa - gap
    block(breakable: false, width: 100%, {
      set align(left)
      set par(leading: 0.3em, spacing: 0pt)
      set block(spacing: 0pt)
      grid(
        columns: (wa, wb), column-gutter: gap,
        [#_title("a")[One spoke per sector, walked outward]#_panel-search(wa / 1pt)],
        grid(
          columns: (1fr,), row-gutter: 10pt,
          [#_title("b")[One radius step as designed: jitter spreads the tries]#_panel-step(wb, true)],
          [#_title("c")[Two finest radius steps as implemented: no jitter]#_panel-step(wb, false)],
        ),
      )
      v(7pt)
      _legend
      v(12pt)
      _title("d")[The tries of one unreliable pixel in the finest round, measured]
      _panel-tries(size.width)
    })
  }),
) <fig-perf-anchor-spokes>]

// ---- the table: what was counted and timed per round ------------------------------------------------
#let perf-anchor-probes-table = [#figure(
  kind: table,
  caption: flex-caption([
    The spoke search of `GenNeighbours` per round, on ETH3D _pipes_ at native resolution. Round 1 has no unreliable pixels. Radius steps and tries are means per unreliable pixel over all reference image passes of a round, counted by a build of the kernel that carries counters. A try is repeated if it probes the pixel that an earlier try of its radius step probed; this is certain only where the shift range is one. Kernel times are sums over the passes of a round in one run under Nsight Systems, before and after the change.
  ], [The spoke search per round: counts and kernel time]),
  {
    set text(size: 9pt)
    set par(justify: false, leading: 0.5em)
    let n = _pr.rounds.len()
    let before = _v.base.select_round_s
    let after = _v.k3.select_round_s
    let hd(body, ..args) = table.cell(align: bottom, ..args, strong(body))
    let rows = ()
    for i in range(n) {
      let r = _pr.rounds.at(i)
      let (steps, tries) = (_pr.steps.at(i), _pr.tries.at(i))
      let same = _pr.shift_range.at(i) == 1
      rows += (
        [#r], [#_pr.spokes.at(i)], [#_pr.shift_range.at(i)],
        fix(steps, 1), fix(tries, 1), fix(tries / steps, 1),
        if same [#fix(tries - steps, 1) (#pct((tries - steps) / tries, 0))] else [-],
        fix(before.at(r - 1), 1), fix(after.at(r - 1), 1),
      )
    }
    table(
      columns: (auto, auto, auto, 1fr, 1fr, 1fr, auto, auto, auto),
      align: (left, right, right, right, right, right, right, right, right),
      stroke: none,
      inset: (x: 5pt, y: 3.5pt),
      table.hline(stroke: 0.8pt),
      table.header(
        hd(rowspan: 2)[Round], hd(rowspan: 2)[Spokes], hd(rowspan: 2)[Shift\ range],
        hd(colspan: 4, align: center + bottom)[Per unreliable pixel],
        hd(colspan: 2, align: center + bottom)[Kernel time (s)],
        table.hline(start: 3, end: 7, stroke: 0.3pt), table.hline(start: 7, end: 9, stroke: 0.3pt),
        hd[Radius\ steps], hd[Tries], hd[Tries\ per step], hd[Repeated\ tries], hd[Before], hd[After],
      ),
      table.hline(stroke: 0.5pt),
      ..rows,
      table.hline(stroke: 0.5pt),
      table.cell(colspan: 7, strong[All rounds]), strong(fix(_v.base.select_s, 1)), strong(fix(_v.k3.select_s, 1)),
      table.hline(stroke: 0.8pt),
    )
  },
) <tab-perf-anchor-probes>]
