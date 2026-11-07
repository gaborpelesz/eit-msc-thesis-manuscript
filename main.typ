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

#include "chapters/background.typ"
#include "chapters/literature_review.typ"
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
