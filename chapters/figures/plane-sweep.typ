// Plane-sweeping stereo.
// A family of planes parallel to the reference image is stepped through the scene. For
// the current plane the pixel p of the reference image is back-projected onto the plane
// and from there projected into every source image; the matching window around p goes the
// same way and arrives in the source images as a warped quadrilateral.
// Nothing is placed by hand. The scene is a small 3D model (three pinhole cameras and
// the sweep planes); the slices of the reference frustum, the points of the viewing ray
// on the planes, the windows and the epipolar lines are all computed by projecting that
// model, and the whole scene is then drawn in an axonometric parallel projection.
//
// Use:  #import "figures/plane-sweep.typ": plane-sweep-figure   then   #plane-sweep-figure
#import "@preview/cetz:0.4.2"
#import "../../template/elteikthesis.typ": flex-caption

#let _ray = rgb("#c0392b")         // the pixel p, its viewing ray and the points on the planes
#let _epi = rgb("#1f6feb")         // everything that belongs to the source images
#let _act = rgb("#e8a33d")         // the current plane of the sweep
#let _ink = luma(20%)
#let _soft = luma(55%)

// ---- vectors
#let _add(a, b) = a.zip(b).map(((x, y)) => x + y)
#let _sub(a, b) = a.zip(b).map(((x, y)) => x - y)
#let _mul(a, k) = a.map(x => x * k)
#let _dot(a, b) = a.zip(b).map(((x, y)) => x * y).sum()
#let _cross(a, b) = (
  a.at(1) * b.at(2) - a.at(2) * b.at(1),
  a.at(2) * b.at(0) - a.at(0) * b.at(2),
  a.at(0) * b.at(1) - a.at(1) * b.at(0),
)
#let _unit(a) = _mul(a, 1 / calc.sqrt(_dot(a, a)))
#let _lerp(a, b, t) = _add(a, _mul(_sub(b, a), t))

// ---- the drawing projection: the reader stands to the left of the reference camera and a
// little above it, so that depth z runs to the right and slightly up the page
#let _yaw = 56deg
#let _pitch = 19deg
#let _s(p) = {
  let (x, y, z) = p
  let back = -x * calc.sin(_yaw) + z * calc.cos(_yaw)
  (x * calc.cos(_yaw) + z * calc.sin(_yaw), y * calc.cos(_pitch) + back * calc.sin(_pitch))
}

// ---- the cameras
#let _f = 2.5                      // distance of the image plane
#let _hw = 0.8                     // half width of the image
#let _hh = 0.6                     // half height of the image
#let _camera(c, target) = {
  let w = _unit(_sub(target, c))
  let r = _unit(_cross((0, 1, 0), w))
  (c: c, w: w, r: r, u: _cross(w, r))
}
#let _target = (0, 0, 7.0)
#let _cam-r = _camera((0, 0, 0), (0, 0, 1))        // the reference camera looks along z
#let _cam-1 = _camera((-1.2, 2.6, 0.4), _target)     // above the reference camera
#let _cam-2 = _camera((3.6, -0.3, 0.6), _target)    // to the right of it
#let _img(cam, p) = {
  let d = _sub(p, cam.c)
  let k = _f / _dot(d, cam.w)
  (k * _dot(d, cam.r), k * _dot(d, cam.u))
}
#let _on-plane(cam, ab) = _add(cam.c, _add(_mul(cam.w, _f), _add(_mul(cam.r, ab.at(0)), _mul(cam.u, ab.at(1)))))
#let _proj(cam, p) = _on-plane(cam, _img(cam, p))

// ---- the sweep: planes z = d, parallel to the reference image
#let _depths = (5.6, 6.3, 7.0, 7.7, 8.4)
#let _active = 2                   // index of the current plane
#let _p = (0.22, 0.05)             // the pixel p, in image coordinates of the reference camera
#let _ph = 0.2                     // half size of the matching window, in image units
// the point of the reference image `ab` on the plane of depth d
#let _lift(ab, d) = (ab.at(0) * d / _f, ab.at(1) * d / _f, d)
#let _square(ab, h) = ((-1, -1), (1, -1), (1, 1), (-1, 1)).map(((i, j)) => (ab.at(0) + i * h, ab.at(1) + j * h))

