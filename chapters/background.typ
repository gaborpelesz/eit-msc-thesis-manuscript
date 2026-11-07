#import "../template/elteikthesis.typ": *

= Background

// | Background (MVS, PatchMatch, GPU model, ETH3D metrics) | 7 |

/*
short 3D reconstruction and Dense MVS intro, contains the formulation of patch match algorithm and focuses on early patch match implementation. Also intros the general structure of MVS programs and ETH3D as a benchmarking target.

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


== PatchMatch Multi-View Stereo

The focus of this thesis is the PatchMatch MVS algorithm family that is the dominant approach for large-scale complex scenes.

=== PatchMatch Two-View formulation

The algorithm starts from randomly initialized plane parameter image. Starting from the top-left image, for each pixel it calculates it's own matching cost, and the matching cost of its top and left neighbors. It updates its own plane parameter estimates if the matching cost is better for either of its neighbors. This way it propagates good hypotheses. The algorithm then does a backwards pass, where it starts from the bottom right pixel. It does 2-3 full passes over the reference image, which already yields good results @zheng2014_joint_view_selection @colmap_mvs.

=== Checkerboard propagation

Gipuma @gipuma introduces the checkerboard propagation to parallelize the algorithm which maps well to the multi-core GPU architecture. Their diffusion-like propagation works by calculating the costs and best candidates for half of the pixels at each iteration.


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
