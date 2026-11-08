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

An image-based stereo reconstruction relies on the parallax effect between images from different viewpoints. Given the camera's internal parameters (intrinsic parameters) and its position and orientation (extrinsic parameters) for the viewpoints, a 3D point can be recovered if its 2D projection (a pixel) is known in at least two viewpoints. Structure from Motion (SfM) is one of the fundamental problems in image-based 3D reconstruction. Its goal is to define an optimization problem to find out the camera's intrinsic calibration matrix and to find the camera extrinsics where the images were taken from. SfM methods work by finding many reliable distinct features across images, matching the corresponding features across images, constructing 2D tracks from the matches, solving for the SfM model from the 2D tracks, and finally, refining the model using bundle adjustment @furukawa2015_mvs_tutorial. Given an initial state for the camera parameters, the optimization can iteratively project the 3D point candidates (calculated from the point correspondences) onto the images, and calculate the error between the point's projected and observed pixel location (reprojection error) @hartley_zisserman_mvg.

Nowadays, a widely used open-source tool for SfM and a general 3D reconstruction pipeline is COLMAP @colmap_sfm. A reliable and accurate SfM reconstruction is key for obtaining an accurate dense 3D representation, often requiring sub-pixel level reprojection errors @furukawa2015_mvs_tutorial. SfM pipelines also produce a set of reliable 3D points that can be utilized in dense reconstruction initialization.

In order to obtain a dense representation of the 3D scene an algorithm has to search through all pixels between views for correspondences and return the matching pixels. Given known camera intrinsics and extrinsics, two-views are enough for a dense reconstruction @scharstein2002_taxonomy @tosi2025_deep_stereo_survey. However, using only two-views can lead to occlusion problems where some parts of objects are not visible.

In a two- or multiple-view stereo setup, matches are found with the help of epipolar geometry @hartley_zisserman_mvg. It defines the geometric constraints that the image of a point on one image is constrained to lie on a line (the epipolar line) on another image which significantly reduces the search space. The general stereo correspondence problem can then be defined as: for each pixel $p_i$ in a reference image $I_r$, find its correspondence on the epipolar line in another image $I_j$ that minimizes the cost.

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

_Multi-View Stereo_ (MVS) is the extension to more than two images and the focus of this thesis. The input of MVS algorithms is a set of images and their corresponding camera parameters. High quality inputs are essential as any errors in earlier stages such as SfM directly bound the achievable quality in MVS @furukawa2015_mvs_tutorial.

Using multiple images has many advantages such as
- Several baselines reduce the matching ambiguity leading to more a precise reconstruction @okutomi1993_multibaseline.
- A point occluded in one view can potentially be matched in others @furukawa2015_mvs_tutorial.
- Frontal views of surfaces often lead to better results @gallup2007_plane_sweeping.

The thesis differentiates between two fundamentally different problems in MVS:
- small-scene or object centric reconstruction, e.g., typically indoor scanning, or object scanning.
- large-scene reconstruction,

The former typically considers relatively small-scale indoor scanning, such as rooms, or scanning objects, usually in more controlled environments. Accurate large-scale unstructured outdoor scene reconstructions pose several challenges over these typical cases. One of these challenges is that objects are typically far away from the imaging device, requiring high-resolution images to be used in MVS. Another challenge is that in many cases, due to the size of the imaged objects compared to the distance from them being imaged, a large number of images are required to cover the scene.

Several taxonomies exist to classify the different approaches of MVS @seitz2006_mvs_evaluation @gipuma. There are two major scene representations of 3D: points and surfaces. Voxel-based reconstructions discretise the scene into a voxel grid volume @steinbrucker2014_volumetric_mapping and optionally fit meshes to extract surfaces @seitz1999_voxel_coloring. Their accuracy is bounded by the voxel grid's resolution. Large-scale high-resolution reconstruction is difficult due to the cubic memory growth in the grid resolution  @shen2013_patchmatch @furukawa2015_mvs_tutorial. Surface evolution methods start from an initial geometric estimate of the imaged 3D object and iteratively deform the representation (such as a mesh, or a visual hull) to maximize photometric-consistency @zaharescu2007_transformesh @furukawa2006_carved_visual_hulls @hernandez2004_silhouette_stereo_fusion. These methods require good initialization for the surfaces which doesn't scale well for larger scenes. Implicit geometry representations, such as level-sets, iteratively evolve a volumetric surface function until it's projection minimizes photometric error and added geometric constraints (smooth curves). More modern approaches use learned Signed Distance Functions for an implicit representation @park2019_deepsdf. Depth map-based methods go through all images and compute a depth map for each of them individually. These depth maps are then fused together into a 3D point cloud eventually yielding a point representation. The images are independent from each other thus the work can be parallelized without the need for updating a global volume. This formulation scales to a very large number of images and therefore became one of the most dominant choices when it comes to large-scale scenes @furukawa2015_mvs_tutorial.

