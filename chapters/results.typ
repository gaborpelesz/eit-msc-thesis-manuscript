#import "../template/elteikthesis.typ": *
#import "figures/bench-common.typ": *

#let B = bench
#let _f(key) = arm(key).f1_2cm
#let _t(key) = arm(key).wall_total_s
#let _sh(key, c) = arm(key).share.at(c)
#let _st = B.front_steps
#let _nb = B.native_vs_best_capped

= Results & Discussion <ch-results>



/*
3. Can a systematically engineered, production-grade reimplementation of a recent state-of-the-art method recover a substantial fraction of the runtime and memory cost while preserving its benchmark accuracy?
  - can we find a single change in a lineage shared kernel part (for example in the ACM family) that if we improve, it would improve the perf of all lineage items?

== Preparing for the benchmarking, Findings
1. all nine methods (ACM-family, two HPM, APD, DPE) ship converters that look for `.jpg` images in a case-sensitive manner while ETH3D downloaded images are `*.JPG` with upper-case. Because of this, the converter decodes and re-encodes every image using OpenCV's default JPEG quality, 95. The re-encode changes 46-59% of pixels at 46-50 dB PSNR.
  - CUMVS reads original images and it doesn't re-encode
*/

== Benchmarking <sec:bench-results>

The final benchmark ran the #B.n_methods measured methods with the protocol of #ref(<sec:benchmark-dimensioning>) on the #B.n_scenes ETH3D training scenes with #spell(B.n_rep) repeats each. A total of #B.n_runs runs were carried out, of which #B.n_ok succeeded. The #B.n_failed failures are all HPM-MVS++ runs from the same cause, and are analyzed in #ref(<sec:bench-resources>). A per-scene value is the mean of the #spell(B.n_rep) repeats of its cell. A value over the #B.n_scenes scenes, the mean F1 or the total runtime, is computed for each repeat index and given as the mean of the #spell(B.n_rep) values with the #B.ci_level_pct% interval of #ref(<eq-ci>) ($n = #B.n_rep$). HPM-MVS++ completed only #spell(B.common_scenes.len()) scenes (#scene(B.common_scenes.join(", "))) and is therefore it is compared on those scenes only and left out of every #(B.n_scenes)-scene value. #ref(<table-bench-main>) collects the headline numbers of this section. // src: bench_json.py docstring; v.common_scenes; v.partial

