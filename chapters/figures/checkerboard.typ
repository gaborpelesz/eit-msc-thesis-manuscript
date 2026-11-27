// Checkerboard (red-black) propagation, the parallel counterpart of panel (b) of
// patchmatch.typ.
// (a), (b) The two half-steps of one iteration on a piece of the pixel grid of I_r. In (a)
//     every red pixel is updated at the same time and reads only black pixels; in (b) the
//     roles are swapped. A ring marks a pixel that is written in the half-step, a solid dot
//     a pixel that is only read. For legibility the arrows of (a) and (b) come from the four
//     nearest neighbours only.
// (c) The candidates of one pixel p as Gipuma defines them (Galliani et al., ICCV 2015,
//     Sec. 3.1 and Fig. 2b/2c): 20 pixels of the other colour in the standard pattern,
//       (+-1, 0), (0, +-1), (+-3, 0), (0, +-3), (+-5, 0), (0, +-5), (+-1, +-2), (+-2, +-1),
//     of which the fast setting (Sec. 5.1) keeps the innermost and the outermost four,
//       (+-1, 0), (0, +-1), (+-5, 0), (0, +-5).
//     Every offset has odd |dx| + |dy|, so every candidate has the other colour.
// Colours of the cells as in acmm-sampling.typ; arrows as in patchmatch.typ.
//
// Use:  #import "figures/checkerboard.typ": checkerboard-figure   then   #checkerboard-figure
#import "@preview/cetz:0.4.2"
#import "../../template/elteikthesis.typ": flex-caption
#import "plane-sweep.typ": _ink, _soft, _t

#let _black = luma(30%)
#let _red = rgb("#c0392b")
#let _grid = 0.3pt + luma(60%)
#let _prop = _ink                  // propagation arrows, as in patchmatch.typ

#let _is-black(x, y) = calc.rem(calc.abs(x + y), 2) == 0   // p = (0, 0) is black
#let _col(x, y) = if _is-black(x, y) { _black } else { _red }
#let _tint(col) = if col == _red { _red.lighten(78%) } else { luma(84%) }

// Gipuma's candidate offsets (dx, dy)
#let _fast = ((1, 0), (-1, 0), (0, 1), (0, -1), (5, 0), (-5, 0), (0, 5), (0, -5))
#let _standard = _fast + ((3, 0), (-3, 0), (0, 3), (0, -3), (1, 2), (1, -2), (-1, 2), (-1, -2), (2, 1), (2, -1), (-2, 1), (-2, -1))

#let _arrow(a, b, k: 1) = {
  import cetz.draw: *
  line(a, b, stroke: k * 2.2pt + white.transparentize(25%))
  line(a, b, stroke: k * 0.9pt + _prop, mark: (end: ">", fill: _prop, scale: k * 0.4))
}
// a pixel that is only read: a solid dot; a pixel that is written: a ring
#let _read(at, col, r) = cetz.draw.circle(at, radius: r, fill: col, stroke: none)
#let _written(at, col, r) = cetz.draw.circle(at, radius: r, fill: white, stroke: 1.1pt + col)

// ---------------------------------------------------------------- (a), (b) the half-steps

#let _h = 2                        // the piece of I_r shown: (2 h + 1) pixels per side
#let _cell = 0.74
#let _size = (2 * _h + 1) * _cell
#let _gap = 1.0                    // between the two half-steps

// one half-step with its lower left corner at x0: the pixels of colour `upd` are updated
#let _half-step(x0, upd, mark-p: false) = {
  import cetz.draw: *
  let c(x, y) = (x0 + (x + _h + 0.5) * _cell, -(y + _h + 0.5) * _cell)
  let cells = range(-_h, _h + 1)
  for y in cells {
    for x in cells {
      let col = _col(x, y)
      rect((x0 + (x + _h) * _cell, -(y + _h) * _cell), (x0 + (x + _h + 1) * _cell, -(y + _h + 1) * _cell),
        fill: if col == upd { _tint(col) } else { white }, stroke: _grid)
    }
  }
  rect((x0, 0), (x0 + _size, -_size), stroke: 0.8pt + _ink)
  if mark-p {
    rect((x0 + _h * _cell, -_h * _cell), (x0 + (_h + 1) * _cell, -(_h + 1) * _cell), stroke: 1.1pt + _ink)
  }
  // every updated pixel takes candidates from its neighbours of the other colour
  for y in cells {
    for x in cells {
      if _col(x, y) == upd {
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)) {
          if calc.abs(x + dx) <= _h and calc.abs(y + dy) <= _h {
            let (ax, ay) = c(x + dx, y + dy)
            let (bx, by) = c(x, y)
            // dy counts downwards, the canvas upwards
            _arrow((ax - dx * 0.2 * _cell, ay + dy * 0.2 * _cell), (bx + dx * 0.27 * _cell, by - dy * 0.27 * _cell))
          }
        }
      }
    }
  }
  for y in cells {
    for x in cells {
      let col = _col(x, y)
      if col == upd { _written(c(x, y), col, 0.15 * _cell) } else { _read(c(x, y), col, 0.15 * _cell) }
    }
  }
  if mark-p {
    content((x0 + (_h + 1) * _cell - 0.04, -_h * _cell - 0.03), anchor: "north-east", _t(size: 7pt, $p$))
  }
}

