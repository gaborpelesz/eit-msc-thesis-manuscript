// MSc thesis — entry point (ported from the former LaTeX my_thesis.tex).
// Build: `make build` (Typst 0.15.1) -> build/thesis.pdf

// official ELTE IK thesis template ported from LaTeX to Typst
// https://github.com/mcserep/elteikthesis
#import "template/elteikthesis.typ": *

#show: elteikthesis.with(
  // class options as ported from the original repo (see the parameters of `elteikthesis`):
  parspace: true,  // adds vertical space between paragraphs
  noindent: true,  // no indentation of first lines in each paragraph, use with parspace
  // nohyp: true,     // no hyphenation of words, probably never use
  // twoside: true,   // double sided format
  // draft: true,     // quicker draft compilation without rendering images, this doesn't matter in Typst as it is already fast
  // final: true,     // set final to hide todos
  revision: sys.inputs.at("rev", default: none), // build stamp, passed by the Makefile and CI

  // Document's metadata
  title: [High-Performance Patch-Match \ Multi-View Stereo: Separating Algorithmic Cost from Implementation Overhead],
  year: [2026], // year of defense

  // Author's metadata
  author: [Gabor Pelesz],
  degree: [Autonomous Systems MSc],

  // Supervisor(s)' metadata
  supervisor: [Adam Istvan Szucs], // internal supervisor's name
  affiliation: [[SUPERVISOR AFFILIATION]], // internal supervisor's affiliation
  // ext-supervisor: [[EXTERNAL SUPERVISOR NAME]], // external supervisor's name
  // ext-affiliation: [[EXTERNAL SUPERVISOR AFFILIATION]], // external supervisor's affiliation

  // University's metadata
  university: [Eötvös Loránd University],
  faculty: [Faculty of Informatics],
  city: [Budapest],
  logo: image("images/elte_cimer_szines.pdf"),

  lang: "en",

  // Topic declaration page (mandatory) - can also be attached instead
  // declaration: include-pdf(read("topicdeclaration.pdf", encoding: none)),
)

// List of todos (not in the final document)
// #list-of-todos()

// Main content

= Introduction

3D reconstruction and perception is a foundational problem in computer vision driving multiple industries and problem spaces such as robotics, manufacturing, healthcare, automotive, logistics and warehousing, agriculture, and more recently construction, surveying, and geomatics #todo[fields need citations]. In the recent years, photogrammetry (image-based 3D reconstruction and measurements) has been gaining interest #todo[citation]. Regular colored images contain vast amount of information, are very accessible and cheap, easy to understand by humans.
- photogrammetry, image-based 3d reconstruction, is very popular and hot topic

// keep this one sentence
- Multi-View Stereo (MVS) produces highly accurate and dense point clouds

// make this more concrete: pixels * views * taps * iterations; cite ETH3D 24 MP images
- the problem of MVS is the amount of data it has to process

// this is the best sentence in the sketch; faster algos directly lead to better quality -> they can use higher resolution / or more sophisticated methods in the optimization
- this is a problem in highly accurate and/or large-scale 3D reconstruction (with faster algorithms, 3D models could become higher quality because the reconstruction could use higher resolution images or more sophisticated algorithms to improve point accuracy)

// The paper says its 24 MP images “encourage the development of memory and computationally efficient methods which can handle very large datasets.” The benchmark’s own authors expected efficiency to be rewarded.
- Another important event was that Schöps et al., CVPR 2017 introduced ETH3D dataset which created an easy way to measure algorithmic performance and with it, and with this dataset, dozens of algorithms were released with papers competing with each other on the benchmarks.

