// Where the time of the baseline run of production APD-MVS goes, on one page: the timeline of the
// run by pass (two charts on shared rows) on top, and underneath the stages of the thesis timing
// table (<table-timing-measurements>) with their calls and totals. The table is also the key to
// the charts: a stage carries the colour chip of the segment it is drawn in.
//
// Every number and every mark is computed from two files:
//   ../../generated/baseline-run/derived/perf-nsys-r1/pass-timeline.json    (per pass)
//   ../../generated/baseline-run/derived/perf-nsys-r1/stage-timings.json    (per stage)
// which `make figures` writes with generated/baseline-run/scripts/pass_timeline.py and
// stage_timings.py from the run's phases.txt and context.txt. The two files are not committed
// (generated/baseline-run/README.md). Do not type numbers into this file.
//
// Use:  #import "figures/run-breakdown.typ": run-breakdown-figure   then   #run-breakdown-figure
#import "@preview/cetz:0.4.2"
#import "../../template/elteikthesis.typ": flex-caption

#let _d = json("../../generated/baseline-run/derived/perf-nsys-r1/pass-timeline.json")
#let _ctx = _d.meta.context

// Descriptions of the run that its files do not hold (source: .dev/perf/runs.md and REPORT.md
// of the production-apd-mvs checkout).
#let _scene = "pipes"
#let _profiler = (nsys: [Nsight Systems attached], plain: [no profiler]).at(_ctx.mode)

// ---- style ---------------------------------------------------------------------------------
// Three classes of stages: host computation with the GPU idle (orange), host-device copies and
// unpacking (green), GPU kernels (blue, split by stage into three steps of the one hue, light to
// dark), and grey for what belongs to no stage. Neighbouring segments were checked for
// separation in the order drawn, also under simulated colour-vision deficiency.
#let _host = rgb("#eb6834")   // host computation with the GPU idle
#let _copy = rgb("#1baf7a")   // host-device copies and unpacking
#let _kernel = rgb("#2a78d6") // GPU kernels
#let _encl = luma(55%)        // enclosing stage or other: the rest of a pass, output writing
#let _ink = luma(8%)
#let _muted = luma(42%)

// ---- segments of a bar, in the order of the timing table ------------------------------------
// stages: the phase-timer stages summed into the segment; on: colour of a number set on the fill.
#let _segments = (
  (class: "host", label: [input loading], stages: ("input_load",), fill: _host, on: _ink),
  (class: "copy", label: [copies], stages: ("device_upload", "patchmatch.readback", "result_readback"), fill: _copy, on: _ink),
  (class: "kernel", label: [initialization], stages: ("patchmatch.init",), fill: rgb("#7daee8"), on: _ink),
  // The planar prior is fitted between the two propagation kernels of every iteration and is
  // below the line width on its own, so it is drawn with the propagation.
  (class: "kernel", label: [propagation with planar prior], stages: ("patchmatch.propagate", "prior_build"), fill: _kernel, on: white),
  (class: "kernel", label: [finalization], stages: ("patchmatch.finalize",), fill: rgb("#123f7a"), on: white),
)
// a stage of the data that no segment draws would silently end up nowhere
#assert(_segments.map(s => s.stages).flatten().sorted() == _d.leaf_stages.sorted(),
  message: "the segments do not cover the stages of the data")
// rows after the loop: thesis term, and the class of the span
#let _tail = (
  fusion: (label: "fusion", fill: _host),
  output_write: (label: "output writing", fill: _encl),
)

// ---- number formatting ---------------------------------------------------------------------
#let _fix(x, digits) = {
  let s = str(calc.round(x, digits: digits))
  if digits == 0 { return s }
  if not s.contains(".") { s += "." }
  s + "0" * (digits - s.split(".").at(1).len())
}
// one decimal; anything that would print as 0.0 is given as an upper bound
#let _one(x) = if x < 0.05 { [< 0.1] } else { _fix(x, 1) }