#let _half-steps = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let x1 = _size + _gap
  _half-step(0, _red)
  _half-step(x1, _black, mark-p: true)
  // the order of the two half-steps
  line((_size + 0.2, -_size / 2), (x1 - 0.2, -_size / 2), stroke: 0.6pt + _soft,
    mark: (end: ">", fill: _soft, scale: 0.4))
  content((_size + _gap / 2, -_size / 2 + 0.1), anchor: "south", _t(size: 7pt, fill: _soft)[then])
  content((_size / 2, 0.12), anchor: "south", _t(size: 7pt)[all #text(fill: _red)[*red*] pixels update])
  content((x1 + _size / 2, 0.12), anchor: "south", _t(size: 7pt)[all #text(fill: _black)[*black*] pixels update])

  // legend
  let y0 = -_size - 0.32
  _written((0.1, y0), _red, 0.1)
  _written((0.4, y0), _black, 0.1)
  content((0.66, y0), anchor: "west", _t(size: 7pt)[updated in parallel])
  _read((x1 + 0.1, y0), _red, 0.1)
  _read((x1 + 0.4, y0), _black, 0.1)
  content((x1 + 0.66, y0), anchor: "west", _t(size: 7pt)[read-only])
  let y1 = y0 - 0.44
  _arrow((0.02, y1), (0.5, y1))
  content((0.66, y1), anchor: "west", _t(size: 7pt)[propagation from the neighbours of the other colour])
})

// ---------------------------------------------------------------- (c) the candidates of p

#let _r = 5                        // the window around p: (2 r + 1) pixels per side
#let _cc = 0.5
#let _fast-edge = 1pt + _red.darken(25%)   // outline of the cells the fast setting keeps

#let _candidates = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let size = (2 * _r + 1) * _cc
  let c(x, y) = ((x + _r + 0.5) * _cc, -(y + _r + 0.5) * _cc)
  let cells = range(-_r, _r + 1)
  for y in cells {
    for x in cells {
      rect(((x + _r) * _cc, -(y + _r) * _cc), ((x + _r + 1) * _cc, -(y + _r + 1) * _cc),
        fill: if (x, y) == (0, 0) { _tint(_black) } else if (x, y) in _standard { _tint(_red) } else { white },
        stroke: _grid)
    }
  }
  rect((0, 0), (size, -size), stroke: 0.8pt + _ink)
  rect((_r * _cc, -_r * _cc), ((_r + 1) * _cc, -(_r + 1) * _cc), stroke: 1.1pt + _ink)
  // the pixels that are not candidates, faint, to keep the checkerboard visible
  for y in cells {
    for x in cells {
      if (x, y) not in ((0, 0), (1, -1)) and (x, y) not in _standard {
        _read(c(x, y), _col(x, y).lighten(72%), 0.13 * _cc)
      }
    }
  }
  // the planes of the candidates arrive at p
  for (x, y) in _standard {
    let stop = 0.6 / calc.sqrt(x * x + y * y)
    _arrow(c(x, y), c(x * stop, y * stop), k: 0.7)
  }
  for (x, y) in _standard {
    _read(c(x, y), _red, 0.2 * _cc)
    if (x, y) in _fast {
      rect(((x + _r) * _cc, -(y + _r) * _cc), ((x + _r + 1) * _cc, -(y + _r + 1) * _cc), stroke: _fast-edge)
    }
  }
  rect((_r * _cc, -_r * _cc), ((_r + 1) * _cc, -(_r + 1) * _cc), stroke: 1.1pt + _ink)
  _written(c(0, 0), _black, 0.17 * _cc)
  content(c(1, -1), _t(size: 7pt, $p$))

  // legend
  let y0 = -size - 0.32
  rect((0.02, y0 - 0.13), (0.28, y0 + 0.13), fill: _tint(_red), stroke: _grid)
  _read((0.15, y0), _red, 0.085)
  content((0.66, y0), anchor: "west", _t(size: 7pt)[candidate of $p$ (20 pixels)])
  let y1 = y0 - 0.44
  rect((0.02, y1 - 0.13), (0.28, y1 + 0.13), fill: _tint(_red), stroke: _fast-edge)
  _read((0.15, y1), _red, 0.085)
  content((0.66, y1), anchor: "west", _t(size: 7pt)[kept by the fast setting (8 pixels)])
})

#let checkerboard-figure = [#figure(
  grid(
    columns: 2, column-gutter: 0.7cm, row-gutter: 0.25cm, align: center + bottom,
    _half-steps, _candidates,
    _t[(a) the two half-steps of one iteration],
    _t[(b) the candidates of $p$ in Gipuma],
  ),
  caption: flex-caption(
    [Checkerboard propagation. (a) The pixels of $I_r$ are labelled red and black. One iteration first updates all red pixels in parallel, then all black pixels. A pixel takes its candidates only from pixels of the other colour, which are not written in the same half-step. For clarity, only the propagation from the four nearest neighbours is drawn. (b) Gipuma @gipuma passes the plane hypotheses of 20 pixels of the other colour to $p$ as candidates. Its fast setting keeps only the innermost and the outermost four.],
    [Checkerboard propagation],
  ),
) <fig-checkerboard>]
