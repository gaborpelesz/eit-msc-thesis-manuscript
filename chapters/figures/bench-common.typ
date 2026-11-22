// Shared by the figures and the text of section 5.2 (benchmark results) and its appendix: how a
// number is printed, the arm labels, and the figure wrapper.
//
// Numbers are never typed into the section files. They are read with json() from
// ../../generated/bench-5.2/derived/numbers-bench.json, which
// generated/bench-5.2/scripts/bench_json.py writes from the CSV snapshot in
// generated/bench-5.2/data (`make figures`), and they are rounded here, in one place.
#import "../../template/elteikthesis.typ": flex-caption
// The number helpers of section 4.3, so that both sections print numbers the same way.
#import "perf-common.typ": fix, signed, pct, spell, enumerate-and

#let bench = json("../../generated/bench-5.2/derived/numbers-bench.json").v

// ---- numbers (in addition to those of perf-common.typ) --------------------------------------------
// An integer with thin-space thousands grouping (12 227), as SI style asks for 5 digits and more.
#let big(x) = {
  let s = str(int(calc.round(x)))
  if s.len() < 5 { return s }
  let out = ""
  let n = s.len()
  for (i, c) in s.clusters().enumerate() {
    if i > 0 and calc.rem(n - i, 3) == 0 { out += sym.space.nobreak.narrow }
    out += c
  }
  out
}
// 1st, 2nd, 3rd, 4th
#let ordinal(n) = [#n#(if calc.rem(n, 100) in (11, 12, 13) { "th" } else { ("th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th").at(calc.rem(n, 10)) })]
// a ratio such as 4.3×
#let times(x, digits) = [#fix(x, digits)#sym.times]
// mean with its 95 % interval, from a record with mean, lo, hi
#let mci(s, digits) = [#fix(s.mean, digits) \[#fix(s.lo, digits), #fix(s.hi, digits)\]]
// half-width of an interval as ± in the unit of the mean
#let hw(s, digits) = [#sym.plus.minus#fix(s.hw, digits)]
// seconds as hours
#let hours(s, digits) = [#fix(s / 3600, digits)~h]

// ---- arms ---------------------------------------------------------------------------------------
#let A = bench.arms
#let AC = bench.arms_common
#let lab(key) = bench.registry.labels.at(key)
#let arm(key) = A.at(key)
#let k = (
  acmh: "ACMH@3200-capped", acmp: "ACMP@3200-capped", acmm: "ACMM@3200-capped", acmmp: "ACMMP@3200-capped",
  mp: "MP-MVS@3200-capped", hpm: "HPM-MVS@3200-capped", hpmpp: "HPM-MVS_plusplus@3200-capped",
  cumvs: "CUMVS@3200-capped", apd: "APD-MVS@native", dpe: "DPE-MVS@native",
  ours3200: "production-apd-mvs@3200-capped", oursnat: "production-apd-mvs@native",
)
// is an arm's data in the JSON yet (false for the reserved CUMVS(APD) arms until their runs are in)
#let has(key) = key in A and not A.at(key).reserved
#let labs(keys) = enumerate-and(keys.map(lab))
#let scene(s) = emph(s)

// ---- figures: matplotlib output of generated/bench-5.2/scripts/fig_*.py ---------------------------
// Floated to the top or bottom of a page, as the figures of the other chapters are.
#let bench-figure(name, caption, short, label-name, width: 100%) = place(auto, float: true, clearance: 22pt, [
  #figure(image("../../generated/bench-5.2/derived/figures/" + name + ".svg", width: width), caption: flex-caption(caption, short)) #label(label-name)
])