// The best value of each column is set in bold, compared at the printed precision so that ties are
// all bold: the largest for F1, accuracy and completeness, the smallest for the others.
#let _main_keys = (k.acmh, k.acmp, k.acmm, k.acmmp, k.mp, k.hpm, k.cumvs, k.ours3200, k.apd, k.dpe, k.oursnat)
#let _main_cols = (
  f1:   (a => a.f1_2cm.mean, 3, calc.max),
  acc:  (a => a.acc_2cm.mean, 3, calc.max),
  comp: (a => a.comp_2cm.mean, 3, calc.max),
  time: (a => a.wall_total_s.mean, 0, calc.min),
  x:    (a => a.x_cumvs, 1, calc.min),
  mem:  (a => a.peak_dev_mib, 0, calc.min),
  kj:   (a => a.energy_total_kj, 0, calc.min),
)
#let _best = {
  let present = _main_keys.filter(has)
  for (c, (get, d, pick)) in _main_cols {
    ((c): pick(..present.map(key => calc.round(get(arm(key)), digits: d))))
  }
}
#let _b(a, c, body) = {
  let (get, d, _) = _main_cols.at(c)
  if calc.round(get(a), digits: d) == _best.at(c) { strong(body) } else { body }
}
#let _row(key) = if has(key) {
  let a = arm(key)
  (lab(key), _b(a, "f1", fix(a.f1_2cm.mean, 3)), _b(a, "acc", fix(a.acc_2cm.mean, 3)), _b(a, "comp", fix(a.comp_2cm.mean, 3)),
   _b(a, "time", [#big(a.wall_total_s.mean) #hw(a.wall_total_s, 0)]), _b(a, "x", times(a.x_cumvs, 1)),
   _b(a, "mem", big(a.peak_dev_mib)), _b(a, "kj", big(a.energy_total_kj)))
} else {
  (lab(key), table.cell(colspan: 7, align: center, text(fill: luma(45%), style: "italic")[pending (M8)]))
}
#figure(
  kind: table,
  caption: flex-caption([
    Headline results per method over the #B.n_scenes scenes. F1-score, accuracy, and completeness are averaged at 2~cm, the total runtime is the method time summed over the scenes (converter excluded), with the half-width of its #B.ci_level_pct% confidence interval. Peak device memory is the largest over all runs; GPU energy is summed over the scenes.
  ], [Headline benchmark results per method]),
  {
    set text(size: 8.5pt)
    set par(justify: false, leading: 0.5em)
    table(
      columns: (auto, auto, auto, auto, auto, auto, auto, auto),
      align: (left, right, right, right, right, right, right, right),
      stroke: none,
      inset: (x: 4pt, y: 3pt),
      table.hline(stroke: 0.8pt),
      table.header([*Method*], [*F1*], [*Acc.*], [*Comp.*], [*Time (s)*], [*Time #sym.times baseline (CUMVS)*], [*Peak GPU mem. (MiB)*], [*Energy (kJ)*]),
      table.hline(stroke: 0.5pt),
      table.cell(colspan: 8, inset: (top: 5pt, bottom: 2pt), emph[Capped at 3200 px]),
      .._row(k.acmh), .._row(k.acmp), .._row(k.acmm), .._row(k.acmmp), .._row(k.mp), .._row(k.hpm), .._row(k.cumvs), .._row(k.ours3200),
      table.cell(colspan: 8, inset: (top: 5pt, bottom: 2pt), emph[Native resolution]),
      .._row(k.apd), .._row(k.dpe), .._row(k.oursnat),
      table.hline(stroke: 0.8pt),
    )
  },
) <table-bench-main>
// src (the whole table): v.arms.<key>.{f1_2cm, acc_2cm, comp_2cm, wall_total_s, x_cumvs, peak_dev_mib, energy_total_kj} (runs.csv, ok runs)

=== Reconstruction quality <sec:bench-quality>

#let _r = B.rank_2cm
From the benchmark perspective, DPE-MVS reconstructs best and it ranks first on #B.first_count.at(k.dpe) of the #B.n_scenes scenes with a mean F1 of #fix(_f(k.dpe).mean, 3) at 2~cm. APD-MVS is the next with #fix(_f(k.apd).mean, 3). It is important to note, that they are the two lineage algorithms running at native resolution. The best 3200~px capped method is #lab(B.best_capped), with #fix(_f(B.best_capped).mean, 3). ACMH, the first algorithm in the lineage, is last with #fix(_f(k.acmh).mean, 3) (#ref(<table-bench-main>)) as expected due to not having all the quality machinary that other algorithms introduce. On the #spell(B.common_scenes.len()) scenes that HPM-MVS++ completed, its F1 of #fix(AC.at(k.hpmpp).f1_2cm.mean, 3) lies between APD-MVS (#fix(AC.at(k.apd).f1_2cm.mean, 3)) and MP-MVS (#fix(AC.at(k.mp).f1_2cm.mean, 3)).

#todo[3200px projections for APD-MVS, how would it perform approximately on quality?]

The quality improvements along the lineage come in the form of completeness (#ref(<lit:acmh>)). Over lineage methods, 3200~px capped completeness ranges from #fix(B.lineage_comp_range.first(), 3) (ACMH) to #fix(B.lineage_comp_range.last(), 3) (MP-MVS), while accuracy stays between #fix(B.lineage_acc_range.first(), 3) and #fix(B.lineage_acc_range.last(), 3). APD-MVS and DPE-MVS trade accuracy for completeness: their accuracy, #fix(arm(k.apd).acc_2cm.mean, 3) and #fix(arm(k.dpe).acc_2cm.mean, 3), is below that of every capped lineage method with a #(B.n_scenes)-scene value, and their completeness, #fix(arm(k.apd).comp_2cm.mean, 3) and #fix(arm(k.dpe).comp_2cm.mean, 3), is the highest.

#bench-figure("bench-scenes",
  [F1 at 2~cm per scene and arm, mean of #spell(B.n_rep) repeats; the best arm of each scene in bold. Scenes from the lowest mean F1 over the arms (top) to the highest, with their number of images. Hatched: no successful run (HPM-MVS++, #ref(<sec:bench-resources>)).],
  [F1 at 2 cm per scene and arm], "fig-bench-scenes")

=== Runtime and the quality-time trade-off <sec:bench-time>

Runtime spans almost two orders of magnitude (#ref(<table-bench-main>)) due to the different resolution caps. The capped methods take #big(B.capped_total_range_s.first())~s (#lab(B.capped_fastest)) to #big(B.capped_total_range_s.last())~s (#lab(B.capped_slowest)), while APD-MVS takes #big(_t(k.apd).mean)~s (#hours(_t(k.apd).mean, 1)) and DPE-MVS #big(_t(k.dpe).mean)~s (#hours(_t(k.dpe).mean, 1)) to complete all scenes. The native resolution is the choice of the APD-MVS and DPE-MVS authors, with small quality improvements at a significantly higher compute cost #todo[here our 3200px capped APD result will be interesting. It will show how much is the improvement over quality for going native]

Time is linear in the number of images: per method, the per-scene runtime correlates with it at $r = #fix(B.lin_r_range.first(), 2)$ to $#fix(B.lin_r_range.last(), 2)$, and the slope is #fix(arm(k.cumvs).s_per_image, 1)~s per image for CUMVS, #fix(arm(k.acmh).s_per_image, 1)~s for ACMH, #fix(arm(k.mp).s_per_image, 1)~s for MP-MVS, #fix(arm(k.apd).s_per_image, 0)~s for APD-MVS and #fix(arm(k.dpe).s_per_image, 0)~s for DPE-MVS. The most expensive scene of every method is _facade_, with #B.n_images.facade images (#ref(<table-bench-scene-time>)). // src: v.lin_r_range, v.arms.*.s_per_image (linear fit of cell means on n_images), v.facade_slowest_all
The converters, which the runtime excludes, add #fix(B.convert_python_range_s.first(), 0) to #fix(B.convert_python_range_s.last(), 0)~s over the #B.n_scenes scenes to each Python-converter method, #fix(arm(k.apd).convert_total_s, 0)~s to APD-MVS and DPE-MVS and #fix(arm(k.cumvs).convert_total_s, 1)~s to CUMVS (converter time in #ref(<table-timing-measurements>)).
#assert(B.facade_slowest_all)
#assert(B.power_max == B.energy_min and arm(k.acmm).input_load_s > 3 * _t(k.cumvs).mean, message: "premise of the energy or input-loading sentence changed")

Cost does not grow monotonically with quality. MP-MVS is faster than ACMM, ACMMP and HPM-MVS and reconstructs better than all three. MP-MVS takes #pct(1 - _t(k.mp).mean / _t(k.acmmp).mean, 0) less time than ACMMP, confirming their claim @mp_mvs. CUMVS reimplementation of ACMM, is #times(arm(k.acmh).x_cumvs, 1) faster than ACMH and #times(arm(k.acmm).x_cumvs, 1) faster than ACMM, with a higher F1 than both. The results reproduce the CUMVS claims exactly @fixstars2025cumvs#footnote[If CUMVS hardware claims are also correct, a further observation is that the NVidia 5070 GPU performs an overall 34% better than NVidia 3080 GPU.].

#bench-figure("bench-tradeoff",
  [Mean F1 at 2~cm against the total runtime over the #B.n_scenes scenes (log scale), with #B.ci_level_pct% intervals (mostly smaller than the markers). Filled markers lie on the Pareto front. HPM-MVS++ is not shown. The CUMVS(APD) arms are added in #ref(<sec:bench-cumvs-apd>).],
  [Quality against runtime], "fig-bench-tradeoff")

#todo[talk about #ref(<fig-bench-tradeoff>) when APD-MVS results are in]TODO


=== Runtime breakdown <sec:bench-phases>

The phase timers of #ref(<table-timing-measurements>) split each method's runtime into the classes of #ref(<fig-bench-phases>)a. The methods fall into two groups. The four ACM methods are host-bound: the GPU is idle for #pct(B.acm4_idle_range.first(), 0) to #pct(B.acm4_idle_range.last(), 0) of their runtime, and input loading alone takes #pct(B.acm4_input_range.first(), 0) to #pct(B.acm4_input_range.last(), 0), the largest share of all phases for ACMM (#pct(_sh(k.acmm, "input_load"), 0)) and ACMMP (#pct(_sh(k.acmmp, "input_load"), 0)). ACMM loads every image #B.acmm_loads_per_image times, so a run on _pipes_ with its #B.n_images.pipes images has #B.acmm_pipes_input_load_spans input-loading spans; over the #B.n_scenes scenes, its input loading takes #big(arm(k.acmm).input_load_s)~s, more than three times the whole runtime of CUMVS (#big(_t(k.cumvs).mean)~s). // src: v.acm4_idle_range, v.acm4_input_range, v.arms.*.share.input_load (phase-categories.csv, self_s / wall); v.acmm_loads_per_image, v.acmm_pipes_input_load_spans (phases.csv input_load count / n_images)
MP-MVS and HPM-MVS keep the GPU busier, with #pct(arm(k.mp).gpu_idle_share, 0) and #pct(arm(k.hpm).gpu_idle_share, 0) idle time. APD-MVS and DPE-MVS are GPU-bound: PatchMatch takes #pct(_sh(k.apd, "patchmatch"), 1) and #pct(_sh(k.dpe, "patchmatch"), 1) of their runtime and the GPU is idle for #pct(arm(k.apd).gpu_idle_share, 1) and #pct(arm(k.dpe).gpu_idle_share, 1). CUMVS spends #pct(_sh(k.cumvs, "input_load"), 1) of its runtime on input loading, which is the clearest evidence that this host share is implementation, and #pct(_sh(k.cumvs, "write"), 1) on writing the point cloud, with #pct(arm(k.cumvs).gpu_idle_share, 0) GPU idle. #ref(<table-bench-phase-seconds>) gives the phase classes in seconds, and #ref(<table-bench-acmm-cumvs>) compares ACMM with CUMVS class by class. // src: v.arms.*.gpu_idle_share (telemetry gpu_idle_share, time weighted), v.arms.*.share

#bench-figure("bench-phases",
  [Where the time goes. (a) Share of each arm's runtime per phase class, from the phase timers (self time, summed over the scenes), with the share of time the GPU was idle (driver utilization zero, sampled at 2~Hz) as a tick on the same axis. Classes and the phases of #ref(<table-timing-measurements>): input loading (`input_load`), host-device transfers (`device_upload`, `patchmatch.readback`, `result_readback`), PatchMatch (`patchmatch`), priors and auxiliary passes (`prior_build`, `edge_prior`, `confidence_eval`, `upsample`, which differ by method), fusion (`fusion`), writing (`depthmap_write`, `output_write`), other (setup, loop overhead, untimed). HPM-MVS++ on its #spell(B.common_scenes.len()) scenes. (b) GPU-idle share against the share of runtime outside PatchMatch, one point per arm that completed all scenes; dashed: equality.],
  [Where the runtime goes, per arm], "fig-bench-phases")

Fusion is the other large phase of the ACM methods: it takes #pct(_sh(k.acmh, "fusion"), 0) of the runtime of ACMH, its largest phase, and #pct(_sh(k.acmp, "fusion"), 0) of ACMP. // src: v.arms.*.share.fusion

Host-boundedness is measured twice, by the driver's utilization counter and by the phase timers, and the two agree across the methods (#ref(<fig-bench-phases>)b): over the #B.idle_vs_outside_n arms that completed all scenes, the GPU-idle share and the share of runtime outside the PatchMatch phase correlate at $r = #fix(B.idle_vs_outside_r, 2)$ (input loading alone at $r = #fix(B.idle_vs_input_r, 2)$). The time an ACM method spends outside PatchMatch is largely time in which the GPU waits for the host. // src: v.idle_vs_outside_r, v.idle_vs_outside_n, v.idle_vs_input_r
The host share is similar across the four ACM methods and smaller in MP-MVS and HPM-MVS. // src: v.acm4_idle_range, v.arms.mp/hpm.gpu_idle_share
#ref(<sec:perf>) recovered a large part of the host cost on the same lineage. On CUMVS(APD), the #B.s43.commits commits of the stack reduced the host-side time on _pipes_ from #fix(B.s43.host_base_s, 1)~s to #fix(B.s43.host_stack_s, 1)~s, #pct(B.s43.host_saved_share, 0) less, and the kernel time by #pct(B.s43.kernel_saved_share, 0), without significant algorithmic changes (analysis runs on unlocked clocks, against the fixed base of #ref(<sec:perf>)). Because the ACM methods share this lineage and spend a larger share of their time on the host, similar recoveries are expected in them; this benchmark shows where that time is, not that it can be recovered. // src: v.s43 (perf43-numbers-results.json: phases.host, phases.kernel, stack.commits)
=== Memory and energy <sec:bench-resources>

#let _hp = B.hpmpp
The capped arms other than HPM-MVS++ need less than half of the #big(B.card_mib)~MiB card (#ref(<fig-bench-memory>)). CUMVS peaks at #big(arm(k.cumvs).peak_dev_mib)~MiB, #labs(B.capped_small) at #big(B.capped_small_peak_range_mib.first()) to #big(B.capped_small_peak_range_mib.last())~MiB, and ACMM and ACMMP at #big(arm(k.acmm).peak_dev_mib) and #big(arm(k.acmmp).peak_dev_mib)~MiB on #scene(arm(k.acmm).peak_dev_scene). At native resolution APD-MVS peaks at #big(arm(k.apd).peak_dev_mib)~MiB and DPE-MVS at #big(arm(k.dpe).peak_dev_mib)~MiB on #scene(arm(k.dpe).peak_dev_scene), #pct(arm(k.dpe).peak_dev_share_card, 0) of the card. // src: v.arms.*.peak_dev_mib, peak_dev_scene, peak_dev_share_card; v.capped_small_peak_range_mib; v.card_mib

The thesis could reproduce APD-MVS @apd claims on ACMMP 3200~px memory (4.5GB), however, APD-MVS's 6.6~GB claim at native turned out 22% worse a peak at 8.5~GB. Thus the thesis could not verify their claim of consuming lower memory than ACMMP. Nonetheless, as the work explored in #ref(<sec:perf>), runtime and memory usage are highly related to implementation quality. Furthermore, increasing memory usage for PatchMatch-based MVS reconstruction pipelines is also a way to improve runtime performance (e.g., retaining more data between image passes). Therefore comparing methods on their memory usage is impractical on a global level.


HPM-MVS++ does not fit. It failed #_hp.n_failed of its #_hp.n_runs runs: every run on the #spell(_hp.failed_scenes.len()) scenes with #_hp.failed_min_images or more images, and none on the #spell(_hp.ok_scenes.len()) scenes with at most #_hp.ok_max_images. Every failure is an illegal memory access in the first scale, with #big(_hp.last_mem_range.first()) to #big(_hp.last_mem_range.last())~MiB of the device in use (#pct(_hp.last_mem_share_card.first(), 0)); its successful runs peak at up to #big(_hp.ok_peak_range.last())~MiB. Its device allocations are not checked, which would explain why exhaustion of the device memory surfaces as an illegal access and a non-zero exit instead of an out-of-memory error (indirect evidence: the memory in use at the crash and the scene sizes). // src: v.hpmpp (runs.csv: status, failure_class, crash_scale, last_device_mem_mib, n_images); unchecked cudaMalloc at HPM.cpp:699-771 (fork 3097e82), .dev/bench-results/analysis.md §1
// NOTE(author): the crash site (stderr "illegal memory access ... HPM.cu:3019", the sync after
// RandomInitialization) is in analysis.md §1, not in the CSVs; it is described, not cited by line.
#assert(_hp.ok_max_images < _hp.failed_min_images)

#bench-figure("bench-memory",
  [Peak device memory per scene (mean of the repeats of a cell) against the #big(B.card_mib)~MiB of the card. Crosses: the failed HPM-MVS++ runs, at the device memory in use when they crashed. Empty slots: the CUMVS(APD) arms of #ref(<sec:bench-cumvs-apd>).],
  [Peak device memory per scene against the card], "fig-bench-memory")

Energy follows runtime. Over the #B.n_scenes scenes the GPU uses #fix(arm(k.cumvs).energy_total_kj, 0)~kJ for CUMVS, #fix(arm(k.acmh).energy_total_kj, 0) to #fix(arm(k.hpm).energy_total_kj, 0)~kJ for the other capped methods, and #big(arm(k.apd).energy_total_kj) and #big(arm(k.dpe).energy_total_kj)~kJ for APD-MVS and DPE-MVS (#ref(<table-bench-main>)). The mean power varies far less than the runtime, from #fix(arm(B.power_min).power_w, 0)~W (#lab(B.power_min)) to #fix(arm(B.power_max).power_w, 0)~W (#lab(B.power_max)), and #lab(B.power_max) draws the most power yet uses the least energy. // src: v.arms.*.energy_total_kj, power_w (energy / wall time)
On the host, the ACM methods and MP-MVS peak at about #fix(arm(k.acmh).peak_host_gib, 0)~GiB of memory, CUMVS at #fix(arm(k.cumvs).peak_host_gib, 0)~GiB, the native arms at #fix(arm(k.apd).peak_host_gib, 0)~GiB and HPM-MVS at #fix(arm(k.hpm).peak_host_gib, 0)~GiB. // src: v.arms.*.peak_host_gib (peak_host_rss_mib)
// NOTE(author): analysis.md calls HPM-MVS's host peak "a known leak"; the cause is not printed, as
// nothing in the data shows it.
=== CUMVS(APD) in the benchmark <sec:bench-cumvs-apd>

// `top`, not `auto`: with `auto` or `bottom` this placeholder and the heading after it keep moving
// each other between pages and the layout does not converge (checked 2026-11-22).
#place(top, float: true, clearance: 22pt, [#figure(
  block(stroke: (paint: luma(60%), dash: "dashed"), inset: 12pt, width: 100%, height: 4cm)[
    #align(center + horizon)[_Figure E, pending the M8 data._ \ Per scene: run-time ratio of CUMVS(APD) @ native to APD-MVS (total ratio as a line), and the F1 difference with its 95% interval.]
  ],
  caption: flex-caption([CUMVS(APD) at native resolution against APD-MVS, per scene (pending).], [CUMVS(APD) against APD-MVS per scene]),
) <fig-bench-cumvs-apd>])

#block(stroke: 0.6pt + rgb("#CC79A7"), inset: 8pt, width: 100%, breakable: false)[
  _this subsection is written once the M8 campaign data arrives._ It reports CUMVS(APD), APD-MVS's algorithm integrated into CUMVS's production CUDA frontend and sped up in #ref(<sec:perf>), at native resolution against APD-MVS and capped at 3200~px among the capped arms.
]