// ---- rows ----------------------------------------------------------------------------------
// One row per pass and per span after the loop: label, start and end. A pass has the parts of
// its bar as (seconds, fill, colour of a number on it); they add up to its span. A span after
// the loop is not divided and has the colour of its class.
#let _pass-row(p) = (
  label: str(p.n), t0: p.t0, t1: p.t1, span: p.span_s,
  parts: _segments.map(s => (s.stages.map(k => p.stage_s.at(k)).sum(), s.fill, s.on)) + ((p.other_s, _encl, _ink),),
)
#let _tail-row(t) = (label: _tail.at(t.key).label, t0: t.t0, t1: t.t1, span: t.span_s, bar: _tail.at(t.key).fill)
// groups of rows: the rounds, then the spans after the loop
#let _round-res(r) = if r.scale == 0 { "native" } else { "1/" + str(calc.pow(2, r.scale)) }
#let _groups = _d.rounds.enumerate().map(((k, r)) => (
  round: k + 1, res: _round-res(r), t0: r.t0, t1: r.t1, span: r.span_s,
  rows: r.passes.map(i => _pass-row(_d.passes.at(i))),
)) + ((round: none, rows: _d.tail.map(_tail-row)),)

// ---- geometry (pt) -------------------------------------------------------------------------
#let _h-head = 15      // column heads
#let _h-row = 11       // one pass
#let _h-gap = 5        // between two rounds
#let _h-gap-tail = 9   // between the last round and the rows after the loop
#let _h-axis = 24      // axes under the panels
#let _bar = 7          // bar of the timeline
#let _sbar = 8.6       // share bar
#let _x-rule = 39      // line that ties the passes of a round together
#let _x-pass = 55      // right edge of the pass numbers
#let _x-time = 65      // left edge of the timeline
#let _w-time = 150     // its width
#let _w-dur = 35       // duration column after the timeline
#let _pad-r = 6        // room for the last tick label
#let _min-w = 0.3      // a bar narrower than this cannot be seen and gets a marker instead
#let _grid = 0.3pt + luma(86%)
#let _axis = 0.4pt + luma(35%)

#let _T = _d.run_s
#let _tx(t) = _x-time + _w-time * t / _T
// rows whose bar on the timeline is too narrow to see
#let _too-short = _groups.map(g => g.rows).flatten().filter(r => _w-time * r.span / _T < _min-w)

// Text edges are set on every piece of text: the thesis template sets all text with a
// 0.7em/0.3em strut and a stand-alone preview does not, and a label centred on a bar would sit
// at a different height in the two. One-line labels are boxed from baseline to cap height.
#let _label(size, body, ..args) = text(size: size, top-edge: "cap-height", bottom-edge: "baseline", ..args, body)
#let _small(body, ..args) = _label(7.5pt, body, ..args)
#let _tick(body) = _label(6.5pt, body, fill: _muted)

