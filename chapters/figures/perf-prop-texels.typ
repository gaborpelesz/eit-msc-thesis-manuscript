// What the change "images as 8-bit textures" removes, as a simplified sketch:
//   (a) a run of neighboring pixels of an image row, stored as 32-bit floats, and the cache
//       sectors that it occupies,
//   (b) the same pixels stored with one byte per pixel, at the same scale of bytes,
//   (c) the requests to the L2 cache in one launch of the update of the unreliable
//       pixels, before and after the change.
// (a) and (b) are a sketch: the gray tones are invented, and a fetch of a window reads a
// two-dimensional neighborhood, not one run of a row. The number of pixels is that which fills
// one sector with one byte per pixel. A float encodes the gray value in all of its four bytes, so
// no byte of a pixel is drawn as empty.
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
#let _pixels = int(_sector / _narrow)              // the pixels of the sketch: one sector of bytes
#let _n-wide = int(_pixels * _wide / _sector)      // sectors that they occupy before
#let _n-narrow = int(_pixels * _narrow / _sector)  // and after

#let _c-waste = rgb("#eb6834")
#let _c-waste-light = rgb("#fbe3d8")
#let _c-waste-dark = rgb("#a8401a")
#let _lab(body, ..args) = chart-label(8.5pt, body, ..args)
#let _s-saved = (paint: _c-waste, thickness: 0.7pt, dash: (2.2pt, 1.6pt))

// The gray value of pixel `p`: an invented scanline with two edges, not data.
#let _tone(p) = {
  let t = p / (_pixels - 1)
  let base = if t < 0.3 { 0.78 - 0.5 * t } else if t < 0.62 { 0.24 + 0.25 * (t - 0.3) } else { 0.55 + 0.9 * (t - 0.62) }
  luma(calc.round(100 * calc.clamp(base + 0.07 * calc.sin(p * 2.4), 0.1, 0.93)) * 1%)
}

// The pixels of the sketch with `per` bytes each, in sectors drawn as frames. Both panels share the
// scale of the bytes, so the sectors that the narrow format no longer needs stay visible as
// dashed frames.
#let _panel-pixels(width, per) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (h, y0, pad, gap, rul) = (14, 12, 2.5, 6, 4.5)
  let n = int(_pixels * per / _sector)           // sectors in use
  let sw = (w - (_n-wide - 1) * gap) / _n-wide   // outer width of a sector
  let byte = (sw - 2 * pad) / _sector
  let per-sector = int(_sector / per)
  let top = y0 + h + rul + 2 * pad
  rect((0, 0), (w, top), stroke: none)
  for s in range(_n-wide) {
    let x = s * (sw + gap)
    if s < n {
      rect((x, y0), (x + sw, top), fill: white, stroke: 0.9pt + c-kernel-dark)
      for i in range(per-sector) {
        let l = x + pad + i * per * byte
        rect((l + 0.25, y0 + pad + rul), (l + per * byte - 0.25, y0 + pad + rul + h), fill: _tone(s * per-sector + i), stroke: none)
      }
      // the bytes of the sector, as a ruler under its pixels
      for b in range(_sector) {
        let l = x + pad + b * byte
        rect((l + 0.25, y0 + pad), (l + byte - 0.25, y0 + pad + rul - 1.5), fill: c-kernel-light, stroke: none)
      }
      content((x + sw / 2, y0 - 3.5), anchor: "north", _lab(fill: c-kernel-dark)[sector #(s + 1): #per-sector pixels])
    } else {
      rect((x, y0), (x + sw, top), fill: _c-waste-light, stroke: _s-saved)
    }
  }
  if n < _n-wide {
    let (l, r) = (n * (sw + gap), w)
    content(((l + r) / 2, y0 - 3.5), anchor: "north", _lab(fill: _c-waste-dark)[#(_n-wide - n) sectors that are no longer requested])
  }
})

// (c) the requests of one launch
#let _panel-requests(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (bar, y0) = (16, 0)
  let x1 = w * (1 - _removed)
  rect((0, 0), (w, y0 + bar), stroke: none)
  rect((0, y0), (x1, y0 + bar), fill: c-kernel, stroke: none)
  rect((x1 + 1.5, y0 + 0.35), (w - 0.35, y0 + bar - 0.35), fill: _c-waste-light, stroke: _s-saved)
  content((x1 / 2, y0 + bar / 2), anchor: "center", _lab(fill: white)[#pct(1 - _removed, 0) of the requests remain])
  content(((x1 + w) / 2, y0 + bar / 2), anchor: "center", _lab(fill: _c-waste-dark)[*#pct(_removed, 0) of the requests* are removed by the seventh change])
})

#let _title(tag, body) = block(below: 4pt, text(size: 8.5pt, top-edge: "cap-height", bottom-edge: "baseline")[*(#tag)* #body])
#let _legend = {
  set text(size: 8pt, top-edge: "cap-height", bottom-edge: "baseline")
  let item(mark, body) = box[#mark#h(3pt)#body]
  let px = box(baseline: -1pt, height: 5.5pt, (_tone(2), _tone(12), _tone(26)).map(c => box(width: 4pt, height: 5.5pt, fill: c)).join(h(0.5pt)))
  let byte = box(baseline: -1pt, height: 3pt, range(4).map(_ => box(width: 2.6pt, height: 3pt, fill: c-kernel-light)).join(h(0.5pt)))
  let frame = box(baseline: -1pt, width: 10pt, height: 5.5pt, stroke: 0.9pt + c-kernel-dark)
  let saved = box(baseline: -1pt, width: 10pt, height: 5.5pt, fill: _c-waste-light, stroke: _s-saved)
  (
    item(px)[pixels, shaded with their gray value],
    item(byte)[bytes],
    item(frame)[cache sector of #_sector bytes],
    item(saved)[no longer requested],
  ).join(h(10pt))
}

#let perf-prop-texels-figure = [#figure(
  kind: image,
  caption: flex-caption([
    The cache sectors that the same pixels occupy as 32-bit floats and as 8-bit integers, as a simplified sketch.
    *(a)*, *(b)* A float encodes the 8-bit gray value of a pixel in #_wide bytes, so #_pixels neighboring pixels of an image row occupy #_n-wide cache sectors of #_sector bytes. With #_narrow byte per pixel they occupy #_n-narrow.
    *(c)* Measured for a launch: the change removes #pct(_removed, 0) of its requests to the L2 cache.
  ], [Cache sectors of an image with four bytes and with one byte per pixel]),
  layout(size => block(breakable: false, width: 100%, {
    set align(left)
    set par(leading: 0.3em, spacing: 0pt)
    set block(spacing: 0pt)
    _title("a")[#_pixels pixels of an image row as 32-bit floats, #_wide bytes per pixel: #_n-wide sectors]
    _panel-pixels(size.width, _wide)
    v(9pt)
    _title("b")[The same #_pixels pixels as 8-bit integers, #_narrow byte per pixel: #_n-narrow sector]
    _panel-pixels(size.width, _narrow)
    v(7pt)
    _legend
    v(12pt)
    _title("c")[Requests to the L2 cache in one launch of the update of the unreliable pixels (from measurements)]
    _panel-requests(size.width)
  })),
) <fig-perf-prop-texels>]
