#import "figures/perf-ablation.typ": perf-ablation-table
#import "figures/perf-common.typ": fix, pct, spell

// Numbers are read from the generated data, not typed (generated/perf-4.3/scripts/perf43_json.py).
#let _ab = json("../generated/perf-4.3/derived/ablation.json")
#let _ab-base = _ab.rows.first()
#let _ab-last = _ab.rows.filter(r => r.key != "stack").last()

= Ablation of the performance optimizations <app:perf-ablation>

#ref(<table-perf-ablation>) lists the changes of #ref(<sec:perf-input>) to #ref(<sec:perf-class>) one by one, as the #_ab.commits commits in which they are applied to the method. Every commit was built and run with #spell(_ab.n) seeds on ETH3D _pipes_ at native resolution, and each row is compared with the row before it, paired by seed. Over all rows, the run time falls from #fix(_ab-base.run_s, 1)~s to #fix(_ab-last.run_s, 1)~s. // src: .dev/perf/thesis-4.3/stack/ablation.md §1-§3; stack/data/ablation.csv, ablation-f1.csv; thesis draft .dev/perf/thesis-4.3/thesis/4.3-results.typ ("The ablation")

The columns of the table are:
- *Commit*: the commit of the change on the main branch of the method.
- *Measured as*: the commit whose build was run. It holds the same change before the commits were replayed onto the main branch; the two differ only by the correction of a misspelled function name.
- *Class*: the exactness class against the row before, established on the fused point cloud of every seed.
- *Run*: the mean run time with this commit and all commits above it.
- *Change*: the change of the run time against the row before, paired by seed, with its #_ab.ci_level_pct% confidence interval.
- *$bold(Delta)$F1*: the difference in F1 at #_ab.decides_cm~cm against the row before over seeds #_ab.f1_seeds.first() to #_ab.f1_seeds.last(), for the rows that change the result. All intervals lie inside the margin of #sym.plus.minus#_ab.margin (#ref(<sec:perf-prop>)). For a row marked with †, the F1 of some seeds on one side of the pair comes from a row with the same point cloud, with only commits of class E0 in between, and not from a run of the row itself.
The last row repeats the last commit with fresh runs of the final image. // src: .dev/perf/thesis-4.3/thesis/chapters/figures/perf-ablation.typ (caption of the draft table); stack/ablation.md §3 ("bridged" seeds); stack/main-hash-map.md

#perf-ablation-table
