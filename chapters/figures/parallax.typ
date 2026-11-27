// The parallax effect: two cameras, a near and a far object.
// (a) is a top view; (b) shows the two images. The image positions in (b) are not
// drawn by hand: both panels use the same pinhole projection u = f (X - C) / Z of the
// same two scene points, so the displacements in (b) are the ones (a) implies
// (d = f b / Z, inversely proportional to depth).
//
// Use:  #import "figures/parallax.typ": parallax-figure   then   #parallax-figure
#import "@preview/cetz:0.4.2"
#import "../../template/elteikthesis.typ": flex-caption

#let _near = rgb("#c0392b")        // near object and everything derived from it
#let _far = rgb("#1f6feb")         // far object and everything derived from it
#let _ink = luma(20%)
#let _soft = luma(55%)
#let _tree = rgb("#2f9e44")
#let _rock = luma(62%)

// scene, in cm of the top view: x to the right, z (depth) upwards
#let _b = 2.4                      // baseline
#let _f = 0.9                      // focal length (distance of the image plane)
#let _hw = 0.8                     // half width of the image plane
#let _c1 = -_b / 2
#let _c2 = _b / 2
#let _pn = (-0.2, 2.2)             // near point: the top of the tree
#let _pf = (0.4, 6.5)              // far point: the mountain peak
#let _proj(p, c) = _f * (p.at(0) - c) / p.at(1)

#let _t(body, fill: _ink, size: 8pt) = text(size: size, fill: fill, body)

