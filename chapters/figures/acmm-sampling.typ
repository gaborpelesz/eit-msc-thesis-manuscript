// Adaptive checkerboard sampling, after the style of Gipuma's Figure 2.
// Region geometry from APD-MVS's APD.cu (CheckerboardPropagationStrong) at
// fork b105b0b, which matches ACMM's paper (7-sample V, 11-sample strip):
//   near V (up):    (0,-1), (+-1,-2), (+-2,-3), (+-3,-4)  and its 3 rotations
//   far strip (up): (0,-3), (0,-5), ..., (0,-23)          and its 3 rotations
// Every offset has odd |dx|+|dy|, so every sample has the other colour.
// (ACMM's own code uses (0,-2), (+-1,-3), (+-2,-4) instead: same colour,
// a data race, see ledger C-DEBT-148.)
// Offsets are (dx, dy) with dy < 0 meaning up.
#import "@preview/cetz:0.4.2"

#let _black = luma(30%)
#let _red = rgb("#c0392b")
#let _region = rgb("#eb9d93")      // light red, sampling regions
#let _pick = rgb("#f1c40f")        // yellow, chosen candidate
#let _arrow = rgb("#1f6feb")       // saturated blue: complement of the warm cells and dots
#let _grid = 0.3pt + luma(60%)

// the 8 sampling regions as lists of (dx, dy)
#let _rot(o, k) = {   // rotate an up-pointing offset by k quarter turns
  let (x, y) = o
  for _ in range(k) { (x, y) = (-y, x) }
  (x, y)
}
#let _near-up = ((0, -1), (-1, -2), (1, -2), (-2, -3), (2, -3), (-3, -4), (3, -4))
#let _far-up(reach) = range(3, reach + 1, step: 2).map(d => (0, -d))
#let acmm-regions(reach: 23) = range(4).map(k => _near-up.map(o => _rot(o, k))) + range(4).map(k => _far-up(reach).map(o => _rot(o, k)))

// draw an r-radius window of cells around p = (0, 0)
#let _cells(r, cell, fill-of) = {
  import cetz.draw: *
  for y in range(-r, r + 1) {
    for x in range(-r, r + 1) {
      rect((x * cell, -y * cell), ((x + 1) * cell, -(y + 1) * cell),
        fill: fill-of(x, y), stroke: _grid)
    }
  }
}
#let _c(x, y, cell) = ((x + 0.5) * cell, -(y + 0.5) * cell)
#let _is-black(x, y) = calc.rem(calc.abs(x + y), 2) == 0   // p = (0, 0) is black
// a small dot in every cell, in the cell's checkerboard colour
#let _dots(r, cell) = {
  import cetz.draw: *
  for y in range(-r, r + 1) {
    for x in range(-r, r + 1) {
      if (x, y) != (0, 0) {
        circle(_c(x, y, cell), radius: cell * 0.16, stroke: none,
          fill: if _is-black(x, y) { _black } else { _red })
      }
    }
  }
}

// (c) the lowest-cost pixel of each region becomes a candidate for p
#let panel-candidates(r: 11, size: 4.2,
  picks: ((2, -3), (0, -7), (-1, 2), (0, 9), (-4, -3), (-5, 0), (3, 2), (11, 0))) = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let cell = size / (2 * r + 1)
  let k = size / 4.2   // arrows were sized for a 4.2 cm panel; scale them with it
  let inside = acmm-regions(reach: r).flatten().chunks(2)
  _cells(r, cell, (x, y) => if (x, y) == (0, 0) { _black } else if (x, y) in inside { _region } else { white })
  _dots(r, cell)
  for (x, y) in picks {
    // stop the arrow just outside p's cell
    let len = calc.sqrt(x * x + y * y)
    let stop = 0.75 / len
    // a thin, slightly transparent white halo lifts the arrow off the dots and
    // grid lines without hiding the shaded sampling cells underneath
    line(_c(x, y, cell), _c(x * stop, y * stop, cell), stroke: k * 1.5pt + white.transparentize(30%))
    line(_c(x, y, cell), _c(x * stop, y * stop, cell), stroke: k * 0.9pt + _arrow,
      mark: (end: ">", fill: _arrow, scale: k * 0.4))
  }
  for (x, y) in picks { circle(_c(x, y, cell), radius: cell * 0.38, fill: _pick, stroke: k * 0.5pt + _black) }
})