== CUMVS(APD)

- Notice, that there are many more micro-optimizations that was not implemented, such as parallel filling of the plane buffer. The goal of the thesis is to remain focused on times that matter, and provide minimal changes to achieve significant results on the overall runtime. The missed optimization opportunities show that there is still room for improvements.

- Nowadays, traditional MVS algorithms are popular over learned methods due their superior accuracy stemming from strong multi-view geometry constraints. This thesis shows, that these methods can also come with promising runtime performance if small care is taken about their implementation. The modern MVS algorithms seem much slower than they are, and optimizations are targeting algorithmic behavior rather than exploring implementation options.

// put the full benchmark result tables in the appendix

/*

- APD-MVS and DPE-MVS runs and publishes results at native ETH3D resolution. This must be a significant runtime hit for some F1 score percentage points. Supporting the claim of the thesis.
- APDe-MVS carries out an ablation study for ACMM at 25% and at 100% the resolution. Did they modify the max_image_size parameter for their ACMM baseline so that the implementation actually uses the max image size? Or did they just use the implementation that auto resizes to 3200 width, \~50%? The benchmarking will show how far our ACMM runs are from their published results.
  - NO! They probably used ACMM results at 25%, and without stating runtime, they showed quality results as a comparison where they used 100% as the resolution and stated that ACMM was also using 100%. This is misleading, they didn't run ACMM on their own, they instead stated ACMM numbers from ETH3D leaderboard which doesn't state the resolution, but because their implementation caps at 3200px and their paper states 3200px resize, it must be 25% width. ACMMP paper TABLE 4 also mentions this number and several other papers use this number as a reference. But then where are the actual 25% numbers are coming from for APDe-MVS and others?
- DVP-MVS++ says "we downsample the images to half their original resolution in the ETH3D and Strecha datasets" for speed, but this is the resolution that everyone else was running on by default

- MP-MVS claims in it's paper that it is 17% faster in depth estimation than ACMMP. This seems to check out.
  - ACMH -> PatchMatch 26.2%; Fusion 41.8%; I/O 13.8%; Preprocessing 11.5%
  - ACMMP -> PatchMatch 39.4%; Fusion 20.1%; I/O 25.6%; Preprocessing 6.3%
    - --> (patch match is $381 * 39.4% = $ *150 sec*)
  - MP-MVS PatchMatch 59.6%; Fusion 16.8%; I/O 10.8%; Preprocessing 7.5%
    - --> (patch match is $307 * 59.6% = $ *182,9 sec*)

*/