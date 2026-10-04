# Shared Predation

An incomplete NetLogo model that extends the composite random search model in [Nolting et al. 2015](https://doi.org/10.1016/j.ecocom.2015.03.002) ([code](https://github.com/hinkelman/composite-random-search)) to include a second resource type and examine shared predation: indirect interactions between two resource types that are eaten by the same forager.

Because the resources are clustered in space, these interactions can show up as neighborhood effects, where a resource's risk of being eaten depends on what is near it:

- **Shared doom**: living near a preferred resource raises the chance of being eaten ([Wahl and Hay 1995](https://doi.org/10.1007/BF00329800); [Emerson et al. 2012](https://doi.org/10.1007/s00442-011-2144-4)).
- **Associational refuge**: neighbors lower that chance ([Hay 1986](https://doi.org/10.1086/284593); [Barbosa et al. 2009](https://doi.org/10.1146/annurev.ecolsys.110308.120242)).

## Overview

Foragers search a landscape that holds two resource types, R1 and R2. Each type is placed in clusters using a Neyman-Scott process, and each has its own number of clusters, cluster radius, energy value and handling time.

Foragers use composite random search. Each step length is drawn from a Lévy (Pareto) distribution. After each step, a forager compares the local resource density with a giving-up density:

- **Intensive search** (`intensive-mu`) when local density is above the giving-up density.
- **Extensive search** (`extensive-mu`) when it is below.

A forager that perceives a resource within its perceptual radius moves straight to it. After eating it, the forager stays put for that resource's handling time.

Optional behaviors:

- **`Both-GUD?`**: base the giving-up decision on the combined density of R1 and R2, instead of R1 alone.
- **`Selective?`**: skip an R2 resource when local R1 density is above `rejection-density`.
- **`calculate-neighbors?`**: record how dense the neighborhood around each eaten resource was.

The model tracks total distance moved, handling time, energy gained, the number of R2 resources rejected, and how many of each resource type remain.

## Usage

Requires [NetLogo 7.0.4](https://ccl.northwestern.edu/netlogo/) or later. Open `SharedPredation.nlogox`, click **setup**, then click **go**. The model includes BehaviorSpace experiments, described below.

## Experiments

Every experiment runs for 20,000 ticks with one forager, 15 clusters of each resource type, and R1 as the high-quality resource (energy 100, handling time 10).

### Naming

Most experiment names combine three parts:

- **`Opp` / `Sel`**: `Selective?` off (opportunistic) or on (selective).
- **`Both` / `R1`**: `Both-GUD?` on or off, so the giving-up decision uses R1 + R2 density or R1 density alone.
- **`FocalXAltY`**: `R1-num` = X and `R2-num` = Y. The three levels (125/375, 250/250, 375/125) keep the total at 500.

### Threshold sweeps

These 12 experiments have no suffix (for example `OppBothFocal125Alt375`). They cross `R1-radius` and `R2-radius` {8, 64} with `R2-energy` {10, 100} and `R2-handle` {10, 1000}:

- **`Opp*`**: sweep `giving-up-density` from 1e-7 to 10 (9 levels). 100 repetitions, 14,400 runs each.
- **`Sel*`**: also sweep `rejection-density` over the same 9 levels. 20 repetitions, 25,920 runs each.

These runs record totals only, not neighbor lists. For selectivity, [Selective foraging](#selective-foraging) uses better handling times and thresholds.

### Neighborhood runs

These experiments run one giving-up density per condition, chosen from the sweeps, with 500 repetitions and `calculate-neighbors?` on. They record the type, time of death and neighborhood density of every resource eaten. They don't record survivors' neighborhoods, so on their own they can't show whether neighbors changed a resource's risk (see [Neighbor analysis](#neighbor-analysis)).

- **`Opp*_1-16`**: all 16 radius × energy × handling time conditions, as subexperiments. 8,000 runs each.
- **`Sel*_Subset`**: only the conditions where the forager actually rejects R2 (8 to 11 per experiment). Two cases remain:
  - `R2-handle` = 1000 with `rejection-density` = 0. The forager rejects nearly every R2, so these runs only tell you about R1.
  - `R2-handle` = 10, where selectivity is a real trade-off.

### Associational-effect designs

These experiments compare the two standard designs from [Hambäck et al. 2014](https://doi.org/10.1890/13-0793.1). Both include monoculture controls (other type = 0), so an associational effect is the fraction of a type eaten in the mix minus the fraction eaten alone.

- **`Replacement`**: total resources fixed at 500, with R1:R2 at 0:500, 125:375, 250:250, 375:125 and 500:0. 4,000 runs.
- **`Additive`**: one type fixed at 250, with 0 to 500 of the other added. Each type takes a turn as the focal type. 7,200 runs.

Both use R2 energy 10 and handling time 1000, and cross `R1-radius` and `R2-radius` {8, 64} with `Both-GUD?` on and off. They use 100 repetitions, a giving-up density of 0.01, and record neighbor lists.

With a handling time of 1000, the forager can eat only about 20 R2 per run, so handling time drives most of the effects. **`Replacement-Handle100`** and **`Additive-Handle100`** are identical except that R2 handling time is 100.

To analyze an experiment, pass its output to the matching script in `analysis/`. The scripts name their outputs after the input file:

```bash
Rscript analysis/replacement.R results/replacement-handle100.csv
```

`analysis/compare_handling.R` compares the outputs of both designs at handling times of 1000 and 100.

### Neighbor analysis

The designs above measure associational effects for the whole landscape. The neighbor analysis asks the individual-level question: does a resource's own neighborhood change its chance of being eaten?

Each resource's neighborhood density is calculated once at setup: a Gaussian-weighted count of nearby R1 and R2, using `sigma`. The Handle100 experiments record this density for every eaten resource and, through two extra metrics, for every survivor. Together, the eaten and surviving resources cover the whole population.

`analysis/neighbors.R` uses only mixed runs (both types present):

1. Builds one row per resource with its conspecific density, heterospecific density, and whether it was eaten.
2. Within each run, fits a logistic regression of being eaten on both densities. Each density is scaled by its standard deviation, pooled across runs for that resource type.
3. Averages the per-run coefficients within each combination of focal type, `R1-radius`, `R2-radius` and `Both-GUD?`, with 95% intervals based on run-to-run variation. Runs where too few resources of a type were eaten, or survived, to fit are skipped.

A positive heterospecific coefficient means neighbors of the other type raise risk (shared doom). A negative one means they lower it (associational refuge).

The script also writes the fraction eaten in bins of heterospecific density, as a model-free check:

```bash
Rscript analysis/neighbors.R results/replacement-handle100-neighbors.csv results/additive-handle100-neighbors.csv
```

Neighborhoods are measured at setup and not updated as resources are eaten, and only at the scale set by `sigma`.

#### Results

These results come from the Handle100 experiments: 8,000 mixed runs with `sigma` = 1. Effects are per standard deviation of neighbor density.

- **R2 near R1: shared doom in all 8 settings.** Each SD of nearby R1 raises an R2's odds of being eaten by about 11–25%. The binned fraction eaten rises from about 18–22% with no R1 nearby to 27–36% in the densest R1 neighborhoods. The effect is strongest when the giving-up decision uses R1 alone (`Both-GUD?` off). The forager stays in intensive search near R1, and nearby R2 get eaten along the way.
- **R1 near R2: no associational refuge.** Nearby R2 has no effect in 3 settings (both with `R1-radius` = 8) and raises R1's risk slightly in the other 5 (about 4–9% per SD).
- **R1 near R1: higher risk in all 8 settings.** Dense R1 triggers intensive search.
- **R2 near R2: depends on the giving-up rule.** With `Both-GUD?` on, dense R2 also triggers intensive search, so R2 clumps are riskier (all 4 settings). With it off, R2 clumps don't hold the forager, and clumping lowers risk in 3 settings and has no effect in 1.

Compared with the landscape-level designs:

- R2 shared doom shows up at both scales.
- The R1 refuge in both designs, and the R2 refuge in the additive design, appear only at the landscape level. They come from the time the forager spends handling the other type, not from a resource's own neighbors. An individual R2 near R1 is at higher risk, not lower.

About 3% of runs in a few settings were skipped because too few resources were eaten, or survived, to fit.

#### Multiple scales

The model measures neighborhoods with the forager's `sigma`, which also sets how the forager perceives density, so changing it would change behavior. Instead, the model records `eaten-coords` and the Handle100 experiments record survivors' coordinates. `analysis/neighbor_scales.R` uses these to rebuild each landscape and recalculate densities with the model's kernel at sigma = 0.5, 1, 2, 4, 8, 16 and 32, while the forager's own `sigma` stays at 1. It then fits the same per-run regressions at each scale. At sigma = 1 its uncorrected densities match the model's to within 4e-4, which comes from rounding the coordinates.

By default, the script edge-corrects densities: each is divided by the share of its kernel that falls inside the core (see [Edge effects](#edge-effects)). Add `--uncorrected` to use the model's kernel as is; the outputs are then named `neighbor_scales_uncorrected_*`.

```bash
Rscript analysis/neighbor_scales.R results/replacement-handle100-scales.csv results/additive-handle100-scales.csv
```

Results from a separate set of 8,000 mixed Handle100 runs, with edge-corrected densities:

- **R2 near R1: shared doom at every scale.** It appears in all 8 settings at every scale, except sigma = 0.5 in the 2 settings with R1 radius 64 and R2 radius 8. When R1 is spread out (radius 64), it peaks around sigma = 4. When R1 is tightly clustered (radius 8), it keeps rising to sigma = 32, which may partly reflect position in the landscape (see [Edge effects](#edge-effects)).
- **R1 near R2: no meaningful associational refuge.** The result depends on how R1 is clustered.
  - With R1 radius 8, nearby R2 gives a small refuge only at sigma = 0.5 with `Both-GUD?` off (2 settings). At most other scales it has no effect, with a few small increases in risk.
  - With R1 radius 64, nearby R2 raises R1's risk modestly from sigma = 1 upward.
- **R1 near R1: risk peaks at the scale of an R1 cluster.** In all 8 settings the effect is largest at sigma = 4 and declines beyond it, with no effect at sigma = 32 in 3 settings.
- **R2 near R2 depends on the giving-up rule.**
  - With `Both-GUD?` on, R2 density triggers intensive search, so R2 clumps raise risk at sigma 0.5–8 (peaking around 2–4), with no effect at sigma ≥ 16.
  - With `Both-GUD?` off, R2 clumps never raise risk. The forager doesn't stay in R2 patches, so clumping with other R2 lowers each one's risk or has no effect. This happens at fine scales when R2 is spread out (radius 64) and at middle-to-large scales when R2 is clustered (radius 8).

Without edge correction (`--uncorrected`), every density raised risk for every type at sigma 16–32. The next section shows that this was mostly an edge effect.

#### Edge effects

At large scales, a resource's density mostly reflects where it sits in the landscape. The kernel isn't corrected at the edges, so resources near the center look denser in both types. Foragers start anywhere in the core but are lost at the boundary, so central resources may also simply be found more often. `analysis/edge_effects.R` tests this on the same runs by comparing three per-run models at each scale:

- **Uncorrected:** as in `neighbor_scales.R --uncorrected`.
- **Edge-corrected:** each density divided by the share of its Gaussian kernel that falls inside the core (±50.5). This fixes the undercounting of neighbors near edges.
- **With position:** the uncorrected densities plus each resource's distance to the nearest core edge. This captures the direct effect of being near an edge.

```bash
Rscript analysis/edge_effects.R results/replacement-handle100-scales.csv results/additive-handle100-scales.csv
```

**Position matters a lot.** Pooled across settings, the fraction eaten rises from 21% within 5 units of the edge to 41% at the center for R1, and from 15% to 30% for R2. Each SD of distance from the edge raises the odds of being eaten by about 30% in all settings up to sigma = 16.

At sigma ≤ 4 the corrections barely change the neighborhood effects, so the results at the model's `sigma` = 1 aren't edge artifacts. At sigma 16–32 (8 settings × 2 scales):

| Effect | Settings that raise risk: uncorrected | Edge-corrected | With position | Interpretation |
|---|---|---|---|---|
| R2 near R1 (shared doom) | 16 | 16 (about 30% smaller) | 16 | Real |
| R1 near R2 | 16 | 8 (about 65% smaller) | 14 | Mostly edge |
| R1 near R1 | 16 | 13 (about 65% smaller) | 16 | Mostly real, weaker |
| R2 near R2 | 16 | 0 (none in 13, lowers risk in 3) | 16 | Edge artifact |

So R2 shared doom from nearby R1 holds at every scale, and it is the clearest individual-level effect in the model. R1 still gets no refuge from nearby R2, except at sigma = 0.5 in 2 of 8 settings after edge correction. The position model leaves more of the large-scale effects in place than edge correction does, so some of what remains at the largest scales may still reflect position in the landscape.

### Selective foraging

The `Sel*` sweeps above use R2 handling times of 10, where rejecting R2 rarely pays, and 1000, where the best rule rejects nearly all R2. Most of their rejection thresholds sit in a range where R1 density barely changes behavior. **`Selective-HandleSweep`** uses:

- `R2-handle` {50, 100, 200}, with `R2-energy` 10.
- `rejection-density` {0.01, 0.03, 0.1, 0.3, 1, 3, 10}, which covers where R1 density actually varies at R2 locations, plus 1000 meaning "never reject" as the non-selective baseline.
- `giving-up-density` {1e-4, 1e-3, 0.01, 0.1, 1}.
- Both radii {8, 64}, `Both-GUD?` on and off, and three R1:R2 mixes (125:375, 250:250, 375:125) as subexperiments.
- 20 repetitions: 57,600 runs, about 45 minutes headless.

`analysis/selective.R` takes, for each condition and rejection threshold, the giving-up density that maximizes energy gained. It then compares the best selective threshold with never rejecting. Choosing the best of many noisy combinations inflates its mean, so thresholds are chosen on odd-numbered runs and evaluated on even-numbered runs.

```bash
Rscript analysis/selective.R results/selective-handlesweep.csv
```

#### Results

| R2 handling time | Conditions where selectivity clearly pays | Median energy gain | Median best rejection density |
|---|---|---|---|
| 50 | 3 of 24 | −0.1% | 0.3 |
| 100 | 0 of 24 | +2.4% | 0.1 |
| 200 | 8 of 24 | +9.4% | 0.03 |

- **Selectivity pays mainly when R2 is slow to handle.** As handling time rises, the best rule rejects R2 at lower R1 densities. At handling time 200, this sweep suggested selectivity paid most when R1 was common, but the Handle200 rerun below shows that R1 clustering matters more.
- **Selectivity gives R2 a behavioral refuge** (but see the low-rejection rerun below). At the best threshold, the fraction of R2 eaten falls by a median of about 3 percentage points, and by 7–8 points when R1 is common. This happens even where selectivity doesn't pay in energy. The fraction of R1 eaten rises by 1–5 points, because the forager spends the saved time finding R1. Unlike the handling-time refuges in the associational-effect designs, this one comes from the forager's choices.
- **The comparisons are noisy.** With 10 repetitions per half, the standard error of the gain is often 200–1,500 energy units, about as large as the gains. The best thresholds are scattered across the grid, which suggests the energy surface is fairly flat near its peak.

#### Handle200 rerun

**`Selective-Handle200`** repeats the sweep with `R2-handle` fixed at 200 and 80 repetitions (40 per half): 76,800 runs, about an hour headless. The standard errors of the gains are roughly half those of the sweep.

```bash
Rscript analysis/selective.R results/selective-handle200.csv
```

With more repetitions, selectivity clearly pays in 16 of 24 conditions (8 of 24 in the sweep), with a median energy gain of 13%.

| R1:R2 | Clearly pays | Median gain | Change in fraction of R2 eaten | Change in fraction of R1 eaten |
|---|---|---|---|---|
| 125:375 | 4 of 8 | +11% | −0.02 | +0.03 |
| 250:250 | 8 of 8 | +15% | −0.05 | +0.05 |
| 375:125 | 4 of 8 | +10% | −0.09 | +0.03 |

- **R1 clustering decides whether selectivity pays.** With R1 spread out (radius 64), it pays in all 12 conditions, with median gains of 15–16%. With R1 tightly clustered (radius 8), it pays only at the 250:250 mix. With 125 R1 the gains are positive but uncertain, and with 375 R1 none are clear.
- **`Both-GUD?` makes no difference.** Selectivity pays in 8 conditions with each setting, with median gains of 13–14%.
- **The best threshold is the lowest one tried.** 15 of 24 conditions chose `rejection-density` 0.01, meaning the forager does best rejecting R2 even where R1 is sparse. The low-rejection rerun below shows that the optimum is lower still.
- **The R2 refuge is clear and grows with R1.** The fraction of R2 eaten falls by 1–13 percentage points. It is largest with common, spread-out R1: 10–13 points at 375:125 with R1 radius 64. The fraction of R1 eaten rises by up to 6 points.

#### Low-rejection rerun

**`Selective-Handle200-Low`** repeats `Selective-Handle200` with `rejection-density` {0, 1e-4, 3e-4, 1e-3, 3e-3, 0.01, 0.03}, plus 1000 for never reject. At 0, the forager rejects R2 wherever R1 density is above zero, which is almost everywhere. That's 76,800 runs, about an hour headless.

```bash
Rscript analysis/selective.R results/selective-handle200-low.csv
```

**The best rule is to reject R2 essentially always.** A rejection density of 0 wins in all 24 conditions and clearly pays in every one, with a median energy gain of 51%. Almost no R2 is eaten.

Gain over never rejecting, median across conditions:

| Rejection density | R1 radius 8 | R1 radius 64 | Fraction of R2 eaten (radius 8 / 64) |
|---|---|---|---|
| 0 | +48% | +54% | 0.002 / 0.000 |
| 1e-4 | +15% | +23% | 0.13 / 0.09 |
| 1e-3 | +10% | +20% | 0.14 / 0.11 |
| 0.01 | +11% | +15% | 0.14 / 0.13 |
| 0.03 | +10% | +15% | 0.15 / 0.13 |
| never | 0 | 0 | 0.18 / 0.19 |

At the two thresholds it shares with `Selective-Handle200` (0.01 and 0.03), the results agree closely.

This is the classic prey model of optimal diet theory: a prey type should be ignored whenever its profitability (energy ÷ handling time) is below the intake rate of a forager that ignores it.

- A forager that rejects all R2 gains 0.22–0.90 energy per tick, depending on R1 abundance.
- R2 gives 10 energy for 200 ticks of handling, or 0.05 per tick, so eating any R2 is a loss.
- The density threshold pays only insofar as it approximates never eating R2.

Even at handling time 50, R2's 0.2 per tick is below the lowest specialist rate. So none of the selective experiments so far include a case where eating R2 is worthwhile.

The jump between thresholds 0 and 1e-4 happens because many R2 lie far enough from R1 that their R1 density is tiny but above zero. A threshold of 1e-4 lets the forager eat those R2, while 0 rejects them too.

This changes how to read the selective results above. In these experiments, the R2 "behavioral refuge" is R2 being dropped from the diet altogether. At the best threshold, R2 avoids shared doom only because it isn't eaten at all.

A density-dependent rejection rule could only matter when R2 is profitable enough to be eaten some of the time, with profitability near the specialist intake rate (about 0.2–0.9 per tick here). The profitability sweep below tests that.

#### Profitability sweep

**`Selective-Profitability`** fixes `R2-handle` at 50 and varies `R2-energy` {5, 10, 20, 40, 80}, giving R2 profitabilities of 0.1, 0.2, 0.4, 0.8 and 1.6 per tick. That brackets the specialist rates. Varying energy instead of handling time keeps the time cost of each R2 meal fixed.

- `rejection-density` {0, 1e-4, 1e-3, 0.01, 0.1, 1, 10} plus 1000 (never reject).
- The same giving-up densities, both radii and three mixes as before.
- `Both-GUD?` fixed on, since it made no difference in the Handle200 runs.
- 40 repetitions: 96,000 runs, about 2 hours headless.

`analysis/selective.R` labels the best rule in each condition as "drop R2" (rejection density 0), "density-dependent" or "no clear gain". It also compares the outcome with the prey model, using the specialist rate measured in the rejection-density-0 runs.

```bash
Rscript analysis/selective.R results/selective-profitability.csv
```

Gain from dropping R2 (rejection density 0) over never rejecting, median across conditions:

| R2 profitability (per tick) | 0.1 | 0.2 | 0.4 | 0.8 | 1.6 |
|---|---|---|---|---|---|
| Gain from dropping R2 | +4.8% | +3.0% | −7.8% | −17% | −32% |
| Conditions where selectivity clearly pays | 2 of 12 | 2 of 12 | 0 of 12 | 0 of 12 | 0 of 12 |

- **The prey model gets the direction right.** When R2 is profitable (0.8 and 1.6 per tick), the forager should eat it: rejecting R2 loses energy, and the more R2 it rejects, the more it loses.
- **The forager should switch to dropping R2 at lower profitability than the prey model predicts.** The model says to drop R2 at 0.4 per tick when R1 is common (specialist rates 0.49–0.75), but there, dropping R2 loses 8%. In this model rejecting isn't free: each rejection costs a tick and resets the forager's step. So dropping R2 pays only when R2 is well below the specialist rate.
- **Where dropping R2 pays, the gain is small at this handling time.** It's 3–5%, about the size of the standard error with 20 repetitions per half. At handling time 200 the gain was 51%, because each R2 meal wasted more time.
- **Rejecting R2 only where R1 is dense never wins.** Intermediate thresholds land between always and never rejecting, and none is clearly best in any condition. In this model, what matters is whether to eat R2 at all, as in the prey model, not where to eat it.

Run 23245 hung during setup because of a bug in `add-offspring`, since fixed. It was stopped, so one cell has 39 of its 40 repetitions: R2 radius 8, energy 80, rejection density 0.1, giving-up density 0.001, R1:R2 125:375.

That left one open question: is R2 next to dense R1 protected individually? The next subsection answers it with neighbor data from selective runs.

#### Selective neighbor analysis

**`Selective-Neighbors`** records the same neighbor and coordinate data as the Handle100 experiments, from selective foragers:

- R2 energy 10 and handling time 100, the Handle100 setting where opportunistic foragers cause shared doom for R2.
- `rejection-density` {0.001, 0.01, 0.1, 1} plus 1000 (never reject). The value 0 is left out because it drops nearly all R2, leaving nothing to fit.
- Giving-up density 0.01, R1:R2 250:250, both radii {8, 64} and `Both-GUD?` on and off.
- 100 repetitions: 4,000 runs, about 5 minutes headless.

`analysis/neighbor_scales.R` splits results by rejection threshold when given selective runs. It names those outputs after the input file:

```bash
Rscript analysis/neighbor_scales.R results/selective-neighbors.csv
```

**Selectivity turns shared doom for R2 into a strong associational refuge.** The table gives R2's log-odds of being eaten per SD of nearby R1 (edge-corrected), as the median across the 8 settings. Negative values are a refuge.

| Rejection density | sigma 0.5 | 1 | 2 | 4 | 8 | 16 | Settings showing a refuge |
|---|---|---|---|---|---|---|---|
| 0.001 | −0.84 | −1.65 | −2.39 | −1.29 | −0.66 | −0.40 | 8 of 8 at sigma ≤ 16 |
| 0.01 | −0.80 | −1.15 | −1.41 | −0.86 | −0.47 | −0.25 | 8 of 8 at sigma ≤ 16 |
| 0.1 | −0.57 | −0.94 | −0.91 | −0.52 | −0.29 | −0.15 | 8 of 8 at sigma ≤ 8 |
| 1 | −0.33 | −0.39 | −0.20 | −0.04 | +0.03 | +0.04 | 8 of 8 at sigma ≤ 2 |
| never | +0.07 | +0.18 | +0.24 | +0.27 | +0.25 | +0.20 | none (shared doom in 7–8 of 8) |

- **The refuge strengthens as the threshold drops.** At 0.001, each SD of nearby R1 cuts an R2's odds of being eaten by about 90% at sigma = 2. Never rejecting reproduces the shared doom of the opportunistic Handle100 runs.
- **The refuge is strongest at sigma 1–2 and fades at larger scales.** It reaches further with lower thresholds. This fits the rule, which rejects R2 based on R1 density near the forager, at the forager's own `sigma` of 1.
- **R1 is unaffected.** Nearby R2 slightly raises R1's risk at every threshold (about 0.02–0.14), as it does without selectivity.
- **Selective foragers still eat R2, just not near R1.** Mean R2 eaten per run falls from 61 (never reject) to 38 (threshold 0.001). R1 eaten rises from 79 to 88, and energy gained from 8,505 to 9,156.

The refuge is partly built into the rule, since the forager rejects R2 exactly where R1 is dense. This experiment measures how strong the refuge is and how far it reaches. At threshold 0.001, some settings had as few as 31 of 100 runs with enough R2 eaten to fit, so those estimates are noisier.

Together with the earlier results:

- **An opportunistic forager** causes shared doom for R2 near R1, at the individual level and in replacement designs.
- **A selective forager** gives R2 near R1 an associational refuge that comes from its choices. The R1 refuges seen elsewhere instead come from handling time.

### Running headless

To run an experiment from the command line:

```bash
/path/to/NetLogo-7.0.4/netlogo-headless.sh --model SharedPredation.nlogox --experiment Replacement --table replacement.csv
```

Experiments with subexperiments write all their runs to one file. Use the parameter columns to tell the conditions apart.

## Status

This is an unfinished exploratory model. See the Info tab in the model for full documentation.