#let _chart(width) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = width / 1pt
  let x-dur = _x-time + _w-time + _w-dur          // right edge of the durations
  let (sx0, sx1) = (x-dur + 9, w - _pad-r)
  let sx(f) = sx0 + (sx1 - sx0) * f
  let n-rows = _groups.map(g => g.rows.len()).sum()
  let body-h = n-rows * _h-row + (_groups.len() - 2) * _h-gap + _h-gap-tail
  let total-h = _h-head + body-h + _h-axis
  let (y-top, y-bot) = (total-h - _h-head, _h-axis)   // the rows lie between these
  // the share bars end with the last pass; their axis stands beside the rows after the loop
  let pass-groups = _groups.filter(g => g.round != none)
  let y-pass = y-top - pass-groups.map(g => g.rows.len()).sum() * _h-row - (pass-groups.len() - 1) * _h-gap

  rect((0, 0), (w, total-h), stroke: none)   // fixes the canvas to the text width

  // ---- column heads
  let head(pos, anchor, body) = content(pos, anchor: anchor, _small(weight: "bold", body))
  let y-head = y-top + 5
  head((0, y-head), "south-west")[Round]
  head((_x-pass, y-head), "south-east")[Pass]
  head((_x-time, y-head), "south-west")[Start to end in the run]
  head((x-dur, y-head), "south-east")[Duration (s)]
  head((sx0, y-head), "south-west")[Share of the pass by stage; numbers: seconds]
  line((0, y-top + 2), (w, y-top + 2), stroke: 0.5pt + _ink)

  // ---- grids and axes: time, with the smallest round step that gives at most six labels
  let step = (10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000).find(c => _T / c <= 6)
  let y-ax = y-bot - 3
  for i in range(0, int(2 * _T / step) + 1) {
    let t = i * step / 2
    let major = calc.rem(i, 2) == 0
    if major { line((_tx(t), y-ax), (_tx(t), y-top), stroke: _grid) }
    line((_tx(t), y-ax), (_tx(t), y-ax - if major { 2.2 } else { 1.2 }), stroke: _axis)
    if major { content((_tx(t), y-ax - 3.4), anchor: "north", _tick(str(t))) }
  }
  line((_tx(0), y-ax), (_tx(_T), y-ax), stroke: _axis)
  content(((_tx(0) + _tx(_T)) / 2, y-ax - 11.5), anchor: "north", _tick[time since the start of the run (s)])
  let y-sax = y-pass - 3
  for i in range(0, 5) {
    let f = i / 4
    line((sx(f), y-sax), (sx(f), y-top), stroke: _grid)
    line((sx(f), y-sax), (sx(f), y-sax - 2.2), stroke: _axis)
    content((sx(f), y-sax - 3.4), anchor: "north", _tick(str(25 * i)))
  }
  line((sx(0), y-sax), (sx(1), y-sax), stroke: _axis)
  content(((sx(0) + sx(1)) / 2, y-sax - 11.5), anchor: "north", _tick[share of the duration of the pass (%)])

  // ---- rows
  let top = y-top
  for (gi, g) in _groups.enumerate() {
    if gi > 0 { top -= if g.round == none { _h-gap-tail } else { _h-gap } }
    let g-h = g.rows.len() * _h-row
    if g.round != none {
      // the round: name, resolution and duration on the left, its span as a pale band
      content((0, top - g-h / 2), anchor: "west", {
        set text(size: 7.5pt, top-edge: 0.7em, bottom-edge: -0.3em)
        set par(leading: 1.6pt, justify: false, first-line-indent: 0pt)
        [round #g.round\ #g.res\ #text(fill: _muted)[#_one(g.span) s]]
      })
      line((_x-rule, top - 1.5), (_x-rule, top - g-h + 1.5), stroke: 0.5pt + luma(60%))
      rect((_tx(g.t0), top - g-h), (_tx(g.t1), top), fill: black.transparentize(91%), stroke: none)
    }
    for r in g.rows {
      let yc = top - _h-row / 2
      top -= _h-row
      if g.round != none {
        content((_x-pass, yc), anchor: "east", _small(r.label))
      } else {
        content((0, yc), anchor: "west", _small(r.label))
      }
      // timeline: the row from its start to its end, at its true width; a pass is divided
      // into its parts (seconds on the time axis)
      let t = r.t0
      for (sec, fill, ..) in if "parts" in r { r.parts } else { ((r.span, r.bar),) } {
        if sec > 0 { rect((_tx(t), yc - _bar / 2), (_tx(t + sec), yc + _bar / 2), fill: fill, stroke: none) }
        t += sec
      }
      if _tx(r.t1) - _tx(r.t0) < _min-w {
        let xm = (_tx(r.t0) + _tx(r.t1)) / 2
        line((xm, yc - _bar / 2), (xm - 2.6, yc + 1.8), (xm + 2.6, yc + 1.8), close: true, fill: white, stroke: 0.5pt + _muted)
      }
      content((x-dur, yc), anchor: "east", _small(_one(r.span)))
      if "parts" not in r { continue }
      // share bar: the same parts as shares of the span, labelled where the number fits
      let acc = 0
      for (sec, fill, on) in r.parts {
        let (a, b) = (sx(acc / r.span), sx((acc + sec) / r.span))
        acc += sec
        if b <= a { continue }
        rect((a, yc - _sbar / 2), (b, yc + _sbar / 2), fill: fill, stroke: none)
        // a white line between segments keeps them apart in a greyscale print
        if acc < r.span - 1e-6 { line((b, yc - _sbar / 2), (b, yc + _sbar / 2), stroke: 0.4pt + white) }
        let label = _label(6.5pt, _one(sec), fill: on)
        if measure(label).width + 3pt <= (b - a) * 1pt {
          content(((a + b) / 2, yc), anchor: "center", label)
        }
      }
    }
  }
})

// =================================================================================================
// The stage table: the numbers of the stages, and the key to the colours of the charts
// =================================================================================================
#let _s = json("../../generated/baseline-run/derived/perf-nsys-r1/stage-timings.json")
#assert(_s.meta.run == _d.meta.run and _s.meta.source_sha256 == _d.meta.source_sha256,
  message: "the two data files are not of the same run")
#assert(_s.rounds.map(r => r.scale) == _d.rounds.map(r => r.scale),
  message: "the two data files do not have the same rounds")

