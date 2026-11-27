# Old → new hashes: `exp/s43-stack` replayed onto main (`exp/s43-main`)

| | |
|---|---|
| date | 2026-11-19 (Gate 6 item 4) |
| main before | `cad2146` ("typo", on `95c9294`) |
| main after | `1ecaf34` (fast-forward; `exp/s43-main` = main) |
| old tip | `exp/s43-stack` `c20e935` (unchanged) |
| worktree | `/home/gabor/production-apd-mvs-s43main` |
| image / runs | `production-apd-mvs:s43-main-1ecaf34`; `s43-main-native-s1..3` (M6 manifest) |

**What a new hash means.** Each of the 27 commits was cherry-picked on its own onto `cad2146`, message,
author and author date unchanged, author and committer `gaborpelesz <gaborpelesz@gmail.com>`. Every new
commit's tree is the old commit's tree plus the typo commit's three-line rename
(`InuputInitialization` → `InputInitialization` in `APD.cpp`, `APD.h`, `run.cpp`); checked per commit
on the changed lines (`git diff -U0 <old> <new>` = `git diff -U0 95c9294 cad2146`). The comment at
`main.h:105` keeps the old spelling (added by `0e048b4`, not touched by the typo commit).

**Conflicts.** Two, both the rename only: `8f0053b` (timers: the `APD::InuputInitialization()` definition
line in `APD.cpp`, the call line in `run.cpp`) and `0e048b4` (H1: the definition line in `APD.cpp`).
Resolved as the stack's code with the typo fix. No behaviour change.

**Verification scope.** Only the new tip `1ecaf34` was rebuilt and run: native pipes s1–s3 md5
`2459e835` / `e36f6951` / `ae059518` = `c20e935`; spans 530.2 / 529.6 / 529.2 s (analysis runs, ilka0).
The intermediate commits were not rebuilt; they rest on the per-commit diff check. Every run, image and
measurement cited for an earlier commit belongs to the **old** SHA (card SHA or stack SHA). When a
citation is moved to a new SHA, the claim is "same code plus the rename", not "measured on this commit".

**Tags** (annotated, tagger gaborpelesz, not pushed): `s43-base2` → `5fe6882`, `s43-input` → `816fae8`,
`s43-anchor` → `962aaf4`, `s43-propagation` → `1737ce6`, `s43-classification` → `1ecaf34`.

Columns: card = name in `ablation.md` §1; original card SHA = the card's commit on its own branch (for the
four base2 commits it is the same commit as on the stack); stack SHA = `exp/s43-stack`; main SHA =
`exp/s43-main` / main.

