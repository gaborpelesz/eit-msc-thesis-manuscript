// What the change "images as 8-bit textures" removes, as a simplified sketch:
//   (a) one cache sector of an image that is stored with four bytes per pixel,
//   (b) the same sector of an image that is stored with one byte per pixel,
//   (c) the requests to the L2 cache in one launch of the update of the unreliable
//       pixels, before and after the change.
// (a) is a sketch: the gray value of a pixel needs one byte, which is drawn as the first of the four
// bytes of the pixel. A floating-point number does not keep its value in one of its bytes.
//
// Every measured number is read from ../../generated/perf-4.3/derived/numbers-prop.json, which
// generated/perf-4.3/scripts/perf43_json.py writes. Do not type numbers into this file.
//
// Use:  #import "figures/perf-prop-texels.typ": perf-prop-texels-figure
#import "../../template/elteikthesis.typ": flex-caption
#import "perf-common.typ": *

#let _v = json("../../generated/perf-4.3/derived/numbers-prop.json").v
#let _sector = _v.profile.sector_bytes
#let (_wide, _narrow) = _v.u8.texel_bytes          // bytes per pixel before and after
#let _removed = _v.ncu.u8.weak.drop.l2_req         // share of the requests that the change removes

#let _c-waste = rgb("#eb6834")
#let _lab(body, ..args) = chart-label(8.5pt, body, ..args)

// One sector as a row of bytes, `per` bytes to a pixel; the first byte of a pixel carries its value.
// A bracket under the row marks one pixel.
#let _panel-sector(width, per) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (h, y0) = (13, 7)
  let cell = w / _sector
  rect((0, 0), (w, y0 + h), stroke: none)
  for b in range(_sector) {
    rect((b * cell + 0.4, y0), ((b + 1) * cell - 0.4, y0 + h), fill: if calc.rem(b, per) == 0 { c-kernel } else { _c-waste }, stroke: none)
  }
  for p in range(int(_sector / per)) {
    let (l, r) = (p * per * cell, (p + 1) * per * cell)
    line((l + 1.2, y0 - 2), (l + 1.2, y0 - 5), (r - 1.2, y0 - 5), (r - 1.2, y0 - 2), stroke: 0.5pt + c-muted)
  }
})

// (c) the requests of one launch
#let _panel-requests(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (bar, y0) = (15, 15)
  let x1 = w * (1 - _removed)
  rect((0, 0), (w, y0 + bar), stroke: none)
  rect((0, y0), (x1, y0 + bar), fill: c-kernel, stroke: none)
  rect((x1, y0), (w, y0 + bar), fill: _c-waste, stroke: none)
  line((x1, y0), (x1, y0 + bar), stroke: 0.6pt + white)
  content((x1 / 2, y0 + bar / 2), anchor: "center", _lab(fill: white)[#pct(1 - _removed, 0) of the requests remain])
  content(((x1 + w) / 2, y0 + bar / 2), anchor: "center", _lab(fill: white, weight: "bold")[#pct(_removed, 0) of the requests])
  line((x1 + 1, y0 - 3), (x1 + 1, y0 - 6), (w - 1, y0 - 6), (w - 1, y0 - 3), stroke: 0.5pt + c-muted)
  content(((x1 + w) / 2, y0 - 8), anchor: "north", _lab(fill: c-muted)[removed by the seventh change])
})

#let _title(tag, body) = block(below: 4pt, text(size: 8.5pt, top-edge: "cap-height", bottom-edge: "baseline")[*(#tag)* #body])
#let _legend = {
  set text(size: 8pt, top-edge: "cap-height", bottom-edge: "baseline")
  let sq(fill) = box(baseline: -1pt, width: 9pt, height: 5.5pt, fill: fill)
  let item(mark, body) = box[#mark#h(3pt)#body]
  let bracket = box(baseline: -1pt, width: 9pt, height: 3.5pt, stroke: (left: 0.5pt + c-muted, right: 0.5pt + c-muted, bottom: 0.5pt + c-muted))
  (
    item(bracket)[one pixel],
    item(sq(c-kernel))[byte that carries the gray value],
    item(sq(_c-waste))[byte without additional information],
  ).join(h(10pt))
}

#let perf-prop-texels-figure = [#figure(
  kind: image,
  caption: flex-caption([
    Image textures with four bytes and with one byte per pixel, as a simplified sketch.
    *(a)*, *(b)* A cache sector of #_sector bytes holds #int(_sector / _wide) pixels of an image stored with four bytes per pixel and #int(_sector / _narrow) pixels of an image stored with one.
    *(c)* Measured for one launch of the update of the unreliable pixels in the finest round: the change removes #pct(_removed, 0) of its requests to the L2 cache.
  ], [Image textures with four bytes and with one byte per pixel]),
  layout(size => block(breakable: false, width: 100%, {
    set align(left)
    set par(leading: 0.3em, spacing: 0pt)
    set block(spacing: 0pt)
    _title("a")[One cache sector of an image stored with four bytes per pixel: #int(_sector / _wide) pixels]
    _panel-sector(size.width, _wide)
    v(10pt)
    _title("b")[The same sector of an image stored with one byte per pixel: #int(_sector / _narrow) pixels]
    _panel-sector(size.width, _narrow)
    v(7pt)
    _legend
    v(12pt)
    _title("c")[Requests to the L2 cache in one launch of the update of the unreliable pixels, measured]
    _panel-requests(size.width)
  })),
) <fig-perf-prop-texels>]