/*
needs evidence in literature review but this is a strong point
“Benchmarks don't measure efficiency”: the accurate version is a better argument
ETH3D collects runtime (“mandatory information for each submission”) but ranks by F1 alone. Runtimes are self-reported without hardware. About 170 of 630 rows show ≥ 999 999 s placeholders. ACMMP, APD-MVS, APDe-MVS, HPM-MVS, HPM-MVS++, MP-MVS and DPE-MVS all list 10⁷ s. The counts are approximate, from a snapshot taken 30 Oct 2026; archive it.
Efficiency is requested but not scored.
Gipuma said the same of KITTI and Middlebury in 2015. Middlebury v3 and KITTI show size-normalised runtimes but still rank by error.

(i) Archiving and citing the leaderboard
- Public archive: submit both the default view and the runtime view (?metric=time) to the Wayback Machine and archive.today. Then open each snapshot and check the numbers actually appear, because the table may be filled in by JavaScript and come out empty.
- Private copy: save the page as HTML and as a full-page PDF, record a SHA-256 hash of each, and keep them in the vault, not the superproject that's going public.
- The count: "~170 of 630 rows" is an agent's approximate count. Under your rule that manuscript numbers come from scripts, add a small parser that reads the archived HTML and outputs the counts and the lineage methods' runtimes. The ledger claim then cites that query.
- Citation: cite the ETH3D paper for what the benchmark intends, and add a @misc entry for the leaderboard with url, urldate = 2026-10-30 and the archive URL in note. The follow-up file has the BibTeX. In the text, put the date on the observation: "As of 30 October 2026, the ETH3D leaderboard lists 10⁷ s for ...".
*/
- The benchmarks doesn't measure and score algorithmic or implementation efficiency, ACM-family was built on Gipuma, then the contenders started to tweaking the original ACM algorithms further and further with introducing more and more constraints into the algorithm such as multiple-scales (adding more iterations), geometric consistency (adding another geometric consistency propagation after the photometric consistency), planar priors (stricter loss function), confidence sweeps (new postprocessing), DL priors (additional deep learning pre-processing), leading to higher quality in the benchmarks but also making them infeasible in production-grade large-scale photogrammetry problems due to increased runtime. Today's top 10 ETH3D are all PatchMatch hybrids led by DVP-MVS++ at 90.23 2cm f1 score.


- The thesis claims that many of the algorithms slowness comes from implementation inefficiency inherited from the lineage of the developing algorithm family.

----------------------------------------

problem formulation, claims, RQs, contributions from thesis itself and how the thesis is structured

(budget 4 pages)

==== RQ1
To what extent is the cost growth across successive patch-match MVS algorithms attributable to genuine algorithmic complexity versus inherited implementation inefficiency?

==== RQ2
Which implementation-level factors (memory access patterns, GPU occupancy, redundant computation, data layout, host-device transfers) contribute most to the performance gap in existing reference implementations?

==== RQ3
Can a systematically engineered, production-grade reimplementation of a recent state-of-the-art method recover a substantial fraction of the runtime and memory cost while preserving its benchmark accuracy?

==== RQ4
What software engineering and performance optimization practices should the MVS research community adopt to prevent the continued accumulation of avoidable overhead in future methods?
//  this is answerable from the paper-versus-release findings plus the literature above. Its tone is brief item 15.


= Background

// | Background (MVS, PatchMatch, GPU model, ETH3D metrics) | 7 |

/*
short 3D reconstruction and Dense MVS intro, contains the formulation of patch match algorithm and focuses on early patch match implementaion. Also intros the general structure of MVS programs and ETH3D as a benchmarking target.

make sure we include enough GPU and performance optimization background to cover methodology and results sections. Especially considering the deep analysis.

(budget 7 pages)
*/

== Image-based 3D reconstruction

The goal of 3D reconstruction is to recover a representation of the 3D shape of objects or scenes. Active sensing approaches such as structured light, time-of-flight sensors, or LiDAR can directly give range measurements for immediate surface information. This thesis concentrates on the passive approach where 3D is derived from images captured by ordinary cameras.

An image-based stereo reconstruction relies on the parallax effect between images from different viewpoints. Given the camera's internal parameters (intrinsic parameters) and its position and orientation (extrinsic parameters) for the viewpoints, a 3D point can be recovered if its 2D projection (a pixel) is known in at least two viewpoints. Structure from Motion (SfM) is one of the fundamental problems in image-based 3D reconstruction. Its goal is to define an optimization problem to find out the camera's intrinsic calibration matrix and to find the camera extrinsics where the images were taken from. SfM methods work by finding many reliable distinct features across images, matching the corresponding features across images, constructing 2D tracks from the matches, solving for the SfM model from the 2D tracks, and finally, refining the model using bundle adjustment #[cite FH15]. Given an initial state for the camera parameters, the optimization can iteratively project the 3D point candidates (calculated from the point correspondences) onto the images, and calculate the error between the point's projected and observed pixel location (reprojection error) @hartley_zisserman_mvg. Nowadays, a widely used open-source tool for SfM and a general 3D reconstruction pipeline is COLMAP @colmap_sfm. A reliable and accurate SfM reconstruction is key for obtaining an accurate dense 3D representation, often requiring sub-pixel level reprojection errors @furukawa2015_mvs_tutorial. SfM pipelines also produce a set of reliable 3D points that is key in dense reconstruction initialization.

