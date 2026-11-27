// PatchMatch multi-view stereo.
// (a) A cross-section of the scene seen from above: the reference camera, two source
//     cameras and the surface. The hypothesis of the pixel p is a plane of its own, a depth
//     d_p along the viewing ray and a normal n_p, which the cross-section cuts in a line.
//     The matching window of p is back-projected onto that slanted plane and projected from
//     there into the source images, which is the homography H_j(theta_p) the plane induces;
//     the fronto-parallel plane at the same depth sends the same window somewhere else.
// (b) One sweep of the sequential PatchMatch of Bleyer et al. (2011) over the pixel grid of
//     the reference image: every pixel carries one plane, drawn as a needle map (a small
//     disc on the plane as the reference camera sees it, with its normal), the pixels before
//     p in the scan order are already updated, and the left and the upper neighbour hand
//     their planes to p (propagation).
// Nothing is placed by hand. Panel (a) is a 2D model (x across, z in depth): three pinhole
// cameras, a surface, and the plane of p as the tangent of that surface. The window on the
// plane and its footprints in the source images are computed by intersecting the viewing
// rays of the window with the plane and projecting the result. The planes of panel (b)
// come from a fixed hash of the cell position.
//
// Use:  #import "figures/patchmatch.typ": patchmatch-figure   then   #patchmatch-figure
#import "@preview/cetz:0.4.2"
#import "../../template/elteikthesis.typ": flex-caption
#import "plane-sweep.typ": _ray, _epi, _act, _ink, _soft, _add, _sub, _mul, _dot, _unit, _lerp, _t

// ---------------------------------------------------------------- (a) scene space

// ---- the cameras: optical centre c, viewing direction w, image axis r
#let _fl = 2.0                     // distance of the image line
#let _hw = 0.78                    // half width of the image
#let _cam(c, target) = {
  let w = _unit(_sub(target, c))
  (c: c, w: w, r: (w.at(1), -w.at(0)))
}
#let _on-img(cam, a) = _add(cam.c, _add(_mul(cam.w, _fl), _mul(cam.r, a)))
#let _img(cam, x) = {
  let d = _sub(x, cam.c)
  _fl * _dot(d, cam.r) / _dot(d, cam.w)
}

// ---- the plane hypothesis of p: the point of the viewing ray at depth d_p, and a unit
// normal that faces the reference camera
#let _a-p = 0.12                   // the pixel p, in image coordinates of the reference camera
#let _a-h = 0.3                    // half size of the matching window, in image units
#let _d-p = 4.0
#let _tilt = 25deg                 // angle between the plane and the reference image
#let _lift(a, d) = (a * d / _fl, d)
#let _x-p = _lift(_a-p, _d-p)
#let _n-p = (calc.sin(_tilt), -calc.cos(_tilt))
#let _along = (calc.cos(_tilt), calc.sin(_tilt))
// the point in which the viewing ray of the reference pixel `a` meets the plane
#let _hit(a) = {
  let dir = (a, _fl)
  _mul(dir, _dot(_n-p, _x-p) / _dot(_n-p, dir))
}
#let _window = (_a-p - _a-h, _a-p + _a-h)

#let _cam-r = _cam((0, 0), (0, 1))
#let _cam-1 = _cam((-3.5, 0.5), _x-p)
#let _cam-2 = _cam((3.55, 0.25), _x-p)

// ---- the surface: a curve that the plane of p touches in the point of p
#let _surface(x) = {
  let u = x - _x-p.at(0)
  (x, _d-p + calc.tan(_tilt) * u + 0.13 * u * u - 0.03 * u * u * u)
}
#let _surface-pts = range(41).map(i => _surface(_x-p.at(0) - 1.45 + i * 0.07))

