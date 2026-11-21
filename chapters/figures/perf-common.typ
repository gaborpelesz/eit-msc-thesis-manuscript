// Shared by the figures and the text of section 4.3 (performance optimizations): how a number
// is printed, the colours of the stage classes, and the chart of paired differences that two of
// the figures draw.
//
// Numbers are never typed into the section or figure files. They are read with json() from
// ../../generated/perf-4.3/derived/, which generated/perf-4.3/scripts/perf43_json.py writes, and
// they are rounded here, in one place.
#import "@preview/cetz:0.4.2"

// ---- numbers ---------------------------------------------------------------------------------
// Magnitude with a fixed number of decimals.
#let _mag(x, digits) = {
  let s = str(calc.round(calc.abs(x), digits: digits))
  if digits == 0 { return s }
  if not s.contains(".") { s += "." }
  s + "0" * (digits - s.split(".").at(1).len())
}
// A value with a fixed number of decimals; a negative one has a minus sign, not a hyphen.
#let fix(x, digits) = if x < 0 { sym.minus } else { "" } + _mag(x, digits)
// A difference: always with its sign. The sign is that of the value, also when it rounds to zero.
#let signed(x, digits) = if x < 0 { sym.minus } else { "+" } + _mag(x, digits)
// A confidence interval from a record with `lo` and `hi`.
#let interval(s, digits) = [\[#signed(s.lo, digits), #signed(s.hi, digits)\]]
// A difference with its interval, from a record with `mean`, `lo` and `hi`.
#let diff-ci(s, digits) = [#signed(s.mean, digits) #interval(s, digits)]
// Mean and standard deviation.
#let pm(mean, sd, digits) = [#fix(mean, digits)~#sym.plus.minus~#fix(sd, digits)]
// A share (0 to 1) in percent.
#let pct(x, digits) = [#fix(100 * x, digits)%]
// A count in millions or thousands.
#let millions(x, digits) = fix(x / 1e6, digits)
#let thousands(x, digits) = fix(x / 1e3, digits)
// A small count in words, as running text wants it.
#let spell(n) = ("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve").at(n)
// "a, b and c"
#let enumerate-and(items) = if items.len() > 1 { items.slice(0, -1).join(", ") + [ and ] + items.last() } else { items.first() }
// width x height of a size given as (width, height), kept on one line
#let size-of(wh) = box[#wh.at(0) #sym.times #wh.at(1)]

// ---- colours: the stage classes of <fig-run-breakdown> ----------------------------------------
#let c-host = rgb("#eb6834")     // host computation with the GPU idle
#let c-copy = rgb("#1baf7a")     // host-device copies and unpacking
#let c-copy-light = rgb("#a9e3cd")
#let c-kernel = rgb("#2a78d6")   // GPU kernels
#let c-kernel-light = rgb("#7daee8")
#let c-kernel-dark = rgb("#123f7a")
#let c-other = luma(55%)         // what belongs to no stage
#let c-ink = luma(8%)
#let c-muted = luma(42%)
#let s-grid = 0.3pt + luma(86%)
#let s-axis = 0.4pt + luma(35%)

// ---- the builds of the input stack, by their key in the data ------------------------------------
// The first is the base; the others are the changes in the order they were stacked, and a chart
// numbers them by their position in the data.
#let input-builds = (
  "base2": [baseline],
  "h1": [images cached],
  "h2h12": [host buffers reused],
  "h14": [upscaling in parallel],
  "h3h6": [device data kept],
)
#let input-build-label(i, key) = if i == 0 { input-builds.at(key) } else [#i: #input-builds.at(key)]

// ---- the builds of the anchor stack and its kernels, by their key in the data ------------------
#let anchor-builds = (
  "base2": [fixed base],
  "k3": [one probe per radius step],
  "k12": [random state in registers],
  "k1c": [nearest table in two passes],
  "gnl": [eight best kept in registers],
  "irs": [tabulated skip-ahead],
)
#let anchor-build-label(i, key) = if i == 0 { anchor-builds.at(key) } else [#i: #anchor-builds.at(key)]
// what a kernel does, in the words of <table-kernel-breakdown>
#let anchor-kernels = (
  "FindNearestStrongPoint": [nearest reliable pixel],
  "GenNeighbours": [anchor selection],
  "InitRandomStates": [one random generator per pixel],
)