/* maybe also include the modern Gaussian Splatting based mesh reconstruction, which scene representation would it be? How about the Nerfs? */

Local matching methods define a cost to compare candidate correspondences using a photometric error that can be minimized across the epipolar line. This photo-consistency is measuring how similar are two pixels given their surrounding area. However, in many cases the global minimum doesn't yield the true corresponding pixel.

Global matching methods extend the cost function to include an objective for all pixels. They enforce properties like smoothness between neighboring pixels based on the assumption that in general surfaces are piecewise smooth. While global matching works well in a two-view case @scharstein2002_taxonomy, these methods don't scale well to multiple images due to their computational cost and high memory demands in large number of high-resolution images @furukawa2010_cmvs @gipuma.

Classical stereo matching algorithms perform the following steps: matching cost computation, cost aggregation, disparity computation/optimization, and disparity refinement #todo[is this also true for 3D?]. Matching algorithms need to aggregate many candidate hypotheses across the epipolar line. To estimate a depth map, every depth hypothesis needs to be tested for every pixel. The cost computation calculates a cost for all hypotheses $O(W H D)$ and stores them in a cost volume. In this case the depth-range on which the cost is computed is bounded. The cost volume quickly grows by introducing higher resolution images, or by requiring higher precision depth estimates at a larger range.

Computing the cost volume is regularly done by plane sweeping @yang2003_realtime_stereo_gpu @collins1996_space_sweep. The method sweeps through a plane in scene space with some discrete steps. At each step all images are projected onto this plane which are then imaged by the reference camera. At each pixel of the reference camera, intensity similarities are calculated using a photometric cost function in the pixel's local neighborhood, such as averaging Sum-of-Squared Differences (SSD). The costs at each pixel and at each plane step define a 3D cost volume. In a winner-takes-all approach the cost volume is not aggregated and stored but each pixel is updated to carry the currently lowest cost found. Note that plane sweeping carries a fronto-parallel bias, i.e., the search window has an implicit assumption that the corresponding surface is flat and parallel to the reference image plane @gipuma. To improve reconstruction of slanted surfaces #cite(<gallup2007_plane_sweeping>, form: "prose") adds several sweep directions. 

Storing the cost volume is necessary to improve on the winner-takes-all approach. It also requires to define the precision on the depth-range for the optimization. The same problem arises in modern learned MVS approaches @apd, where the cost volume is calculated by a neural network using learned features and regularisation. Even though much progress has been made in order to reduce the memory requirements of these approaches, methods such as @yao2019_rmvsnet @gu2020_casmvsnet can still only compute the depth at a lower resolution or over a low precision depth-range, and has to fine-tune these through costly refinement approaches.

/*
- reference image -> the image being reconstructed
- source images -> the images where we are trying to find the correspondences
 
-  Note that in a two-view case, this is trivial. One can find the epipolar line on the neighbor image, and evaluate all pixels on that line to find a match. It is possible that the point is not visible on the other image which can be filtered out by a threshold on the cost or the strength of the consistency compared to the other candidates. However, MVS problems require going through all pixels in all images and matching that with other pixels in other images which is a really compute-intensive task @gipuma. In case of rectified images (the epipolar line is horizontal) with 2000x1000 pixel resolution, in the naive case this means 2000x1999x1000 = 4 billion comparisons and 4 billion entries in a cost volume. Traditionally, global matching methods calculated the dense cost volume in a predefined depth (or disparity) range. There are sparse and memory efficient approximations, and methods that are using image pyramids to densely sample the search space on a lower resolution example, then restrict the search space around the predicted disparities. These methods can be considered local in the search space. It is easy to see how this approach starts to fail in a large-scale outdoor setting. The depth range is unknown and potentially extremely large growing the cost volumes into unbareable sizes unless the precision is limited. 
*/


