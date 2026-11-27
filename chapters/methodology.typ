#import "../template/elteikthesis.typ": *
#import "figures/acmm-sampling.typ": *
#import "figures/kernel-breakdown.typ": kernel-breakdown-table
#import "figures/run-breakdown.typ": run-breakdown-figure
#import "figures/dimensioning-run-statistics.typ": dimensioning-run-statistics-figure
#import "figures/perf-input-regions.typ": perf-input-regions-figure
#import "figures/perf-anchor-kernels.typ": perf-anchor-kernels-figure
#import "figures/perf-anchor-spokes.typ": perf-anchor-spokes-figure
#import "figures/perf-anchor-nearest.typ": perf-anchor-nearest-figure
#import "figures/perf-prop-kernels.typ": perf-prop-kernels-figure
#import "figures/perf-prop-cost.typ": perf-prop-cost-figure, perf-prop-zero-figure
#import "figures/perf-prop-texels.typ": perf-prop-texels-figure
#import "figures/perf-class-kernels.typ": perf-class-kernels-figure
#import "figures/perf-common.typ": fix, pct, spell, signed, interval

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
  caption: flex-caption([
    The timing measurements recorded for every run, each with a description. On the method level, the measurements are taken by the injected timer tool (described in #ref(<bench-system>)). Nested stages are indented according to their place in algorithms. Some stages of the algorithms can run multiple times per execution, such as the reconstruction loop, the reference image pass, or PatchMatch. The \* sign marks algorithm stages that are only present in some methods.
  ], [Timing measurements recorded per run]),
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
      [Time incl. converter], [Total time taken by a single algorithm's stack.],

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
  caption: flex-caption([
    The resource measurements recorded for every run, each with a description. The host-side sampling frequency is 10Hz and is live during the container's lifetime. However, the RTX 5070's driver refresh for some metrics is only 2Hz. The interval column gives the effective resolution regardless of the host-side sampler's frequency. System scope includes every process across the system while process scope covers only the method's own processes.
  ], [Resource measurements recorded per run]),
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


= Methodology <ch-methodology>

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

This chapter introduces the core contributions of this thesis. First, #ref(<sec:methodology-benchmarking>) describes a benchmarking process that is being used to evaluate state-of-the-art MVS algorithms. It defines the configuration, the exact metrics being measured, the process to find out the number of necessary repeats, and the measurement system and hardware configuration. Following the rigorous benchmarking, #ref(<sec:methodology-cumvs-baseline>) examines APD-MVS and describes its integration into CUMVS, a production-ready third-party environment. The resulting integration serves as the baseline for performance optimizations that the thesis explores in #ref(<sec:methodology-cumvs-apd-perf>). The output of the integration and optimization is CUMVS(APD). The implementation improves the runtime performance 2x over the APD-MVS baseline, while achieving identical results in terms of quality.


== Benchmarking the state-of-the-art <sec:methodology-benchmarking>

This section describes the evaluation of 10 MVS algorithms that were selected with the following considerations: all selected algorithms are building on the same concepts of PatchMatch-based stereo reconstruction (#ref(<sec:bg-pm-mvs>)) and they are top-performers on the ETH3D leaderboard (#ref(<sec:benchmark-dataset>)) as of writing the thesis. Furthermore, they all provide access to an open-source implementation on GitHub which was crucial for evaluating implementation performance and reproducing published results. The selected methods follow the lineage, described in #ref(<sec:literature_review-acm-lineage>), and contain
- ACM-family (ACMH, ACMP, ACMM, ACMMP): they establish the foundation on top of Gipuma that successors are building upon.
- APD-MVS, HPM-MVS, and MP-MVS: three major works on top of the ACM-family, all choosing a different approach to improve the results.
- DPE-MVS: APD-MVS successor extending the lineage.
- HPM-MVS++: HPM-MVS successor.
- CUMVS: a simplification and reimplementation of the ACMH/ACMM released by an independent high-performance company, Fixstars. The implementation focuses on performance and production quality.

/*APDe-MVS, DVP-MVS were considered but not chosen*/ 

The benchmarking _forked_ the implementations and analyzes them through injected phase timers to gather as much information as possible. The algorithm implementations are treated as is with only essential and non-harmful deviations. Apart from the phase timers, the required changes are related to setup and compilation, described in #ref(<sec:methodology-deviations>).

The benchmarking has two target measurements: runtime speed through *mean execution time*, and quality through ETH3D's *F1-score*.

=== Configuration

==== Dataset, selected scenes, and input resolution <sec:benchmark-dataset>

The thesis uses the ETH3D dataset as the target for the evaluations. ETH3D fits the goals conveniently: it focuses directly on MVS algorithms and all selected methods have published results for the benchmark. The dataset features 13 scenes with provided ground-truth for a training set. It has a wide variety of indoor and outdoor scenes. The dataset consists of 7 scenes that have uniform-sized images and 6 scenes which have mixed-sized images. How the implementations prepare these images is described in #ref(<sec:bench-converter>).

The algorithms can react very differently to scene differences#footnote[For example, in APD-MVS, large textureless areas require the heavy unreliable pixel computation in many pixels (see @table-kernel-breakdown)], thus including all scenes in the benchmarking is crucial. The native resolution of ETH3D images is $6221 times 4146$~px, with slight variation across different views. Most of the selected algorithms prefer to run on downsampled resolution and publish results with a capped image width of maximum 3200~px @acmh_acmm @acmp @acmmp @hpm @hpm_plusplus @mp_mvs, following the decision of @colmap_mvs. On the other hand, APD-MVS and DPE-MVS publish results primarily for native resolution @apd @dpe. Note that the resizing step is slightly different as CUMVS uses area averaging and other methods generally use bilinear interpolation with no anti-aliasing. Pixel-based fixed constant settings in the PatchMatch kernels change meaning with resolution, such as window size, sampling step size, geometric consistency limits, planar prior grid size, propagation reach. Therefore, the benchmarking keeps the problem of resizing to the authors' choice, and considers this step as part of their proposed reconstruction system.

/*
Although it is interesting from an algorithm evaluation perspective to observe the behavior of the implementations at lower resolutions, it will also keep the choice of resizing to 3200px or keeping the native resolution parameter. 3D reconstruction software usually provide the ability to (either explicitly or implicitly through "quality" flags) rescale the images to a lower resolution to make the reconstruction faster. Some work also states that their have run at least part of their evaulations on lower resolutions #todo[cite!]. However, only CUMVS and MP-MVS provide a way to set the maximum image size externally, all the other methods' implementations compile this choice into the final program.

Generally, production-grade scanning systems produce a stream of images at lower resolutions than they are captured in ETH3D. Otherwise, 3D reconstruction software usually provide the ability to (either explicitly or implicitly through "quality" flags) rescale the images to a lower resolution to make the reconstruction faster. Many papers also state that they have run at least part of their evaulations on lower resolutions #todo[cite!]. Thus, apart from the native resolution, the benchmark defines two downsampled variants at half (3200px width) and at quarter (1600px width) the resolution of the original images (around 6200px width). To minimize loss of image quality while preparing the dataset, the benchmarking system handles the rescaling using JPEG q100 4:4:4 re-encoding with Hamming windows for anti-aliasing.
*/

==== Input conversion <sec:bench-converter>

The lineage methods ship with a Python preprocessing script. The script is a _converter_, that turns the sparse reconstruction of a scene (COLMAP-formatted cameras, image poses, and triangulated sparse points) into the input format of the methods @yao2018_mvsnet. Furthermore, The image-level view selection is performed by the script following the strategy of COLMAP @acmh_acmm @colmap_mvs. The script is copied from fork to fork nearly unchanged.

The image handling differs between the two variants. The ACM-lineage converter copies an image only if its file name ends in `.jpg`. The test is case-sensitive and the ETH3D files end in `.JPG`, so every image is decoded and re-encoded with the OpenCV default JPEG quality of 95 and chroma 4:2:2. CUMVS @fixstars2025cumvs ships no Python converter. Its initializer reads the ETH3D calibration directly, performs the same kind of view selection, and later reads the original ETH3D images themselves.

The benchmark runs each method with the converter its authors shipped, without modifications. The converter runs in its own container before the method, and its duration is recorded as a separate phase (_Converter time_ in #ref(<table-timing-measurements>)).

==== Quality metrics

The ETH3D dataset provides a small set of quality metrics for evaluating MVS algorithms. Given an evaluation threshold for the radius around points, the dataset defines
- _Accuracy_: the ratio of reconstructed points that have a ground-truth point within a certain radius over all reconstructed points.
- _Completeness_: the ratio of ground-truth points that have a reconstructed point within the same radius over all ground-truth points.
- _F1 score_: the harmonic mean of accuracy and completeness, combining the two metrics into a single measure.

The quality is measured at 1, 2, 5, 10, 20 cm radius evaluation thresholds, with 2 cm being the primary (the ETH3D default on their leaderboard).

==== Runtime metrics

The system thoroughly measures each execution through a diverse set of runtime metrics. It measures the algorithm timings in depth through an injected timer tool, discussed in #ref(<bench-system>). Conveniently, the stages that the algorithm implementations define are nearly identical. These shared stages give the thesis an ability to conduct a fine-grained comparison analysis (#ref(<sec:bench-phases>)). #ref(<table-timing-measurements>) shows a comprehensive overview of all the timing measurements. Resource utilization is also measured, including host RAM, disk I/O, CPU and GPU utilization, among other more granular metrics, shown by @table-resource-measurements.

#place(auto, float: true, clearance: 22pt, timing-table)

#place(auto, float: true, clearance: 22pt, resource-table)


==== Algorithm free-parameters

The methods are building on the same algorithmic blocks with the same or similar parameters to configure. All of them publish varying levels of quality and performance configurations in their papers. The thesis aims at a globally consistent setting for shared free-parameters and chooses to use any values from the papers where those values have been explicitly stated by the authors. These paper-stated values have been cross-verified with their respective implementation. For the benchmarking, explicitly stated values in the papers will override any deviation in implementation defaults. Apart from these, the benchmarking runs the implementations' own shipped converters and parameters.

No reconstruction method states the number of source images explicitly in its paper. Some define 10 source images for only their memory and runtime comparison without explaining the choice @apd @tsar @dvp. The implementations all agree on a maximum of 20 sources per reference image, with the converter's view selection (#ref(<sec:bench-converter>)) doing the rest. The shipped converter was mostly copied over from project to project, thus the selected views are generally byte-identical.

==== Benchmark dimensioning <sec:benchmark-dimensioning>

The MVS algorithms are non-deterministic, thus the benchmarking requires repeated execution to combat variance in results. To determine the number of necessary repeats during benchmarking, prior work has to find the randomness factors, make sure that runs are independent, and estimate the variance. For this, the thesis carries out a dimensioning experiment to prepare the benchmarking run. During execution, uncontrolled variables can lead to bias in interpreting benchmarking results, while selecting the right number of repetitions improves the likelihood of finding true means through measured variance. The goals of dimensioning are exactly these: 1. eliminate the uncontrolled variables; 2. find the right number of repetitions to minimize the effect of random variables. @kalibera_rigorous_benchmarking


*Randomness factors* In all methods, the GPU clock cycle counter seeds the random number generator. No method implementation allows for changing this. The random number generator drives the PatchMatch random initialization, the pixel-level view sampling, the depth refinement and RANSAC iterations, and indirectly everything else downstream such as the selected planar priors. Even if the work were to fix the seed as a deviation from the original implementation, most algorithms would stay non-deterministic due to bugs and concurrency issues (@sec:perf-base). To name a few, the ACM-family PatchMatch kernel implementations have race conditions in the near sampling reads. DPE-MVS has the same type of race in its edge-aware sampling. Furthermore, it reads uninitialized memory past the end of the image buffer. APD-MVS (and DPE-MVS due to copy-pasted code) leaves an uninitialized border row and column on odd image sizes. Meanwhile, HPM-MVS++ has multiple uninitialized values in the kernel. These are the types of bugs that the thesis names as inherited problems.

*Run independence and variance estimation*: for proving the independence of runs and finding out the variance to calculate the number of repetitions, a dimensioning @kalibera_rigorous_benchmarking has been run 15 times per method on three different scenes: *pipes*, *meadow*, and *office*. A total of 450 runs were scheduled in a randomized order. Next to wall time, F1-score is also included in the dimensioning as a target measurement because the non-deterministic factors alter the results.

#figure(
  dimensioning-run-statistics-figure,
  caption: [Run statistics of the dimensioning experiment. The lag-1 plots' correlations show that generally the runs are independent of each other both in terms of runtime and quality. The compacted sequence plots show the mean and variance of the runs.],
) <fig-dimensioning-run-statistics>

#ref(<eq-ci>) gives the 95% confidence interval for the mean of a cell after $n$ repetitions suggested by @kalibera_rigorous_benchmarking for the single-level experiment:

$ overline(Y) plus.minus t_(0.975, n_b-1) dot s / sqrt(n) $ <eq-ci>

where $overline(Y)$ is the sample mean, $s$ the sample standard deviation and
$t_(0.975, n_b-1)$ Student's $t$ quantile with $n_b-1$ degrees of freedom.

The number of repetitions is the smallest $n$ whose half-width meets the target $E$. Taking into account the minimum suggested value for $n_b$ which is 5:

$ n_b^* = min { n_b >= 5 : t_(0.975, n_b-1) dot s / sqrt(n_b) <= E } $ <eq-repeats>

The results for the 15 runs are shown in #ref(<fig-dimensioning-run-statistics>). The suggested minimum repetitions for the dimensioning is 30, however, 15 runs across all of the methods already take over 44 hours. Slightly more repetitions in the dimensions would not lower the calculated $n_b$. During the dimensioning measurements there were 10 slow runs that were hit by CPU clock frequency changes or other unknown machine related effects. Omitting these from the calculations $n_b = 5$ would land most of the results in $±1%$ of the mean wall time. Considering the already conducted amount of runs, this thesis accepts $5$ as a good estimate and will run the final benchmarking with this many repeats.


=== Measurement system <bench-system>

A measurement bench is defined by a host system, a GPU and its driver, and a Docker image containing a pinned evaluator and forked methods with pinned commits.

==== Deviations (open-source forks) and environment <sec:methodology-deviations>

The measurement system consists of a fork from each measured lineage algorithm's open-source implementation. All forks contain a byte-identical bench timer that times the different phases of the algorithms, according to @table-timing-measurements. The bench timer can be enabled by an environment variable. The forks in the ACM lineage already synchronize after every CUDA kernel launch, so no commit was required for measuring kernel timings. CUMVS is asynchronous by default for its initialization kernels, so a commit was required to make these synchronous. The effect is negligible, measured on _delivery_area_ at 3200~px on 5 runs, the synchronization costed at most 0.04 seconds per run (0.03% of the wall time).

The measurement system creates a Docker image that contains all of the forks, ensuring that the environment matches between each method: CUDA 12.8 toolkit, clang-18 #box[C++] compiler, a statically linked OpenCV 4.12. All forks are compiled directly to native NVIDIA `sm_120` feature set. Furthermore, all forks keep their own defined compile flags: `-O3` on the host-side and `--use_fast_math --maxrregcount=128` on the device-side.

==== Hardware

When selecting hardware for the benchmarking, the most important component for MVS evaluations is the GPU. The DVP-MVS paper claims that a mainstream GPU has 24~GiB VRAM. Nowadays, obtaining a graphics card with 24~GiB VRAM is hardly feasible. All methods use CUDA so only the top-of-the-line consumer-grade NVIDIA GPUs (3090, 4090, 5090) could be considered, or workstation-grade alternatives. Graphics cards with 12~GiB memory are much more accessible.

The benchmarking system uses an NVIDIA 5070 GPU with 12~GiB VRAM. The benchmark explicitly states out-of-memory crash states (@sec:bench-resources). For the CPU, the system uses an AMD Ryzen 9 9950X3D 16-Core Processor and a Samsung SSD 990 EVO Plus 4TB for storage. The machine has 192~GiB DDR5 RAM, eventhough much fewer memory would suffice.

For controlling the experiments the 5070 GPU's streaming multiprocessor (SM) clock is locked at the card's base frequency: 2310 MHz. The card has a much higher boost frequency which it might not be able to sustain under the changing temperatures and the fluctuating power over the long benchmarking session which could negatively affect the results. No other processes running on the GPU is a requirement for the benchmarking.

Controlling the host requires pinning the containers to use CPU threads 0-7,16-23 because the 9950X3D's dual-CCD design has 96~MiB L3 cache for these 16 threads, while having only 32~MiB for the other 16. A method that is only running on the latter would be at a disadvantage compared to the others that run only on the former. Apart from this, the benchmark sets the CPU governor and the Energy Performance Preference (EPP) to performance mode. However, the CPU frequency scaling is left on as it didn't provide significant differences in wall time on separately carried out experiments. However, the boost gave up to 9.3% improvement in runtime which is significant in the scale of the benchmarking#footnote[Across the 735 successful runs, repeat wall times stayed within 4.3% of their method median.]. This agrees with public reviews @gamersnexus2025_9950x3d reporting that the 9950X3D holds its boost clocks under sustained all-core load.

== CUMVS(APD) baseline depiction <sec:methodology-cumvs-baseline>

APD-MVS @apd is one of the more recent PatchMatch approaches on improving textureless surface reconstruction (@sec:literature_review-acm-lineage). The algorithm is particularly interesting from several points of views: their published results perform the best among the audited methods, they are using native resolution images instead of capping the maximum width at 3200~px, and early benchmarking results have shown that the method is the second slowest method across the lineage#footnote[The only slower method is DPE-MVS, descending from APD-MVS, see Appendix @table-bench-phase-seconds.].

This section starts with an overview of the ACMH/ACMM algorithm that serves as the foundation for APD-MVS, while #ref(<apd-mvs-overview>) explains the algorithm changes introduced by APD-MVS. @sec:apd-cumvs describes CUMVS(APD), the integration of APD-MVS into CUMVS (@lit:cumvs), and produces the baseline measurements for the further optimization steps. #ref(<apd-mvs-analysis>) follows with an analysis over the runtime contribution factors of the baseline system.

=== ACMM algorithm overview

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

ACMM @acmh_acmm algorithm is an improved PatchMatch-based MVS algorithm (#ref(<sec:bg-modern-pm>)). A _reference image_ $I_r$ defines the image being updated, at each step of the algorithm. The image-level view selection first assembles image collections by assigning a set of _source images_ $S_r$ to each $I_r$, with varying number of images included $n = |cal(S)_r| <= 20$, that are observing the same part of the scene (#ref(<sec:bench-converter>)). Every pixel $p$ of $I_r$ carries a _plane hypothesis_ $theta_p$, which gives a depth and a surface normal estimate. $theta_p$ defines a slanted image window centered around $p$ called a _patch_, and predicts where the patch appears in each source image $I_j in S_r$. The _matching cost_ $rho_j (theta_p)$ defines a metric to evaluate how good is the mapping of this _patch_ using the plane hypothesis. The cost in ACMM calculates a bilaterally weighted Zero-mean Normalized Cross-Correlation (ZNCC) between two grayscale images and their patches using each pixel's intensity value. The algorithm uses $rho_j (theta_p) = 1 - "zncc"_j (theta_p)$ to define the cost from the correlation, i.e., 0 is a perfect match while 2 is the worst. The weighted mean is taken across $S_r$ to combine all costs.

$ "Cost"(theta_p, w_p) = (sum_(j in S_r) w_p_j dot rho_j (theta_p)) / (sum_(j in S_r) w_p_j), $ <eq:acmm-cost>

where the view weights $w_p$ are different for each pixel that was set through the pixelwise joint view selection mechanism @acmh_acmm.

The images of the scene are processed in a multi-scale image pyramid fashion from coarsest to finest. In ACMM's implementation and default parameters, there are 3 _scale_ levels in total. Each scale runs $1 + N_"geom"$ _passes_ over all reference images, where $N_"geom"$ is the number of geometric passes (ACMM default is $N_"geom" = 2$) defined as follows:
- _photometric_ pass: uses only the bilateral ZNCC cost, starts from random planes or from the  upsampled previous scale result
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

The core of the _ImagePass_ is the PatchMatch iterations running on device. The iterations are running the diffusion-like propagation introduced in #ref(<sec:bg-checkerboard>), where each pixel is considered red or black based on its position in the checkerboard pattern (see #ref(<fig-checkerboard>)a).

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

The _ImagePass_ is responsible for initializing the current plane parameter estimates, either randomly, or from the previous state. The cost for the current estimates is always recalculated. Notice that PatchMatch can start from any initialization such as initial estimates from SfM points (#ref(<sec:image-based-3d>)).

#figure(
  panel-candidates(size: 8.64),
  caption: flex-caption([ACMH propagation and pixel sampling where pixels are split into red and black in a checkerboard, marked by the dots. Same-colored pixels are updated in parallel. The eight sampling regions of the current pixel $p$ (black in the center) are shaded in light red: four V-shaped regions around $p$ and four lines further out that continue to a distance of 23 pixels (beyond the window shown). The pixel with the lowest current cost in each region (yellow) passes its plane to $p$ as a candidate.], [ACMH propagation pixel sampling]),
) <fig:acmm-sampling>

The _UpdatePixel_ function (#ref(<alg:acmm-pixel>)) consists of four main steps: sampling, view selection, propagation, refinement.

*Sampling* (adaptive checkerboard sampling) takes an input pixel with its current plane estimate and defines eight distinct _sampling areas_ that surround the pixel in four V-shaped regions (up, right, bottom, left), and four straight lines in each direction (#ref(<fig:acmm-sampling>)). For each pixel of each sampling area the algorithm calculates the matching cost across all source images, and from each area, the pixel with the lowest cost is taken as a candidate plane.#footnote[In ACMM's released code, the V-shaped regions are offset by one pixel leading to multiple sampled pixels having the color of $p$. These pixels are updated in the same kernel launch, so the propagation reads costs and plane hypotheses creating a race condition in every propagation pass.] 

*View selection* (multi-hypothesis joint view selection) decides which source images to trust based on two assumptions:
1. Bad views generally have low photometric consistency across all eight sampling candidates while good views generally have at least some candidates with high consistency.
2. A view that has high photometric consistency with $p$'s direct neighbors will probably also observe $p$.
Thus, ACMH defines a voting scheme where a source image is likely to be drawn if, with it, several of the eight candidates match well and if pixels in $p$'s 4-connected neighborhood also select it.

*Propagation* adopts the best candidate if its cost is lower than that of $p$'s current plane after weighting them with the view selection prior. Otherwise, it keeps the current estimate as the result of the propagation.

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

/*
- reliable/strong and unreliable/weak pixels: APD-MVS classifies each pixel as either of these two, and creates a classification mask for these.
  - how do we actually define strong vs weak points?
- APD-MVS has an extra step to handle weak points. In this extra step it alters the sampling such that the sampling is reaching for nearby strong pixels as anchor points.
  - I approximately remember how we are searching for these anchors. I think we are dividing equally the circle around the pixel into circular sectors, and we are trying to find the closest anchor in each sector?
  - I don't know what happens when we find these anchor points. Do we somehow interpolate between them, considering that whatever lies between them is plane, essentially implementing some kind of a planar prior? Or do we also consider their normals and we somehow fit a surface between the anchor points?
    - note: could a monocular prior help in determining this surface? Marigold v2 seems to have good knowledge about how different objects are bending or layed out. (or trying to fit basic geometries line planes or cylinder?)
*/


APD-MVS @apd is an extension of ACMM @acmh_acmm focusing on textureless regions as their main contribution. It inherits the image-level view selection, the image pyramid multi-scale scheme, and the photometric and geometric PatchMatch passes. It claims that the main problem of traditional PatchMatch is the fixed window size where, in case of a textureless region, the cost profile does not have a distinct minimum around the true depth. Therefore, APD-MVS assigns every pixel a _reliability_ state and updates the reliable and unreliable pixels differently. A _reliable_ pixel has a distinct cost minimum at its current depth and is updated by the traditional _UpdatePixel_ function (#ref(<alg:acmm-pixel>)). Initially, the algorithm classifies each pixel as reliable, thus the first iteration of PatchMatch is exactly the same as ACMM. An _unreliable_ pixel uses a _deformable patch_ for matching#footnote[APD-MVS evaluates the ZNCC without the bilateral weights of ACMM, so every sample of a window has the same weight. The restrictive change remains unexplained in the paper or the implementation.], where next to the regular patch window, equally large but sparser windows around nearby reliable pixels are defined. These reliable pixels, called _anchors_, are selected to lie on a common plane surrounding the pixel. This requires three additional components in the algorithm: the reliability evaluation, the adaptive patch deformation that selects the anchors, and a modified update for unreliable pixels.

/* 
 * Disparity is used instead of depth, as depth would lead to uneven steps in pixel space across the views. They are just approximating the average disparity.
 */
*Reliability evaluation.* The state of a pixel $p$ is derived from analyzing the cost profile along its viewing ray. Multiple samples around the depth of $p$ are taken in each direction, with steps defined in the average disparity across the reference and the source views. Only the source images from joint view selection result are taken. The matching cost is computed and aggregated for each step from the selected source images using ACMM #ref<eq:acmm-cost>. The cost profile is analyzed for local and global minima. There are multiple heuristics set up to classify the pixels, such as how many valleys the profile has, how close the estimated depth is to the depth with the global minimum, or whether the profile has a distinct minimum that the pixel can reach in a couple of iterations. Generally, reliable pixels show evidence for convergence, or the ability to converge in reasonable time. Unreliable pixels are described by several valleys, and no clear convergence.

#todo[maybe reliability figure that shows the cost profile for an unreliable point and a reliable point]

*Adaptive patch deformation* finds the anchor points for unreliable pixels in three stages:
1. _Nearest reliable pixel._ For every unreliable pixel $q$ it finds the nearest reliable pixel $cal(N)(q)$ by brute-force, scanning a $201 times 201$ window around $q$. In essence, this step builds an acceleration structure for the search in the next stage.
2. _Spoke search._ This step carries out the actual search for reliable pixels in all directions. It divides the surroundings of $p$ into $phi$ sectors. In each sector, it shoots probing rays in a random direction and tests pixels at different radii. A probe that finds an unreliable pixel returns $cal(N)(q)$ if $q$ lands in the sector otherwise returns $q$ for a reliable anchor.
3. _RANSAC filtering._ The goal of this step is to filter out anchor points that are from different surfaces, potentially due to occlusion. A RANSAC loop draws three anchor candidates whose image triangle contains $p$ and fits a plane to their 3D points. It counts the other candidates that fit onto this plane with $epsilon$ threshold as inliers, and the rest as outliers. The filtering step removes all candidates whose distance is larger than the tolerance to the winning plane and outputs the three that defined the plane.



#todo[is I do the previous todo figure, we can make one here that shows how the adaptive patch deformation changes an unreliable pixels cost profile: so show the unreliable cost profile before and after adaptive deformation]

*Modified update for unreliable pixels.* Within an iteration, the reliable pixels are updated first, because the planes of the anchors are the candidates of the unreliable pixels. A second RANSAC loop then refits a plane to the updated 3D points of the anchors of each unreliable pixel. It again draws triples whose triangle contains $p$ and keeps the plane with the smallest summed distance to the remaining anchors. Unlike the fit of the anchor selection, which runs once per pass, this fit is repeated in every iteration, and its result, the _planar prior_ $pi_p$, serves as a hypothesis. Finally, the unreliable pixels are updated in red-black iterations. It differs from #ref(<alg:acmm-pixel>) in five respects: the candidates are the planes of the anchors instead of the eight checkerboard regions; the view selection takes its prior from the views selected by the anchors instead of the four direct neighbors; every hypothesis is scored with the deformable cost; $pi_p$ is tested as an additional hypothesis before the refinement; and the stored cost $c_p$ (#ref(<alg:acmm-pixel>)) is recomputed with the conventional cost at the end. The stored costs of all pixels thus remain conventional costs, which the sampling step of reliable pixels compares within a region. 

#ref(<alg:apd-imagepass>) shows the modified image pass to account for the unreliable pixel propagation. It adds loading of the 

#let _new = box(width: 1.1em, $star$)
#let _old = box(width: 1.1em)
#let _in = h(1.5em)
#algorithm(caption: [APD-MVS _ImagePass_$(r, k, "phase")$: one reference image pass in round $k$ ($star$: no counterpart in #ref(<alg:acmm-imagepass>))])[
  #algorithmic(
    (0, [#_old load $I_r$, $S_r$ with their cameras $C$ at scale $s$], emph[input loading]),
    (0, [#_old load $D_r$ and $N_r$ of the previous pass, upsampled if needed]),
    (0, [#_new load $V_r$ and $L_r$ likewise;#h(0.6em) $U_r <- {p : L_r (p) = "unreliable"}$, empty if $k = 1$]),
    (0, [#_old copy the images, cameras and maps to the device], emph[device upload]),
    (0, [#_new *for each* $q in U_r$ *in parallel do* $cal(N)(q) <-$ nearest reliable pixel], emph[initialization], <alg:apd-nearest>),
    (0, [#_new *for each* $p in U_r$ *in parallel do*]),
    (0, [#_new#_in $A_p <-$ SelectAnchors$(p)$;#h(0.6em) *if* none are found *then* remove $p$ from $U_r$], none, <alg:apd-anchors>),
    (0, [#_old *for each* pixel $p$ *in parallel do*]),
    (0, [#_old#_in $theta_p <-$ the loaded plane, or a random plane in the first pass of round 1]),
    (0, [#_old#_in $c_p <-$ initial cost of $theta_p$]),
    (0, [#_old *for* $t = 1, 2, 3$ *do*], emph[propagation]),
    (0, [#_old#_in *for each* black, then *each* red $p in.not U_r$ *in parallel do* UpdatePixel$(p, t)$], none, <alg:apd-reliable>),
    (0, [#_new#_in *for each* $p in U_r$ *in parallel do* $pi_p <-$ FitPlane$(A_p)$], emph[planar prior], <alg:apd-fit>),
    (0, [#_new#_in *for each* black, then *each* red $p in U_r$ *in parallel do* UpdateUnreliable$(p, t)$], none, <alg:apd-unreliable>),
    (0, [#_old convert every $theta_p$ to depth and normal; median-filter the depths], emph[finalization], <alg:apd-filter>),
    (0, [#_new *for each* pixel $p$ *in parallel do* $L_r (p) <-$ EvaluateReliability$(p, eta)$], none, <alg:apd-reliability>),
    (0, [#_new *for each* pixel $p$ *in parallel do* SearchDepth$(p)$], none, <alg:apd-search>),
    (0, [#_old copy the planes, states and selected views to the host], emph[readback]),
    (0, [#_old unpack them into $D_r$, $N_r$, $L_r$ and $V_r$], emph[result unpacking]),
    (0, [#_old write $D_r$, $N_r$, $L_r$ and $V_r$ to disk], emph[depth map writing]),
  )
] <alg:apd-imagepass>


=== APD-MVS integration into CUMVS <sec:apd-cumvs>

This section describes the integration process and the differences between the integrated and the original performance of APD-MVS. The work starts by integrating APD-MVS as a propagation backend into CUMVS, resulting in _CUMVS(APD)_. CUMVS already supports multiple backends and implements Gipuma- and ACMH-style propagation and allows for switching between the backends using a Command-Line Interface (CLI) flag. The first goal of the thesis is to achieve a seamless integration where the F1-score results are intact compared to the original APD-MVS implementation.


==== Image-level view selection

CUMVS employs a slightly different strategy for view selection than the converter tool that many MVS forks use (#ref(<sec:bench-converter>)). The two implementations use completely opposite ordering for the images because CUMVS indexes images in line order from the input file, while APD's converter indexes images by sorted image IDs. The integration uses CUMVS ordering because the ordering had no measured effect on the quality.

==== Depth-range calculation

Both implementations calculate the minimum and maximum allowed depth for each reference image and store them for the PatchMatch propagation step. Depth-range is used for the random initialization, a neighbor plane is only accepted if it is inside the range, and the random perturbation guesses are also drawn from the range. However, they use slightly different strategies to calculate the range. CUMVS projects *all* SfM sparse points into the reference camera, filters out those that are behind the camera, and calculates the 1st and 99th percentiles for a low and high range estimate, finally it widens the results by x0.75 and x1.25, respectively. APD-MVS finds only those SfM points that are inside the camera frustum. #ref(<tab:depth-range-f1>) shows the effects of using the two different approaches for depth-range calculation. The results show that using APD-MVS's frustum-based calculation gives significantly better F1-score results due to increasing the completeness over the scene. Therefore, the integration's depth-range strategy will follow APD-MVS.

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
    [APD-MVS], [`Frustum`],   [0.82261], [*0.87874*], [0.92546], [0.97870], [0.99207],
    [APD-MVS], [`All`], [0.82687], [*0.87997*], [0.90874], [0.91946], [0.92919],
    table.hline(stroke: 0.3pt),
    [CUMVS], [`Frustum`],   [0.72815], [*0.77528*], [0.80987], [0.83098], [0.84562],
    [CUMVS], [`All`], [0.69696], [*0.74122*], [0.77097], [0.78589], [0.80350],
    table.hline(stroke: 0.8pt),
  ),
  caption: [F1-score by tolerance on ETH3D _pipes_ (native resolution, 14 images) after the integration into CUMVS. Results are the mean of two runs, for each backend and depth-range strategy.],
) <tab:depth-range-f1>


==== Re-encoded images

The lineage's shipped converter script has a re-encoding bug described in #ref(<sec:bench-converter>). CUMVS ships with its own conversion and avoids the re-encode problem altogether therefore the results are not byte-identical.

==== Device compile flags

APD-MVS builds its CUDA kernels using `--maxrregcount=128` and `--use_fast_math` compiler flags, while CUMVS includes neither of them. To understand the effect of each flag on the results, four measurements have been made after the integration: without the flags, with each flag alone, and with both flags being used. The results (in #ref(<tab:apd-device-flags>)) clearly show that using `--use_fast_math` gives significant performance improvements without affecting the quality of the results. On the other hand, the register cap forces no register spilling because no kernel needs more than 128 registers (the maximum being 120 in kernel `DepthToWeak`). The only explanation for the faster results while turning on register capping is that NVCC decides on different PTX optimizations while the cap is active. The integration decides to use both flags and will override the CUMVS default behavior without further examining the root cause of the register capping speedup.

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


==== Intermediate artifacts storage: in-memory vs. disk <sec:apd-cumvs-inmemory>

APD-MVS writes each image iteration's depths, normals and unreliable pixel masks to disk and reads them back in later passes. This host I/O takes up 22-23% of APD-MVS wall time. Meanwhile, CUMVS stores all images in-memory. Even though this is not a scalable approach, the integration first uses an in-memory storage to minimize deviation from default CUMVS behavior.

During PatchMatch propagation, a single image's data structure stores its: color and grayscale image (4 bytes / px), its depth map (4 bytes / px), its normal map (3 x 4 bytes / px), and its unreliable pixel map (1 byte / px). For a native resolution ETH3D image that is 516~MiB per image. Running CUMVS(APD) baseline integration on `pipes` scene peaks at 13.8 GiB host RAM usage.


=== Runtime decomposition and analysis <apd-mvs-analysis>

/*
 * The baseline is: https://github.com/gaborpelesz/production-apd-mvs/commit/cad21462540a71fb5cce8e5fc29793682fc10c11
 */

The work continues by closely examining the performance characteristics of the CUMVS(APD). First it depicts the contributing factors, then examines them carefully to find performance improvement opportunities. It analyzes the stages of the MVS algorithm that take the most time, and focuses on finding the best targets for optimization. The runtime decomposition uses *pipes* scene from ETH3D @eth3d_dataset which contains only 14 images, ideal for quick measurements. *office* and *playground* will be used to confirm that gains hold at scale. The former to support the claim on larger textureless surfaces, the latter to confirm on scenes with more textured objects. Finally, the result will be run across all scenes to show an overall improvement. The optimization attempts to focus on improvements that retain the F1-score of the algorithm. The F1 spread measured in #ref(<sec:benchmark-dimensioning>) serves as a baseline and the same benchmarking technique will be used to confirm quality stays around the mean.

#ref(<fig-run-breakdown>) shows the decomposition of a run with CUMVS(APD). A significant share is spent on *input loading/initialization* (\~14%), consisting of:
- Converting unsigned integer images to 32-bit floating point images.
- Collecting the required cameras for the reference and source images.
- Downsampling RGB images
- Upsampling depth images, normal images, unreliable pixel masks, and selected view images (when moving from a higher level in the scales)

#run-breakdown-figure

A similar amount of runtime share (\~15.6%) goes to the *PatchMatch initialization kernel*. #ref(<table-kernel-breakdown>) details the composition of this stage where it shows that finding the anchors for the unreliable pixels dominates. The *finalization* step includes the (re-)classification of pixels into reliable and unreliable, which takes up another 7% of the total runtime (DepthToWeak kernel).

The largest contribution (\~50%) is coming from the *propagation* itself. This is expected, as the propagation runs multiple iterations (1344 total calls compared to 224 initialization calls) and adds significant overhead to the unreliable pixels due to the added windows around the anchors. These new windows add more NCC evaluations and they are the main cost of runtime. One update evaluates $(8 + 1 + 5) dot n = 14 n$ of them, and each compares an $11 times 11$ window sampled at every second pixel. That is $6 times 6 = 36$ samples, after warping it into the source image with the homography that the plane induces. An iteration updates every pixel once, so a photometric pass over a $W times H$ image with $n = 20$ and $T_m = 3$ evaluates about $3 dot 14 dot 20 dot W H = 840 W H$ windows, and its initialization another $20 W H$.

In total, 

Notice that the initialization, the propagation, and the finalization kernels run close to 4x the time of their previous scales, confirming that the runtime of the kernels scales linearly in the number of pixels processed. Finally, at the baseline completing a dense 3D reconstruction from a calibrated setup costs close to *80 seconds / image*.

In total, input preprocessing, initialization kernel, propagation, and finalization take up *88% of the total runtime*. These four stages are the focus of the next sections.

#kernel-breakdown-table

== CUMVS(APD) performance optimizations <sec:methodology-cumvs-apd-perf>

This section describes the changes made to the APD-MVS integration from #ref(<sec:apd-cumvs>), to showcase performance improvements that are simple yet effective. The work focuses on all four main contributors to execution time: the input loading, the anchor search, the propagation, and the finalization steps. As a result, the improvements together achieve 2x over the baseline with zero or negligible effect on the quality.

Note that the analysis of the baseline and the improvements were running on a development machine with RTX 5070 Ti (16~GiB), and an AMD Ryzen 9 5900XT, both with unlocked clocks. However, final benchmarking results in #ref(<ch-results>) are measured on the same benchmarking configuration as described in #ref(<bench-system>). All development runs used ETH3D _pipes_ at native resolution while the changes were verified on _office_ during evaluations. For evaluations the same bench timer measurements were used as in #ref(<apd-mvs-analysis>). For determinism, the seeds were controlled where possible instead of taking the GPU clock (#ref(<bench-system>)). The changes are classified into three exactness classes to report deviations in quality scores: 1. identical (*E0*); 2. identical up to floating-point rounding (*E1*), 3. results change (*E2*).

=== Fixed baseline for repeatability <sec:perf-base>

Before any performance change, the integration fixes the upscaling of APD-MVS, which leaves part of its output to chance. Whenever the size of a stored result differs from the current image size, APD-MVS brings the depth maps, normal maps, reliability labels and selected views of the previous pass to that size with `RescaleMatToTargetSize`, a nearest-neighbor resize on the host. The function has two defects, which DPE-MVS @dpe and DVP-MVS @dvp inherit unchanged. First, it allocates the output without initializing it, and skips every target pixel whose source position falls outside the source image, so these pixels keep whatever the memory held before. Second, it divides the row index by the horizontal scale and the column index by the vertical scale. The two scales are equal only if the resize keeps the aspect ratio exactly. When rounding of odd image sizes makes them differ, the last row or column of the target can map outside the source and is left uninitialized. The content of that memory differs from run to run, and so does every result that reads it. The fixed base zero-initializes the output and uses the row scale for the rows and the column scale for the columns. It also adds an optional fixed seed for the random generators, which the runs of this section use. The APD-MVS release measured in #ref(<ch-results>) keeps the original function.

=== Hiding the input loading and data transfers <sec:perf-input>

The input loading runs on the host while the GPU is idle and it is responsible for preparing the data for one reference image pass. This section removes most of the time spent on input loading by introducing four E0 changes.

*Breakdown.* To see where the time goes, six region timers were placed inside the stage, each recording the minor page faults of the process at its boundaries. The timed run of the fixed base measured a total of 187.7s going to operations that are related to image data and their input/output. #ref(<fig-perf-input-regions>) shows the detailed breakdown. As a result, the whole run goes from 1106.1s to 926s, a *16%* improvement.

#place(auto, float: true, clearance: 22pt, perf-input-regions-figure)

==== Converting RGB images once, resizing once per scale

The performance improvement attempt caches the images in the scene object that all image passes share instead of reloading at every iteration. Therefore, image conversion and resizing only happen at the first image pass of each scale. Sharing image data is safe because it is only read to be uploaded to the device. The cache costs about 1.34~GiB of host memory for the 14 full-resolution images of _pipes_, plus at most 0.34~GiB for one round's resized images. As expected from this trivial change, the results are significant. The time spent converting went from 71.3s to 0.7s while the page faults per image pass went from 198,000 to 16,000. Resizing went from 17s to 0.1s. Inside the passes of the timed runs the region attributed to host work fell from 187.7s to 92.6s. The improvement is [+34, -12] lines changed in the source code. // commit 57c6261

==== More buffers reused

Following the same logic as the previous section, each native resolution image pass is also asking for about 2.4GB of new host memory for other buffer data that could be utilized again. The plane buffer, the index map of the unreliable pixel anchors, the selected views, and copies of the depth and normal maps of the reference and of all source views. The second performance improvement attempt has the following changes:
1. The plane array and the index maps are kept in the scene object and reallocated only when the size changes at each scale iteration.
2. The host-side depth maps, normal maps, and selected view buffers are read only during the image pass thus the changes avoid copying them.
3. The plane fill loop order is swapped so it walks the rows and columns in memory order.

In the timed runs, the plane hypotheses decreased from 44.2s to 11.5s. The improvement is [+41,-21] lines changed in the source code. // 8bd5505

==== Upscaling in parallel 

All of the upscaling uses a shared templated function which is called multiple times such as for every depth map on initialization. A small improvement on top of it which makes the rescaling loop parallel improves the overall contribution from 6.1s to 0.7s. The improvement is only [+18,-10] lines changed in the source code.

=== Host-device data transfers

Data transfers around the kernels are the remaining largest contributors in this region. In the baseline implementation every image pass iteration allocates and uploads data to the device that is potentially already there, doing unnecessary work on the order of around 2.7~GiB host-device data movement per iteration. Furthermore, the plane hypothesis results were unpacked sequentially into the depth and normal maps on the host-side.

This performance improvement attempt has the following changes:
1. The same scale iteration images are kept on device instead of reallocating and copying again.
2. The depth maps are kept on device until they change.
3. The host-side plane hypothesis buffer is page-locked so that Direct Memory Access (DMA) between host and device is fully utilized.
4. The host-side plane hypothesis unpacking loop is parallelized.

These improvements cost only [+130,-22] lines of mostly boilerplate code while reducing the host-device data related runtime from 35.8s to 7.0s. The page-locked buffer allocation is more expensive (around +0.5s), however, the overall improvements are still significant. // 816fae8

=== Efficient anchor search

The core mechanism of APD-MVS is giving reliable anchor points for unreliable pixels on textureless areas. Searching for these anchors is the first step, and it is done by three kernels: *InitRandomStates* (10.7 s, 6%) gives every pixel its unique random generator, *FindNearestStrongPoint* (94.3 s, 55%) stores the nearest reliable pixel inside a $201 times 201$ window for each unreliable pixel, *GenNeighbours* (64.8 s, 38%) then walks up to 32 sectors around the pixel to find reliable pixels (#ref(<apd-mvs-overview>)). This section removes 90% of this part's runtime in five E0 class changes (see #ref(<fig-perf-anchor-kernels>)).

#place(auto, float: true, clearance: 22pt, perf-anchor-kernels-figure)

==== Anchor selection: probes, random state and candidate sort // 6ff0e7e +21,-2; 078d9f8 +7,-1; 6099c88 +48,-7

// Measured values of this subsection are read from the generated numbers, not typed:
// generated/perf-4.3/scripts/perf43_json.py writes them, each with its source.
#let _an = json("../generated/perf-4.3/derived/numbers-anchor.json").v
#let _sp = _an.spokes.per_round          // per round with unreliable pixels: rounds 2, 3, 4
#let _steps = _sp.steps.last()           // finest round, means per unreliable pixel
#let _tries = _sp.tries.last()
#let _found = _sp.found.last()
#let _fine = _an.base.select_round_s.slice(2).sum() / _an.base.select_s   // share of the two finest rounds

`GenNeighbours` selects the anchors of the unreliable pixels with the spoke search of #ref(<apd-mvs-overview>). Most of its time goes into work that has no effect on its result: it repeats probes whose outcome it already knows, it moves the state of a random generator through memory at every draw, and it sorts all of its candidates to keep only a few. Three small changes remove this work and take #pct(1 - _an.gnl.select_s / _an.base.select_s, 0) off the kernel.

#place(auto, float: true, clearance: 22pt, perf-anchor-spokes-figure)

For an unreliable pixel $p$, the kernel divides the surroundings into sectors and looks for one reliable pixel in each of them (#ref(<fig-perf-anchor-spokes>)a). In every sector it walks outward from $p$ along the middle of the sector, the _spoke_, in growing _radius steps_, and at each step it probes the pixel that the spoke reaches. If the probed pixel, or the nearest reliable pixel stored for it, is a reliable pixel inside the sector, it is accepted as the anchor candidate of the sector and the walk ends. Otherwise the step is rejected and the walk continues at the next radius. A probe exactly on the spoke can miss a suitable pixel just beside it, so every radius step has up to four _tries_, and each try turns the spoke by a small random _jitter_ before it probes (#ref(<fig-perf-anchor-spokes>)b). // src: APD.cu GenNeighbours at 6ff0e7e^ (:1819-1862); .dev/perf/profiles/static-kernels.md §3

The kernel timeline of Nsight Systems only shows that `GenNeighbours` is expensive: #fix(_an.base.select_s, 1)~s of a run on _pipes_, #pct(_fine, 0) of it in the two finest rounds of the image pyramid. To see what this time is spent on, the kernel was built once more with counters. In the finest round, an unreliable pixel takes on average #fix(_steps, 0) radius steps, and only #fix(_found, 0) of them end with an accepted candidate. Yet it makes #fix(_tries, 0) tries, #fix(_tries / _steps, 1) per step where #fix(_an.spokes.tries, 1) is the maximum. Nearly every radius step therefore fails and uses up all of its tries (#ref(<fig-perf-anchor-spokes>)d). // src: .dev/perf/profiles/instr-counters.md (f); .dev/perf/thesis-4.3/stage-anchor/analysis.md §1; data/kern-per-round.csv (base2)

The code of the kernel explains why the tries of a step fail together. The size of the jitter is an integer that is derived from the width of the sector, and for the narrow sectors of the two finest rounds it is rounded down to zero.#footnote[The jitter is an integer between 0 and $s - 1$ that is added to the direction of the spoke, with $s = max(floor(20 tan(alpha \/ 2)), 1)$ for an angle $alpha$ between two spokes. With the #_sp.spokes.last() spokes of the two finest rounds, $20 tan(alpha \/ 2) = 1.97$ and $s = #_sp.shift_range.last()$.] The #spell(_an.spokes.tries) tries of a step then probe the same pixel and reach the same decision (#ref(<fig-perf-anchor-spokes>)c): when the first try is rejected, the other three are rejected as well. In the finest round, #pct((_tries - _steps) / _tries, 0) of all tries repeat a probe whose outcome is already known. // src: APD.cu at 6ff0e7e^ :1809, :1827-1829; .dev/perf/thesis-4.3/stage-anchor/cards/K3.md §1; .dev/perf/profiles/static-kernels.md §3

The first change makes one try per radius step wherever the jitter is zero. The skipped tries still draw their random numbers and discard them. The generator of a pixel later also supplies the random choices of the RANSAC filtering and of the propagation, so drawing the same numbers keeps every later random decision, and with it the result, unchanged. // src: 6ff0e7e; .dev/perf/thesis-4.3/stage-anchor/cards/K3.md §2, §3

These draws are the second cost. A profile of one launch of the kernel with Nsight Compute shows its second-level cache #pct(_an.k12.ncu.l2_busy.first(), 0) busy. The generator state of a pixel lives in device memory, and the kernel loads and stores it at every draw, because the compiler cannot assume that no other thread sees this memory. The second change copies the state into a local variable when a thread starts, draws from the copy, and writes it back once when the thread ends. The draws and their order are the same. // src: 078d9f8; .dev/perf/thesis-4.3/stage-anchor/cards/K12.md §1-§3

The third change concerns the end of the kernel. The candidates of all sectors are filtered by a RANSAC plane fit and sorted by their distance to the fitted plane, and the #spell(_an.anchors.kept) closest become the anchors of the pixel. The kernel sorted all candidates in the memory of its thread, although only #spell(_an.anchors.kept) entries of the result are used; in a profile of the kernel after the second change, this sort holds #pct(_an.sort.stall_share, 0) of the stall samples. The change keeps only the #spell(_an.anchors.kept) best candidates, in registers, while it goes through them, and it yields the same #spell(_an.anchors.kept) in the same order. // src: 6099c88; .dev/perf/thesis-4.3/stage-anchor/cards/GN-L.md §1-§3; .dev/findings/genneighbours-local-memory.md

`GenNeighbours` time reduces from #fix(_an.base.select_s, 1)~s to #fix(_an.k3.select_s, 1)~s with the first change, to #fix(_an.k12.select_s, 1)~s with the second and to #fix(_an.gnl.select_s, 1)~s with the third (builds 1, 2 and 4 in #ref(<fig-perf-anchor-kernels>)). On top of the changes of #ref(<sec:perf-input>), the first two take the wall time of the whole run from #fix(_an.abl.k3.run_s - _an.abl.k3.run.mean, 1)~s to #fix(_an.abl.k12.run_s, 1)~s, the mean of #spell(_an.abl.n) seeded runs, and the third saves a further #fix(-_an.abl.gnl.run.mean, 1)~s. All three changes are of class E0: with a fixed seed, the fused point cloud is identical byte for byte to that of the baseline, at native resolution and for #spell(_an.abl.k12.md5_seeds) seeds. Together the changes are [+76, -10] lines in the source code. // src: data/kern-anchor2-k3-vs-base2.csv, kern-anchor2-k12-vs-k3.csv; data/kern-gnl-vs-k3.csv; data/ablation.csv (rows K3, K12, GN-L: runtime and md5 of seeds 1-3)

The first two changes are applied in this order for a reason. Applied alone to the baseline, the second change gave a slightly different point cloud at native resolution, although its source computes the same values: the compiler then builds the spoke search with a different mix of floating-point instructions. That the output is identical is therefore a property of the built program, which is checked for every build, and with the first change in place it holds. The gains of these two changes also overlap: in the opposite order, the second change alone removes #fix(_an.order.first.k12_s, 1)~s and the first only #fix(_an.order.first.k3_s, 1)~s more. // src: .dev/perf/thesis-4.3/stage-anchor/cards/K12.md §7; .dev/findings/k12-native-codegen.md; data/kern-k12-2-vs-base2.csv, kern-k3-vs-k1c.csv

==== The nearest table in two passes // 9bac0e6

#let _an = json("../generated/perf-4.3/derived/numbers-anchor.json").v
#let _win = _an.window
// a count with a thousands separator
#let _count(n) = {
  let s = str(n)
  if s.len() > 3 { s.slice(0, s.len() - 3) + "," + s.slice(s.len() - 3) } else { s }
}

When a probe of the spoke search lands on an unreliable pixel, the search takes the nearest reliable pixel of that pixel as its candidate. `FindNearestStrongPoint` provides it: for every unreliable pixel, it stores the nearest reliable pixel inside a window of #_win.side #sym.times #_win.side pixels around it, in the _nearest table_. It is the most expensive kernel of the anchor stage, because it reads the whole window for every unreliable pixel, however close the nearest reliable pixel is. Splitting the search into two one-dimensional passes fills the same table with at most #pct(_win.two_pass_samples / _win.samples, 0) of the reads, and the kernel time, summed over a run on _pipes_, falls from #fix(_an.k12.nearest_s, 1)~s to #fix(_an.k1c.nearest_s, 1)~s.

// A float: the template sets figures in place, which left half a page empty here.
#place(auto, float: true, clearance: 22pt, perf-anchor-nearest-figure)

A profile of one launch with Nsight Compute shows that the kernel is not limited by memory: neighboring pixels read almost the same window, so nearly all reads are served from the cache. It is limited by the number of instructions it executes, and that number does not depend on how close the answer is. All #_count(_win.samples) pixels of the window are read and compared for every unreliable pixel (#ref(<fig-perf-anchor-nearest>)a). The counter build of the previous subsection also recorded how far away the answer is: at the finest level of the image pyramid, the median distance to the nearest reliable pixel is #_win.median_px pixels, while the window reaches #_win.radius pixels in every direction. // src: .dev/perf/thesis-4.3/stage-anchor/cards/K1c.md §1, §3; .dev/perf/profiles/p2-kernels.md (FindNearestStrongPoint: issue bound, 94 % L1 hits); .dev/perf/profiles/instr-counters.md (e)

The change uses the decomposition of separable distance transforms, restricted to the window: two one-dimensional passes replace the two-dimensional scan. The first pass visits every pixel and finds the nearest reliable pixel in the column of that pixel, walking up and down the column, at most #_win.radius rows each way, and stopping at the first one it meets (#ref(<fig-perf-anchor-nearest>)b). The second pass visits every unreliable pixel $p$. It reads the results of the first pass along the row of $p$, one for each column of the window, and keeps the candidate that is nearest to $p$ (#ref(<fig-perf-anchor-nearest>)c). No candidate is lost: whichever reliable pixel is nearest to $p$, it is also the nearest one in its column as seen from the row of $p$, so the first pass has stored it and the second pass finds it. Each pass reads at most #_win.side pixels for a pixel, #_win.two_pass_samples instead of #_count(_win.samples) (#ref(<fig-perf-anchor-nearest>)d). The price is one more byte of device memory per pixel, which holds the result of the first pass. // src: 9bac0e6; .dev/perf/thesis-4.3/stage-anchor/cards/K1c.md §2, §3

The table has to hold exactly the same entries as before, also where two reliable pixels are equally near and the order of the original scan decides between them. The two passes are built to decide such ties in the same way.#footnote[Ties go to the leftmost and then to the upper pixel, as in the original scan. The passes compare integer squared distances where the scan compares square roots, which was verified on the GPU to give the same order.] // src: .dev/perf/thesis-4.3/stage-anchor/cards/K1c.md §2 "Why it is the same entry" (sqrtmono test: 3737 squared distances)

A search that grows outward from the pixel and stops at the first reliable pixel would be the more obvious remedy. It was not built. Of the unreliable pixels, #pct(_win.none_share, 1) have no reliable pixel in their window and would still scan all of it, and on a GPU the threads of a group wait for the slowest among them. The two passes do the same small amount of work for every pixel. // src: .dev/perf/thesis-4.3/stage-anchor/cards/K1c.md §1 "Why K1c and not K1a"; .dev/perf/profiles/instr-counters.md (e)

The gain is build 3 in #ref(<fig-perf-anchor-kernels>), and it is the largest step of the anchor stage: the wall time of the whole run falls from #fix(_an.abl.k12.run_s, 1)~s to #fix(_an.abl.k1c.run_s, 1)~s, the mean of #spell(_an.abl.n) seeded runs. The change is of class E0, that is, the output is identical: with a fixed seed, the fused point cloud is the same byte for byte as that of the baseline, at native resolution and for #spell(_an.abl.k1c.md5_seeds) seeds. The nearest table feeds every launch of the spoke search, so a single different entry would very likely show there. // src: data/kern-anchor2-k1c-vs-k12.csv; data/ablation.csv (row K1c: runtime and md5 of seeds 1-3); .dev/perf/thesis-4.3/stage-anchor/cards/K1c.md §4, §5, §7

==== Tabulated skip-ahead for the random generators // 962aaf4

#let _an = json("../generated/perf-4.3/derived/numbers-anchor.json").v

`InitRandomStates` gives every pixel its own random generator at the start of every reference image pass. Each generator has to start at its own position in the random stream, which is given by the row and the column of the pixel. The library reaches this position by skipping ahead in the stream, with about #_an.init.products_before matrix-vector products per pixel, each on a matrix that is read from device memory. In a profile of the kernel, #pct(_an.init.stall_share, 0) of the stall samples fall into this loop. // src: .dev/perf/thesis-4.3/stage-anchor/cards/IRS.md §1, §3
// NOTE(author): the profile (perf-ncu-native-r1) is from the base before the two
// RescaleMatToTargetSize fixes; the kernel times are from the fixed base.

The skip is a linear map of the generator state, and it is the same for all pixels of a row and for all pixels of a column. The change therefore computes it once per row and once per column, with the functions of the library itself, and stores each result as a matrix. A pixel then applies #spell(_an.init.products_after) matrices where it applied about #_an.init.products_before. The generator states are the same bit for bit, for any seed, so every random number of the run is unchanged; the change is of class E0, checked on the fused point cloud for #spell(_an.abl.irs.md5_seeds) seeds. `InitRandomStates` falls from #fix(_an.gnl.init_s, 1)~s to #fix(_an.irs.init_s, 1)~s (build 5 in #ref(<fig-perf-anchor-kernels>)) for #_an.init.table_mb~MB of tables at native resolution, and the wall time of the whole run from #fix(_an.abl.gnl.run_s, 1)~s to #fix(_an.abl.irs.run_s, 1)~s. // src: 962aaf4; .dev/perf/thesis-4.3/stage-anchor/cards/IRS.md §2, §4, §5; data/kern-irs-vs-gnl.csv; data/ablation.csv (row IRS)

=== Propagation <sec:perf-prop>

// Measured values of this section are read from the generated numbers, not typed:
// generated/perf-4.3/scripts/perf43_json.py writes them, each with its source. Three kinds of
// measurement are used, and they come from different builds:
//   kernel seconds (_pb, _p1 ... _p7)  one run under Nsight Systems, seed 1, of builds that hold the
//                                      propagation changes alone on the baseline (the 8-bit textures:
//                                      on top of all earlier changes);
//   wall time and F1 (_pa)             plain seeded runs of the commits of the final stack, where these
//                                      commits follow the input and anchor changes (data/ablation.csv);
//   counters (_pn)                     one launch in the finest round under Nsight Compute, seed 1.
// The two bases (kernel seconds on the baseline, wall time on the stack) are stated once, in the
// opening paragraph and in the caption of <fig-perf-prop-kernels>; source: the header comment of
// .dev/perf/thesis-4.3/thesis/4.3-prop.typ.
// Paths in the `// src:` comments are relative to .dev/perf/thesis-4.3/stage-prop/ of the
// production-apd-mvs checkout unless they start with data/ (generated/perf-4.3/data) or .dev/;
// "upstream" is benchmark/methods/APD-MVS at b105b0b.
#let _pr = json("../generated/perf-4.3/derived/numbers-prop.json").v
#let (_pb, _p1, _p2, _p3, _p4, _p5, _p6, _p7) = (_pr.base, _pr.k10, _pr.reftex, _pr.k2, _pr.k11, _pr.k7lite, _pr.cu2, _pr.u8)
#let _pa = _pr.abl
#let _pn = _pr.ncu
// the two kernels of the reliability classification that evaluate the same matching cost
#let _pcls(a) = a.depth_to_weak_s + a.local_refine_s
// a difference in F1 with its confidence interval
#let _pf1(s) = [#signed(s.mean, 4) #interval(s, 4)]
// the share of the source images of an unreliable pixel that get a view weight of zero
#let _pzero = 1 - _pr.views.weighted / _pr.views.total
// the share of the evaluations of an unreliable pixel that are only used with their view weight
#let _pweighted = _pr.calls.weighted_only_per_view / (_pr.calls.deformable_per_view + _pr.calls.plain_per_view)

Propagation is the part of an image pass that improves the planes, iteration by iteration (#ref(<alg:apd-imagepass>)). Its kernels take #fix(_pb.prop_s, 1)~s, #pct(_pb.prop_share_of_kernels, 0) of the kernel time of the baseline, and #pct(_pb.weak_share_of_prop, 0) of this is the update of the unreliable pixels. The rest is the update of the reliable pixels and the fit of the planar prior (#ref(<fig-perf-prop-kernels>)).

Both updates spend their time in the matching cost $rho_j (theta)$ (#ref(<apd-mvs-overview>)). One _evaluation_ of this cost scores one candidate plane of a pixel in one source image. It compares a _window_ of samples around the pixel and _fetches_ every sample twice, once from the reference image and once from the source image. For an unreliable pixel, an evaluation also compares an equally large but sparser window at each anchor, so its fetches are scattered over both images (#ref(<fig-perf-prop-cost>)). // src: analysis.md "Sources and conventions", §1; upstream APD.cu :401-530 (ComputeBilateralNCCNew), :531-623 (ComputeBilateralNCCOld)

#place(bottom, float: true, clearance: 22pt, perf-prop-cost-figure)

The update of the unreliable pixels spends its time on these scattered fetches. Many of them miss the first-level cache of the GPU and have to be served by the second-level (L2) cache, and the rate at which this cache serves them limits the kernel. This section shows how this was found, and it removes work in four steps. The window loop of the matching cost issues its fetches one at a time and reads the reference image through an interpolating filter that it does not need. Costs are computed for source images whose weight is zero. The anchors, the cost arrays and the cameras pass through memory more often than necessary. The images take four bytes per pixel where one suffices. Together, the seven changes remove #pct(1 - _p7.prop_s / _pb.prop_s, 0) of the kernel time of the propagation (#ref(<fig-perf-prop-kernels>)). Six of them leave the result identical, or identical up to floating-point rounding (classes E0 and E1). The seventh changes it (class E2), without a measurable effect on the F1-score. // src: analysis.md "Sources and conventions", §1 "Stalls", "Is the weak kernel L2 bound?"; data/kern-k10-2-vs-base2.csv (base_s), kern-8bit-vs-comb-cu2.csv (cand_s); data/ablation.csv (rows IRS, 8-bit); .dev/perf/thesis-4.3/gate-m4-decisions.md items 1, 2; profile perf-ncu-native-r1 (first-level cache hit rate 62 %, numbers-prop.json profile.l1_hit)

#place(auto, float: true, clearance: 22pt, perf-prop-kernels-figure)


==== The window loop of the matching cost: unrolled and a point filter // aebb78f +89,-58; c8c9666 +1,-1

The matching cost calculation is a standalone function. The two updates of the propagation  and the two kernels of the reliability classification (#ref(<sec:perf-class>)) both call it. Therefore, an improvement of it benefits all of these kernels. Its core is a loop over the samples of a window: each turn fetches one sample from the reference image and from the source image and adds it to the sums of the cost. // src: cards/K10.md §6, reftex.md §6; data/kern-k10-2-vs-base2.csv, kern-reftex-2-vs-k10-2.csv (strong: base_s, cand_s)

A profile of the update of the unreliable pixels with Nsight Compute pointed to this loop. #pct(_pr.profile.window_loop_stall_share, 0) of the stalls happen in this kernel, therefore it spends most of its waiting time on the fetches of its windows. The reason is the way the loop is executed. Each turn issues its two fetches and uses their results immediately. A GPU thread executes its instructions in order, so the next turn cannot issue its fetches before these two have arrived, and only one pair of fetches is under way at a time. The compiler cannot reorder the fetches, because the reference code of APD-MVS reads the size of a window at runtime, so the number of turns is unknown when the kernel is compiled. // src: analysis.md §1 "Stalls"; cards/K10.md §1-§3; upstream APD.cu :461-474, :550-574, main.h :76-79

The first change adds compile time constants to the size of the window for the two window sizes that the method uses. The compiler then unrolls the loop and issues all fetches of a window back to back, so that their waiting times overlap. As a result, the update of the reliable pixels falls by #pct(1 - _p1.strong_s / _pb.strong_s, 0), from #fix(_pb.strong_s, 1)~s to #fix(_p1.strong_s, 1)~s (build 1 in #ref(<fig-perf-prop-kernels>)), and the two classification kernels together by #pct(1 - _pcls(_p1) / _pcls(_pb), 0), from #fix(_pcls(_pb), 1)~s to #fix(_pcls(_p1), 1)~s. // src: data/kern-k10-2-vs-base2.csv; cards/K10.md §5, §6; analysis.md §1 "Is the weak kernel L2 bound?"; .dev/findings/l2-throughput-is-tag-requests.md "Facts", "Consequence"

The update of the unreliable pixels, the kernel in which the loop was profiled, gains only #pct(_p1.gain.weak_share, 1), although it executes fewer instructions. The difference lies in where the fetches are served. A fetch that the first-level cache cannot serve becomes a request to the L2 cache. The profiler reports a 31% L2 cache rate for the compact windows of the reliable pixel update, and 71% for the scattered windows of the unreliable pixel update. Overlapping the fetches helps a kernel that waits for each fetch in turn. It does not help a kernel that is limited by the rate at which the L2 cache serves its requests. For the update of the unreliable pixels, a further change therefore helps only if it removes requests. // src: cards/K10.md §3 ("limited by how fast L2 serves scattered texture misses ... which more fetches in flight cannot raise"), §5-§6; analysis.md §1 (the update of the reliable pixels at 31 % on the same counter, before the first change); data/kern-k10-2-vs-base2.csv; ncu perf-ncu-native-r1 (L2 tag rate)

The performance improvement attempt makes the fetch from the reference image lighter. The texture of the reference image was created with linear filtering, like those of the source images, but a window reads it at pixel centers only, where the interpolation of four pixels returns the pixel itself. The change gives the reference image a point filter, which reads one pixel. The update of the unreliable pixels gains only #pct(1 - _p2.weak_s / _p1.weak_s, 1) (build 2), because its requests come mostly from the source images: the fetches from the reference image are mostly served by L1 cache. The two classification kernels, which are not limited by their requests, gain more and fall from #fix(_pcls(_p1), 1)~s to #fix(_pcls(_p2), 1)~s. // src: cards/reftex.md §1-§3, §7; data/kern-reftex-2-vs-k10-2.csv; upstream APD.cpp :601; data/ablation.csv (rows IRS, K10, reftex: runtime and md5 of seeds 1-3); cards/K10.md §7 (nofma identity); .dev/perf/ideas.md row K4 ("ref fetches mostly hit L1, src misses dominate L2"; reference fetch line 6 % of the stall samples against 27 % for the source fetch)

==== Skipping the source images of zero weight // b3fc14a +50,-10

After its view selection, an update gives most source images a view weight of zero, and still evaluates the matching cost in all of them. Thus the third optimization attempt skips the evaluations whose cost is multiplied by zero and takes #pct(_p3.gain.weak_share, 1) off the update of the unreliable pixels. Skipping these evaluations leaves every score unchanged. // src: cards/K2.md §1, §6; data/kern-k2-vs-reftex-2.csv (weak: -delta_s / base_s)

#todo[this figure needs a review]#place(auto, float: true, clearance: 22pt, perf-prop-zero-figure)

An update evaluates its candidate planes in two halves (#ref(<fig-perf-prop-zero>)a). In the first half it evaluates the candidate planes of the anchors in every source image, and the view selection derives the view weights from these costs (#ref(<alg:acmm-pixel>)). In the second half it evaluates the remaining candidates, such as the planar prior, and scores each by the mean of its costs, weighted with the view weights. A cost from a source image of weight zero does not affect this score. A build of the kernels with counters shows that, in the finest round of the image pyramid, #pct(_pzero, 0) of the source images of an unreliable pixel carry a weight of zero. The second half holds half of all evaluations, so #pct(_pweighted * _pzero, 0) of the evaluations of an unreliable pixel compute a cost that is then multiplied by zero (#ref(<fig-perf-prop-zero>)b). // src: cards/K2.md §1; analysis.md §1 "Calls per weak pixel per launch"; .dev/perf/profiles/instr-counters.md (a), scale 0, weak; upstream APD.cu :1362 (8 anchor planes), :1462 (current plane), :917 (fit plane), :958 (5 refined planes), :1502 (plain rewrite); own APD.cu at 1ecaf34 :1557, :1658, :1098, :1139, :1701

==== Anchors, cost arrays and cameras: less memory traffic // 34a9a62 +23,-10; 59532c5 +24,-7; f71b9cc +17,-10

Besides the images, the pixel updates move three kinds of data through memory more often than needed. Three small changes remove this traffic and take another #fix(_p3.prop_s - _p6.prop_s, 1)~s off the propagation kernels (builds 4 to 6 in #ref(<fig-perf-prop-kernels>)). The fourth change reads the positions of the anchors of a pixel once and not in every evaluation. The fifth change no longer initializes those cost arrays of a thread whose entries are all computed before they are read; relative to its size, the update of the reliable pixels gains most from it. The sixth change keeps the cameras in constant memory, as CUMVS does for its own matching kernels. Its gain is small, because the APD-MVS kernels already read the cameras mostly from the L1 cache. // src: cards/K11.md §1-§3, §5; cards/K7lite.md §1-§3, §5 and commit 59532c5 (rows of anchors without a plane are filled, weighted-only vectors not initialized); cards/CU2.md "Credit" (cuda_multi_view_stereo.cu:224-230), §1-§3, §5; data/kern-k11-vs-k2.csv, kern-k7lite-vs-k11.csv, kern-cu2-vs-k7lite.csv; data/ablation.csv (rows K11, K7-lite, CU-2: runtime and md5 of seeds 1-3); upstream APD.cu :395-399, :435, :1005, :1346, :408-410, :538-540
// NOTE(author): dropped after the cold read: the baseline profile that attributes 77% of the
// excessive global-load sectors (ncu "excessive sectors", uncoalesced accesses; textures aside) to
// the anchor re-reads (K11.md §1, perf-ncu-native-r1, base before the RescaleMatToTargetSize
// fixes), and the 1.2 to 1.4 kB that the initialization wrote per thread (K7lite.md §3).

==== Images as 8-bit textures // 1737ce6 +146,-58

The update of the unreliable pixels still dominates the propagation kernels and is still limited by its requests. The last performance improvement attempt stores the images in their data type instead of converting them to 32-bit floats. This reduces the memory footprint of images, and requires fewer requests in the fetches of the windows. It takes #pct(1 - _p7.weak_s / _p6.weak_s, 0) off the kernel, and it is the only change of this section that alters values with which the method computes (class E2). // src: data/kern-cu2-vs-k7lite.csv; data/ncu-*.csv (BlackPixelUpdateWeak, l2_tag_pct 69-73% in builds 3 to 6); cards/8bit.md §1; data/kern-8bit-vs-comb-cu2.csv

#todo[this figure needs a review]#place(auto, float: true, clearance: 22pt, perf-prop-texels-figure)

The L2 cache serves data in sectors of a fixed size, so the number of requests depends on how many pixels a sector holds. In the finest round the grayscale images hold 8-bit integers, but, as in the reference code of APD-MVS, they are uploaded as 32-bit floats per pixel. CUMVS stores the images of its own matching kernels with one byte per pixel, and a sector then holds four times as many pixels (#ref(<fig-perf-prop-texels>)a, b).

In a profiled launch, the requests to the L2 cache fall by #pct(_pn.u8.weak.drop.l2_req, 0) (#ref(<fig-perf-prop-texels>)c), far more than the #pct(1 - _p7.weak_s / _p6.weak_s, 0) by which the kernel gets faster. The limit has moved: the kernel is no longer limited by its requests, and what remains is the latency of the individual fetches and the computation. The peak of the device memory is also reduced by #pct(_pr.u8.pipes_gpu_saved_mib / _pr.u8.pipes_gpu_peak_mib.first().last(), 0), from #fix(_pr.u8.pipes_gpu_peak_mib.first().last() / 1024, 2)~GiB to #fix(_pr.u8.pipes_gpu_peak_mib.last().last() / 1024, 2)~GiB. // src: data/ncu-8bit-vs-comb-cu2.csv (BlackPixelUpdateWeak); cards/8bit.md §5; data/kern-cu2-vs-k7lite.csv (cand_s), kern-8bit-vs-comb-cu2.csv (cand_s); data/ablation.csv (row 8-bit)

The result changes only through the source images. They are read between pixels, and the interpolation of 8-bit values differs from that of 32-bit values in the last bits. Where two candidate planes cost nearly the same, this can decide which of them wins, so the point cloud differs from the baseline. However, the quality is unchanged: over #spell(_pa.f1_n) seeds on _pipes_, the difference in F1 at #_pr.tol.decides_cm~cm against build 6 is #signed(_pa.u8.f1_2cm.mean, 4), with a #_pr.ci_level_pct% confidence interval (#ref(<eq-ci>)) of #interval(_pa.u8.f1_2cm, 4). // src: cards/8bit.md §2, §4 "Reference: exact", "Sources: not exact", "Tier 1"; data/ablation-f1.csv (row 8-bit at 2cm); data/tier1-8bit-vs-comb-cu2.csv (cand_md5, ref_md5)

==== Combined gain

 Together the seven changes take the propagation kernels from #fix(_pb.prop_s, 1)~s to #fix(_p7.prop_s, 1)~s, in [+350, -154] lines of source code. On top of the changes of the previous sections, the wall time of a run falls from #fix(_pa.stage.from_s, 1)~s to #fix(_pa.u8.run_s, 1)~s (the mean of #spell(_pa.n) seeded runs), which is #pct(_pa.u8.run_s / _pr.stack.base_run_s, 0) of the #fix(_pr.stack.base_run_s, 1)~s of the baseline.

=== Reliability classification <sec:perf-class> // 10647e6 +39,-2; a2dfcc4 +8,-1; ce4313e +18,-6; d2dfdff +1,-1; b29db51 +19,-14; fix 1ecaf34 +7,-0

// Measured values of this section are read from the generated numbers, not typed:
// generated/perf-4.3/scripts/perf43_json.py writes them, each with its source.
// Kernel times, the profile and the counters are from the builds on which the changes were made:
// the stack with the propagation changes before the 8-bit textures (5cf8608) and the five builds on
// top of it (2045188, f223fa9, b921d39, 40da3b4, 97809e9). runtimes, the F1 differences and the
// identity checks of the E0 changes are from the final order (_cl.abl.*), where the same commits
// follow the 8-bit textures; on main they are 10647e6, a2dfcc4, ce4313e, d2dfdff, b29db51 and the
// bug fix 1ecaf34 (.dev/perf/thesis-4.3/stack/main-hash-map.md).
#let _cl = json("../generated/perf-4.3/derived/numbers-class.json").v
#let _clb = _cl.prop                       // the build before the changes of this section
#let _clc = _cl.counters                   // counters over all passes of one run, shares in percent
#let _cls = _cl.stall                      // one profiled launch per kernel, shares in percent
#let _clp(x, digits) = [#fix(x, digits)%]  // a share that the data gives in percent

#let _clr = _cls.depth_to_weak             // stall samples of the profiled launch of DepthToWeak, by region, in percent
#let _cl-cost = _clr.window.stall + _clr.geometric.stall + _clr.projection.stall + _clr.setup.stall + _clr.homography.stall

At the end of every reference image pass, the reliability evaluation of #ref(<apd-mvs-overview>) labels each pixel. Two kernels do this work: `DepthToWeak` (#fix(_clb.depth_to_weak_s, 1)~s) samples the cost profile of a pixel and derives its label, and `LocalRefine` (#fix(_clb.local_refine_s, 1)~s) then moves the pixel to a nearby depth if the matching cost there is clearly lower. `LocalRefine` re-evaluates the matching cost at depths where `DepthToWeak` already did making it an easy target to eliminate. `DepthToWeak` itself, however, is only #pct(1 - _cl.c3.depth_to_weak_s / _clb.depth_to_weak_s, 0) faster after the #spell(_cl.changes) changes that were targeting this region (#ref(<fig-perf-class-kernels>)a). // src: data/kern-c2-vs-5cf8608.csv (base_s), kern-c3chain-vs-5cf8608.csv; .dev/perf/thesis-4.3/stage-class/cards/C2.md §1-§3 (2045188: the 11 depths of LocalRefine are samples of DepthToWeak's sweep, for the same pixel, plane and views); upstream APD-MVS APD.cu:2061-2083 against :2203-2216 at b105b0b

#todo[figure may need improvement]#place(auto, float: true, clearance: 22pt, perf-class-kernels-figure)

The reason for not finding opportunities to improve is that `DepthToWeak` is limited by computation, not by memory. Profiling a launch with Nsight Compute shows that #_clp(_cl.ncu.base.depth_to_weak.l1_hit_pct, 0) of the kernel's reads are served by the first-level cache, and #_clp(_cl-cost, 0) of its stall samples are in the evaluation of the matching cost. The kernel does not wait for data, and its own logic around the matching cost is negligible. Its runtime is effectively dominated by the cost of evaluations. The cost of one evaluation was already reduced by the changes of #ref(<sec:perf-prop>), which roughly improved 2x for these two kernels (#ref(<fig-perf-prop-kernels>)). The kernel can therefore only get faster by evaluating less which is hardly possible without changing the result. // src: data/stall-5cf8608-DepthToWeak.csv (regions: window 51.6, geometric cost 16.6, projection of the window samples 10.8, set-up 5.4, homography 2.8 = matching cost; sweep control 5.6, view-weight load 4.4, valley analysis 1.3 = the kernel's own logic; other 1.6); data/ncu-5cf8608.csv; .dev/perf/thesis-4.3/stage-class/analysis.md §7.3 ("Neither is memory bound: they are latency and issue bound"); data/kern-k10-2-vs-base2.csv (93.6 s before the propagation changes)

`DepthToWeak` evaluates the matching cost at #_cl.sweep.samples depths per pixel, in every selected view, and a build with counters shows that more than nine in ten of these evaluations are needed for the label (#ref(<fig-perf-class-kernels>)b). The remaining ones are now skipped, which gains little. A larger gain needs fewer depths, and fewer depths change the labels: in an offline test on the cost profiles of one run, every second depth gave #pct(1 - _cl.c8.step2.agree, 0) of the pixels another label, and the #fix(_cl.c8.win20.samples, 0) nearest depths #pct(1 - _cl.c8.win20.agree, 0). Since the labels decide which pixels get anchors, this is a different method and not a faster classification (class E2), and it is left as future work. // src: data/counters-5cf8608-native-s1.csv (edge_pct 3.3, w0_share_pct 5.4; instrumented build c397c7c on 5cf8608, native, seed 1, all passes); .dev/perf/thesis-4.3/stage-class/analysis.md §7.2, §7.6; cards C1.md, C3.md, K13.md, C9.md; cards/C8.md §2-§6 and data/c8-summary.json (step2: every second sample, win20: the 41 nearest; run at 1024 px, 46.5 million profiles; the script reproduces the label of the kernel for every pixel)

Together, the two kernels go from #fix(_clb.class_s, 1)~s to #fix(_cl.c3.class_s, 1)~s in [+85, -24] lines of source code, and the wall time of a run from #fix(_cl.abl.stage.from_s, 1)~s to #fix(_cl.abl.stage.to_s, 1)~s, the mean of #spell(_cl.abl.n) seeded runs. Three of the changes are of class E0 and two of class E1; the differences in F1 of the latter are well inside the margin of #sym.plus.minus#fix(_cl.margin, 3) of #ref(<sec:perf-prop>).#footnote[The work also exposed a defect that is inherited from the reference code of APD-MVS: when all selected views of a pixel have a weight of zero (#_clp(_clc.wn0_share_pct, 1) of the pixels), `DepthToWeak` divides by zero. Such a pixel is now labeled unreliable explicitly.] // src: data/kern-c3chain-vs-5cf8608.csv; data/ablation.csv (rows 8-bit to fix-d2w: span; rows C1, C9, C3: md5_eq_prev, native, seeds 1-3), ablation-f1.csv (rows C2, K13 at 2cm, five seeds: [-0.0002, +0.0002] and [-0.0002, +0.0003]); cards C2.md §4, K13.md §4, C3.md §4; acceptance.md (Tier 1, +-0.003 at 2 cm); defect: .dev/findings/classification-sweep-m5.md item 2, data/counters-5cf8608-native-s1.csv (wn0_px / swept_px), upstream APD.cu:2052, :2082-2083 against the guard at :2195 at b105b0b, fix 1ecaf34