In order to obtain a dense representation of the 3D scene an algorithm has to search through all pixels between views for correspondences and return the mathcing pixels. Given known camera intrinsics and extrinsics, two-views are enough for reconstruction @scharstein2002_taxonomy @tosi2025_deep_stereo_survey. In a two- or multiple-view stereo setup matches are found with the help of epipolar geometry @hartley_zisserman_mvg. The image of a point on one image is constrained to lie on a line (the epipolar line) on another image which significantly reduces the search space. The general stereo correspondence problem can then be defined as: for each pixel $p_i$ in a reference image $I_r$, find its correspondence on the epipolar line in another image $I_j$ that minimizes the cost.

== Multi-view approaches

/*
key questions to answer:
- dense MVS has several family of methods: why depth-map is the choice for large high-resolution scenes?
- why Patch-Match avoids the problems of plane sweeping and cost volumes?
- the stages of a typical depth-map MVS program

- taxonomy and MVS method classification
  - voxel / surface evolution
  - feature growing
  - depth map merging (scalable approach for large scenes)
- plane sweep and cost volumes
- learned MVS
- depth map MVS program structure
  - view selection -> depth+normal estimation -> postprocessing/filtering -> fusion -> point cloud
*/

_Multi-View Stereo_ (MVS) is the extension to more than two images and the focus of this thesis. The input of MVS algorithms is a set of images and their corresponding camera parameters. High quality inputs are essential as any errors in earlier stages such as SfM directly bound the achievable quality in MVS @furukawa2015_mvs_tutorial. However, using multiple images has many advantages such as
- several baselines reduce the matching ambiguity leading to more precise reconstruction @okutomi1993_multibaseline
- a point occluded in one view can potentially be matched in others @furukawa2015_mvs_tutorial
- frontal views of surfaces often lead to better results. #todo[no citation here, maybe replace, or cite]

The thesis differentiates between two fundamentally different problems when it comes to MVS:
- small-scene or object centric reconstruction, e.g., typically indoor scanning, or object scanning.
- large-scene reconstruction,

The former typically considers relatively small-scale indoor scanning, such as rooms, or scanning objects, usually in more controlled environments. Accurate large-scale unstructured outdoor scene reconstructions pose several challenges over these typical cases. One of these challenges is that objects are typically far away from the imaging device, requiring high-resolution images to be used in MVS. Another challenge is that in many cases, due to the size of the imaged objects compared to the distance from them being imaged, a large number of images are required to cover the scene.

Several taxonomies exist to classify the different approaches of MVS @seitz2006_mvs_evaluation @gipuma. There are two major scene representations: points and surfaces. Voxel-based reconstructions discretise the scene into a voxel grid volume @steinbrucker2014_volumetric_mapping and optionally fit meshes to extract surfaces @seitz1999_voxel_coloring. Their accuracy is bounded by voxel grid's resolution. Large-scale high-resolution reconstruction is difficult due to the cubic memory growth in the grid resolution  @shen2013_patchmatch @furukawa2015_mvs_tutorial. Surface evolution methods start from an initial geometric estimate of the imaged 3D object and iteratively deform the representation (such as a mesh, or a visual hull) to maximize photometric-consistency @zaharescu2007_transformesh @furukawa2006_carved_visual_hulls @hernandez2004_silhouette_stereo_fusion. These methods require good initialization for the surfaces which doesn't scale well for larger scenes. Implicit geometry representations, such as level-sets, iteratively evolve a volumetric surface function until it's projection minimizes photometric error and added geometric constraints (smooth curves). More modern approaches use learned Signed Distance Functions for an implicit representation @park2019_deepsdf. Depth map-based methods go through all images and compute a depth map for each of them individually. These depth maps are then fused together into a 3D point cloud eventually yielding a point representation. The images are independent from each other thus the work can be parallelized without the need for updating a global volume. This formulation scales to a very large number of images and therefore became one of the most dominant choices when it comes to large-scale scenes @furukawa2015_mvs_tutorial. #todo[also include the modern Gaussian Splatting based mesh reconstruction, which scene representation would it be? How about the Nerfs?].