| # | card | original card SHA | stack SHA | main SHA | main SHA (full) | subject | tag |
|---|---|---|---|---|---|---|---|
| 1 | base2 (NVTX) | same as stack (`557b2dc`) | `557b2dc` | `0cfd426` | `0cfd4269766e96b0fad71a27f472c261381deff9` | instrumentation: NVTX ranges for phases and APD kernel launches | |
| 2 | base2 (APD_SEED) | same as stack (`b228c67`) | `b228c67` | `4665ae3` | `4665ae3c1da4d2dcabf55107429d346c8152af32` | apd: optional fixed RNG seed through APD_SEED | |
| 3 | base2 (zero-init) | same as stack (`024808a`) | `024808a` | `76cdde4` | `76cdde4d60e2e2450c5874032e6e09b6be431759` | apd: zero-initialize the RescaleMatToTargetSize output | |
| 4 | base2 (row/col scales) | same as stack (`6c1f7b1`) | `6c1f7b1` | `5fe6882` | `5fe68828693b6f34c3566bd28b30939b25c6a76f` | apd: use the row scale for rows and the column scale for columns in RescaleMatToTargetSize | `s43-base2` |
| 5 | timers | `d9d1bf2` | `8f0053b` | `155b82b` | `155b82bce06477ea48361067a2af858c88032799` | apd: input-loading region timers with page-fault counts | |
| 6 | H1 | `774a713` | `0e048b4` | `57c6261` | `57c6261b7bb27ce79a72083529570b414c53fcf6` | apd: convert each image once per run and resize it once per scale | |
| 7 | H2′+H12 | `45acddb` | `da36d0e` | `8bd5505` | `8bd55052bc6988ee239539d059f553c1b810ac7e` | apd: reuse per-pass host buffers, drop read-only clones, fill planes row by row | |
| 8 | H14 | `88adf19` | `0950c04` | `61a5090` | `61a50900505c9a688b500b2d48490ab219e14152` | apd: RescaleMatToTargetSize over rows in parallel, without the source copy | |
| 9 | H3/H6 | `5d0c66f` | `3713d05` | `816fae8` | `816fae8edb7677d76dada355d4013beb5bdfcc6f` | apd: keep device images and depths across passes, pinned planes, parallel readback | `s43-input` |
| 10 | K3 | `10b696d` | `d993a52` | `6ff0e7e` | `6ff0e7e980c503eb88ca00173a462945ffc1ce07` | apd: GenNeighbours probes once per radius when shift_range is 1 | |
| 11 | K12 | `e70d1e9` | `34c4a54` | `078d9f8` | `078d9f888cd55fe8e665ba5f056db93ad879b819` | apd: GenNeighbours keeps its curand state in registers | |
| 12 | K1c | `3a55b7f` | `296a6e0` | `9bac0e6` | `9bac0e66594097352bd6553eb9d61ad788c98265` | apd: FindNearestStrongPoint as a column pass and a row pass | |
| 13 | GN-L | `7d0ae8f` | `4c2203b` | `6099c88` | `6099c8873a6630599d93bd15c8efcf99a19f0c25` | apd: GenNeighbours keeps the eight closest anchors in registers | |
| 14 | IRS | `0e63a9e` | `c42e052` | `962aaf4` | `962aaf4fe820ff4f0c52f674aab959e25ddc1ada` | apd: InitRandomStates applies tabulated skip-ahead matrices | `s43-anchor` |
| 15 | K10 | `ea3bbcb` | `9ad2ad5` | `aebb78f` | `aebb78fa19590db05578828e806a117d422d025f` | apd: NCC window loops unrolled for the configured window sizes | |
| 16 | reftex | `7574477` | `b391004` | `c8c9666` | `c8c96660bfa509ee04f6fba67c0db398a131e0f6` | apd: point-filtered texture for the reference image | |
| 17 | K2 | `065b525` | `5c99601` | `b3fc14a` | `b3fc14ab0460d9b561db186969020b83d30da6f8` | apd: skip the NCC of zero-weight views where only weighted costs are used | |
| 18 | K11 | `60d778f` | `2aa7afc` | `34a9a62` | `34a9a62b9233bf9a06081fa239bf4a68f0d6946a` | apd: weak update reads the pixel's anchors once | |
| 19 | K7-lite | `714ed21` | `9bfecba` | `59532c5` | `59532c5c3e2a85a22248068a99f508fccb281fd3` | apd: propagation fills only the cost entries it reads | |
| 20 | CU-2 | `5cf8608` | `929cb5f` | `f71b9cc` | `f71b9cc5161859c9eeeb162b7eafe8a516047ed6` | apd: cameras of the pass in constant memory | |
| 21 | 8-bit | `ee07854` | `17a3b51` | `1737ce6` | `1737ce6881c9bb3e77b3cc7baa9b641b76f12b57` | apd: 8-bit image textures at native scale | `s43-propagation` |
| 22 | C2 | `e4fd2ce` | `4f797ec` | `10647e6` | `10647e6e544ae805754e13a58f74774f7ae526da` | apd: classification sweep also does LocalRefine's search | |
| 23 | C1 | `a91e2a2` | `0a9d02c` | `a2dfcc4` | `a2dfcc4baf2b51a98f636c1b027d37b463ba2d53` | apd: classification sweep skips samples 0 and 60 | |
| 24 | K13 | `f49c796` | `752e54d` | `ce4313e` | `ce4313efb8164616b9a78f61fa6a42ff34d7e0d8` | apd: classification sweep reads the pixel's view weights once | |
| 25 | C9 | `5ff21fa` | `147e47d` | `d2dfdff` | `d2dfdffc6a6c016794a3e1cff783e5bae304ca1c` | apd: point-filtered textures for the depth maps | |
| 26 | C3 | `1069a53` | `159cfae` | `b29db51` | `b29db51252d67191bc20b52113af267b2f5abfc4` | apd: classification skips the costs of selected views with weight 0 | |
| 27 | bug fix | `e783ac4` | `c20e935` | `1ecaf34` | `1ecaf3435fc5018e2b1c1b8f4d408d89ca427ea6` | apd: DepthToWeak labels a pixel weak when its selected views all have weight 0 | `s43-classification` |