== PatchMatch Multi-View Stereo

Exhaustive matching algorithms that require a large portion of the cost volume and thus their memory usage is significant. Another limitation of such methods is the fixed discrete depth range. #cite(<bleyer2011_patchmatch_stereo>, form: "normal") introduced PatchMatch Stereo, an algorithm that estimates a 3D plane at every pixel of a reference image using a randomized iterative approach. The 3D plane esimation is analogous to plane sweeping from infinite directions. It reduces the fronto-parallel bias and directly improves slanted surface reconstruction. The algorithm solves the problem of searching for such planes with an approximate nearest neighbor search across the epipolar line, using PatchMatch @barnes2009_patchmatch. The search space of PatchMatch Stereo is a continuous space, allowing subpixel disparities in the formulation which efficiently describe slanted surfaces. Note, that the algorithm only has to store a small number of current hypotheses and thus significantly reduces the required memory. Therefore, GPU implementations are also more feasible.

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

The main of focus of the thesis are the derived PatchMatch MVS algorithms which became the dominant approach for large-scale complex scenes.

=== Algorithm formulation

Given a reference image $I_r$ and N source views $I_s$ the goal is to find a 3D plane for each pixel $p$ in the reference image. 
The algorithm starts by randomly initializing the current planes in all pixels. The random initialization is controlled so that planes lie within the range of allowed values in the current camera and view configuration. In each iteration, the algorithm goes through all pixels of $I_r$, from top-left to bottom-right, then backwards. For each pixel $p$ it compares the cost of it's spatial neighbors' planes with the cost of it's current plane estimate and updates its plane if the cost is lower using the plane from any of its neighbor. Thus, the algorithm propagates good hypotheses throughout the image, assuming that depth maps are piecewise smooth. After top-to-bottom propagation, the algorithm does a backwards pass bottom-to-top. It does 2-3 full passes over the reference image, which already yields good results. Finally, the algorithm refines the plane estimates by applying small random perturbation to the current estimates and taking these newly generated hypotheses if they reduce the matching cost. @bleyer2011_patchmatch_stereo

- The cost for a pixel and its plane is defined as follows...

One of the core problems of early PatchMatch formulations is the sequential nature of the propagation scheme. Some work has parallelized PatchMatch across rows and columns of images to improve the performance #todo[cite]. @gipuma introduces the checkerboard propagation to parallelize the algorithm which maps well to the multi-core GPU architecture. Their diffusion-like propagation works by calculating the costs and best candidates for half of the pixels at each iteration, and receiving plane candidates from a pixel's 4-neighborhood. 


=== Modern PatchMatch systems

PatchMatch uses the assumption that multiple pixels are present in the scene with similar depth thus a pixel can get good hypotheses by checking neighboring pixels. Empirically, after multiple iteration, the patch-match algorithm converges to a very good depth estimate @gipuma.

Every modern PatchMatch MVS reconstruction systems follow the same stages to compute a 3D point cloud @colmap_mvs:
+ For each _reference image_ $I_r$, an *image-level view selection* algorithm selects $N$ neighbouring _source images_ $I_n$, $n in cal(N)(r)$, from the set of all images $cal(M) = {1, dots, M}$, where $cal(N)(r) subset cal(M) without {r}$ and $|cal(N)(r)| = N$.
+ Given a reference image and its source images, a patch-match-based algorithm iteratively *estimates a depth map and a normal map*.
+ Unreliable or inconsistent estimates are filtered out.
+ Consistent reference and source pixels from the depth maps are fused into a single 3D point cloud.

/*
4. A cost model
Per reference image, cost is pixels × source views × patch taps × iterations × passes. The Literature Review can then place each lineage step as “multiplies term X”, using compendium §2.2’s numbers. That turns a list of papers into an argument.
*/


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
// - It's in Knowledge and Information Systems 52:341–378 and labelled as a survey paper. Its key line: runtimes of one algorithm "can differ by several orders of magnitude due to implementation differences, without actual algorithmic differences". It also argues for exactly your design: compare implementations in the same framework, at the same level of optimisation. Their field is clustering and outlier detection, so cite it as the general precedent, with your thesis as the MVS case.