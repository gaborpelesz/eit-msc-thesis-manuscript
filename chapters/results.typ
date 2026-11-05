#import "../template/elteikthesis.typ": *


= Results & Discussion

3. Can a systematically engineered, production-grade reimplementation of a recent state-of-the-art method recover a substantial fraction of the runtime and memory cost while preserving its benchmark accuracy?
  - can we find a single change in a lineage shared kernel part (for example in the ACM family) that if we improve, it would improve the perf of all lineage items?

== Preparing for the benchmarking, Findings

/*
1. all nine methods (ACM-family, two HPM, APD, DPE) ship converters that look for `.jpg` images in a case-sensitive manner while ETH3D downloaded images are `*.JPG` with upper-case. Because of this, the converter decodes and re-encodes every image using OpenCV's default JPEG quality, 95. The re-encode changes 46-59% of pixels at 46-50 dB PSNR.
  - CUMVS reads original images and it doesn't re-encode
*/

== Benchmarking

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