Local matching methods define a cost to compare candidate correspondences using a photometric error that then can be minimized across the epipolar line. This photo-consistency is measuring how similar are two pixels given their surrounding area. However, in many cases the global minimum doesn't yield the true corresponding pixel. Global matching methods extend the cost function to include an objective for all pixels. They enforce properties like smoothness between neighboring pixels based on the assumption that in general surfaces are piecewise smooth. While global matching works well in a two-view case @scharstein2002_taxonomy, these methods don't scale well to multiple images due to their computational cost and high memory demands in large number of high-resolution images @furukawa2010_cmvs @gipuma.

Classical stereo matching algorithms perform the following steps: matching cost computation, cost aggregation, disparity computation/optimization, and disparity refinement #todo[is this also true for 3D?]. Matching algorithms need to aggregate many candidate hypotheses across the epipolar line. To estimate a depth map, every depth hypothesis needs to be tested for every pixel. The cost computation calculates a cost for all hypotheses O(W*H*D) and stores them in a cost volume. In this case the depth-range on which the cost is computed is bounded. The cost volume quickly grows by introducing higher resolution images, or by requiring higher precision depth estimates at a larger range.

Computing the cost volume is regularly done by plane sweeping @yang2003_realtime_stereo_gpu @collins1996_space_sweep. In its simplest form a plane parallel to the reference image plane, sweeps through the depth range. At each step all neighbor images are projected onto this plane and the pixel similarities are calculated using some cost function such as averaging Sum-of-Squared Differences (SSD). In the winner-takes-all approach the cost volume is not aggregated and stored but each pixel is updated to carry the currently lowest cost found. Note that plane sweeping carries a fronto-parallel bias, i.e., the search window has an implicit assumption that the corresponding surface is flat and parallel to the reference image plane @gipuma. To improve reconstruction of slanted surfaces @gallup2007_plane_sweeping adds several sweep directions. 

The same problem arises in modern learned MVS approaches, where the cost volume is calculated by a neural network using learned features and regularisation. Methods such as @yao2019_rmvsnet @gu2020_casmvsnet can still only compute the depth at a much lower resolution or over a low precision depth range, and has to fine-tune these through costly refinement approaches.

/*
- reference image -> the image being reconstructed
- source images -> the images where we are trying to find the correspondences
 
-  Note that in a two-view case, this is trivial. One can find the epipolar line on the neighbor image, and evaluate all pixels on that line to find a match. It is possible that the point is not visible on the other image which can be filtered out by a threshold on the cost or the strength of the consistency compared to the other candidates. However, MVS problems require going through all pixels in all images and matching that with other pixels in other images which is a really compute-intensive task @gipuma. In case of rectified images (the epipolar line is horizontal) with 2000x1000 pixel resolution, in the naive case this means 2000x1999x1000 = 4 billion comparisons and 4 billion entries in a cost volume. Traditionally, global matching methods calculated the dense cost volume in a predefined depth (or disparity) range. There are sparse and memory efficient approximations, and methods that are using image pyramids to densely sample the search space on a lower resolution example, then restrict the search space around the predicted disparities. These methods can be considered local in the search space. It is easy to see how this approach starts to fail in a large-scale outdoor setting. The depth range is unknown and potentially extremely large growing the cost volumes into unbareable sizes unless the precision is limited. 
*/


== Patch-Match Multi-View Stereo

The focus of this thesis is the Patch-Match MVS algorithm family that is the dominant approach for large-scale complex scenes. A PatchMatch

- early 3D reconstruction algorithms were inefficient because they were using large cost-volumes to store costs for the optimization problem.   with the huge leaps in GPU technology in the last decade there has been a great demand for highly parallel MVS algorithms that can map to GPUs efficiently. But GPUs generally have limitations on the amount of memory that they can utilize thus limiting the scale of the 3D reconstruction problem.