#let _scene = cetz.canvas(length: 1.2cm, {
  import cetz.draw: *

  let dot(p, col, r: 0.05) = circle(p, radius: r, fill: col, stroke: none)
  let lab(p, dx, dy, body, anchor: "center") = content((p.at(0) + dx, p.at(1) + dy), anchor: anchor, body)
  let dashed(col, t: 0.5pt) = (paint: col, thickness: t, dash: (2.2pt, 1.6pt))
  let hyp = _act.darken(35%)

  let on-slant = _window.map(_hit)                       // the window of p on the plane of p
  let on-front = _window.map(a => _lift(a, _d-p))        // ... and on the fronto-parallel plane
  let far = _lift(_a-p, _d-p + 1.25)

  // the surface, with the solid behind it
  line(.._surface-pts, .._surface-pts.rev().map(((x, z)) => (x, z + 0.28)), close: true,
    fill: luma(91%), stroke: none)
  line(.._surface-pts, stroke: 0.9pt + _soft)

  // the cameras: the pinhole triangle and the image line
  let camera(cam) = {
    line(_on-img(cam, -_hw), cam.c, _on-img(cam, _hw), stroke: 0.4pt + _soft)
    line(_on-img(cam, -_hw), _on-img(cam, _hw), stroke: 1pt + _ink)
  }
  (_cam-r, _cam-1, _cam-2).map(camera).join()

  // the fronto-parallel plane at the same depth, and where it sends the window
  line(_lift(_window.at(0) - 0.1, _d-p), _lift(_window.at(1) + 0.1, _d-p), stroke: dashed(_soft, t: 0.9pt))
  for cam in (_cam-1, _cam-2) {
    for x in on-front { line(x, _on-img(cam, _img(cam, x)), stroke: dashed(_soft, t: 0.45pt)) }
  }

  // the window of p: its two boundary rays up to the plane, and on to the source cameras
  for (a, x) in _window.zip(on-slant) {
    line(_cam-r.c, _on-img(_cam-r, a), stroke: 0.4pt + _ray.lighten(40%))
    line(_on-img(_cam-r, a), x, stroke: 0.5pt + _ray)
    for cam in (_cam-1, _cam-2) {
      let q = _on-img(cam, _img(cam, x))
      line(x, q, stroke: 0.5pt + _epi)
      line(q, cam.c, stroke: 0.4pt + _epi.lighten(40%))
    }
  }
  // the viewing ray of p
  line(_cam-r.c, far, stroke: 0.9pt + _ray)

  // the plane of p, the window on it, and its normal
  let ext = 0.38
  let ends = (_add(on-slant.at(0), _mul(_along, -ext)), _add(on-slant.at(1), _mul(_along, ext)))
  line(..ends, stroke: (paint: _act, thickness: 3.4pt, cap: "round"))
  line(..on-slant, stroke: 1.1pt + _ray)
  let n-tip = _add(_x-p, _mul(_n-p, 0.95))
  let k = 0.13                                           // the right angle at the foot of the normal
  line(_add(_x-p, _mul(_along, k)), _add(_x-p, _mul(_add(_along, _n-p), k)), _add(_x-p, _mul(_n-p, k)),
    stroke: 0.5pt + hyp)
  line(_x-p, n-tip, stroke: 1.1pt + hyp, mark: (end: ">", fill: hyp, scale: 0.5))
  for x in on-slant { dot(x, _ray, r: 0.04) }
  dot(_x-p, _ray, r: 0.06)

  // the footprints of the window in the source images: under the plane of p (on the image
  // line) and under the fronto-parallel plane (a grey bar just behind it)
  for cam in (_cam-1, _cam-2) {
    let off(a, k) = _add(_on-img(cam, a), _mul(cam.w, k))
    let (s0, s1) = on-slant.map(x => _img(cam, x))
    let (f0, f1) = on-front.map(x => _img(cam, x))
    line(off(f0, -0.1), off(f1, -0.1), stroke: 1.6pt + _soft)
    line(off(s0, 0), off(s1, 0), stroke: (paint: _epi, thickness: 2.8pt))
    dot(cam.c, _ink)
  }
  // the window in the reference image
  line(.._window.map(a => _on-img(_cam-r, a)), stroke: (paint: _ray, thickness: 2.8pt))
  dot(_cam-r.c, _ink)

  // labels
  lab(_cam-r.c, 0, -0.26, _t($C_r$))
  lab(_cam-1.c, 0, -0.26, _t($C_1$))
  lab(_cam-2.c, 0, -0.26, _t($C_2$))
  lab(_on-img(_cam-r, -_hw), -0.04, -0.06, anchor: "north-east", _t($I_r$))
  lab(_on-img(_cam-1, _hw), 0.04, -0.08, anchor: "north", _t($I_1$))
  lab(_on-img(_cam-2, -_hw), -0.04, -0.08, anchor: "north", _t($I_2$))
  lab(_on-img(_cam-r, _hw), 0.05, -0.07, anchor: "north-west", _t(fill: _ray, size: 7pt)[window\ of $p$])
  lab(_on-img(_cam-1, 0), -0.1, 0.62, anchor: "south-east", _t(fill: _epi, $H_1(theta_p)$))
  lab(_on-img(_cam-2, 0), 0.1, 0.62, anchor: "south-west", _t(fill: _epi, $H_2(theta_p)$))
  lab(n-tip, 0.1, 0.02, anchor: "west", _t(fill: hyp, $bold(n)_p$))
  lab(ends.at(1), 0.14, -0.14, anchor: "west", _t(fill: hyp)[plane $theta_p = (d_p, bold(n)_p)$])
  lab(_lerp(_on-img(_cam-r, _window.at(0)), on-slant.at(0), 0.2), -0.08, 0, anchor: "east", _t(fill: _ray, size: 7pt)[depth $d_p$])
  lab(far, -0.1, -0.08, anchor: "east", _t(fill: _ray, size: 7pt)[viewing ray of $p$])
  lab(_lift(_window.at(0) - 0.1, _d-p), -0.1, 0.12, anchor: "east", _t(fill: _soft, size: 7pt)[fronto-parallel plane])
  lab(_surface-pts.last(), 0.1, 0.14, anchor: "west", _t(fill: _soft, size: 7pt)[surface])
})

