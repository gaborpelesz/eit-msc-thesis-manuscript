#import "../template/elteikthesis.typ": *

#import "@preview/cetz:0.4.2"

#let lineage-figure = [#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *

    let at(i, r) = (i * 1.95 + (if i >= 7 { 0.35 } else { 0 }), r * 0.72)
    let years = (2015, 2019, 2020, 2022, 2023, 2024, 2025, 2026)

    let node(name, i, r, body, status) = {
      let (st, fl, tc) = if status == "measured" {
        (0.6pt + black, luma(222), black)
      } else if status == "excluded" {
        (0.6pt + black, white, black)
      } else if status == "pending" {
        ((paint: black, thickness: 0.8pt, dash: "dotted"), white, black)
      } else {
        ((paint: luma(100), thickness: 0.6pt, dash: "dashed"), white, luma(70))
      }
      content(at(i, r),
        text(size: 8pt, fill: tc, body),
        name: name, frame: "rect", padding: 0.08, stroke: st, fill: fl)
    }

    let edge(a, b, kind, via: ()) = {
      let st = if kind == "fork" {
        0.6pt + black
      } else if kind == "credited" {
        (paint: black, thickness: 0.6pt, dash: "dashed")
      }
      line(a, ..via, b, stroke: st,
        mark: (end: "stealth", fill: black, stroke: 0.4pt + black, scale: 0.6))
    }

    node("gip",   0,  1,    [Gipuma],    "outside")
    node("acmh",  1,  2,    [ACMH],      "measured")
    node("acmm",  1,  0,    [ACMM],      "measured")
    node("acmp",  2,  1.5,  [ACMP],      "measured")
    node("acmmp", 3,  1,    [ACMMP],     "measured")
    node("hpm",   4,  2,    [HPM-MVS],   "measured")
    node("mp",    4,  1,    [MP-MVS],    "measured")
    node("apd",   4,  0,    [APD-MVS],   "measured")
    node("tsar",  5, -2.8,  [TSAR-MVS],  "excluded")
    node("cumvs", 6,  3,    [CUMVS],     "measured")
    node("dpe",   6, -1,    [DPE-MVS],   "measured")
    node("dvp",   6, -2.0,  [DVP-MVS],   "excluded")
    node("hpmpp", 7,  2,    [HPM-MVS++], "measured")
    node("apde",  7,  0,    [APDe-MVS],  "excluded")
    node("dvppp", 7, -2.0,  [DVP-MVS++], "excluded")

    // edges
    edge("gip.east",   "acmh.west",  "credited")
    edge("acmh.south", "acmm.north", "fork")
    edge("acmh.east",  "acmp.west",  "fork")
    edge("acmp.east",  "acmmp.west", "fork")
    edge("acmm.east",  "acmmp.south", "fork")
    edge("acmmp.east", "mp.west",    "credited")
    edge("acmh.east",  "hpm.west",   "credited")
    edge("hpm.east",   "hpmpp.west", "fork")
    edge("acmm.east",  "apd.west",   "credited")
    edge("apd.east",   "apde.west",  "fork")
    edge("apd.east",   "dpe.west",   "credited")
    edge("apd.south",  "dvp.west",   "fork", via: (at(4, -2.0),))
    edge("dvp.east",   "dvppp.west", "fork")
    edge("gip.south",  "tsar.west",  "fork", via: (at(0, -2.8),))
    edge("tsar.east",  "dvp.south",  "credited")
    edge("acmh.north", "cumvs.west", "credited", via: (at(1, 3),))

    // year axis
    line(at(-0.4, -3.55), at(7.4, -3.55), stroke: 0.4pt + luma(120))
    for (i, y) in years.enumerate() {
      content(at(i, -4), text(size: 7.5pt, fill: luma(80), str(y)))
    }
  }),
  caption: [
    The lineage from Gipuma onward by year of publication. Edges: solid, code fork (shared source tree); dashed, baseline credited in a paper or their repository's README.md file; Nodes: grey, included in benchmark; white, excluded; dashed border, not in the collection.
  ],
  placement: auto,
) <fig-lineage>]

= Literature review

This chapter describes the PatchMatch lineage of MVS algorithms that followed Gipuma @gipuma, COLMAP @colmap_mvs, and ACMH @acmh_acmm. The lineage is a set of MVS algorithms that build directly on top of these foundational methods, including references to them as baselines in their paper, refining these approaches, providing ablation studies, and by descending directly from their open-source implementations.