// ---- the builds of the propagation stack and its kernels, by their key in the data --------------
#let prop-builds = (
  "base2": [fixed base],
  "k10": [window loops unrolled],
  "reftex": [reference point-filtered],
  "k2": [zero-weight views skipped],
  "k11": [anchors read once],
  "k7lite": [only read cost entries filled],
  "cu2": [cameras in constant memory],
  "u8": [images as 8-bit textures],
)
#let prop-build-label(i, key) = if i == 0 { prop-builds.at(key) } else [#i: #prop-builds.at(key)]
// the kernel groups of the propagation data: the kernels and what they do
#let prop-kernels = (
  "weak": (name: [`BlackPixelUpdateWeak` and `RedPixelUpdateWeak`], short: [`…PixelUpdateWeak`], what: [unreliable pixels]),
  "strong": (name: [`BlackPixelUpdateStrong` and `RedPixelUpdateStrong`], short: [`…PixelUpdateStrong`], what: [reliable pixels]),
  "fit": (name: [`RANSACToGetFitPlane`], short: [`RANSACToGetFitPlane`], what: [plane fit]),
  "depth_to_weak": (name: [`DepthToWeak`], short: [`DepthToWeak`], what: [reliability classification]),
  "local_refine": (name: [`LocalRefine`], short: [`LocalRefine`], what: [local refinement]),
  "gen_neighbours": (name: [`GenNeighbours`], short: [`GenNeighbours`], what: [anchor selection]),
)
// ---- the builds of the classification stack and the regions of its stall map, by their key ------
#let class-builds = (
  "prop": [propagation stack],
  "c2": [refinement folded into the sweep],
  "c1": [unread end samples dropped],
  "k13": [view weights read once],
  "c9": [depth maps point-filtered],
  "c3": [zero-weight views skipped],
  "u8": [8-bit textures],
  "comb": [8-bit textures and all changes],
)
#let class-kernels = (
  "depth_to_weak": (name: [`DepthToWeak`], what: [sweep and label]),
  "local_refine": (name: [`LocalRefine`], what: [local refinement]),
)
#let class-regions = (
  "window": [window loop: fetches and sums],
  "geometric": [geometric cost],
  "projection": [projection of the window samples],
  "body": [refinement search (`LocalRefine` only)],
  "control": [sweep control],
  "setup": [matching cost outside the window],
  "weights": [view-weight load and weighted sum],
  "homography": [homography],
  "valleys": [valley analysis],
  "other": [other],
)
// ---- the stacks combined, by their key in the data ---------------------------------------------
// (n is the number of propagation changes in the first of the two builds that have them)
#let stack-builds = (
  "base2": n => [fixed base],
  "comb": n => [input and anchor stacks],
  "prop-comb": n => [with propagation changes 1 to #n],
  "prop-comb-cu2": n => [with propagation change #(n + 1)],
  "prop-8bit": n => [with 8-bit image textures],
  "class-comb": n => [with the classification changes],
)

// ---- the final stack: its stages and the rows of the ablation, by their key in the data ---------
#let final-stages = (
  "base2": [fixed base],
  "input": [input loading and transfers],
  "anchor": [anchor search],
  "prop": [propagation],
  "u8": [8-bit image textures],
  "class": [reliability classification],
  "tip": [reliability classification and fix],
)
// one row per commit; a change keeps the words of the chart of its own subsection
#let ablation-rows = (
  "base2": [fixed base],
  "timers": [region timers (no change of the method)],
  "h1": input-builds.h1, "h2h12": input-builds.h2h12, "h14": input-builds.h14, "h3h6": input-builds.h3h6,
  "k3": anchor-builds.k3, "k12": anchor-builds.k12, "k1c": anchor-builds.k1c, "gnl": anchor-builds.gnl, "irs": anchor-builds.irs,
  "k10": prop-builds.k10, "reftex": prop-builds.reftex, "k2": prop-builds.k2, "k11": prop-builds.k11, "k7lite": prop-builds.k7lite,
  "cu2": prop-builds.cu2, "u8": prop-builds.u8,
  "c2": class-builds.c2, "c1": class-builds.c1, "k13": class-builds.k13, "c9": class-builds.c9,
  "c3": [zero-weight views skipped in the sweep],
  "fix": [division by zero removed (bug fix)],
  "stack": [stack image, fresh runs],
)
// the kernels of the final kernel table, by their key in the data
#let final-kernels = (
  "weak": (name: [`BlackPixelUpdateWeak`, `RedPixelUpdateWeak`], what: [update of the unreliable pixels]),
  "strong": (name: [`BlackPixelUpdateStrong`, `RedPixelUpdateStrong`], what: [update of the reliable pixels]),
  "depth_to_weak": (name: [`DepthToWeak`], what: [reliability classification]),
  "gen_neighbours": (name: [`GenNeighbours`], what: [anchor selection]),
  "nearest": (name: [`FindNearestStrongPoint`], what: [nearest reliable pixel]),
  "init_states": (name: [`InitRandomStates`], what: [one random generator per pixel]),
  "fit": (name: [`RANSACToGetFitPlane`], what: [plane fit]),
  "local_refine": (name: [`LocalRefine`], what: [local refinement]),
  "random_init": (name: [`RandomInitialization`], what: [random initial planes]),
  "other": (name: [other kernels], what: [filters and copies]),
)

