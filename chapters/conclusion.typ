= Conclusion

- most of the runtime for the algorithm implementations is unnecessary work, and the thesis proves that there is much room for improvement for all methods (all methods because everything derives from the same lineage, improvements can be done even on the core pieces of the systems that are shared among all)
- only quantitative analysis, and qualitative would be interesting as well. ETH3D benchmark is biased towards its laser scanners accuracy and completeness, and on specific scenes (playground) parts of the scene is not well covered with ground truth. Also methods are not punished for being eager with their reconstruction around areas where there is no ground truth.

RQs
- To what extent is the performance decline across successive patch-match MVS algorithms attributable to genuine algorithmic complexity versus inherited implementation inefficiency?
  - no further decline due to implementation inefficiency, algorithms got more complex, but some proved to have improved overall algorithmic performance (MP-MVS)
  - however, all implementations suffer from bad implementation decisions leading them to showcase much worse performances than they could have otherwise
- Which implementation-level factors (memory access patterns, GPU occupancy, redundant computation, data layout, host-device transfers) contribute most to the performance gap in existing reference implementations?
  - The biggest contributing factor in the implementations are
    - host-side data handling, host-device transfer (over 40-50% contributing factor for simpler methods)
    - inefficient GPU kernels (APD example where 94.4 seconds went to 0.1 in the anchor search)
    - improper data type selection (uint8 image improves 17% over APD propagation kernel times without any affect on quality, while also reduces memory usage. This change is applicable to all lineage items except CUMVS)
- Can a systematically engineered, production-grade reimplementation of a recent state-of-the-art method recover a substantial fraction of the runtime and memory cost while preserving its benchmark accuracy?
  - Yes, as it was proven by third-party implementation CUVMS over ACMM, and now proven by CUMVS(APD) which improved 2x over the original method.
- What software engineering and performance optimization practices should the MVS research community adopt to prevent the continued accumulation of avoidable overhead in future methods?
  - More in-depth analysis of their runtimes
  - avoid comparing implementation runtimes while not focusing performance, try to compare algorithmic time complexity instead. Avoid comparing memory usage, as it is highly dependent on the implementation rather focus on establishing the memory complexity model of algorithm.
  - benchmarks should focus on evaluating for runtimes as a secondary goal at least to incentivize the community to develop fast alternatives
  - explicitly state the input image resolution and understand how other methods were measured before comparing the quality or runtime to them
