#import "../template/elteikthesis.typ": *
#import "figures/bench-common.typ": *
#import "figures/bench-main.typ": bench-main-table

#let B = bench
#let _f(key) = arm(key).f1_2cm
#let _t(key) = arm(key).wall_total_s
#let _sh(key, c) = arm(key).share.at(c)
#let _st = B.front_steps
#let _nb = B.native_vs_best_capped
#let O = B.ours

= Results & Discussion <ch-results>

The final benchmark evaluates the 10 selected methods and CUMVS(APD) with the protocol described in #ref(<sec:benchmark-dimensioning>). The benchmark includes all ETH3D training scenes with five repeats per method to ensure statistical significance. CUMVS(APD) was included at two resolutions, once capped at 3200px maximum image width, the setting that most methods use (_CUMVS(APD) \@ 3200px_), and once at native resolution (_CUMVS(APD) \@ native_) for comparison with its baseline, APD-MVS. During benchmarking, a total of 780 runs were carried out, of which 735 succeeded. The 45 failures are all HPM-MVS++ runs, caused by reaching the memory limit of the GPU (#ref(<sec:bench-resources>)). All per-scene values show the mean of the five repeats, unless stated otherwise. HPM-MVS++ completed only four scenes (_meadow_, _office_, _pipes_, _terrace_) and therefore it is compared on those scenes only. #ref(<table-bench-main>) collects the headline numbers of this section.

#place(auto, float: true, clearance: 22pt, bench-main-table)

== Reconstruction quality <sec:bench-quality>

#let _r = B.rank_2cm
DPE-MVS performs the best on the benchmark and it ranks first on #B.first_count.at(k.dpe) of the #B.n_scenes scenes with a mean F1-score of #fix(_f(k.dpe).mean, 3) at 2~cm. CUMVS(APD) \@ native and APD-MVS are next with #fix(_f(k.oursnat).mean, 3) and #fix(_f(k.apd).mean, 3). It is important to note that these three methods run at native resolution giving them an unfair advantage due to having access to four times as much pixel information. The best quality capped method is #lab(B.best_capped), with #fix(_f(B.best_capped).mean, 3) F1-score at 2~cm. ACMH, the initial algorithm in the lineage, is last with an F1-score of #fix(_f(k.acmh).mean, 3) (#ref(<table-bench-main>)). This is expected due to not having all the compute heavy completeness machinery that other algorithms introduced. ACMH is the best performing in accuracy, likely because it only keeps candidates that it truly trusts through strong photometric constraints, meanwhile lacking concepts like planar priors that would let it estimate points on textureless surfaces at a much lower accuracy. On the #spell(B.common_scenes.len()) scenes that HPM-MVS++ completed, its F1 of #fix(AC.at(k.hpmpp).f1_2cm.mean, 3) lies between #lab(B.hpmpp_common_above.last()) (#fix(AC.at(B.hpmpp_common_above.last()).f1_2cm.mean, 3)) and #lab(B.hpmpp_common_below_next) (#fix(AC.at(B.hpmpp_common_below_next).f1_2cm.mean, 3)). Therefore, HPM-MVS++ is likely an equivalent or better performing capped candidate than MP-MVS, had it finished all of its scenes (see the detailed results in #ref(<app-bench>)). // src: v.rank_2cm; v.arms.*.f1_2cm; v.arms_common.*.f1_2cm, v.hpmpp_common_above, v.hpmpp_common_below_next
#assert(_r.at(0) == k.dpe and _r.at(1) == k.oursnat and _r.at(2) == k.apd, message: "the order of the three native runs changed: rewrite the paragraph")

