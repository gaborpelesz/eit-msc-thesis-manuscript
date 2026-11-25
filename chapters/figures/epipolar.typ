// Epipolar geometry and matching along the epipolar line.
// (a) a pixel p of the reference image, its viewing ray, and the epipolar line that the
//     ray traces in a second image; (b) the patch around p next to the patches around
//     the candidates on that line.
// Nothing is placed by hand. The scene is a small 3D model (a house and two pinhole
// cameras that look at it); the house in each image, the pixel p, the candidate
// points and the epipolar line are all computed by projecting that model, and the
// whole scene is then drawn in an oblique parallel projection (depth runs up the page).
// The patches of (b) are crops of the same two projected images, not separate drawings.
//
// Use:  #import "figures/epipolar.typ": epipolar-figure   then   #epipolar-figure
#import "@preview/cetz:0.4.2"
#import "../../template/elteikthesis.typ": flex-caption

#let _ray = rgb("#c0392b")         // the pixel p, its viewing ray and the 3D point
#let _epi = rgb("#1f6feb")         // the epipolar line and the rays of the second camera
#let _ink = luma(20%)
#let _soft = luma(55%)
#let _wall = luma(86%)
#let _roof = rgb("#e8c9a0")

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

// ---- the drawing projection: x to the right, y up, depth z up the page
#let _kz = 0.72
#let _view = (0, -_kz, 1)          // direction in which the reader looks into the scene
#let _s(p) = (p.at(0), p.at(1) + _kz * p.at(2))

// ---- the two cameras
#let _f = 2.6                      // distance of the image plane
#let _hw = 1.45                    // half width of the image
#let _hh = 1.05                    // half height of the image
#let _target = (0, 0.5, 6.5)
#let _camera(c) = {
  let w = _unit(_sub(_target, c))
  let r = _unit(_cross((0, 1, 0), w))
  (c: c, w: w, r: r, u: _cross(w, r))
}
#let _cam-r = _camera((-2.7, 0, 0))
#let _cam-j = _camera((2.7, 0, 0))
// image coordinates (a, b) of a scene point, and the scene point of image coordinates
#let _img(cam, p) = {
  let d = _sub(p, cam.c)
  let k = _f / _dot(d, cam.w)
  (k * _dot(d, cam.r), k * _dot(d, cam.u))
}
#let _on-plane(cam, ab) = _add(cam.c, _add(_mul(cam.w, _f), _add(_mul(cam.r, ab.at(0)), _mul(cam.u, ab.at(1)))))
#let _proj(cam, p) = _on-plane(cam, _img(cam, p))

// ---- the house: a box with a pyramid roof, turned a little about the vertical axis
#let _house = {
  let (cx, cz, h, y0, y1, y2, turn) = (0, 6.5, 1.05, -0.7, 0.8, 1.9, 24deg)
  let corner(i) = {
    let (dx, dz) = ((-h, -h), (h, -h), (h, h), (-h, h)).at(i)
    (cx + dx * calc.cos(turn) - dz * calc.sin(turn), cz + dx * calc.sin(turn) + dz * calc.cos(turn))
  }
  let low = range(4).map(i => (corner(i).at(0), y0, corner(i).at(1)))
  let top = range(4).map(i => (corner(i).at(0), y1, corner(i).at(1)))
  let apex = (cx, y2, cz)
  let faces = ()
  for i in range(4) {
    let j = calc.rem(i + 1, 4)
    faces.push((pts: (low.at(i), low.at(j), top.at(j), top.at(i)), fill: _wall))
    faces.push((pts: (top.at(i), top.at(j), apex), fill: _roof))
  }
  (faces: faces, apex: apex, centre: (cx, (y0 + y1) / 2, cz))
}
// a face is seen from `eye` (a point), or along `dir` (a parallel projection), if it turns towards it
#let _normal(face) = {
  let (a, b, c) = face.pts.slice(0, 3)
  let n = _cross(_sub(b, a), _sub(c, a))
  if _dot(n, _sub(a, _house.centre)) < 0 { _mul(n, -1) } else { n }
}
#let _seen-from(face, eye) = _dot(_normal(face), _sub(eye, face.pts.at(0))) > 0
#let _seen-along(face, dir) = _dot(_normal(face), dir) < 0