/*
- multiple hypotheses idea was coming from #todo[cite campbell2008_multiple_hypotheses.pdf], they established a Markov-Random Field (MRF) formulation allowing for multiple depth hypotheses per point including an unknown state. This to fight Ambiguous matching along the epipolar line.
*/


== Multi-Hypothesis Joint View Selection (ACMH)

Adaptive Checkerboard Multi-Hypothesis Joint View Selection (ACMH) inherits checkerboard from Gipuma and replaces the fixed sampling with adaptive sampling. It increases the sampled neighborhood by introducing new sampling directions. To avoid significantly increasing the number of candidates it changes the sampling positions for each pixel at every iteration, according to the current costs. A hypothesis from a reliable, well-textured pixel can then spread further and faster. This matters most in low-texture regions, where the nearest neighbours often carry poor hypotheses. @acmh_acmm

ACMH integrates and improves the pixelwise view selection from @colmap_mvs using their joint view selection. Furthermore, after iterations using the photometric cost, they introduce iterations with an added geometric consistency metric in the cost function. The geometric consistency includes the estimates from neighboring depth images as priors, enforcing temporal consistency in the reference images. Their open-source implementation is being used and the foundation for multiple subsequent MVS algorithms.

ACMM introduces a multi-scale reconstruction through image pyramids. Here, the photometric and geometric iterations are first running a downsampled image and compute a low resolution depth-map. This improves hypotheses to travel large areas in early iterations and help textureless surface reconstruction. Upsampling of computed depth and normal maps between scales is being handled by Joint Bilateral Upsampling (JBU). @acmh_acmm

3D planes can regularly define textureless surfaces, especially in environments with human-made structures. Based on this assumption, ACMP's planar-prior model @acmp triangulates low-cost points of a photometric run into planes that are used as priors for subsequent iterations next to the geomtric consistency . Later, ACMMP @acmmp combines all mentioned strategies, the planar-prior model and the multi-scale reconstruction, into a single system totalling 12 passes per image.

== ACM-lineage

A large range of research has followed the introduction of the ACM-family methods. Partially because of the developing benchmarks such as ETH3D @eth3d_dataset and Tanks and Temples @tanks_and_temples_dataset, but more importantly due to their highly accessible open-source implementations. #ref(<fig-lineage>) shows the lineage of algorithms that this thesis audits. It is important to state that many other MVS algorithms exist. However, not many of these other algorithms feature open-source implementations while being top-performers on the ETH3D benchmark.

#lineage-figure

HPM-MVS @hpm builds on top of ACMH and changes where the hypotheses are coming from. It also features a hierarchical planar prior model, and runs one photometric, three planar prior and two geometric iterations totalling 6 passes / image. HPM-MVS++ @hpm_plusplus is the natural extension that adds multi-scale through an image-pyramid and adds two additional terms to the cost. The new costs are derived from a probabilistic graphical model: prior consistency and mandatory consistency. HPM-MVS++ has a total of 18 passes / image, the most among the audited algorithms.


MP-MVS @mp_mvs approaches the multi-scale from the opposite side than ACMM @acmh_acmm. Instead of resizing the images, it resizes the patch match window dynamically in a multi-scale fashion. It argues the image-pyramid rescaling and per-scale optimization increases the running cost and redundancy, while the upsampling introduces accuracy loss. MP-MVS is the only work across the lineage that directly addresses the performance problem of the lineage and improves the performance while keeping or exceeding the quality. The paper claims a 17% faster depth-map estimation than @acmmp while surpassing it in F1-score for both indoor and outdoor scenes.

APD-MVS @apd builds directly on top of ACMH. It separates reliable and unreliable pixels of a reference image, where the latter have ambigous matches and are mostly related to textureless surfaces. It introduces an adaptive patch window deformation strategy to improve the cost profile of unreliable pixels by anchoring them to reliable ones, based on the idea of deformable convolution kernels from recent learning based methods. DPE-MVS @dpe descends from APD-MVS and extends it edge map guidance for the reliable pixel search and sampling. Their dual-level precision edge maps is built from combining multiple classical approaches such as Canny edge detection, and the Roberts operator with Hough line detection @tsar. They avoid using generalized segmentation models such as SAM @kirillov2023_segment_anything, regarding their inference speed to be inadequate for an already heavy computation pipeline. On the contrary, DVP-MVS @dvp builds a similar edge-aware guidance for deformable PatchMatch but combines a monocular depth prior from Depth-Anything V2 @yang2024depth_anything_v2 with the same Roberts+Hough edge segmentation @tsar. 


