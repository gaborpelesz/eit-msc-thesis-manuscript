#import "../template/elteikthesis.typ": *

// booktabs-style rules: top, below header, bottom; no vertical lines
#let _rule(w) = table.hline(stroke: w)
#let _group(cols, body) = table.cell(colspan: cols, inset: (top: 6pt, bottom: 3pt), emph(body))
// indent nested phases under their parent span
#let _sub(depth, name) = h(depth * 1em) + raw(name)
// subgroup inside a group: tells how often the phases below it occur
#let _subgroup(cols, body) = table.cell(colspan: cols, inset: (left: 5pt + 1em, top: 5pt, bottom: 2pt),
  text(size: 8pt, emph(body)))

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

Although it is interesting from an algorithm evaluation perspective to observe the behavior of the implementations at lower resolutions, it will also keep the choice of resizing to 3200px or keeping the native resolution parameter. 3D reconstruction software usually provide the ability to (either explicitly or implicitly through "quality" flags) rescale the images to a lower resolution to make the reconstruction faster. Some work also states that their have run at least part of their evaulations on lower resolutions #todo[cite!]. However, only CUMVS and MP-MVS provide a way to set the maximum image size externally, all the other methods' implementations compile this choice into the final program. A selected algorithm will be analysed further in #ref(<selected-method-analysis>).

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

*Run independence and variance estimation*: for proving the independence of runs and finding out the variance to calculate the number of repetitions, a dimensioning @kalibera_rigorous_benchmarking on three factor configurations has been run 15 times per method. The configurations include three selected datasets all downscaled to resolution 1600px for speed: *pipes*, *meadow*, and *office*. The runs were scheduled in a randomized order. Next to wall time, F1 score is also included in the dimensioning as a target measurement because the non-deterministic factors alter the results.

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

The results for the 15 runs are shown in #ref(<fig-dimensioning-run-statistics>). The suggested minimum repetitions for the dimensioning is 30, however, 15 runs across all of the methods already take over 11 hours. Slightly more repetitions in the dimensions would not lower the calculated $n_b$. In the case of the results for most dimensioning runs, $n_b = 5$. However, 15 runs is already a sparser sampling of the variance $s$ which requires more repetitions to achieve the 95% confidence interval. Thus the thesis uses *$n_b = 8$* as the number of repetitions during the benchmarking experiment.


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


== Runtime decomposition, algorithmic cost, and analysis <selected-method-analysis>



== Own implementation...

Itt van az algoritmus leirasa es kidolgozasa

claude: mik azok amik érdekesek lehetnek más szemszögéből, mik azok az angle-ök

/*
instead of Quorum MVS, do an ablation study based on the selected algorithm (for example APD-MVS or MP-MVS). Change only a single component at a time, for example remove the JPEG re-encoding and measure how it affects the system, and move component by component to show how we are slowly improving the system. Move in small iterations and do the same when making the system into a production system. Make sure we stay bit-identical for performance improvements, and make sure we measure as ablation when we are deviating from the original implementation.
*/
#todo[ablation study]

focus on production implementation considerations, plus performance considerations