The quality improvements along the lineage come in the form of completeness (#ref(<lit:acmh>)). Over the 3200~px capped lineage methods the completeness ranges from #fix(B.lineage_comp_range.first(), 3) (ACMH) to #fix(B.lineage_comp_range.last(), 3) (MP-MVS), while accuracy stays between #fix(B.lineage_acc_range.first(), 3) and #fix(B.lineage_acc_range.last(), 3). The native runs trade accuracy for completeness, the accuracy of APD-MVS (#fix(arm(k.apd).acc_2cm.mean, 3)), and DPE-MVS (#fix(arm(k.dpe).acc_2cm.mean, 3)) is below that of every capped lineage method with a #(B.n_scenes)-scene value, and their completeness, #fix(arm(k.apd).comp_2cm.mean, 3), #fix(arm(k.dpe).comp_2cm.mean, 3) and #fix(arm(k.oursnat).comp_2cm.mean, 3), is the highest. Through CUMVS(APD) \@ 3200, the benchmark can observe the performance of APD-MVS's algorithm capped and compare it directly to other methods. At capped image width, it reaches a mean F1-score of #fix(_f(k.ours3200).mean, 3), #fix(-O.c3200_d_f1_on_pp.at("2cm"), 1)~pp below its native run and #ordinal(O.c3200_rank_capped) among the #spell(O.c3200_n_capped) capped methods. The accuracy and completeness of CUMVS(APD) \@ 3200 compared to its native run verify that accuracy is being traded for completeness at least with default settings. This gap was measured for one algorithm only, on one such setting, and it may not carry over to the other methods of the lineage. If it does, part of the difference between the methods evaluated at native resolution @apd @dpe and those capped at 3200~px comes from the input size and not from the algorithm itself. Reporting the input resolution with the results, and comparing methods at the same resolution where possible, would separate the two effects.
// src: v.ours.c3200_d_f1_on_pp, c3200_rank_capped, c3200_n_capped
#assert(O.c3200_d_f1_on_pp.at("2cm") < 0)
/*
it wasn't proven, but more accurate anchor points lead to more accurate plain fitting over textureless planar surfaces. This can improve the overall accuracy significantly, while
*/


CUMVS(APD) \@ native  F1-score closely matches APD-MVS. Its mean F1 at 2~cm, #fix(_f(k.oursnat).mean, 3), is #sci(O.d_f1_13.at("2cm"), 2)~pp above that of APD-MVS, the difference being in completeness (#signed(O.d_comp_13_pp, 2)~pp). Per scene (#ref(<fig-bench-cumvs-apd>)b), F1 at 2~cm is higher on #spell(O.d_f1_pos.len()) scenes, by at most #fix(O.d_f1_max, 2)~pp on #scene(O.d_f1_max_scene), and lower on none. On the other #spell(O.d_f1_zero.len()) the interval contains zero, and no interval reaches beyond #sym.plus.minus#fix(O.d_f1_absmax_ci, 2)~pp. // src: v.ours.d_f1_13 (Welch interval of the difference of the 13-scene means over the repeats), d_comp_13_pp, d_acc_13_pp; v.ours.scene.*.d_f1_2cm (Welch, per cell), d_f1_pos, d_f1_neg, d_f1_zero, d_f1_absmax_ci
#assert(O.d_f1_neg.len() == 0 and O.d_f1_13.at("2cm").lo > 0 and O.d_f1_13.at("1cm").lo > 0 and ("5cm", "10cm", "20cm").all(t => O.d_f1_13.at(t).lo < 0 and O.d_f1_13.at(t).hi > 0), message: "the F1 comparison with APD-MVS changed: rewrite the paragraph")

#assert(B.native_acc_below_lineage and B.native_comp_top)

#bench-figure("bench-scenes",
  [F1 at 2~cm per scene and method, mean of #spell(B.n_rep) repeats; the best method of each scene in bold. Scenes from the lowest mean F1 over the methods (top) to the highest, with their number of images. Hatched: no successful run (HPM-MVS++, #ref(<sec:bench-resources>)).],
  [F1 at 2 cm per scene and method], "fig-bench-scenes")

== Runtime and the quality-time trade-off <sec:bench-time>

Runtime spans almost two orders of magnitude (#ref(<table-bench-main>)) due to the different resolution caps. The capped methods take #big(B.capped_total_range_s.first())~s (#lab(B.capped_fastest)) to #big(B.capped_total_range_s.last())~s (#lab(B.capped_slowest)), while at native resolution CUMVS(APD) takes #big(_t(k.oursnat).mean)~s (#hours(_t(k.oursnat).mean, 1)), APD-MVS #big(_t(k.apd).mean)~s (#hours(_t(k.apd).mean, 1)) and DPE-MVS #big(_t(k.dpe).mean)~s (#hours(_t(k.dpe).mean, 1)) to complete all scenes. The native resolution is the choice of the APD-MVS and DPE-MVS authors, with completeness improvements at a significantly higher compute cost. For APD-MVS's algorithm the benchmark measures this trade directly: CUMVS(APD) \@ 3200 is more than four times faster than CUMVS(APD) \@ native and loses #fix(-O.c3200_d_f1_on_pp.at("2cm"), 1) percentage points of F1-score at 2~cm. // src: v.ours.c3200_x_on, c3200_d_f1_on_pp

There is a strong correlation (0.96-0.98) between the number of images per method and their per-scene runtimes. The slope is #fix(arm(k.cumvs).s_per_image, 1)~s per image for CUMVS, #fix(arm(k.acmh).s_per_image, 1)~s for ACMH, #fix(arm(k.mp).s_per_image, 1)~s for MP-MVS, #fix(arm(k.oursnat).s_per_image, 0)~s for CUMVS(APD) \@ native, #fix(arm(k.apd).s_per_image, 0)~s for APD-MVS and #fix(arm(k.dpe).s_per_image, 0)~s for DPE-MVS. The most expensive scene of every method is _facade_, with #B.n_images.facade images (#ref(<table-bench-scene-time>)). // src: v.lin_r_range, v.arms.*.s_per_image (linear fit of cell means on n_images), v.facade_slowest_all
The format converters (which the runtime excludes) add #fix(B.convert_python_range_s.first(), 0)-#fix(arm(k.apd).convert_total_s, 0)~s over the #B.n_scenes scenes to each method with the default Python converter, and only #fix(arm(k.cumvs).convert_total_s, 1)-#fix(arm(k.oursnat).convert_total_s, 1)~s to CUMVS and CUMVS(APD) run, which uses CUMVS's converter (#ref(<sec:bench-converter>)).
#assert(B.facade_slowest_all)
#assert(B.power_max == B.energy_min and arm(k.acmm).input_load_s > 3 * _t(k.cumvs).mean, message: "premise of the energy or input-loading sentence changed")

Cost does not grow monotonically with quality. MP-MVS is faster and reconstructs better according to the benchmark than ACMM, ACMMP, and HPM-MVS. MP-MVS takes #pct(1 - _t(k.mp).mean / _t(k.acmmp).mean, 0) less time than ACMMP, which confirms the stated speedup @mp_mvs. The CUMVS reimplementation of ACMM is #times(arm(k.acmh).x_cumvs, 1) faster than ACMH and #times(arm(k.acmm).x_cumvs, 1) faster than ACMM, with a higher F1 than both. The results reproduce the CUMVS claims exactly @fixstars2025cumvs#footnote[If CUMVS's hardware claims are also correct, a further observation is that the NVIDIA 5070 GPU performs an overall 34% better than the NVIDIA 3080 GPU.].

#bench-figure("bench-tradeoff",
  [Mean F1 at 2~cm against the total runtime over the #B.n_scenes scenes (log scale), with #B.ci_level_pct% intervals (smaller than the markers). Filled markers lie on the Pareto front. HPM-MVS++ is not shown.],
  [Quality against runtime], "fig-bench-tradeoff")

#ref(<fig-bench-tradeoff>) puts quality against runtime. At 2~cm the Pareto front is #B.front.map(lab).join[ #sym.arrow.r ] (same at 1~cm, #ref(<table-bench-scene-quality-1cm>)). Its steps are #signed(_st.at(0).d_f1_pp, 1)~pp for #times(_st.at(0).x_time, 1) the time from #lab(_st.at(0).a) to #lab(_st.at(0).b), #signed(_st.at(1).d_f1_pp, 2)~pp for #times(_st.at(1).x_time, 1) to #lab(_st.at(1).b), and #signed(_st.at(2).d_f1_pp, 2)~pp for #times(_st.at(2).x_time, 1) to #lab(_st.at(2).b). // src: v.front, v.front_by_tol, v.front_steps
CUMVS(APD) \@ native takes the place of APD-MVS on the front: it reconstructs as well in #pct(O.time_share, 0) of the time. #lab(k.cumvs) dominates #labs(B.dominated_by.keys().filter(a => B.dominated_by.at(a).contains(k.cumvs))), and #lab(k.mp) dominates #labs(B.dominated_by.keys().filter(a => B.dominated_by.at(a).contains(k.mp))). At coarser tolerances the front changes. From 5~cm on, the F1 of CUMVS(APD) \@ 3200 is above that of MP-MVS and the method joins the front; at 5 and 10~cm, where CUMVS(APD) \@ native and APD-MVS are not resolved, APD-MVS is on it as well; at 20~cm, CUMVS(APD) \@ 3200 reconstructs better than both, and only DPE-MVS is above it. On its #spell(B.common_scenes.len()) scenes, HPM-MVS++ joins the 2~cm front between #lab(B.hpmpp_front_between.first()) and #lab(B.hpmpp_front_between.last()). // src: v.front_by_tol, v.ours.c3200_on_front_tols, v.ours.apd_on_front_tols, v.ours.d_f1_13 (5-20 cm intervals contain 0), v.ours.c3200_d_f1_mp_pp, v.ours.c3200_d_f1_on_pp; v.front_common, v.hpmpp_front_between
#assert(B.front_by_tol.at("1cm") == B.front and B.front.len() == 4 and B.front.contains(k.oursnat) and B.dominated_by.at(k.apd) == (k.oursnat,) and B.front_common.contains(k.hpmpp), message: "the 2 cm front changed: rewrite the paragraph")
#assert(O.c3200_on_front_tols == ("5cm", "10cm", "20cm") and O.apd_on_front_tols == ("5cm", "10cm") and not B.front_by_tol.at("20cm").contains(k.oursnat) and B.front_by_tol.at("20cm").contains(k.dpe), message: "the front at coarse tolerances changed")
Two of the four points of the 2~cm front are production implementations, CUMVS at the fast end and CUMVS(APD) \@ native. Between them, the front is set by an implementation that is faster than the methods it dominates.

#let _s = B.s43
#let _x = O.s43_vs_bench
#let _sc(s) = O.scene.at(s)
#let _cs = O.class_s
The benchmark measures CUMVS(APD) against the original APD-MVS. CUMVS(APD) @ native achieves #times(O.speedup.mean, 2) over the #B.n_scenes scenes, #times(_x.pipes_bench_x, 2) on _pipes_ and #times(_x.office_bench_x, 2) on _office_. The results confirm the speedup of #ref(<sec:methodology-cumvs-apd-perf>): the halving found on two scenes holds on all #B.n_scenes.
CUMVS(APD) \@ native takes #big(_t(k.oursnat).mean)~s for the #B.n_scenes scenes, against #big(_t(k.apd).mean)~s for APD-MVS. Of the #big(O.saved_s)~s saved over the #B.n_scenes scenes, #pct(O.class_saved_share.patchmatch, 0) is in PatchMatch, which takes #big(_cs.at(k.oursnat).patchmatch)~s against #big(_cs.at(k.apd).patchmatch)~s, #times(O.class_x.patchmatch, 2) less. #pct(O.class_saved_share.input_load, 0) in input loading, which takes #big(_cs.at(k.oursnat).input_load)~s against #big(_cs.at(k.apd).input_load)~s (#ref(<sec:perf-input>), #ref(<sec:apd-cumvs-inmemory>)). Fusion, outside the scope of #ref(<sec:methodology-cumvs-apd-perf>), takes about the same time in both, #big(_cs.at(k.oursnat).fusion) and #big(_cs.at(k.apd).fusion)~s, and is now #pct(_sh(k.oursnat, "fusion"), 0) of the runtime of CUMVS(APD) \@ native. The converter adds #fix(O.convert_s.first(), 0)~s to CUMVS(APD) and #fix(O.convert_s.last(), 0)~s to APD-MVS. // src: v.ours.saved_s, class_saved_share, class_s (share x mean total, phase-categories.csv), class_x; v.ours.convert_s
#assert(calc.abs(O.class_x.fusion - 1) < 0.02 and O.class_saved_share.patchmatch + O.class_saved_share.input_load > 0.9)



== Runtime breakdown <sec:bench-phases>

The phase timers of #ref(<table-timing-measurements>) split each method's runtime into the classes of #ref(<fig-bench-phases>)a. The methods fall into two groups. The four ACM methods are host-bound: the GPU is idle for #pct(B.acm4_idle_range.first(), 0) to #pct(B.acm4_idle_range.last(), 0) of their runtime, and input loading alone takes #pct(B.acm4_input_range.first(), 0) to #pct(B.acm4_input_range.last(), 0), the largest share of all phases for ACMM (#pct(_sh(k.acmm, "input_load"), 0)) and ACMMP (#pct(_sh(k.acmmp, "input_load"), 0)). ACMM loads every image #B.acmm_loads_per_image times, so a run on _pipes_ with its #B.n_images.pipes images has #B.acmm_pipes_input_load_spans input-loading spans; over the #B.n_scenes scenes, its input loading takes #big(arm(k.acmm).input_load_s)~s, more than three times the whole runtime of CUMVS (#big(_t(k.cumvs).mean)~s). // src: v.acm4_idle_range, v.acm4_input_range, v.arms.*.share.input_load (phase-categories.csv, self_s / wall); v.acmm_loads_per_image, v.acmm_pipes_input_load_spans (phases.csv input_load count / n_images)
MP-MVS and HPM-MVS seemingly keep the GPU busier but their time spent on input loading relative to the number of per image passes is equivalent to that of ACMP, ACMM, or ACMMP. This is due to the shared lineage code, handling inputs the same way. APD-MVS and DPE-MVS are GPU-bound: PatchMatch takes #pct(_sh(k.apd, "patchmatch"), 1) and #pct(_sh(k.dpe, "patchmatch"), 1) of their runtime and the GPU is idle for #pct(arm(k.apd).gpu_idle_share, 1) and #pct(arm(k.dpe).gpu_idle_share, 1). So are the two CUMVS(APD) runs, with PatchMatch at #pct(_sh(k.ours3200, "patchmatch"), 0) and #pct(_sh(k.oursnat, "patchmatch"), 0) and the GPU idle for #pct(arm(k.ours3200).gpu_idle_share, 1) and #pct(arm(k.oursnat).gpu_idle_share, 1) of the runtime. CUMVS spends #pct(_sh(k.cumvs, "input_load"), 1) of its runtime on input loading, which is the clearest evidence that this host share is implementation, and #pct(_sh(k.cumvs, "write"), 1) on writing the point cloud, with #pct(arm(k.cumvs).gpu_idle_share, 0) GPU idle. The same shows in the one algorithm that was measured in two implementations: input loading takes #pct(_sh(k.apd, "input_load"), 1) of the runtime of APD-MVS and #pct(_sh(k.oursnat, "input_load"), 1) of that of CUMVS(APD) \@ native. #ref(<table-bench-phase-seconds>) gives the phase classes in seconds, and #ref(<table-bench-acmm-cumvs>) compares ACMM with CUMVS class by class.
Fusion is the other large phase of the ACM methods: it takes #pct(_sh(k.acmh, "fusion"), 0) of the runtime of ACMH, its largest phase, and #pct(_sh(k.acmp, "fusion"), 0) of ACMP. 

#bench-figure("bench-phases",
  [Runtime breakdown, (a) with each method's runtime split into classes of the phases of #ref(<table-timing-measurements>) (summed over the scenes). The tick marks the share of the runtime in which the GPU was idle. (b) GPU-idle share against the share of the runtime outside PatchMatch.],
  [Where the runtime goes, per method], "fig-bench-phases")


Host-boundedness is measured twice, by the driver's utilization counter and by the phase timers (#ref(<fig-bench-phases>)b). Over the #B.idle_vs_outside_n methods that completed all scenes, the GPU-idle share and the share of runtime outside the PatchMatch phase correlate at $r = #fix(B.idle_vs_outside_r, 2)$ (input loading alone at $r = #fix(B.idle_vs_input_r, 2)$). The time an ACM method spends outside PatchMatch is largely time in which the GPU waits for the host. // src: v.idle_vs_outside_r, v.idle_vs_outside_n, v.idle_vs_input_r
The host share is similar across the four ACM methods and smaller in MP-MVS and HPM-MVS. // src: v.acm4_idle_range, v.arms.mp/hpm.gpu_idle_share
#ref(<sec:methodology-cumvs-apd-perf>) recovered a large part of the host cost on the same lineage. On CUMVS(APD), the improvements reduced the host-side time on _pipes_ from #fix(B.s43.host_base_s, 1)~s to #fix(B.s43.host_stack_s, 1)~s, and the kernel time by #pct(B.s43.kernel_saved_share, 0), without significant algorithmic changes (analysis runs on unlocked clocks, against the fixed base of #ref(<sec:perf-base>)). Because the ACM methods share this lineage and spend a larger share of their time on the host, the same improvements are expected to have similar effects.


== Memory <sec:bench-resources>

#let _hp = B.hpmpp
#assert(arm(k.acmmp).peak_dev_scene == arm(k.acmm).peak_dev_scene and arm(k.ours3200).peak_dev_scene == arm(k.acmm).peak_dev_scene and arm(k.oursnat).peak_dev_scene == arm(k.dpe).peak_dev_scene)
The capped methods other than HPM-MVS++ need less than half of the #gib(B.card_mib)~GiB card (#ref(<fig-bench-memory>)). CUMVS peaks at #gib(arm(k.cumvs).peak_dev_mib)~GiB, #labs(B.capped_small) at #gib(B.capped_small_peak_range_mib.first()) to #gib(B.capped_small_peak_range_mib.last())~GiB, and ACMM, ACMMP and CUMVS(APD) \@ 3200 at #gib(arm(k.acmm).peak_dev_mib), #gib(arm(k.acmmp).peak_dev_mib) and #gib(arm(k.ours3200).peak_dev_mib)~GiB, all three on #scene(arm(k.acmm).peak_dev_scene). At native resolution APD-MVS peaks at #gib(arm(k.apd).peak_dev_mib)~GiB, and DPE-MVS and CUMVS(APD) \@ native on #scene(arm(k.dpe).peak_dev_scene) at #gib(arm(k.dpe).peak_dev_mib) and #gib(arm(k.oursnat).peak_dev_mib)~GiB, #pct(arm(k.dpe).peak_dev_share_card, 0) and #pct(arm(k.oursnat).peak_dev_share_card, 0) of the card (#ref(<fig-bench-memory>)). // src: v.arms.*.peak_dev_mib, peak_dev_scene, peak_dev_share_card; v.capped_small_peak_range_mib; v.card_mib

The thesis could reproduce the APD-MVS @apd claims on ACMMP 3200~px memory (4.5GB), however, APD-MVS's 6.6~GB claim at native turned out 22% worse, with a peak at 8.5~GB. Thus the thesis could not verify their claim of consuming less memory than ACMMP. Nonetheless, as the work explored in #ref(<sec:methodology-cumvs-apd-perf>), runtime and memory usage are highly related to implementation quality. Furthermore, increasing memory usage for PatchMatch-based MVS reconstruction pipelines is also a way to improve runtime performance (e.g., retaining more data between image passes). Therefore comparing methods on their memory usage is impractical on a global level.


HPM-MVS++ failed #_hp.n_failed of its #_hp.n_runs runs on the #spell(_hp.failed_scenes.len()) scenes with #_hp.failed_min_images or more images. Every failure is an illegal memory access in the first scale, with #gib(_hp.last_mem_range.first()) to #gib(_hp.last_mem_range.last())~GiB of the device in use (#pct(_hp.last_mem_share_card.first(), 0)). Its successful runs peak at up to #gib(_hp.ok_peak_range.last())~GiB. 

#bench-figure("bench-memory",
  [Peak device memory per scene (mean of the repeats of a cell) against the #gib(B.card_mib)~GiB of the card. Crosses: the failed HPM-MVS++ runs, at the device memory in use when they crashed.],
  [Peak device memory per scene against the card], "fig-bench-memory")

On the host, the ACM methods and MP-MVS peak at about #fix(arm(k.acmh).peak_host_gib, 0)~GiB of memory, CUMVS at #fix(arm(k.cumvs).peak_host_gib, 0)~GiB, APD-MVS and DPE-MVS at #fix(arm(k.apd).peak_host_gib, 0)~GiB and HPM-MVS at #fix(arm(k.hpm).peak_host_gib, 0)~GiB. CUMVS(APD) peaks at #fix(arm(k.ours3200).peak_host_gib, 0)~GiB at 3200~px and #fix(arm(k.oursnat).peak_host_gib, 0)~GiB at native resolution, as it keeps the maps of every image in host memory (#ref(<sec:apd-cumvs-inmemory>)). // src: v.arms.*.peak_host_gib (peak_host_rss_mib)

The speedup of CUMVS(APD) costs device memory on some scenes and saves it on others. CUMVS(APD) \@ native peaks higher than APD-MVS on #spell(O.mem_higher.len()) scenes and lower on the others. It peaks #gib(arm(k.oursnat).peak_dev_mib)~GiB on #scene(arm(k.oursnat).peak_dev_scene) against #gib(arm(k.apd).peak_dev_mib)~GiB for APD-MVS. By design, CUMVS(APD) keeps the device copies of the views between passes and frees the least recently used ones only when a pass needs the room, so it trades free device memory for fewer uploads.

/*
== CUMVS(APD)

- Notice, that there are many more micro-optimizations that was not implemented, such as parallel filling of the plane buffer. The goal of the thesis is to remain focused on times that matter, and provide minimal changes to achieve significant results on the overall runtime. The missed optimization opportunities show that there is still room for improvements.

- Nowadays, traditional MVS algorithms are popular over learned methods due their superior accuracy stemming from strong multi-view geometry constraints. This thesis shows, that these methods can also come with promising runtime performance if small care is taken about their implementation. The modern MVS algorithms seem much slower than they are, and optimizations are targeting algorithmic behavior rather than exploring implementation options.
*/

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