= Introduction

An ordinary photograph is one of the richest while cheapest records of the world. High-resolution cameras cost little, work almost anywhere, and capture a scene in an instant. However, what they capture is mostly unstructured data arriving as millions of raw pixels in a grid that depend on each other in highly complex ways. Recovering information from such grids has occupied computer vision for as long as there have been computers.


Many applications of computer vision are interested in the retrieval of 3D information from images. While a camera projects down a 3D scene into a 2D plane effortlessly, moving in the opposite direction has a long history of challenges. The core problem is that information about the distance of an object point to the camera is missing. One remedy is to control or have a priori information about the environment being captured, another is to simply take more images. Both of them can turn a camera into a precise measurement system. Finding lines that are parallel in 3D can recover structure up to scale, while a measurement tape layed out in the scene reveals information about the size of each object on it. On the other hand, several views of the same scene mathematically constrain each other through perspective geometry, and under these constraints a handful of photographs can recover the exact 3D surface. Such techniques are fundamental in computer vision, and are being used from detecting faults in a manufacturing lines, to supporting autonomous navigation through complex unknown environments. @hartley_zisserman_mvg

Besides their abilities to collect vast amount of information in milliseconds, produced images are heavy in data quantity. Computer vision and high-performance computing have therefore long travelled together, and runtime is regularly among the requirements of an image-based system.

This thesis explores the runtime performance of modern algorithms that recover dense 3D structure from plain color images. The work starts by introducing the basics of 3D reconstruction in #ref(<ch-background>), focusing on dense recovery from multiple images using the PatchMatch technique. Next, #ref(<ch-litreview>) explores the history of approaches and introduces an algorithm lineage that descends from PatchMatch-based 3D reconstruction. The lineage consists of state-of-the-art algorithms that one-by-one improve on public benchmarks. However, the benchmarks that drive the field rank methods by quality alone, and the runtime cost of reconstructing a scene with these methods has grown from minutes to hours. The thesis asks the following questions:
1. How much of this runtime cost belongs to the algorithms, and how much to the way they were implemented?
2. Which implementation-level factors contribute the most to the performance gap in existing reference implementations?
3. Can a systematically engineered reimplementation recover substantial fraction of the runtime cost while preserving benchmark accuracy?
4. What software engineering and performance optimization practices should the community adopt to prevent the continued accumulation of overhead?

To answer these questions, #ref(<ch-methodology>) describes a production-ready integration of one state-of-the-art approach and demonstrates several performance optimization attempts that significantly reduce the runtime. As its core contribution, the thesis shows that substantial portion of runtime can be recovered using only minor improvements while keeping the quality intact. In #ref(<sec:methodology-benchmarking>), the work verifies the gains by defining a comprehensive benchmarking system where among the improved version, 10 of the top performing classical algorithms are analysed. The analysis identifies the high-level runtime contributing factors and examines the results.

In #ref(<ch-results>), the thesis demonstrates through its own improvements that runtime comparisons are impractical unless more attention is payed to implementation details. Additionally, the results suggest that the performance that the analysed methods achieve is far from their true potential. A fact that is key to understand when making decisions on algorithm choices based on observed or published runtime results.


/*
// The paper says its 24 MP images “encourage the development of memory and computationally efficient methods which can handle very large datasets.” The benchmark’s own authors expected efficiency to be rewarded.
- Another important event was that Schöps et al., CVPR 2017 introduced ETH3D dataset which created an easy way to measure algorithmic performance and with it, and with this dataset, dozens of algorithms were released with papers competing with each other on the benchmarks.

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

- The benchmarks doesn't measure and score algorithmic or implementation efficiency, ACM-family was built on Gipuma, then the contenders started to tweaking the original ACM algorithms further and further with introducing more and more constraints into the algorithm such as multiple-scales (adding more iterations), geometric consistency (adding another geometric consistency propagation after the photometric consistency), planar priors (stricter loss function), confidence sweeps (new postprocessing), DL priors (additional deep learning pre-processing), leading to higher quality in the benchmarks but also making them infeasible in production-grade large-scale photogrammetry problems due to increased runtime. Today's top 10 ETH3D are all PatchMatch hybrids led by DVP-MVS++ at 90.23 2cm f1 score.
*/
