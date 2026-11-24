#import "../template/elteikthesis.typ": *
#import "figures/parallax.typ": parallax-figure
#import "figures/epipolar.typ": epipolar-figure

= Background <ch-background>

// | Background (MVS, PatchMatch, GPU model, ETH3D metrics) | 7 |

/*
short 3D reconstruction and Dense MVS intro, contains the formulation of patch match algorithm and focuses on early patch match implementation. Also intros the general structure of MVS programs and ETH3D as a benchmarking target.

make sure we include enough GPU and performance optimization background to cover methodology and results sections. Especially considering the deep analysis.

(budget 7 pages)
*/

== Image-based 3D reconstruction

The goal of 3D reconstruction is to formulate and capture a secondary representation of a scene or objects of the real-world. 3D reconstruction is possible through a wide-range of technique and devices. Active sensing approaches use a camera or similar sensor in combination with emitters or complementary sensors to give range measurements or immediate surface information. These include approaches such as structured light, which uses a camera in combination with a a known projected pattern and derive information from how the pattern is bending on the surfaces, and time-of-flight sensors that typically use an infrared laser to estimate depth based on the round-trip time from emitting the light ray to its reflection on the object hitting the sensor (e.g., LiDAR). Passive sensing approaches focus on existing information, such as natural light, thermal radiation, or other naturally emitted waves. This thesis concentrates on the passive approach where 3D solely from color images captured by ordinary cameras.

#place(auto, float: true, clearance: 22pt, parallax-figure)

An image-based stereo reconstruction relies on the parallax effect between images from different viewpoints. Parallax, as also shown in #ref(<fig-parallax>)b, is the optical effect that describes the relative motion where objects closer to the camera move faster than objects further away. Given the camera's internal parameters (intrinsic parameters) and its position and orientation (extrinsic parameters) relative to the other views, a 3D point can be recovered if its 2D projection (a pixel) is known in at least two viewpoints by _triangulation_ (#ref(<fig-parallax>)a). More precisely, the 3D point is the intersection of 3D lines that go through the optical center and the point's projection on the image plane @hartley_zisserman_mvg. Notice that obtaining a dense 3D representation is fundamentally a search problem between images. Given two images with known camera parameters, triangulation gives the exact 3D position of all observed points if for any pixel of one image, it's corresponding pixel is know on the other. A stereo algorithm has to search through all pixels between views, find the correspondences with the highest likelihood, and return the matching pixels, as shown in #ref(<fig-epipolar>). Utilizing the cameras' known relative position and orientation, an algorithm can reduce the search space using epipolar geometry. This mathematical formulation defines geometric constraints such that a 3D point's projection on one image is contrained to lie on a line (_epipolar line_) on another image @hartley_zisserman_mvg.

#place(auto, float: true, clearance: 22pt, epipolar-figure)

The stereo correspondence problem can then be stated as follows. For a pixel $p$ of a reference image $I_r$ that observes a scene point $X$, its _correspondence_ in another image $I_j$ is the projection $q^*$ of $X$ into $I_j$. It lies on the epipolar line $l_j (p)$, generally at a sub-pixel position, and it does not exist if $X$ is occluded in $I_j$ or projects outside it. Since $X$ is unknown, stereo methods score candidates $q in l_j (p)$ with a _matching cost_ $rho_j (p, q)$. Generally, the matching cost defines the photometric dissimilarity between a window around $p$ in $I_r$ and the corresponding window around $q$ in $I_j$. A low cost indicates that both windows likely observe the same surface, i.e., they are _photo-consistent_. In the naive, approach taking the candidate $q$ of lowest cost at every pixel independently gives the solution (winner-takes-all):