// ---- rows: the stages of <table-timing-measurements>, in its order and nesting ------------
// Stages the method does not log (device init, depth map writing) have no row; the note names
// them. `rest` is the part of the passes that no stage covers: the grey end of a share bar. It
// is derived, not a stage, and is set in muted italics.
#let _rows = (
  (label: "reconstruction", depth: 0, key: "run"),
  (group: "Setup"),
  (label: "problem parsing", depth: 1, key: "problem_list"),
  (label: "preparation", depth: 1, key: "scene_scan"),
  (group: "Reconstruction loop"),
  (label: "scale (round)", depth: 1, key: "scale"),
  (label: "reference image pass", depth: 1, key: "image_pass"),
  (label: "input loading", depth: 2, key: "input_load"),
  (label: "device upload", depth: 2, key: "device_upload"),
  (label: "PatchMatch", depth: 2, key: "patchmatch"),
  (label: "initialization", depth: 3, key: "patchmatch.init"),
  (label: "propagation", depth: 3, key: "patchmatch.propagate"),
  // In <table-timing-measurements> the planar prior stands before PatchMatch. This method fits
  // it inside the PatchMatch call, between the two propagation kernels of an iteration (every
  // prior_build span lies in a patchmatch span), so it is listed where its time is counted.
  (label: "planar prior", depth: 3, key: "prior_build"),
  (label: "finalization", depth: 3, key: "patchmatch.finalize"),
  (label: "readback", depth: 3, key: "patchmatch.readback"),
  (label: "result unpacking", depth: 2, key: "result_readback"),
  (label: "rest of the pass", depth: 2, rest: true),
  (group: "Fusion and output"),
  (label: "fusion", depth: 1, key: "fusion"),
  (label: "fusion loading", depth: 2, key: "fusion.load"),
  (label: "point generation", depth: 2, key: "fusion.consistency"),
  (label: "output writing", depth: 1, key: "output_write"),
)
#let _not-logged = ("device_init", "depthmap_write")
#for k in _not-logged { assert(k not in _s.stages, message: k + " is logged by this run: give it a row") }
#for k in _s.stages.keys() { assert(_rows.any(r => r.at("key", default: none) == k), message: "stage " + k + " of the data has no row") }

// ---- chips: the mark of a stage in the charts ------------------------------------------------
// A stage drawn in a segment of the pass bars has that segment's fill; a row after the loop has
// the fill of its bar, or the triangle that marks it when its bar is too narrow to see.
#let _chip-fill = {
  let m = (:)
  for seg in _segments { for k in seg.stages { m.insert(k, seg.fill) } }
  for (k, t) in _tail { m.insert(k, t.fill) }
  m
}
#let _marked = _too-short.map(r => r.label)
#let _chip(r) = {
  let sq(fill) = box(width: 6pt, height: 6pt, fill: fill)
  if r.at("rest", default: false) { sq(_encl) }
  else if r.key in _tail and _tail.at(r.key).label in _marked {
    box(width: 6pt, height: 6pt, polygon(fill: white, stroke: 0.5pt + _muted, (0pt, 0.6pt), (6pt, 0.6pt), (3pt, 5.4pt)))
  }
  else if r.key in _chip-fill { sq(_chip-fill.at(r.key)) }
}