// ---- the point, its ray and the candidates along it
#let _x = _house.apex
#let _on-ray(t) = _lerp(_cam-r.c, _x, t)       // t = 1 is the point itself
#let _candidates = (0.6, 0.78, 1.26)           // other depths along the ray
#let _ray-end = 1.42

#let _t(body, fill: _ink, size: 8pt) = text(size: size, fill: fill, body)

// ---- matching windows
#let _ph = 0.3                     // half size of a window, in image units
#let _zoom = 2.5                   // enlargement of a patch in panel (b)
// the part of a camera's image inside the window centred on `ab`, enlarged
#let _patch(cam, ab, col, thick: 0.6pt) = box(
  width: 2 * _ph * _zoom * 1cm, height: 2 * _ph * _zoom * 1cm, clip: true, stroke: thick + col,
  place(top + left,
    dx: -(ab.at(0) - _ph + _hw) * _zoom * 1cm,
    dy: -(_hh - ab.at(1) - _ph) * _zoom * 1cm,
    cetz.canvas(length: _zoom * 1cm, {
      import cetz.draw: *
      rect((-_hw, -_hh), (_hw, _hh), fill: white, stroke: none)   // the image; also fixes the extent of the canvas
      for face in _house.faces.filter(f => _seen-from(f, cam.c)) {
        line(..face.pts.map(p => _img(cam, p)), close: true, fill: face.fill, stroke: 0.6pt + _soft)
      }
      circle(ab, radius: 0.018, fill: col, stroke: none)
    }),
  ),
)

#let _canvas = cetz.canvas(length: 1cm, {
  import cetz.draw: *

  let dot(p, col, r: 0.06) = circle(_s(p), radius: r, fill: col, stroke: none)
  let ring(p, col, r: 0.065) = circle(_s(p), radius: r, fill: white, stroke: 0.7pt + col)

  // the house in the scene
  for face in _house.faces.filter(f => _seen-along(f, _view)) {
    line(..face.pts.map(_s), close: true, fill: face.fill, stroke: 0.6pt + _soft)
  }

  // an image plane with the house as its camera sees it
  let image(cam, name, label-side, label-up) = {
    let corners = ((-1, -1), (1, -1), (1, 1), (-1, 1)).map(((i, j)) => _on-plane(cam, (i * _hw, j * _hh)))
    for c in corners { line(_s(cam.c), _s(c), stroke: 0.4pt + _soft) }
    line(..corners.map(_s), close: true, fill: white, stroke: 0.8pt + _ink)
    for face in _house.faces.filter(f => _seen-from(f, cam.c)) {
      line(..face.pts.map(p => _s(_proj(cam, p))), close: true, fill: face.fill, stroke: 0.5pt + _soft)
    }
    let at = _on-plane(cam, (label-side * (_hw + 0.12), label-up * (_hh - 0.12)))
    content(_s(at), anchor: if label-side < 0 { "east" } else { "west" }, _t(name))
  }
  image(_cam-r, $I_r$, -1, 1)
  image(_cam-j, $I_j$, 1, -1)

  // baseline
  line(_s(_cam-r.c), _s(_cam-j.c), stroke: (paint: _soft, thickness: 0.5pt, dash: "dashed"))

  // the epipolar line: the image of the ray in I_j, cut to the image rectangle
  let a = _img(_cam-j, _on-ray(0.5))
  let b = _img(_cam-j, _on-ray(1.5))
  let (lo, hi) = (-1e9, 1e9)
  for (k, half) in ((0, _hw), (1, _hh)) {
    let d = b.at(k) - a.at(k)
    let (t0, t1) = ((-half - a.at(k)) / d, (half - a.at(k)) / d)
    lo = calc.max(lo, calc.min(t0, t1))
    hi = calc.min(hi, calc.max(t0, t1))
  }
  let epi-a = _on-plane(_cam-j, _lerp(a, b, lo))
  let epi-b = _on-plane(_cam-j, _lerp(a, b, hi))

  // rays of the second camera to the candidates and to the point
  for t in _candidates + (1,) {
    line(_s(_cam-j.c), _s(_on-ray(t)), stroke: (paint: _epi, thickness: 0.5pt, dash: "densely-dotted"))
  }
  line(_s(epi-a), _s(epi-b), stroke: 1.1pt + _epi)

  // the viewing ray of p
  line(_s(_cam-r.c), _s(_x), stroke: 0.9pt + _ray)
  line(_s(_x), _s(_on-ray(_ray-end)), stroke: (paint: _ray, thickness: 0.9pt, dash: "dashed"))

  // the matching windows: around p in I_r and around every candidate in I_j
  let window(cam, ab, col, thick) = line(
    ..((-1, -1), (1, -1), (1, 1), (-1, 1)).map(((i, j)) => _s(_on-plane(cam, (ab.at(0) + i * _ph, ab.at(1) + j * _ph)))),
    close: true, stroke: thick + col)
  window(_cam-r, _img(_cam-r, _x), _ray, 0.8pt)
  for t in _candidates { window(_cam-j, _img(_cam-j, _on-ray(t)), _epi, 0.4pt) }
  window(_cam-j, _img(_cam-j, _x), _epi, 0.8pt)

  for t in _candidates {
    ring(_on-ray(t), _ray)
    ring(_proj(_cam-j, _on-ray(t)), _epi)
  }
  dot(_x, _ray, r: 0.075)
  dot(_proj(_cam-r, _x), _ray)
  dot(_proj(_cam-j, _x), _epi)
  dot(_cam-r.c, _ink)
  dot(_cam-j.c, _ink)

  // labels
  let lab(p, dx, dy, body, anchor: "center") = {
    let q = _s(p)
    content((q.at(0) + dx, q.at(1) + dy), anchor: anchor, body)
  }
  lab(_cam-r.c, 0, -0.28, _t($C_r$))
  lab(_cam-j.c, 0, -0.28, _t($C_j$))
  lab(_lerp(_cam-r.c, _cam-j.c, 0.5), 0, -0.2, _t(fill: _soft, size: 7pt)[baseline])
  lab(_proj(_cam-r, _x), -0.3, 0.12, anchor: "east", _t(fill: _ray, $p$))
  lab(_x, 0.16, 0.1, anchor: "west", _t(fill: _ray, $upright(bold(X))$))
  lab(_on-ray(_candidates.at(0)), -0.14, 0.05, anchor: "east", _t(fill: _ray, size: 7pt)[viewing ray of $p$])
  lab(epi-b, 0.1, 0.05, anchor: "west", _t(fill: _epi, size: 7pt)[epipolar\ line of $p$])
})