$ hat(q)(p) = op("arg min", limits: #true)_(q in l_j (p)) rho_j (p, q). $ <eq:stereo-correspondence2>

== Multi-View Stereo

_Multi-View Stereo_ (MVS) extends the two-view problem to multiple images, and it is the focus of this thesis. Although two views suffice for dense depth estimation @scharstein2002_taxonomy @tosi2025_deep_stereo_survey, incorporating additional views offer several advantages. First, additional views mitigate occlusion: a surface point that is visible in the reference image but hidden by a foreground object in another. These points are frequently visible in a third view therefore a correspondence can still be established @furukawa2015_mvs_tutorial @colmap_mvs. Second, redundant observations improve precision. Image noise, the sampling of the sensor, and other contributing factors perturb every measurement. When the matching costs of several image pairs are accumulated, the variance of the depth estimate decreases with each additional pair @okutomi1993_multibaseline. Note that systematic errors, such as inaccurate camera calibration, are not averaged out in this way and continue to bound the attainable accuracy. Third, additional views reduce _matching cost ambiguity_, a failure that can happen on repetitive textures creating false matches. A two-view matching cost along the epipolar line may exhibit several comparable minima #todo[may need figure or explanation or reference to other section], while a wrong depth hypothesis rarely remains photo-consistent across multiple views @okutomi1993_multibaseline. Weakly textured regions, by contrast, remain ambiguous regardless of the number of views. Finally, multiple views relax the trade-off governed by the _baseline_, the effective distance between the optical centers that define the triangulation angle (#ref(<fig-epipolar>)). Relative to scene depth, a wide baseline yields a large triangulation angle and therefore precise depth, but it enlarges the disparity range that must be searched @okutomi1993_multibaseline and makes the same surface appear more dissimilar across views @furukawa2015_mvs_tutorial. Therefore matching becomes harder and false matches more likely. A narrow baseline has the opposite effect. Combining near and distant neighbours overcomes this trade-off between precision and correctness @okutomi1993_multibaseline.

The disadvantage of MVS is that the compute cost of matching grows linearly with the number of source views @zheng2014_joint_view_selection @colmap_mvs. Furthermore, not every view is informative for every pixel. A view may be occluded, differently illuminated, captured at a very different resolution, observe the surface at a grazing angle, or simply too close to the reference to provide sufficient parallax @zheng2014_joint_view_selection @colmap_mvs. MVS methods therefore select views at two levels: a set of neighbouring source images per reference image, which bounds the computational cost, and, within this set, the views that enter the matching cost of each pixel, which provides robustness to occlusion and appearance changes @goesele2007_community_mvs @zheng2014_joint_view_selection @colmap_mvs.

So far the assumption was that the camera internal parameters (focus, optical center offset, distortion coefficients) and their relative position and orientation is known. However, if the camera is moving through a scene capturing multiple images, the relative position and orientation of these views are commonly as unknown. Structure from Motion (SfM) finds and uses many reliable distinct features across multiple images to define an optimization problem to find the camera's intrinsic and extrinsic parameters. The algorithm first finds and matches the corresponding features, constructs a 2D track from the matches, and solves an initial SfM model which it then refines using bundle adjustment @furukawa2015_mvs_tutorial. Given an initial state for the camera parameters, the optimization can iteratively project the 3D point candidates (calculated from the point correspondences) onto the images, and calculate the error between the point's projected and observed pixel location (_reprojection error_) @hartley_zisserman_mvg. Nowadays, a widely used open-source tool for SfM and a general 3D reconstruction pipeline is COLMAP @colmap_sfm. A reliable and accurate SfM reconstruction is key for obtaining an accurate dense 3D representation, often requiring sub-pixel level reprojection errors @furukawa2015_mvs_tutorial. SfM pipelines also produce a set of reliable 3D points that can be utilized in dense reconstruction initialization.


/*
#todo[we can also cite 3d_survey2026 to support the learning-based claims]
*/

/*
- reference image -> the image being reconstructed
- source images -> the images where we are trying to find the correspondences
 
-  Note that in a two-view case, this is trivial. One can find the epipolar line on the neighbor image, and evaluate all pixels on that line to find a match. It is possible that the point is not visible on the other image which can be filtered out by a threshold on the cost or the strength of the consistency compared to the other candidates. However, MVS problems require going through all pixels in all images and matching that with other pixels in other images which is a really compute-intensive task @gipuma. In case of rectified images (the epipolar line is horizontal) with 2000x1000 pixel resolution, in the naive case this means 2000x1999x1000 = 4 billion comparisons and 4 billion entries in a cost volume. Traditionally, global matching methods calculated the dense cost volume in a predefined depth (or disparity) range. There are sparse and memory efficient approximations, and methods that are using image pyramids to densely sample the search space on a lower resolution example, then restrict the search space around the predicted disparities. These methods can be considered local in the search space. It is easy to see how this approach starts to fail in a large-scale outdoor setting. The depth range is unknown and potentially extremely large growing the cost volumes into unbareable sizes unless the precision is limited. 
*/


== PatchMatch Multi-View Stereo

The thesis differentiates between two fundamentally different problems in MVS:
- small-scene or object centric reconstructions
- large-scale reconstructions
The former considers relatively small-scale indoor scanning, such as rooms, or scanning objects, usually in more controlled environments (e.g., objects on a turn table). On the other hand, accurate large-scale outdoor scene reconstructions pose several challenges over these typical cases. One of these challenges is that objects are regularly far away from the imaging device, requiring keeping high-resolution imagery during MVS processing. Another challenge is that in many cases a large number of images are required to cover the scene due to the size of the imaged scenes compared to the distance from them being imaged. Examples are reconstructing outdoor urban areas, drone-based mapping solutions, or reconstructing from large collections of unstructured internet photography.

The main of focus of this thesis is an algorithm family called PatchMatch MVS, which became the dominant approach for large-scale complex scenes. #ref(<ch-litreview>) analysis the history of 3D reconstruction algorithms, while this section's goal is to explain PatchMatch without an in-depth review of the long history of its predecessors.

=== Plane-sweeping stereo

=== Fronto-parallel bias (Why patchamtch)

Exhaustive matching algorithms that require a large portion of the cost volume and thus their memory usage is significant. Another limitation of such methods is the fixed discrete depth range. #todo[cite in the form of Bleyer et al. [x]]#cite(<bleyer2011_patchmatch_stereo>, form: "normal") introduced PatchMatch Stereo, an algorithm that estimates a 3D plane at every pixel of a reference image using a randomized iterative approach. The 3D plane esimation is analogous to plane sweeping from infinite directions. It reduces the fronto-parallel bias and directly improves slanted surface reconstruction. The algorithm solves the problem of searching for such planes with an approximate nearest neighbor search across the epipolar line, using PatchMatch @barnes2009_patchmatch. The search space of PatchMatch Stereo is a continuous space, allowing subpixel disparities in the formulation which efficiently describe slanted surfaces. Note, that the algorithm only has to store a small number of current hypotheses and thus significantly reduces the required memory. Therefore, GPU implementations are also more feasible.

/*
- patch match history:
  - PatchMatch algorithm for interactive editing: Barnes et al. 2009
  - Bleyer 2011 slanted planes for stereo, strictly sequential, authors call a GPU port an obvious idea but it is only stated as a future work
  - bailer 2012: row column paralellize (useful info: their depth-map filtering step is dominated by I/O which a production ready implementation can easily resolve by background i/o threads)
  - shen 2013: same seemingly independent paper moving patchmatch from two-views into multi-view. In a sentence, we can state that "Bailer2012 and Shen2013 carried PatchMatch from two-view stereo to multi-view stereo"
  - zhen 2014: single-neighbor alternating sweeps on GPU then they implemented a parallel version of this algorithm that could paralellize across 1 axis of images at the time, doing sweeps.
  - COLMAP uses Zheng sweeps
  - Gipuma 2015: 50s -> 2.7s, a paper with great focus on PatchMatch efficiency, introduced the checkerboard propagation which created a highly efficient MVS algorithm. They also have a fast mode that uses algorithmic approximation
*/


=== PatchMatch algorithm formulation

Given a reference image $I_r$ and N source views $I_s$ the goal is to find a 3D plane for each pixel $p$ in the reference image. 
The algorithm starts by randomly initializing the current planes in all pixels. The random initialization is controlled so that planes lie within the range of allowed values in the current camera and view configuration. In each iteration, the algorithm goes through all pixels of $I_r$, from top-left to bottom-right, then backwards. For each pixel $p$ it compares the cost of it's spatial neighbors' planes with the cost of it's current plane estimate and updates its plane if the cost is lower using the plane from any of its neighbor. Thus, the algorithm propagates good hypotheses throughout the image, assuming that depth maps are piecewise smooth. After top-to-bottom propagation, the algorithm does a backwards pass bottom-to-top. It does 2-3 full passes over the reference image, which already yields good results. Finally, the algorithm refines the plane estimates by applying small random perturbation to the current estimates and taking these newly generated hypotheses if they reduce the matching cost. @bleyer2011_patchmatch_stereo

- The cost for a pixel and its plane is defined as follows...

One of the core problems of early PatchMatch formulations is the sequential nature of the propagation scheme. Some work has parallelized PatchMatch across rows and columns of images to improve the performance #todo[cite]. @gipuma introduces the checkerboard propagation to parallelize the algorithm which maps well to the multi-core GPU architecture. Their diffusion-like propagation works by calculating the costs and best candidates for half of the pixels at each iteration, and receiving plane candidates from a pixel's 4-neighborhood.


=== Modern PatchMatch systems

PatchMatch uses the assumption that multiple pixels are present in the scene with similar depth thus a pixel can get good hypotheses by checking neighboring pixels. Empirically, the patch-match algorithm converges to a very good depth estimate after only a couple iterations @gipuma.

Every modern PatchMatch MVS reconstruction system follows the same stages to compute a 3D point cloud @colmap_mvs:
+ For each _reference image_ $I_r$, an *image-level view selection* algorithm selects $N$ neighbouring _source images_ $I_n$, $n in cal(N)(r)$, from the set of all images $cal(M) = {1, dots, M}$, where $cal(N)(r) subset cal(M) without {r}$ and $|cal(N)(r)| = N$.
+ Given a reference image and its source images, a PatchMatch propagation algorithm iteratively *estimates and refines a depth map and a normal map*.
+ Consistent reference and source pixels from the depth maps are fused into a single 3D point cloud.

/*
4. A cost model
Per reference image, cost is pixels × source views × patch taps × iterations × passes. The Literature Review can then place each lineage step as “multiplies term X”, using compendium §2.2’s numbers. That turns a list of papers into an argument.
*/

==== View selection

In a real-world large-scale reconstruction scenario as well as in larger benchmarks @eth3d_dataset @tanks_and_temples_dataset the covered area can not be observed by all images. Including all images would lead to poor results and ambiguous matches. The goal of image-level view selection is to find a small set of source images that can be used for photo-consistency evalution in the reference image. The algorithm to select views uses the existing SfM reconstruction. Two images that share many _sparse points_ (used in SfM triangulation) observe the same part of the scene with a similar appearance. Dense matching between such views will generally succeed in depth estimation @goesele2007_community_mvs. The number of shared sparse points is not sufficient as it favours nearly co-located cameras whose short baseline leaves depth poorly constrained. Practical view selection scores therefore combine the shared points with the triangulation angle between the cameras. Viewing angle differences of 5-15° are a good compromise between matching reliability and depth precision @furukawa2015_mvs_tutorial. Selecting 5-20 source images per reference is a common practice in most MVS systems @acmh_acmm @acmp @acmmp @apd @hpm @hpm_plusplus @dpe @dvp.

==== Depth-map fusion

A large range of merging techniques has been proposed for fusing depth maps together into a single 3D point cloud. However, PatchMatch MVS methods mostly avoid any complex machinery. Their focus is mostly on generating the best possible depth maps and instead employ basic fusion strategies @gipuma. Depth discontinuities, occlusion boundaries, and distant camera estimates are unreliable in depth maps and they must be suppressed or filtered out for reliable 3D reconstruction @furukawa2015_mvs_tutorial. In the simple consistency-based fusion algorithm, each reference image pixel's depth is checked against all source views. A source view agrees with a depth if the depth estimate at the reference views pixel reprojected into the source, and that source pixel's depth reprojected into the reference agree withing $epsilon$ and their normals within $theta = 10°$. A depth passes the consistency check if at least $n$ source views agree. Typical values for these are $epsilon = 0.01$, $theta = 10°$, and $n = 2$ @acmmp. The advantages of the simple method are that the runtime is negligible compared to the depth estimation @colmap_mvs, and that tuning the parameters to balance accuracy and completeness does not require depth recomputation @gipuma.

/*
Note, colmap MVS claims that the fusion is negligible compared to depth estimation. This is generally not necessarily true in most of the implementations I think, but have to check how it comes out from the benchmarks. It could show that this is an implementation overhead and it should actually be negligible while it isn't.
*/

/*
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

//  Kriegel et al. 2017:
// - It's in Knowledge and Information Systems 52:341-378 and labelled as a survey paper. Its key line: runtimes of one algorithm "can differ by several orders of magnitude due to implementation differences, without actual algorithmic differences". It also argues for exactly your design: compare implementations in the same framework, at the same level of optimisation. Their field is clustering and outlier detection, so cite it as the general precedent, with your thesis as the MVS case.
*/