// ---------------------------------------------------------------- (b) image space

#let _n = 7                        // pixels per side of the piece of I_r that is shown
#let _cell = 0.7
#let _pp = (3, 3)                  // the current pixel p: (column, row), row 0 on top
#let _grid = 0.3pt + luma(60%)
#let _hyp = _act.darken(35%)       // the plane of p, as in panel (a)
#let _prop = _ink                  // propagation arrows
#let _r = 0.31 * _cell             // radius of the disc that stands for the plane of a pixel

// a fixed pseudo-random number in [0, 1) for every cell
#let _hash(x, y, k) = {
  let v = calc.sin(x * 12.9898 + y * 78.233 + k * 37.719) * 43758.5453
  v - calc.floor(v)
}
#let _visited(x, y) = y < _pp.at(1) or (y == _pp.at(1) and x < _pp.at(0))
// the plane of a pixel as (tilt of the normal away from the viewing direction, direction of
// the tilt in the image, grey level standing for the depth): a smooth field where the sweep
// has already been, the random initialisation elsewhere. Every normal faces the camera, so
// the tilt stays well below 90deg.
#let _plane(x, y) = if _visited(x, y) {
  (50deg + (x - y) * 1.5deg + (_hash(x, y, 2) - 0.5) * 5deg,
   58deg - (x + y) * 2deg + (_hash(x, y, 3) - 0.5) * 8deg,
   90% + (x - 3) * 1.2% - (y - 1) * 1%)
} else {
  (if _hash(x, y, 7) < 0.12 { 0deg } else { 18deg + _hash(x, y, 7) * 52deg }, _hash(x, y, 4) * 360deg,
   78% + _hash(x, y, 1) * 21%)
}
#let _plane-p = (48deg, 52deg)    // the plane p holds after propagation
#let _c(x, y) = ((x + 0.5) * _cell, -(y + 0.5) * _cell)
// the outline of a disc with the given tilt, as the camera sees it: an ellipse whose short
// axis lies along the direction of the tilt and shrinks with its cosine
#let _outline(at, tilt, dir, r) = range(48).map(i => {
  let a = i * 7.5deg
  let (u, v) = (r * calc.cos(tilt) * calc.cos(a), r * calc.sin(a))
  (at.at(0) + u * calc.cos(dir) - v * calc.sin(dir), at.at(1) + u * calc.sin(dir) + v * calc.cos(dir))
})
// the glyph of a plane: the disc, and its normal as a needle from the centre, which
// shrinks to a dot when the plane faces the camera
#let _glyph(at, tilt, dir, r: _r, face: _act.lighten(30%), edge: _act.darken(40%), thick: 0.6pt) = {
  import cetz.draw: *
  line(.._outline(at, tilt, dir, r), close: true, fill: face, stroke: thick + edge)
  let l = 1.25 * r * calc.sin(tilt)
  let needle = _ink
  if l > 0.02 {
    line(at, (at.at(0) + l * calc.cos(dir), at.at(1) + l * calc.sin(dir)),
      stroke: (paint: needle, thickness: 0.7pt, cap: "round"))
  }
  circle(at, radius: 0.028, fill: needle, stroke: none)
}
#let _arrow(a, b) = {
  import cetz.draw: *
  line(a, b, stroke: 2.2pt + white.transparentize(25%))
  line(a, b, stroke: 0.9pt + _prop, mark: (end: ">", fill: _prop, scale: 0.4))
}

