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

Requires [NetLogo 7.0.4](https://ccl.northwestern.edu/netlogo/) or later. Open `SharedPredation.nlogox`, click **setup**, then click **go**. The model includes BehaviorSpace experiments for parameter sweeps.

## Status

This is an unfinished exploratory model. See the Info tab in the model for full documentation.