== Cuda Multi-View Stereo from Fixstars

CUMVS is a production-grade reimplementation of ACMH by the Japanese company, Fixstars. The work is directly focusing on the performance improvement and real world adaptability of the PatchMatch propagation. 




/*
describes the lineage and selected methods that the thesis considers. shows and analyzes the algorithmic improvements and what added costs these have. Also analyzes the software source code a bit.

also include
- prior optimizaiton work on CUMVS -> third-party evidence that optimization headroom exists
- lineage and code sharing evidence
- maybe cost of each improvement (referring to the later benchmarking section)

watch out for this not to blow up! we have a lot of methods, and deeply analysing all of them can take a lot of time. The focus should be on the methodology and the results sections instead of this!
- consider analysing only a few key papers, and mentioning others that are less relevant
  - acm family
  - APD-MVS
  - HPM-MVS
  - (maybe MP-MVS or DPE-MVS)

prior mvs efficiency work:
- Bailer/Zheng parallel sweeps
- Gipuma Checkerboard propagation
- OpenMVS ACMH
- SURE
- CUMVS

prior algorithmic cost cutting work as optimization
- SURE (Stuttgart dense matching software built on SGM): an example from photogrammetry where efficiency engineering is what made dense matching practical
  - SURE: Photogrammetric Surface Reconstruction from Imagery", LC3D Workshop, Berlin, 2012
    - 21.1GB -> 1.3GB memory usage through optimization work
  - "SURE - The ifp Software for Dense Image Matching", Photogrammetric Week '13, 2013.
    - 36 (135 megapixels) aerial images in 4h 37min 

prior algorithmic vs implementation work:
- Leiserson 2020 (focusing on software optimizations and engineering of research). Python matrix multiply 25 552 s → 0.41 s, 62 806x from engineering alone.

prior benchmarking culture:
- "The Efficiency Misnomer" and "Green AI" show a similar trend in AI happening right now -> benchmarks and leaderboards competing only on quality disregarding cost and efficiency
- Ethayarajh & Jurafsky, "Utility is in the Eye of the User" (EMNLP 2020) saying that highly inefficient models provide less utility to practitioners but not to a leaderboard, since it is a cost that only the former must bear. Also "To allow practitioners to better estimate a model's utility to them, we advocate for more transparency on leaderboards, such as the reporting of statistics that are of practical concern (e.g., model size, energy efficiency, and inference latency)."
- Gipuma's 2015 complaint
  - "Nevertheless, guided by the quality metrics used in standard benchmarks such as KITTI and Middlebury, most authors concentrate on accuracy and pay limited attention to scalability and runtime performance. Many existing algorithms become impractical when moving to larger sets of high-resolution images."
  - This is a strong support saying that this is also what is happening in ETH3D with PatchMatch-based MVS, and efficiency and cost is not incentivized. Making these methods stand out in leaderboards but fail in real-world adaptability.
    - Should introduce KITTI and Middlebury as two-view stereo benchmark before ETH3D
    - Also Gipuma authors are included in ETH3D authors and they said that their 24MP images would encourage efficient methods, yet they rank only by F1 and stating the runtime is not crucial in submitting to them!
    The ETH3D paper says more about efficiency than we had. It has four passages:
      1. p. 1: the 24 MP images "encourage the development of memory and computationally efficient methods which can handle very large datasets."
      2. p. 1: the video scenario "rewards efficient algorithms which can handle large amounts of data."
      3. p. 7: the methods "take in the order of several minutes to an hour" on the video sequences, "underlining the need for more efficient algorithms".
      4. p. 8, Conclusion: "One of these challenges is efficient processing of large amounts of data ... These challenges are far from being solved and there is significant room for improvement."
    > In 2015, Gipuma's authors observed that benchmark metrics led authors to neglect runtime [p. 1]. Two of them co-authored ETH3D, whose paper names efficient processing of large data as an open challenge [p. 8], and the benchmark requests a runtime with every submission. It ranks by F1 alone, however, and as of 30 October 2026 the lineage's leading entries report placeholder runtimes. The challenge was posed but never scored.
*/