#let _iteration = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let size = _n * _cell
  let (px, py) = _pp

  for y in range(_n) {
    for x in range(_n) {
      let (tilt, dir, grey) = _plane(x, y)
      rect((x * _cell, -y * _cell), ((x + 1) * _cell, -(y + 1) * _cell),
        fill: if (x, y) == _pp { _ray.lighten(82%) } else { luma(grey) }, stroke: _grid)
      if (x, y) != _pp { _glyph(_c(x, y), tilt, dir) }
    }
  }
  // the border between the pixels the sweep has updated and the ones it has not reached
  line((0, -py * _cell), (0, -(py + 1) * _cell), (px * _cell, -(py + 1) * _cell), (px * _cell, -py * _cell),
    (size, -py * _cell), (size, 0), (0, 0), close: true, stroke: 0.9pt + _ink)
  rect((0, 0), (size, -size), stroke: 0.8pt + _ink)

  // the current pixel: its plane, and the planes that arrive from the left and from the
  // upper neighbour
  rect((px * _cell, -py * _cell), ((px + 1) * _cell, -(py + 1) * _cell), stroke: 1pt + _ray)
  let (cx, cy) = _c(px, py)
  _glyph((cx, cy), .._plane-p, face: _act, edge: _hyp, thick: 0.9pt)
  _arrow(_c(px - 1, py), (cx - 0.4 * _cell, cy))
  _arrow(_c(px, py - 1), (cx, cy + 0.4 * _cell))
  content(((px + 1) * _cell - 0.04, -py * _cell - 0.03), anchor: "north-east", _t(fill: _ray, size: 7pt, $p$))

  // the scan order
  let m = (end: ">", fill: _soft, scale: 0.4)
  line((0, 0.16), (size, 0.16), stroke: 0.6pt + _soft, mark: m)
  line((-0.16, 0), (-0.16, -size), stroke: 0.6pt + _soft, mark: m)
  content((size / 2, 0.24), anchor: "south", _t(size: 7pt)[scan order])
  content((size, 0.3), anchor: "south-east", _t($I_r$))

  // legend
  let y0 = -size - 0.32
  _arrow((0.02, y0), (0.5, y0))
  content((0.66, y0), anchor: "west", _t(size: 7pt)[propagation from updated neighbours])
  let y1 = y0 - 0.44
  _glyph((0.1, y1), 0deg, 0deg, r: 0.13)
  _glyph((0.44, y1 - 0.03), 55deg, 60deg, r: 0.13)
  content((0.66, y1), anchor: "west", _t(size: 7pt)[plane seen from $C_r$: frontal, tilted])
})

#let patchmatch-figure = [#figure(
  grid(
    columns: 2, column-gutter: 0.35cm, row-gutter: 0.25cm, align: center + bottom,
    _scene, _iteration,
    _t[(a) the plane hypothesis of $p$ in scene space],
    _t[(b) one sweep over the pixels of $I_r$],
  ),
  caption: flex-caption(
    [PatchMatch multi-view stereo. (a) The scene from above. Every pixel $p$ of $I_r$ carries its own plane hypothesis $theta_p = (d_p, bold(n)_p)$, and the plane-induced homography $H_j (theta_p)$ maps the window of $p$ into the source images (blue). A fronto-parallel plane at the same depth (dashed) maps it onto different footprints (grey). (b) Every pixel in $C_r$ holds a plane, the grey intensity of a pixel stands for its depth $d_p$. In one iteration, the already updated left and upper neighbours pass their planes to $p$ as candidates (propagation). Pixels after $p$  hold random planes.],
    [PatchMatch MVS],
  ),
) <fig-patchmatch>]
