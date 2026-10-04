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

These runs record totals only, not neighbor lists.

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

### Running headless

To run an experiment from the command line:

```bash
/path/to/NetLogo-7.0.4/netlogo-headless.sh --model SharedPredation.nlogox --experiment Replacement --table replacement.csv
```

Experiments with subexperiments write all their runs to one file. Use the parameter columns to tell the conditions apart.

## Status

This is an unfinished exploratory model. See the Info tab in the model for full documentation.