- PatchMatch is an algorithm that is
  - global in the search space
  - it keeps only a few hypothesis at the same time
  - it uses the assumption that multiple pixels are present in the scene with similar depth thus a pixel can get good hypotheses by checking neighboring pixels
  - then it introduces random perturbation to find a slightly better pixel candidate locally
  - empirically, after multiple iteration, the patch-match algorithm converges to a very good depth estimate.
  - patchmatch doesn't have the problem of fronto-parallel bias because it uses separate slanted planes for each pixel

/*
4. A cost model
Per reference image, cost is pixels × source views × patch taps × iterations × passes. The Literature Review can then place each lineage step as “multiplies term X”, using compendium §2.2’s numbers. That turns a list of papers into an argument.
*/

- patch match history:
  - PatchMatch algorithm for interactive editing: Barnes et al. 2009
  - Bleyer 2011 slanted planes for stereo, strictly sequential, authors call a GPU port an obvious idea but it is only stated as a future work
  - bailer 2012: row column paralellize (useful info: their depth-map filtering step is dominated by I/O which a production ready implementation can easily resolve by background i/o threads)
  - shen 2013: same seemingly independent paper moving patchmatch from two-views into multi-view. In a sentence, we can state that "Bailer2012 and Shen2013 carried PatchMatch from two-view stereo to multi-view stereo"
  - zhen 2014: single-neighbor alternating sweeps on GPU then they implemented a parallel version of this algorithm that could paralellize across 1 axis of images at the time, doing sweeps.
  - COLMAP uses Zheng sweeps
  - Gipuma 2015: 50s -> 2.7s, a paper with great focus on PatchMatch efficiency, introduced the checkerboard propagation which created a highly efficient MVS algorithm. They also have a fast mode that uses algorithmic approximation

//  Kriegel et al. 2017:
// - It's in Knowledge and Information Systems 52:341–378 and labelled as a survey paper. Its key line: runtimes of one algorithm "can differ by several orders of magnitude due to implementation differences, without actual algorithmic differences". It also argues for exactly your design: compare implementations in the same framework, at the same level of optimisation. Their field is clustering and outlier detection, so cite it as the general precedent, with your thesis as the MVS case.

Every depth-map MVS program in this thesis follows the same stages to compute a 3D point cloud @colmap_mvs:
+ For each _reference image_ $I_r$, an *image-level view selection* algorithm selects $N$ neighbouring _source images_ $I_n$, $n in cal(N)(r)$, from the set of all images $cal(M) = {1, dots, M}$, where $cal(N)(r) subset cal(M) without {r}$ and $|cal(N)(r)| = N$.
+ Given a reference image and its source images, a patch-match-based algorithm iteratively *estimates a depth map and a normal map*.
+ Unreliable or inconsistent estimates are filtered out.
+ Consistent reference and source pixels from the depth maps are fused into a single 3D point cloud.





== GPU execution and performance

define
- occupancy
- latency-bound
- synchronisation
- streams and fast-math

- The CUDA Programming Guide and Best Practices Guide. The latter says “higher occupancy does not always equate to higher performance”; cite that before calling 33 % occupancy a defect.
- Roofline (Williams et al., CACM 2009).
- Volkov (GTC 2010) and Little's law.
- Hwu, Kirk & El Hajj, 4th ed., 2022.
- The Nsight Compute documentation.


= Literature review

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
    

#include "chapters/methodology.typ"

/*
showing and analysing benchmarking results. showing selected method and some deep analyses results (e.g., cuda kernels occupancy etc.)
demonstrate our own implementation that fixes issues
*/
#include "chapters/results.typ"


= Conclusion

/*
should answer the RQs directly, say what the work can't claim and list of future work
*/

// Acknowledgements (optional)
// #heading(numbering: none)[#tr("acknowledgements")]
// #todo(inline: true)[Acknowledgements: to be written by the author.]

// Appendices (optional)
#show: appendix
// #include "chapters/<appendix>.typ"

// Bibliography (mandatory)
#bibliography("thesis.bib")

// List of figures (optional)
#list-of-figures()

// List of tables (optional)
#list-of-tables()

// List of algorithms (optional)
// #list-of-algorithms()

// List of codes (optional)
// #list-of-codes()

// List of symbols (optional)
// #print-nomenclature()
