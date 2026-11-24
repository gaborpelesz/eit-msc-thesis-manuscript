= Conclusion

- only quantitative analysis, and qualitative would be interesting as well. ETH3D benchmark is biased towards its laser scanners accuracy and completeness, and on specific scenes (playground) parts of the scene is not well covered with ground truth. Also methods are not punished for being eager with their reconstruction around areas where there is no ground truth.

/*
3. Can a systematically engineered, production-grade reimplementation of a recent state-of-the-art method recover a substantial fraction of the runtime and memory cost while preserving its benchmark accuracy?
  - can we find a single change in a lineage shared kernel part (for example in the ACM family) that if we improve, it would improve the perf of all lineage items?

== Preparing for the benchmarking, Findings
1. all nine methods (ACM-family, two HPM, APD, DPE) ship converters that look for `.jpg` images in a case-sensitive manner while ETH3D downloaded images are `*.JPG` with upper-case. Because of this, the converter decodes and re-encodes every image using OpenCV's default JPEG quality, 95. The re-encode changes 46-59% of pixels at 46-50 dB PSNR.
  - CUMVS reads original images and it doesn't re-encode
*/


/*
should answer the RQs directly, say what the work can't claim and list of future work
*/

