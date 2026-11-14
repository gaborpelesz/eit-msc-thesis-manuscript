#import "../template/elteikthesis.typ": *
#import "figures/acmm-sampling.typ": *

// booktabs-style rules: top, below header, bottom; no vertical lines
#let _rule(w) = table.hline(stroke: w)
#let _group(cols, body) = table.cell(colspan: cols, inset: (top: 6pt, bottom: 3pt), emph(body))
// indent nested phases under their parent span
#let _sub(depth, name) = h(depth * 1em) + raw(name)
// subgroup inside a group: tells how often the phases below it occur
#let _subgroup(cols, body) = table.cell(colspan: cols, inset: (left: 5pt + 1em, top: 5pt, bottom: 2pt),
  text(size: 8pt, emph(body)))

// Pseudo-code block: left-aligned, with full-height lines so that the
// sub- and superscripts of neighbouring lines do not touch.
#let pseudo(..lines) = {
  set align(left)
  set text(top-edge: "ascender", bottom-edge: "descender")
  algorithmic(..lines)
}

// #include "measurement-tables.typ"
#let timing-table = [#figure(
  kind: table,
  caption: [
    The timing measurements recorded for every run, each with a description. On the method level, the measurements are taken by the injected timer tool (described in #ref(<bench-system>)). Nested stages are indented according to their place in algorithms. Some stages of the algorithms can run multiple times per exectuion, such as the reconstruction loop, the reference image pass, or PatchMatch. The \* sign marks algorithm stages that are only present in some methods.
  ],
  {
    set text(size: 9pt)
    set par(justify: false, leading: 0.5em)
    table(
      columns: (auto, 1fr),
      align: (left + top, left + top),
      stroke: none,
      inset: (x: 5pt, y: 3.5pt),
      _rule(1pt),
      table.header([*Measurement*], [*Details*]),
      _rule(0.5pt),

      _group(2)[*Execution level*],
      [Converter time], [The method's preprocessing dataset conversion.],
      [Method time], [From starting the container to teardown.],
      [Time incl. converter], [Total time taken by a single algorithms stack.],

      _group(2)[*Method level*],
      [reconstruction /* run */], [Time from the start of the reconstruction process until the end. ],
      _subgroup(2)[*Setup*],
      [#_sub(1, "") problem parsing /* problem_list */], [Parsing the view-selection file into per-reference-image problems.],
      [#_sub(1, "") preparation /* scene_scan */], [Such as setting pyramid levels, rounds, or image validation.],
      [#_sub(1, "") device init /* device_init */], [Selecting the CUDA device; creating CUDA context.],
      _subgroup(2)[*Reconstruction loop*],
      [#_sub(1, "") scale \* /* scale */], [Span of one pyramid level (ACM family) or one round (APD-MVS, DPE-MVS).],
      [#_sub(1, "") upsampling \* /* upsample */], [Carrying depth and normal maps to a finer scale (bilinear or JBU).],
      [#_sub(1, "") confidence evaluation \* /* confidence_eval */], [HPM-MVS++ host-side confidence sweep over the whole scene.],
      [#_sub(1, "") edge map prior \* /* edge_prior */], [HPM-MVS++ Canny edge detection, DPE-MVS edge segmentation.],
      [#_sub(1, "") reference image pass /* image_pass */], [PatchMatch pass for one reference image.],
      [#_sub(2, "") input loading /* input_load */], [Images, and depth map in geometric passes.],
      [#_sub(2, "") device upload /* device_upload */], [Allocating device memory; copying the inputs to the device.],
      [#_sub(2, "") planar prior \* /* prior_build */], [Building the planar prior for the next PatchMatch call.],
      [#_sub(2, "") PatchMatch /* patchmatch */], [One PatchMatch call on one reference image.],
      [#_sub(3, "") initialization /* patchmatch.init */], [Initializing hypotheses and their matching costs.],
      [#_sub(3, "") propagation /* patchmatch.propagate */], [Propagation and refinement iteration.],
      [#_sub(3, "") finalization /* patchmatch.finalize */], [Post-iteration kernels; such as depth from plane, and filtering.],
      [#_sub(3, "") readback /* patchmatch.readback */], [Copying the result from device to host.],
      [#_sub(2, "") result unpacking /* result_readback */], [Host-side unpacking of the results into image-shaped buffers.],
      [#_sub(2, "") depth map writing /* depthmap_write */], [Writing depth, normal and cost maps to disk.],
      _subgroup(2)[*Fusion and output*],
      [#_sub(1, "") fusion /* fusion */], [Fusing the depth maps into a point cloud.],
      [#_sub(2, "") fusion loading /* fusion.load */], [Reading images, cameras and depth maps again for fusion.],
      [#_sub(2, "") point generation /* fusion.consistency */], [Checking multi-view consistency; generating points.],
      [#_sub(1, "") output writing /* output_write */], [Writing the final PLY point cloud.],
      _rule(1pt),
    )
  },
) <table-timing-measurements>]

#let resource-table = [#figure(
  kind: table,
  caption: [
    The resource measurements recorded for every run, each with a description. The host-side sampling frequency is 10Hz and is live during the container's lifetime. However, the RTX 5070's driver refresh for some metrics is only 2Hz. The interval column gives the effective resolution regardless of the host-side sampler's frequency. System scope includes every process across the system while process scope covers only the method's own processes.
  ],
  {
    set text(size: 9pt)
    set par(justify: false, leading: 0.5em)
    table(
      columns: (auto, auto, auto, auto, 1fr),
      align: (left + top, left + top, left + top, left + top, left + top),
      stroke: none,
      inset: (x: 5pt, y: 3.5pt),
      _rule(1pt),
      table.header([*Measurement*], [*Unit*], [*Scope*], [*Interval*], [*Details*]),
      _rule(0.5pt),

      _group(5)[*Memory*],
      [Peak device memory /* peak_device_mem_bytes */], [MiB], [process], [100 ms], [Measured lower-bound for the device peak memory.],
      [Peak host memory /* peak_host_rss_bytes */], [MiB], [process], [100 ms], [Measured lower-bound for the host peak memory.],

      _group(5)[*GPU activity*],
      [GPU utilization /* gpu_util_pct */], [%], [system], [500 ms], [Share of time with a kernel running; basis of the GPU-idle share.],
      [Power draw /* gpu_power_w */], [W], [system], [500 ms], [GPU energy measured throughout the run.],

      _group(5)[*Validity checks*],
      [SM clock /* gpu_sm_clock_mhz */], [MHz], [system], [100 ms], [Confirms the locked clock held for the whole run.],
      [GPU temperature /* gpu_temp_c */], [°C], [system], [500 ms], [Confirms no thermal throttling.],

      _group(5)[*Storage*],
      [Disk read / write /* io_read_bytes, io_write_bytes */], [MiB], [process], [100 ms], [Block-device I/O of the container (cgroup v2); page-cache hits are not counted.],
      [Disk footprint /* intermediates_bytes */], [MiB], [process], [once, after run], [Footprint of all files the converter and method left behind for each run separately.],
      _rule(1pt),
    )
  },
) <table-resource-measurements>]


= Methodology

/*
types of research methodologies:
- quantitative
  - controlled benchmarking & experimental CS
  - empirical performance analysis
- qualitative
  - A/B testing, empirical case studies, content analysis, interviews and think-aloud protocols
- mixed methods
  - start by qualitative, develop a tool and method and perform quantitative

methodology / RQ:
- RQ1
  - main methodology: quantitative experimental (benchmarks) / deductive, math proofs (time complexity math maybe)
  - define the algorithmic complexity for main algorithms, see whether their implementation performs according to this complexity model. We can understand how many operations we need to perform the specific task, and see how many operations we ended up needing in order to execute it (maybe)
  - we need to find and show a single (or multiple) implementation inefficiency in one of the early methods, that other methods inherit and don't change
    - this could be extended with bugs, like if the early method has a bug that the later method inherits
  - there is a big assumption here: "... performance *decline* across successive patch-match MVS algorithms ..."
    - this we need to answer with the controlled benchmarking that we did.
- RQ2
  - having found inefficiencies, describe why are they inefficient with specifics
  - controlled benchmarking is one tool that we will use here
- RQ3
  - answer by showing
  - then controlled benchmarking to prove the point
- RQ4
  - main methodology: Mixed Methods / Qualitative (try to get this from existing research instead of providing something new as we don't have time for this!)
  - they should detail the complexity of their algorithm in their research paper, or have a section that focusing on runtime performance. They should also describe their hardware better. Today what they have is very superficial. They should also detail more how they were carrying out performance evaluations and comparing to other methods. Let's see the benchmarks but I think their measured performance is barely reproducible. Also they should detail the parameters they were using when carrying out the measurements, or if they are getting measurements for other methods then how did they gather those.
    - Maybe find some papers that are good in terms of describing their performance characteristics
  - software engineering:
    - clean specified interface design
    - modularize to fit into existing systems, e.g.
      - CUMVS provides an OpenCV interface so it is easy to integrate into OpenCV projects
      - why having a separate Python converter? Why not parse the COLMAP immediately? (CUMVS does this as well)
    - why bury parameters inside the source code that are not exposed and can't be turned?
    - common software engineering smells: main.h, hardcoded variables, etc.
  - methodology (maybe):
    - Systematic Literature Reviews

the methodology section mainly contains the following in some way:
- benchmarking
- selected method deep analysis
- own implementation that shows and demosntrates improvements
*/

== Benchmarking the state-of-the-art

To showcase the claim that the lineage of MVS algorithms improve quality while they also increase running time, the work starts with a comprehensive benchmarking of the selected methods.

We have chosen 13 MVS algorithms to evaluate in total with the following considerations: all selected algorithms are building on the same concepts of Patch-Match-based stereo reconstruction and they are top-performers on the ETH3D leaderboard as of writing the thesis. They also provide access to an open-source implementation on Github which was crucial for evaluating implementation performance and comparing local with published results. The selected methods contain the
- ACM-family (ACMH, ACMP, ACMM, ACMMP): they establish the foundation on top of Gipuma that successors are building upon.
- APD-MVS, HPM-MVS, and MP-MVS: three major work on top of the ACM-family, all choosing a different approach to improve the results.
- APDe-MVS, DPE-MVS, DVP-MVS: APD-MVS successors extending the lineage.
- HPM-MVS++: HPM-MVS successor.
- TSAR-MVS: a different approach than the ACM-family building on Gipuma.
- CUMVS: a simplification and reimplementation of the ACMH/ACMM released by an independent high-performance company, Fixstars. The implementation focuses on performance and production quality.

The benchmarking analyses predefined phases of the algorithms to gather as much information as possible without significant modifications to the implementation. The algorithm implementations are treated as is, with only essential changes to the implementations as possible. The required changes are mostly related to setup and compilation, or phase timing for the benchmarking. Later sections describe these changes in depth.

The benchmarking has two target measurements: speed through *mean execution time*, and quality through *F1 score*.

=== Configuration

==== Dataset, selected scenes, and input resolution

There are many influential benchmarks in the field of 3D reconstruction all of them serving a different purpose. The Middlebury dataset @middlebury_dataset serves as the foundational work in creating a structured framework for evaulating two-view stereo algorithms. DTU MVS dataset @dtu_dataset was established for robotics. It provides no leaderboard to rank MVS algorithms and their performances. ETH3D @eth3d_dataset is dataset with natural, large-scale scenes, high-resolution images, and provided ground-truth camera parameters to directly evaluate MVS algorithms for pointcloud reconstruction. It showcases a leaderboard, with many SOTA MVS contenders. Tanks and Temples @tanks_and_temples_dataset focuses on full 3D pipeline evaluation thus an evaluation requires camera parameter estimation as the first step. It also provides a good leaderboard with many SOTA MVS methods.

For the benchmarking in this thesis, ETH3D dataset has been selected as the evaluation dataset for the following reasons:
- it focuses directly on MVS algorithms,
- many algorithm choose this dataset as their primary target for benchmarking,
- and convenient evaluation scripts are available.

The dataset features 13 scenes with provided ground-truth for a training set. It has a wide-variety of indoor and outdoor scenes. The algorithms can react very differently to scene differences thus including all scenes in the benchmarking is crucial. For example, the dataset consists of 7 scenes that have uniform-sized images and 6 scenes which have mixed-sized images. The APD-MVS and DPE-MVS implementations handle the mixed-sized images in the converter by zero-padding the images to a uniform size. It is important to note that the benchmarking experiment does not try to control these implementation decisions, it merely acknowledges them.

Almost none of the selected algorithms publishes results for native resolution ($6221$ x $4146$ px) on ETH3D images. They explicitly state that their published results resized images at 3200px in their implementation @acmh_acmm @acmp @acmmp @hpm @hpm_plusplus @mp_mvs all based on the decision of @colmap_mvs. APD-MVS and DPE-MVS publishes results primarely for native resolution @apd @dpe. Note, that the resizing step is slightly different as CUMVS uses area averaging and other methods generally use bilinear interpolation with no anti-aliasing. Fixed constant pixel-based settings in the PatchMatch kernels change meaning with resolution such as window size, or step size, geometric consistency limits, planar prior grid size, propagation reach. Therefore, the benchmarking keeps the problem of resizing to the authors choice, and considers this step as part of their proposed reconstruction system.

Although it is interesting from an algorithm evaluation perspective to observe the behavior of the implementations at lower resolutions, it will also keep the choice of resizing to 3200px or keeping the native resolution parameter. 3D reconstruction software usually provide the ability to (either explicitly or implicitly through "quality" flags) rescale the images to a lower resolution to make the reconstruction faster. Some work also states that their have run at least part of their evaulations on lower resolutions #todo[cite!]. However, only CUMVS and MP-MVS provide a way to set the maximum image size externally, all the other methods' implementations compile this choice into the final program. A selected algorithm will be analysed further in #ref(<apd-mvs-analysis>).

/*Generally, production-grade scanning systems produce a stream of images at lower resolutions than they are captured in ETH3D. Otherwise, 3D reconstruction software usually provide the ability to (either explicitly or implicitly through "quality" flags) rescale the images to a lower resolution to make the reconstruction faster. Many papers also state that they have run at least part of their evaulations on lower resolutions #todo[cite!]. Thus, apart from the native resolution, the benchmark defines two downsampled variants at half (3200px width) and at quarter (1600px width) the resolution of the original images (around 6200px width). To minimize loss of image quality while preparing the dataset, the benchmarking system handles the rescaling using JPEG q100 4:4:4 re-encoding with Hamming windows for anti-aliasing.*/

==== Quality metrics

The ETH3D dataset provides a small set of quality metrics for evaluating MVS algorithms. Given an evaluation threshold for the radius around points, the dataset defines
- _Accuracy_: the ratio of reconstructed points that have a ground truth point within a certain radius over all reconstructed.
- _Completeness_: the ratio of ground truth points that have a reconstructed point within the same radius over all ground truth points.
- _F1 score_: the harmonic mean of accuracy and completeness, combining the two metrics into a single measure.

The quality is measured at 1, 2, 5, 10, 20 cm radius evaluation thresholds, with 2 cm being the primary (the ETH3D default on their leaderboard).

==== Runtime metrics

The system thoroughly measures each execution through a diverse set of runtime metrics. It measures the algorithm timings in depth through an injected timer tool, discussed in #ref(<bench-system>). Conveniently, the stages that the algorithm implementations define are nearly identical. These shared stages give the thesis an ability to conduct a fine-grained comparison analyses (section xxx #todo[refer to benchmark analysis in results]). #ref(<table-timing-measurements>) shows a comprehensive overview of all the timing measurements.

#timing-table

Resource utilization is also measured, including host RAM, disk I/O, CPU and GPU utilization, among other more granular metrics.

#resource-table


==== Algorithm free-parameters

The algorithms are building on the same algorithmic blocks with the same or similar parameters to configure. All of them publish varying levels of quality and performance configurations in their papers. The thesis aims at a globally consistent setting for shared free-parameters and chooses to use any values from the papers where those values has been explicitly stated by the authors. These paper stated values have been cross-verified with their respective implementation. For the benchmarking, explicitly stated values in the papers will override any deviation in implementation defaults. Apart from these, the benchmarking runs the implementation's own shipped converters and parameters.

No reconstruction method states the number of source images explicitly in its paper. Some define 10 source images for only their memory and runtime comparison without explaining the choice @apd @tsar @dvp. The implementations all agree on a maximum 20 sources per reference image, with the converter's view selection doing the rest. The shipped converter was mostly copied over from project to project, thus the selected views are generally byte-identical.

==== Benchmark dimensioning

The MVS algorithms are non-deterministic, thus the benchmarking requires repeated execution to combat variance in results. To determine the number of necessary repeats during benchmarking prior work has to find the randomness factors, make sure that runs are independent, and estimate the variance. For this, the thesis carries out a dimensioning experiment to prepare the benchmarking run. During execution, uncontrolled variables can lead to bias in interpreting benchmarking results, while selecting the right number of repetitions improves the likelihood of finding true means through measured variance. The goals of dimensioning are exactly these: 1. eliminate the uncontrolled variables; 2. find the right number of repetitions to minimize the effect of random variables. @kalibera_rigorous_benchmarking


*Randomness factors* In all methods, the GPU clock cycle counter seeds the random number generator. No method implementation allows for changing this. The random number generator drives the PatchMatch random initialization, the pixel-level view sampling, the depth refinement and RANSAC iterations, and indirectly everything else downstream such as the selected planar priors. Even if the work would fix the seed as a deviation from the original implementation, most algorithms would stay non-deterministic due to bugs and concurrency issues. The ACM-family PatchMatch kernel implementations have race conditions in the near sampling reads. DPE-MVS has the same type of race in its the edge-aware sampling. Furthermore, it reads uninitialized memory past the end of the image buffer. APD-MVS (and DPE-MVS due to copy-pasted code) leaves an uninitialized border row and column on odd image sizes. Meanwhile, HPM-MVS++ has multiple uninitialized values in the kernel. These are the types of bugs that the thesis claims as inherited problems.

*Run independence and variance estimation*: for proving the independence of runs and finding out the variance to calculate the number of repetitions, a dimensioning @kalibera_rigorous_benchmarking has been run 15 times per method on three different scenes: *pipes*, *meadow*, and *office*. The total of 450 runs were scheduled in a randomized order. Next to wall time, F1 score is also included in the dimensioning as a target measurement because the non-deterministic factors alter the results.

#figure(
  image("../generated/figures/dimensioning_run_statistics.png", width: 100%),
  caption: [Run statistics of the dimensioning experiment. The lag-1 plots' correlations show that generally the runs are independent of each other both in terms of runtime and quality. The compacted sequence plots show the mean and variance of the runs.],
) <fig-dimensioning-run-statistics>

#ref(<eq-ci>) gives the 95% confidence interval for the mean of a cell after $n$ repetitions suggested by @kalibera_rigorous_benchmarking for our single-level experiment.

$ overline(Y) plus.minus t_(0.975, n_b-1) dot s / sqrt(n) $ <eq-ci>

where $overline(Y)$ is the sample mean, $s$ the sample standard deviation and
$t_(0.975, n_b-1)$ Student's $t$ quantile with $n_b-1$ degrees of freedom.

The number of repetitions is the smallest $n$ whose half-width meets the target $E$. Taking into account the minimum suggested value for $n_b$ which is 5:

$ n_b^* = min { n_b >= 5 : t_(0.975, n_b-1) dot s / sqrt(n_b) <= E } $ <eq-repeats>

The results for the 15 runs are shown in #ref(<fig-dimensioning-run-statistics>). The suggested minimum repetitions for the dimensioning is 30, however, 15 runs across all of the methods already take over 44 hours. Slightly more repetitions in the dimensions would not lower the calculated $n_b$. During the dimensioning measurements there were 10 slow runs that were hit by CPU clock frequency changes or other unknown machine related effects. Omitting these from the calculations $n_b = 5$ would land most of the results in $±1%$ of the mean wall-time. Considering the already conducted amount of runs, this thesis accept $5$ as a good estimate and will run the final benchmarking with this many repeats.


=== Measurement system <bench-system>

A measurement bench is defined by a host system, a GPU and it's driver, and a docker image containing a pinned evaluator and forked methods with pinned commits.

==== environment

- Docker image that builds all algorithm implementations
- CUDA 12.8 toolkit, clang-18, static OpenCV 4.12, every methods kernel embeds sm_120 machine code
- All lineage methods keep their `-O3` `--use_fast_math`, and `--maxrregcount=128` compile flags for device code.

===== deviations (open-source forks)

A byte-identical bench timer that times different phases of the algorithms is commited and compiled into every measured fork. It is enabled by an environment variable that the docker image sets. The forks in the ACM lineage already synchronise after every CUDA kernel launch, so no commit was required for measuring kernel timings. CUMVS is asynchronous by default for its initialization kernels, so a commit was required to make these synchronous. The effects are negligible and they only added a measured 0.9 seconds to the wall runtime.

Furthermore, all forks are compiled directly to native NVidia `sm_120`.

==== hardware

When selecting hardware for the benchmarking, the most important component for MVS evaluations is the GPU. DVP-MVS paper claims that a mainstream GPU has 24GB VRAM. This thesis does not agree with this statement. All methods are built using CUDA kernels so they vendor lock NVidia hardware. The only GPUs that have at least 24GB VRAM are the top consumer GPUs (3090, 4090, 5090) or workstation-grade alternatives. Most companies favor more affordable consumer GPUs for example 5070, or 5080 for production grade company clusters with 12GB-16GB VRAM. Especially for MVS, where for the traditional algorithms more compute can outweigh more VRAM, companies would probably choose two 5070 cards instead of a single 5080 #todo("lot of claims, any sources?").

The benchmarking system uses Nvidia 5070 GPU with 12GB VRAM. The benchmark explicitly states out-of-memory crash states. For CPU, the system uses an AMD Ryzen 9 9950X3D 16-Core Processor and a Samsung SSD 990 EVO Plus 4TB for storage. The machine has 192GB DDR5 RAM.

For controlling the experiments the 5070 GPU's streaming multiprocessor (SM) clock is locked at the card's base frequency: 2317 MHz. The card has a much higher boost frequency which it might not be able to sustained under changing temperatures and fluctuating power over the long benchmarking session and could negatively affect the results. No other processes running on the GPU is a requirement for the benchmarking.

Controlling the host requires us to pin the containers to use CPU threads 0-7,16-23 because of the 9950X3D dual CCD design having 96 MB L3 cache for these 16 threads, while having only 32 MB for the other 16. A method that is only running on the latter would be in disadvantage compared to the others that run only on the former. Apart from this, the benchmark sets the CPU governor and the Energy Performance Preference (EPP) to performance mode, and turn the CPU frequency scaling. However, the CPU frequency scaling on is left on as it didn't provide significant differences in wall time, and the AMD 9950X3D CPU can sustain boosted frequencies indefinitely. #todo[could link https://gamersnexus.net/cpus/amd-ryzen-9-9950x3d-cpu-review-benchmarks-vs-9800x3d-285k-9950x-more]

== APD-MVS production ready reimplementation

APD-MVS is one of the more recent approaches to help the patch-match window problem. The main contribution of this thesis is the integration of APD-MVS into CUMVS. #todo[slightly better intro once we have more content]

This section starts with an overview of the ACMH/ACMM algorithm that serves as the foundation for APD-MVS. Then in #ref(<apd-mvs-overview>) the most important APD-MVS improvements will be described. These sections are providing the basic information on the algorithms to then understand the analysis of the different parts layed out in #ref(<apd-mvs-analysis>).

=== ACMH/ACMM algorithm overview

/*
ACMM algorithm:
- image-level view selection assembles image collections which consist of a reference image and N source images (neighbor images)
- for each scale in the image pyramid scales
  - if not first scale: upscale from previous
  - go through all images with one photometric run, then all images with N geometric runs
    - for each collection of images in each run:
      - initialize planes and calculate initial cost
        - if this is the first, then randomly initialize the planes, if not, assemble the planes from earlier depth and normal
      - for each patchmatch propagation iteration:
        - update black pixels
        - update red pixels
      - run median filter on resulting depth map
*/

The goal of the ACMM @acmh_acmm algorithm is to estimate one depth map per image. A _reference image_ $I_r$ defines the image being updated, at each step of the algorithm. The image-level view selection first assembles image collections by assigning a set of _source images_ $S_r$ to each $I_r$, with varying number of images included $n = |cal(S)_r| <= 20$, that are observing the same part of the scene. Every pixel $p$ of $I_r$ carries a _plane hypothesis_ $theta_p$, which gives a depth and a surface normal estimate. $theta_p$ defines a slanted image window centered around $p$ called a _patch_, and predicts where the patch appears in each source image $I_j in S_r$. The _matching cost_ $rho_j (theta_p)$ defines a metric to evaluate how good is the mapping of this _patch_ using the plane hypothesis. The cost in ACMM calculates a bilaterally weighted Zero-mean Normalized Cross-Correlation (ZNCC) between two grayscale images and their patches using each pixel's intensity value. The algorithm uses $rho_j (theta_p) = 1 - "zncc"_j (theta_p)$ to define the cost from the correlation, i.e., 0 is a perfect match while 2 is the worst. The weighted mean is taken across $S_r$ to combine all costs.

$ "Cost"(theta_p, w_p) = (sum_(j in S_r) w_p_j dot rho_j (theta_p)) / (sum_(j in S_r) w_p_j), $ <eq:acmm-cost>

where the view weights $w_p$ are different for each pixel that was set through the pixel-wise joint view selection mechanism @acmh_acmm.

The images of the scene are processed in a multi-scale image pyramid fashion from coarsest to finest. In ACMM's implementation and default parameters, there are 3 _scale_ levels in total. Each scale runs $1 + N_"geom"$ _passes_ over all reference images, where $N_"geom"$ is the number of geometric passes (ACMM default is $N_"geom" = 2$):
- _photometric_ pass: uses only the bilateral ZNCC cost, starts from random planes or from the an upsampled previous scale result
- _geometric_ pass: starts from the result of the previous pass, and defines an additional geometric term in the cost that uses the source images' depth maps to calculate an additional reprojection error.

#ref(<alg:acmm-reconstruction>) shows the high-level overview of the steps and it matches the outline that #ref(<table-timing-measurements>) proposed for time measurements.

#algorithm(caption: [ACMM: Multi-scale PatchMatch reconstruction])[
  #algorithmic(
    (0, [*Input:* $N$ images, $M$ cameras and the image collection {$I_1 union S_1, dots, I_(|N|) union S_(|N|)}$]),
    (0, [*Output:* point cloud $cal(P)$]),
    (0, [*for each* scale $s$, from coarsest to finest, *do*]),
    (1, [*if* $s$ is *not* the coarsest scale *then*]),
    (2, [*for each* $r in {1, dots, N}$ *do* upsample $D_r$ and $N_r$ to scale $s$], none, <alg:acmm-upsample>),
    (1, [*for each* $r in {1, dots, N}$ *do* ImagePass$(r, s, "\"photometric\"")$]),
    (1, [*repeat* $N_"geom"$ times]),
    (2, [*for each* $r in {1, dots, N}$ *do* ImagePass$(r, s, "\"geometric\"")$], none, <alg:acmm-geom>),
    (0, [$cal(P) <-$ fuse all $D_r$ and $N_r$ of the finest scale]),
  )
] <alg:acmm-reconstruction>

The core of the _ImagePass_ is the PatchMatch iterations running on device. The iterations are running the diffusion-like propagation, where each pixel is considered red or black based on their position in the checkerboard pattern (see #ref(<fig:acmm-sampling>)). This propagation scheme ensures that a pixel's neighbors are not updated and can be used without worrying about race conditions when updating each pixel concurrently.#footnote[This is the pattern of the ACMM paper, and the one APD-MVS implements. In ACMM's released code, five of the six distinct pixels of each V-shaped region have the colour of $p$, so it reads pixels that are being updated at the same time.] 

#algorithm(caption: [ImagePass$(r, s, "phase")$: one reference image pass])[
  #algorithmic(
    (0, [load $I_r$ and $S_r$ with their cameras $C$ at scale $s$], emph[input loading]),
    (0, [*if* $s$ is *not* the finest scale *then*]),
    (1, [*for each* $r in {1, dots, N}$ *do* upsample $D_r$ and $N_r$ to scale $s$], none, <alg:acmm-upsample>),
    (0, [copy $C$, $I_r$, $S_r$, $D_r$, and $N_r$ to the device], emph[device upload]),
    (0, [*for each* pixel $p$ *in parallel do*], emph[initialization]),
    (1, [*if* $"phase" = "\"photometric\""$ *then* $theta_p <-$ a random plane]),
    (1, [*else* $theta_p <-$ the loaded plane]),
    (1, [$c_p, V_p <-$ initial cost and selected views of $theta_p$]),
    (0, [*for* $t = 1, dots, T_"phase"$ *do*], emph[propagation]),
    (1, [*for each* black pixel $p$ *in parallel do* UpdatePixel$(p, t)$], none, <alg:acmm-black>),
    (1, [*for each* red pixel $p$ *in parallel do* UpdatePixel$(p, t)$], none, <alg:acmm-red>),
    (0, [convert every $theta_p$ to a depth and a normal; median-filter the depths], emph[finalization]),
    (0, [copy the planes and costs to the host], emph[readback]),
    (0, [unpack them into $D_r$, $N_r$ and $C_r$], emph[result unpacking]),
    (0, [write $D_r$, $N_r$ and $C_r$ to disk], emph[depth map writing]),
  )
] <alg:acmm-imagepass>

The _ImagePass_ is responsible for initializing the current plane parameter estimates, either randomly, or from the previous state. The cost for the current estimates is always recalculated. Notice, that PatchMatch can start from any initialization.




#figure(
  panel-candidates(size: 8.64),
  caption: [ACMH propagation and pixel sampling where pixels are split into a red and black in a checkerboard, marked by the dots. Same colored pixels are updated in parallel. The eight sampling regions of the current pixel $p$ (black in the center) are shaded in light red: four V-shaped regions around $p$ and four lines further out that continue to a distance of 23 pixels (beyond the window shown). The pixel with the lowest current cost in each region (yellow) passes its plane to $p$ as a candidate.],
) <fig:acmm-sampling>

The _UpdatePixel_ function (#ref(<alg:acmm-pixel>)) consists of four main steps: sampling, view selection, propagation, refinement.

*Sampling* (adaptive checkerboard sampling) takes an input pixel with its current plane estimate and defines eight distinct _sampling areas_ that surround the pixel in four V-shaped regions (up, right, bottom, left), and four straight lines in each direction (#ref(<fig:acmm-sampling>)). For each pixel of each sampling area the algorithm calculates the matching cost across all source images, and from each area, the pixel with the lowest cost is taken as a candidate plane.

*View selection* (multi-hypothesis joint view selection) decides which source images to trust based on two assumptions:
1. Bad views generally have low photometric consistency across all eight sampling candidates while good views generally have at least some candidates with high consistency.
2. A view that has high photometric consistency with $p$'s direct neighbors will probably also observe $p$.
Thus, ACMH defines a voting scheme where a source image is likely to be drawn if, with it, several of the eight candidates match well and if pixels in $p$'s 4-connected neighborhood also select it.

*Propagation* adopts the best candidate if its cost is lower than the $p$'s current plane after weighting them with the view selection prior. Otherwise, it keeps the current estimate as the result of the propagation.

*Refinement* tries alternative variations (five in ACMH) of the propagation result that combine its depth and normal with randomly perturbed and freshly drawn values. This step is crucial, as it slightly alters the current estimate to better fit the local structure, and it introduces new samples for the whole PatchMatch state space that other pixels can utilize.


#algorithm(caption: [UpdatePixel$(p, t)$: update of one pixel])[
  #algorithmic(
    (0, [#strong[for] $a = 1, dots, 8$ #strong[do]], [sampling], <alg:acmm-sample>),
    (1, [$hat(theta)_a <-$ plane of the lowest-cost pixel in region $a$]),
    (1, [$rho_(a,j) <- rho_j (hat(theta)_a)$ for every $j in cal(S)_r$], [$8 n$ NCC]),
    (0, [$w <-$ SelectViews$(rho, t)$], [view selection], <alg:acmm-views>),
    (0, [$c_p <-$ Cost$(theta_p, w)$], [$n$ NCC]),
    (0, [$c_a <-$ Cost$(hat(theta)_a, w)$ for every $a$;#h(0.6em) $b <- arg min_a c_a$], [reuses $rho_(a,j)$]),
    (0, [#strong[if] $c_b < c_p$ #strong[then]], [propagation], <alg:acmm-prop>),
    (1, [$theta_p <- hat(theta)_b$;#h(0.6em) $c_p <- c_b$;#h(0.6em) $V_p <- {j : w_j > 0}$]),
    (0, [#strong[for each] of the five variations $theta'$ of $theta_p$ #strong[do]], [refinement], <alg:acmm-refine>),
    (1, [$c' <-$ Cost$(theta', w)$], [$n$ NCC each]),
    (1, [#strong[if] $c' < c_p$ #strong[then] $theta_p <- theta'$;#h(0.6em) $c_p <- c'$]),
  )
] <alg:acmm-pixel>





=== APD-MVS <apd-mvs-overview>

APD-MVS is an extension for ACMH @acmh_acmm

=== APD-MVS integration into CUMVS

This section describes the integration process and the differences between the integrated and the original performance of APD-MVS. The work starts by integrating APD-MVS as a propagation backend into CUMVS. CUMVS already supports multiple backends and implements Gipuma- and ACMH-style propagation and allows for switching between the backends using a Command-Line Interface (CLI) flag. The first goal of the thesis is to achieve a seemless integration where the F1-score results are similar to the original APD-MVS implementation.


==== Image-level view selection

CUMVS employs a slightly different strategy for view selection strategy than the converter tool that many MVS forks use. The two implementations use completely opposite ordering for the images because CUMVS indexes images in line order from the input file, while APD's converter indexes images by sorted image IDs. The integration uses CUMVS ordering because the ordering had no measured effect on the quality.

==== Depth-range calculation

Both implementations calculate the minimum and maximum allowed depth for each reference image and store them for the PatchMatch propagation step. Depth-range is used for the random initialization, a neighbor plane is only accepted if it is inside the range, and the random perturbation guesses are also drawn from the range. However, they use a slightly different strategies to calculate the range. CUMVS projects *all* SfM sparse points into the reference camera, filters out those that are behind the camera, and calculates the 1st and 99th percentiles for a low and high range estimate, finally it widens the results by x0.75 and x1.25, respectively. APD-MVS finds only those SfM points that are insideb the camera frustrum. #ref(<tab:depth-range-f1>) shows the effects of using the two different approaches for depth-range calculation. The results show that using APD-MVS's frustrum-based calculation gives significantly better F1-score results due to increasing the completeness over the scene. Therefore, the integrations depth-range strategy will follow APD-MVS.

#figure(
  table(
    columns: (auto, auto, 1fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, left, right, right, right, right, right),
    stroke: none,
    inset: (x: 6pt, y: 4pt),
    table.hline(stroke: 0.8pt),
    table.header(
      [*Backend*], [*SfM points*], [*1 cm*], [*2 cm*], [*5 cm*], [*10 cm*], [*20 cm*],
    ),
    table.hline(stroke: 0.5pt),
    [APD-MVS], [`Frustrum`],   [0.82261], [*0.87874*], [0.92546], [0.97870], [0.99207],
    [APD-MVS], [`All`], [0.82687], [*0.87997*], [0.90874], [0.91946], [0.92919],
    table.hline(stroke: 0.3pt),
    [CUMVS], [`Frustrum`],   [0.72815], [*0.77528*], [0.80987], [0.83098], [0.84562],
    [CUMVS], [`All`], [0.69696], [*0.74122*], [0.77097], [0.78589], [0.80350],
    table.hline(stroke: 0.8pt),
  ),
  caption: [F1 score by tolerance on ETH3D _pipes_ (native resolution, 14 images) after the integration into CUMVS. Results are mean of two runs, for each backend and depth-range strategy.],
) <tab:depth-range-f1>


==== Re-encoded images

The lineage's shipped COLMAP to MVS-Net converter script is generally copy-pasted from method to method. Due to a bug, this script copies only lowercase `.jpg` extension image files and considers all other extensions as images it needs to actively re-encode as JPEG. The ETH3D files are all uppercase `.JPG` thus the converter decodes and re-encodes the images using JPEG with default settings at 95 quality and 4:2:0 chroma subsampling. Note, that APD-MVS would always re-encode images as it pads those images so that it can process using the same resolution.  CUMVS ships with it's own conversion and avoids the re-encode problem altogether. However, we should expect results to be slightly different due to the higher information density of the used images.

==== Device Compile flags

APD-MVS builds its CUDA kernels using `--maxrregcount=128` and `--use_fast_math` compiler flags, while CUMVS includes neither of them. To understand the effect of each flag on the results, four measurements have been made after the integration: without the flags, with each flag alone, and with both flags being used. The results (in #ref(<tab:apd-device-flags>)) clearly show that using `--use_fast_math` gives significant performance improvements without affecting the quality of the results. On the other hand, the register cap forces no register spilling because no kernel need more than 128 registers (the maximum being 120 in kernel `DepthToWeak`). The only explanation for the faster results while turning on register capping is that NVCC decides on different PTX optimizations while the cap is active. Without further understanding the root-cause for the register capping speedup, the integration will use both flags and will override the CUMVS default behavior here.

#figure(
  table(
    columns: 5,
    align: (left, right, right, right, right),
    stroke: none,
    table.hline(),
    table.header(
      [Phase], [No flags], [Fast math], [Reg. cap], [Both],
    ),
    table.hline(stroke: 0.5pt),
    [Initialization], [181.8s], [176.6s], [182.9s], [171.2s],
    [Propagation],    [619.9s], [545.4s], [617.0s], [549.9s],
    [Finalization],   [147.9s], [100.0s], [134.1s], [93.7s],
    table.hline(stroke: 0.5pt),
    [*Kernel total*], [*949.6s*], [*822.0s*], [*934.0s*], [*814.8s*],
    table.hline(stroke: 0.5pt),
    [Whole run],      [1232.1s], [1102.0s], [1216.9s], [1097.3s],
    table.hline(stroke: 0.5pt),
    [F1 at 2 cm],     [0.877], [0.877], [0.877], [0.876],
    table.hline(),
  ),
  caption: [
    Effect of device compiler flags on kernel time on the CUMVS integrated APD-MVS. Measured on ETH3D _pipes_ at
    native resolution (6220 #sym.times 4141, 14 images). Times in seconds.
  ],
) <tab:apd-device-flags>


==== Intermediate artifacts storage: in-memory vs. disk

APD-MVS writes each image iteration's depths, normals and unreliable pixel masks to disk and reads them back in later passes. This host I/O takes up 22-23% of APD-MVS wall-time. Meanwhile, CUMVS stores all images in-memory. Eventhough this not being a scalable approach, the integration first uses an in-memory storage to minimize deviation from default CUMVS behavior.

During PatchMatch propagation, a single image's data structure stores its: colour and grayscale image (4 bytes / px), its depth map (4 bytes / px), its normal map (3 x 4 bytes / px), and its unreliable pixel map (1 byte / px). For a native resolution ETH3D image that is 541 MB per image. Running APD-MVS integration on `pipes` scene peaks at 13.8 GB host RAM usage.


=== Runtime decomposition, algorithmic cost, and analysis <apd-mvs-analysis>

/*
obvious inefficient implementation decisions:
- ACMH uses F32 RGB images. They are converting a uint image to float. They could use texture acces on float images I think which might lead to perf increase due to lower memory traffic. This needs to come from a measurement though: measurement should show that we are memory bound!
```cpp
image_uint.convertTo(image_float, CV_32FC1);
images.push_back(image_float);`
```

TODO
- Always ask: are we memory bound or compute bound, why?

- generally we should do a deep measurement and performance analyses of APD-MVS integrated into CUMVS. We need to plan this out and understand what we are going to measure. This has to be written down, and this will drive the GPU background section
- I have to better understand the implementation of APD-MVS.
- introduce CUMVS improvements into APD-MVS and see whether we can gain easy performance using these methods
- analyse quorum-mvs and see if it made the CUMVS improvements itself, if not, why not and what did it do instead
- octahedral normals are a likely interesting thing to try
*/


The work continues by closely examining the performance characteristics of the APD-MVS integration. First it depicts the contributing factors, then examines them carefully to find performance improvement opportunities. It analyzes the stages of the MVS algorithm that take the most time, and focuses on applying Amdahl's law to find the best targets for optimization.

The work of _UpdatePixel_ (#ref(<alg:acmm-pixel>)) is dominated by NCC evaluations and it is the main cost of runtime. One update evaluates $(8 + 1 + 5) dot n = 14 n$ of them, and each compares an $11 times 11$ window sampled at every second pixel, that is $6 times 6 = 36$ samples, after warping it into the source image with the homography that the plane induces. An iteration updates every pixel once, so a photometric pass over a $W times H$ image with $n = 20$ and $T_m = 3$ evaluates about $3 dot 14 dot 20 dot W H = 840 W H$ windows, and its initialization another $20 W H$.

/*
Itt van az algoritmus leirasa es kidolgozasa

claude: mik azok amik érdekesek lehetnek más szemszögéből, mik azok az angle-ök

I'm not sure whether this should be here or in the results yet, but we will include it here and we will be able to still change it later.

- this section should select an algorithm that is doing poorly in terms of runtime, it will be: APD-MVS (check whether I still agree that APD-MVS is the best candidate. I should read APD-MVS, MP-MVS, and DP-MVS (the thin structured paper))
- this section should analyse each component of the benchmark, understand whether it is necessary to spend time on those certain steps or not.
- From the benchmarking, we should also understand whether the runtimes that the published papers share, are regarding to their total runtime, or to their patch match algorithms only. I know that for MP-MVS, they were comparing their patch match kernel performance with ACMMP's kernel performance, and I could verify their claims of being faster almost exactly.
- and point out the different contributing pieces

Methodology:
1. we are going to run the method with the benchmark steps, to get a sense of how the timings are doing. This we will able to derive from the benchmarking results themselves.
2. We should first integrate APD-MVS to be working in CUMVS
3. Then, we should be able to continue looking into the internals, and performance optimize the method.


There is no reason why I shouldn't use and fork CUMVS as my primary baseline for the production ready ipmlementation. I should integrate APD-MVS into CUMVS, and then continue performance optimizing it and map it to the CUMVS style. I can go even further than CUMVS did when they perf optimized ACMH. I should acknowledge their great work, and should utilize what they've already created instead of creating my own! This is easier to justify and will easier and better from the thesis perspective.

instead of Quorum MVS, do an ablation study based on the selected algorithm (for example APD-MVS or MP-MVS). Change only a single component at a time, for example remove the JPEG re-encoding and measure how it affects the system, and move component by component to show how we are slowly improving the system. Move in small iterations and do the same when making the system into a production system. Make sure we stay bit-identical for performance improvements, and make sure we measure as ablation when we are deviating from the original implementation.
*/

#todo[ablation study]

/*focus on production implementation considerations, plus performance considerations*/