// ---- cells -----------------------------------------------------------------------------------
#let _h-trow = 11pt     // stage row
#let _h-tgroup = 12.5pt // group row
#let _rule(w) = table.hline(stroke: w)
#let _dash = text(fill: _muted)[--]
// seconds of the rest of the passes, in total and per round
#let _rest-round = _d.rounds.map(r => r.passes.map(i => _d.passes.at(i).other_s).sum())
#let _cells = {
  let out = ()
  for r in _rows {
    if "group" in r {
      out.push(table.cell(colspan: 4 + _d.rounds.len() + 1, align: left + bottom, inset: (left: 16pt, bottom: 2pt),
        text(size: 7.5pt, emph(strong(r.group)))))
      continue
    }
    // raised to the middle of the lower-case letters of the label beside it
    out.push(table.cell(inset: (left: 5pt, right: 0pt), move(dy: -1.2pt, _chip(r))))
    out.push(if r.at("rest", default: false) { text(fill: _muted, style: "italic")[#h(r.depth * 0.9em)#box(r.label)] } else [#h(r.depth * 0.9em)#box(r.label)])
    if r.at("rest", default: false) {
      let total = _rest-round.sum()
      out += (_dash, _one(total), _one(100 * total / _s.run_s)) + _rest-round.map(_one)
    } else {
      let s = _s.stages.at(r.key)
      out += ([#s.calls], _one(s.total_s), _one(100 * s.total_s / _s.run_s))
      // per round only for what runs inside the rounds
      out += if s.in_loop_s > 0 and r.key != "run" { s.round_s.map(_one) } else { ([],) * _d.rounds.len() }
    }
  }
  out
}

#let _table = {
  // the template's strut, set here too so that rows look the same in a stand-alone preview
  set text(size: 8.5pt, top-edge: 0.7em, bottom-edge: -0.3em)
  set par(justify: false, leading: 0.3em)
  let n = _d.rounds.len()
  let hd(body, ..args) = table.cell(inset: (x: 5pt, y: 3pt), align: bottom, ..args, strong(body))
  table(
    columns: (auto, 1fr, auto, auto, auto) + (49pt,) * n,
    rows: (auto, auto) + _rows.map(r => if "group" in r { _h-tgroup } else { _h-trow }),
    align: (left + horizon, left + horizon) + (right + horizon,) * (3 + n),
    stroke: none,
    inset: (x: 5pt, y: 0pt),
    _rule(0.8pt),
    table.header(
      hd(colspan: 2, rowspan: 2)[Stage], hd(rowspan: 2)[Calls], hd(rowspan: 2)[Total (s)], hd(rowspan: 2)[Share (%)\ #text(size: 6.5pt, weight: "regular", fill: _muted)[of the run]],
      hd(colspan: n, align: center + bottom)[Total by round (s)],
      table.hline(start: 5, end: 5 + n, stroke: 0.3pt),
      .._d.rounds.enumerate().map(((k, r)) => hd[#(k + 1) #text(size: 7.5pt, weight: "regular", fill: _muted)[(#_round-res(r))]]),
    ),
    _rule(0.5pt),
    .._cells,
    _rule(0.8pt),
  )
}

// ---- note: what the charts and the table do not show by themselves -------------------------------
// The first pass of a round (FIRST_INIT, REFINE_INIT in the method) runs without the geometric
// consistency term, the following ones (REFINE_ITER) with it: run.cpp, the two loops of a round.
#let _photometric = _d.passes.filter(p => p.kind != "REFINE_ITER").map(p => str(p.n))
#let _note = {
  set text(size: 8pt, top-edge: 0.7em, bottom-edge: -0.3em, overhang: false)
  set par(justify: true, leading: 0.25em, spacing: 0.6em, first-line-indent: 0pt)
  let sq(fill) = box(width: 0.7em, height: 0.7em, baseline: 0.05em, fill: fill)
  let load = _s.stages.input_load
  [
    A pass is run on each of the #_d.images images once per scale. Its bar is divided into the stage times summed over the pass, always in the order input loading, copies (device upload, readback, result unpacking), initialization, propagation with planar prior, finalization, and rest. The order in which the stages run is not the order they are shown. #sq(_host)~is host computation with the GPU idle, #sq(_copy)~host-device copies and unpacking, #sq(_segments.at(2).fill)#sq(_kernel)#sq(_segments.at(4).fill)~GPU kernels. Passes #_photometric.slice(0, -1).join(", ") and #_photometric.last() are photometric, the others geometric. Input loading also runs #load.outside_calls times before the loop (#_one(load.outside_s) s). The method does not log device init, whose work falls in the first device upload (#_one(_s.stages.device_upload.first_s) s, pass #_d.passes.first().n), nor depth map writing, because depth maps stay in memory as per #ref(<sec:apd-cumvs-inmemory>).
  ]
}

#let _timing-ref = context {
  if query(<table-timing-measurements>).len() > 0 { ref(<table-timing-measurements>) } else [the timing table of the methodology]
}

#let run-breakdown-figure = [#figure(
  kind: image,
  caption: flex-caption([
    Runtime analysis of CUMVS(APD) (the algorithm of APD-MVS @apd, integrated into CUMVS) on ETH3D _#_scene;_ at native resolution. #_timing-ref defines the timing stages. Timing shows the baseline measurements before any optimization. In APD-MVS, the planar prior is conceptually built into PatchMatch, so its time is shown as of PatchMatch's.
  ], [Runtime analysis of the baseline APD-MVS integration by pass and by stage]),
  // a grid, so that the distances between the parts do not depend on the paragraph spacing of
  // the surrounding document
  block(breakable: false, width: 100%, grid(
    columns: (1fr,),
    align: left,
    row-gutter: (5pt, 4pt),
    layout(size => _chart(size.width)),
    _table,
    _note,
  )),
) <fig-run-breakdown>]

#run-breakdown-figure