// (b): the patch of p, and the patches of the candidates in their order along the line
#let _matching = {
  let ts = (_candidates + (1,)).sorted()
  let cell(body) = align(center + horizon, body)
  grid(
    columns: ts.len() + 2, column-gutter: 0.28cm, row-gutter: 0.18cm,
    cell(_patch(_cam-r, _img(_cam-r, _x), _ray, thick: 1pt)),
    cell(_t(size: 11pt)[$arrow.l.r$]),
    ..ts.map(t => cell(_patch(_cam-j, _img(_cam-j, _on-ray(t)), _epi, thick: if t == 1 { 1.4pt } else { 0.6pt }))),
    cell(_t(fill: _ray)[around $p$ in $I_r$]),
    [],
    ..ts.map(t => cell(if t == 1 { _t(fill: _epi)[*best match*] } else { [] })),
  )
}

#let epipolar-figure = [#figure(
  stack(dir: ttb, spacing: 0.25cm,
    _canvas,
    _t[(a) the epipolar line of $p$],
    v(0.35cm),
    _matching,
    _t[(b) the patch around $p$ and the patches around the candidates in $I_j$],
  ),
  caption: flex-caption(
    [Epipolar geometry and matching. (a) The pixel $p$ of the reference image $I_r$ fixes only a viewing ray: the scene point $upright(bold(X))$ may lie anywhere along it (circles). Seen from a second camera $C_j$, the ray appears as a line in $I_j$, the epipolar line of $p$, so the pixel that corresponds to $p$ has to be searched only along this line. (b) The search compares the patch around $p$ with the patch around each candidate on the line and keeps the candidate whose patch is the most similar.],
    [Epipolar geometry and matching along the epipolar line],
  ),
) <fig-epipolar>]