#let _canvas = cetz.canvas(length: 1cm, {
  import cetz.draw: *

  // ---------------------------------------------------------------- (a) top view
  let cam(c, name) = {
    // viewing frustum up to the image plane, and the image plane itself
    line((c, 0), (c - _hw, _f), stroke: 0.5pt + _soft)
    line((c, 0), (c + _hw, _f), stroke: 0.5pt + _soft)
    line((c - _hw, _f), (c + _hw, _f), stroke: 1pt + _ink)
    circle((c, 0), radius: 0.06, fill: _ink, stroke: none)
    content((c, -0.28), _t(name))
  }
  let rays(p, col, dash) = {
    for c in (_c1, _c2) {
      line((c, 0), p, stroke: (paint: col, thickness: 0.6pt, dash: dash))
      circle((c + _proj(p, c), _f), radius: 0.055, fill: col, stroke: none)
    }
  }
  rays(_pf, _far, "dashed")
  rays(_pn, _near, none)
  cam(_c1, $C_1$)
  cam(_c2, $C_2$)

  // the two objects, seen from above
  circle(_pn, radius: 0.2, fill: _tree.lighten(70%), stroke: 0.6pt + _tree)
  circle(_pn, radius: 0.05, fill: _near, stroke: none)
  // left of the far ray of C1, which passes the tree at x = -0.66
  content((_pn.at(0) - 0.62, _pn.at(1)), anchor: "east", _t(fill: _near)[near object])
  line((_pf.at(0) - 0.34, _pf.at(1) - 0.2), (_pf.at(0), _pf.at(1) + 0.14), (_pf.at(0) + 0.34, _pf.at(1) - 0.2),
    close: true, fill: _rock.lighten(60%), stroke: 0.6pt + _rock)
  circle(_pf, radius: 0.05, fill: _far, stroke: none)
  content((_pf.at(0) - 0.45, _pf.at(1)), anchor: "east", _t(fill: _far)[far object])

  // baseline and image plane annotations
  line((_c1, -0.62), (_c2, -0.62), stroke: 0.5pt + _ink,
    mark: (start: "stealth", end: "stealth", fill: _ink, scale: 0.5))
  content((0, -0.84), _t[baseline])
  content((_c1 - _hw - 0.08, _f), anchor: "east", _t(fill: _soft, size: 7pt)[image\ plane])
  content((0, -1.45), _t[(a) top view of the scene])

  // ---------------------------------------------------------------- (b) the two images
  let ox = 6.3                     // centre of the image column
  let w = 4.6                      // image width
  let h = 2.4                      // image height
  let s = (w / 2) / _hw            // image plane units to cm
  let y-top = 4.1                  // bottom edge of the left camera's image
  let y-bot = 0.0                  // bottom edge of the right camera's image
  let row-n = 3.5                  // displacement arrow of the near object
  let row-f = 2.9                  // displacement arrow of the far object

  let xn = (ox + s * _proj(_pn, _c1), ox + s * _proj(_pn, _c2))
  let xf = (ox + s * _proj(_pf, _c1), ox + s * _proj(_pf, _c2))
  let tree-top = 1.85              // heights inside an image, above its bottom edge
  let peak = 2.0
  let horizon = 0.8

  let image(y0, x-tree, x-peak, title) = {
    rect((ox - w / 2, y0), (ox + w / 2, y0 + h), fill: white, stroke: 0.8pt + _ink)
    line((ox - w / 2, y0 + horizon), (ox + w / 2, y0 + horizon), stroke: 0.4pt + _soft)
    // far: the mountain
    line((x-peak - 1.3, y0 + horizon), (x-peak, y0 + peak), (x-peak + 1.3, y0 + horizon),
      close: true, fill: _rock.lighten(60%), stroke: 0.6pt + _rock)
    // near: the tree, drawn over the mountain
    rect((x-tree - 0.05, y0 + 0.25), (x-tree + 0.05, y0 + 0.7), fill: luma(35%), stroke: none)
    for (base, top, half) in ((0.55, 1.25, 0.42), (0.95, 1.6, 0.33), (1.3, tree-top, 0.24)) {
      line((x-tree - half, y0 + base), (x-tree, y0 + top), (x-tree + half, y0 + base),
        close: true, fill: _tree.lighten(70%), stroke: 0.6pt + _tree)
    }
    circle((x-peak, y0 + peak), radius: 0.05, fill: _far, stroke: none)
    circle((x-tree, y0 + tree-top), radius: 0.05, fill: _near, stroke: none)
    content((ox - 0.2, y0 + 0.3), _t(size: 7pt, title))   // on the ground, clear of both tree positions
  }
  image(y-top, xn.at(0), xf.at(0), [image of $C_1$])
  image(y-bot, xn.at(1), xf.at(1), [image of $C_2$])

  // guides from the two points of each image into the gap, and the displacements there
  let guide(x, from, to, col) = line((x, from), (x, to),
    stroke: (paint: col, thickness: 0.5pt, dash: "densely-dashed"))
  guide(xn.at(0), y-top, row-n, _near)
  guide(xn.at(1), y-bot + tree-top, row-n, _near)
  guide(xf.at(0), y-top, row-f, _far)
  guide(xf.at(1), y-bot + peak, row-f, _far)
  let shift(xs, y, col) = line((xs.at(0), y), (xs.at(1), y), stroke: 0.9pt + col,
    mark: (end: "stealth", fill: col, scale: 0.55))
  shift(xn, row-n, _near)
  shift(xf, row-f, _far)
  content((xn.at(1) - 0.1, row-n), anchor: "east", _t(fill: _near, size: 7pt)[near])
  content((xf.at(0) + 0.1, row-f), anchor: "west", _t(fill: _far, size: 7pt)[far])
  content((ox, -1.45), _t[(b) the same two points in both images])
})

#let parallax-figure = [#figure(
  _canvas,
  caption: flex-caption(
    [The parallax effect. (a) Two cameras, $C_1$ and $C_2$, observe a near and a far object from the two ends of a baseline. Perspective rays (red solid, blue striped) are drawn from their optical center through the image plane to the observed object point. (b) Between the two images the near object is displaced more than the far one: the displacement (called _disparity_ in pixels) is inversely proportional to the distance of the object from the cameras (_depth_).],
    [The parallax effect],
  ),
) <fig-parallax>]