#let _t(body, fill: _ink, size: 8pt) = text(size: size, fill: fill, body)

// the part of the segment a-b whose depth lies in [lo, hi], or none
#let _between(a, b, lo, hi) = {
  let (za, zb) = (a.at(2), b.at(2))
  if calc.abs(zb - za) < 1e-9 { return if za >= lo and za < hi { (a, b) } else { none } }
  let (t0, t1) = ((lo - za) / (zb - za), (hi - za) / (zb - za))
  let (s, e) = (calc.max(0, calc.min(t0, t1)), calc.min(1, calc.max(t0, t1)))
  if s < e { (_lerp(a, b, s), _lerp(a, b, e)) } else { none }
}

#let _canvas = cetz.canvas(length: 1.2cm, {
  import cetz.draw: *

  let dot(p, col, r: 0.055) = circle(_s(p), radius: r, fill: col, stroke: none)
  let ring(p, col, r: 0.055) = circle(_s(p), radius: r, fill: white, stroke: 0.7pt + col)
  let lab(p, dx, dy, body, anchor: "center") = {
    let q = _s(p)
    content((q.at(0) + dx, q.at(1) + dy), anchor: anchor, body)
  }

  let d-act = _depths.at(_active)
  let x-act = _lift(_p, d-act)
  let far = _depths.last() + 0.9
  let corners = _square((0, 0), 1).map(((i, j)) => (i * _hw, j * _hh))

  // the lines that cross the planes: (from, to, stroke)
  let segments = ()
  for c in corners {                                   // frustum of the reference camera
    segments.push((_on-plane(_cam-r, c), _lift(c, _depths.last()), 0.4pt + _soft))
  }
  segments.push((_on-plane(_cam-r, _p), _lift(_p, far), 0.9pt + _ray))   // viewing ray of p
  for cam in (_cam-1, _cam-2) {                        // the point of the current plane in the source images
    segments.push((_proj(cam, x-act), x-act, 0.6pt + _epi))
  }

  let layer(lo, hi) = for (a, b, stroke) in segments {
    let part = _between(a, b, lo, hi)
    if part != none { line(_s(part.at(0)), _s(part.at(1)), stroke: stroke) }
  }

  // from the back to the front: what lies behind a plane, then the plane and what lies on it
  layer(_depths.last(), 1e9)
  for k in range(_depths.len()).rev() {
    let d = _depths.at(k)
    let on = k == _active
    line(..corners.map(c => _s(_lift(c, d))), close: true,
      fill: if on { _act.lighten(72%).transparentize(40%) } else { none },
      stroke: if on { 1pt + _act.darken(15%) } else { (paint: if k > _active { luma(72%) } else { _soft }, thickness: 0.5pt, dash: "dashed") })
    if on {
      // the matching window of p on the plane: a square parallel to the reference image
      line(..(_square(_p, _ph).map(c => _s(_lift(c, d)))), close: true,
        fill: _ray.lighten(75%), stroke: 0.8pt + _ray)
      dot(_lift(_p, d), _ray, r: 0.065)
    } else {
      ring(_lift(_p, d), _ray)
    }
    layer(if k == 0 { -1e9 } else { _depths.at(k - 1) }, d)
  }

  // an image plane, and the edges of the pyramid from the optical centre to its corners. The
  // reader stands on the side of the optical centres, so these edges lie in front of the image
  // and are drawn after everything that is in the image.
  let pyramid(cam) = for c in corners {
    line(_s(cam.c), _s(_on-plane(cam, c)), stroke: 0.4pt + _soft)
  }
  let image(cam, name, side, up, col) = {
    let cs = corners.map(c => _on-plane(cam, c))
    line(..cs.map(_s), close: true, fill: white, stroke: 0.8pt + col)
    let at = _on-plane(cam, (side * (_hw + 0.1), up * (_hh - 0.1)))
    content(_s(at), anchor: if side < 0 { "east" } else { "west" }, _t(name))
  }
  // the image of the viewing ray in a source image (its epipolar line), cut to the image
  let epipolar(cam) = {
    let a = _img(cam, _lift(_p, 2.5))
    let b = _img(cam, _lift(_p, 40))
    let (lo, hi) = (-1e9, 1e9)
    for (k, half) in ((0, _hw), (1, _hh)) {
      let d = b.at(k) - a.at(k)
      let (t0, t1) = ((-half - a.at(k)) / d, (half - a.at(k)) / d)
      lo = calc.max(lo, calc.min(t0, t1))
      hi = calc.min(hi, calc.max(t0, t1))
    }
    line(_s(_on-plane(cam, _lerp(a, b, lo))), _s(_on-plane(cam, _lerp(a, b, hi))), stroke: 0.6pt + _epi.lighten(35%))
  }
  let source(cam, name, side, up) = {
    image(cam, name, side, up, _ink)
    epipolar(cam)
    // the window of the current plane as this camera sees it
    line(..(_square(_p, _ph).map(c => _s(_proj(cam, _lift(c, d-act))))), close: true,
      fill: _epi.lighten(80%), stroke: 0.8pt + _epi)
    for (k, d) in _depths.enumerate() {
      if k != _active { ring(_proj(cam, _lift(_p, d)), _epi, r: 0.04) }
    }
    dot(_proj(cam, x-act), _epi, r: 0.05)
    pyramid(cam)
    line(_s(cam.c), _s(_proj(cam, x-act)), stroke: 0.6pt + _epi)
    dot(cam.c, _ink)
  }

  source(_cam-1, $I_1$, 1, 1)

  image(_cam-r, $I_r$, -1, 1, _ink)
  line(..(_square(_p, _ph).map(c => _s(_on-plane(_cam-r, c)))), close: true,
    fill: _ray.lighten(75%), stroke: 0.8pt + _ray)
  pyramid(_cam-r)
  line(_s(_cam-r.c), _s(_on-plane(_cam-r, _p)), stroke: 0.9pt + _ray)
  dot(_on-plane(_cam-r, _p), _ray, r: 0.05)
  dot(_cam-r.c, _ink)

  source(_cam-2, $I_2$, 1, -1)

  // labels
  lab(_cam-r.c, -0.05, -0.26, _t($C_r$))
  lab(_cam-1.c, -0.05, -0.26, _t($C_1$))
  lab(_cam-2.c, 0, -0.26, _t($C_2$))
  lab(_on-plane(_cam-r, _p), 0.02, 0.36, _t(fill: _ray, $p$))
  lab(_lift((-_hw, _hh), d-act), -0.12, 0.1, anchor: "south-east", _t(fill: _act.darken(35%))[current plane $Pi_d$])
  lab(_lift(_p, far), 0.1, 0.02, anchor: "west", _t(fill: _ray, size: 7pt)[viewing ray of $p$])

  // the range of the sweep, at the lower right corners of the first and the last plane
  lab(_lift((_hw, -_hh), _depths.first()), 0.3, -0.1, anchor: "north-west", _t(size: 7pt)[$d_min$])
  lab(_lift((_hw, -_hh), _depths.last()), 0.1, 0, anchor: "west", _t(size: 7pt)[$d_max$])
})

#let plane-sweep-figure = [#figure(
  _canvas,
  caption: flex-caption(
    [Plane-sweeping stereo. A plane parallel to the reference image $I_r$ is moved through the scene in discrete depth steps between $d_min$ and $d_max$.],
    [Plane-sweeping stereo],
  ),
) <fig-plane-sweep>]