// A count as mantissa and power of ten.
#let sci(x, digits) = {
  let e = calc.floor(calc.log(x, base: 10.0))
  let m = calc.round(x / calc.pow(10.0, e), digits: digits)
  if m >= 10 { m = m / 10; e += 1 }
  [#fix(m, digits)#h(0.08em)#sym.dot.c#h(0.08em)10#super(str(e))]
}

// ---- text in a chart ---------------------------------------------------------------------------
// Text edges are set on every label, as in run-breakdown.typ: the thesis template sets all text
// with a strut and a stand-alone preview does not.
#let chart-label(size, body, ..args) = text(size: size, top-edge: "cap-height", bottom-edge: "baseline", ..args, body)
#let small(body, ..args) = chart-label(7.5pt, body, ..args)
#let tick(body) = chart-label(6.5pt, body, fill: c-muted)

// The smallest round step that gives at most `n` intervals over `span`.
#let nice-step(span, n) = {
  let e = calc.pow(10.0, calc.floor(calc.log(span / n, base: 10.0)))
  (1, 2, 5, 10).map(m => m * e).find(c => span / c <= n)
}

// ---- chart of paired differences ----------------------------------------------------------------
// One row per comparison: the mean as a marker, the confidence interval as a whisker with caps,
// optionally the single differences as open dots above it, and the numbers at the right. The
// axis is shared by all rows, is linear and contains zero.
//
// rows: (group: content)  a heading, or
//       (label, sub, mean, lo, hi, dots, marker, band)   with
//         sub     second line of the label or none
//         dots    the single differences, or ()
//         marker  "circle", "square" or "diamond"
//         band    (lo, hi) of a margin shaded in this row only, or none
//         marks   optional: values marked by a dotted line in this row (a former margin)
// ci-level: level of the intervals in percent; digits: decimals of the numbers; x-title: axis title; indent: of the row labels, under a
// group heading.
// label-w: width of the label column (the left edge of the plot).
#let paired-chart(width, rows, ci-level: none, digits: 4, x-title: [], indent: 0, row-h: 22, dot-row-h: 30, label-w: 112) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let (x0, x1) = (label-w, w - 132)     // the plot
  let x-num = w - 124               // left edge of the numbers
  let h-head = 15
  let h-group = 15
  let h-axis = 27
  let data = rows.filter(r => "group" not in r)
  // axis range: round steps around everything drawn
  let lo = calc.min(0, ..data.map(r => calc.min(r.lo, ..r.dots, ..if r.band != none { (r.band.at(0),) })))
  let hi = calc.max(0, ..data.map(r => calc.max(r.hi, ..r.dots, ..if r.band != none { (r.band.at(1),) })))
  // a margin drawn at the very edge of the plot would look like its frame: keep one step of room
  let has-band = data.any(r => r.band != none)
  let step = nice-step(hi - lo, 7)
  let room = if has-band { 0.5 } else { 0.05 }
  let (k0, k1) = (calc.floor(lo / step - room), calc.ceil(hi / step + room))
  let (a, b) = (k0 * step, k1 * step)
  let x(v) = x0 + (x1 - x0) * (v - a) / (b - a)
  let tick-digits = calc.max(0, -calc.floor(calc.log(step, base: 10.0) + 1e-9))
  let h(r) = if "group" in r { h-group } else if r.dots.len() > 0 { dot-row-h } else { row-h }
  let body-h = rows.map(h).sum()
  let total-h = h-head + body-h + h-axis
  let (y-top, y-bot) = (total-h - h-head, h-axis)

  rect((0, 0), (w, total-h), stroke: none)   // fixes the canvas to the text width

  // column heads
  let head(pos, anchor, body) = content(pos, anchor: anchor, small(weight: "bold", body))
  head((0, y-top + 5), "south-west")[Comparison]
  head((x-num, y-top + 5), "south-west")[Mean and #ci-level% interval]
  line((0, y-top + 2), (w, y-top + 2), stroke: 0.5pt + c-ink)

  // grid and axis
  let y-ax = y-bot - 3
  for k in range(k0, k1 + 1) {
    let v = k * step
    line((x(v), y-ax), (x(v), y-top), stroke: if k == 0 { 0.5pt + luma(35%) } else { s-grid })
    line((x(v), y-ax), (x(v), y-ax - 2.2), stroke: s-axis)
    content((x(v), y-ax - 3.4), anchor: "north", tick(if k == 0 { [0] } else { signed(v, tick-digits) }))
  }
  line((x(a), y-ax), (x(b), y-ax), stroke: s-axis)
  content(((x0 + x1) / 2, y-ax - 12.5), anchor: "north", tick(x-title))

  // rows
  let top = y-top
  for r in rows {
    let rh = h(r)
    if "group" in r {
      content((0, top - rh + 3.5), anchor: "south-west", small(style: "italic", weight: "bold", r.group))
      top -= rh
      continue
    }
    let yc = top - rh / 2
    let has-dots = r.dots.len() > 0
    let (y-dots, y-mean) = if has-dots { (yc + 6, yc - 5) } else { (yc, yc) }
    if r.band != none {
      // the margin, in the row it decides: behind everything else of the row
      rect((x(r.band.at(0)), top - rh + 1), (x(r.band.at(1)), top - 1), fill: c-kernel.transparentize(86%), stroke: none)
      for v in r.band {
        line((x(v), top - rh + 1), (x(v), top - 1), stroke: (paint: c-kernel-dark, thickness: 0.6pt, dash: "dashed"))
      }
    }
    for v in r.at("marks", default: ()) {
      line((x(v), top - rh + 1), (x(v), top - 1), stroke: (paint: c-kernel-dark, thickness: 0.5pt, dash: "dotted"))
    }
    // label
    if r.sub == none {
      content((indent, yc), anchor: "west", small(r.label))
    } else {
      content((indent, yc + 4.5), anchor: "west", small(r.label))
      content((indent, yc - 4.5), anchor: "west", chart-label(6.5pt, r.sub, fill: c-muted))
    }
    // single differences
    for v in r.dots {
      circle((x(v), y-dots), radius: 2, fill: none, stroke: 0.6pt + c-muted)
    }
    // interval and mean
    line((x(r.lo), y-mean), (x(r.hi), y-mean), stroke: 0.9pt + c-ink)
    for v in (r.lo, r.hi) { line((x(v), y-mean - 2.6), (x(v), y-mean + 2.6), stroke: 0.9pt + c-ink) }
    let xm = x(r.mean)
    if r.marker == "circle" {
      circle((xm, y-mean), radius: 2.7, fill: c-ink, stroke: none)
    } else if r.marker == "square" {
      rect((xm - 2.5, y-mean - 2.5), (xm + 2.5, y-mean + 2.5), fill: white, stroke: 0.9pt + c-ink)
    } else {
      line((xm - 3.6, y-mean), (xm, y-mean + 3.6), (xm + 3.6, y-mean), (xm, y-mean - 3.6), close: true, fill: c-ink, stroke: none)
    }
    // numbers
    content((x-num, y-mean), anchor: "west", small(diff-ci(r, digits)))
    top -= rh
  }
})
