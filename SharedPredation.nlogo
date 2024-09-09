breed [ resources resource ]
breed [ foragers forager ]

foragers-own [
  R1-density                                                          ; Generalized metric of local resource density at current location of forager; only calculated for giving-up density strategy and after resource consumption or after step length completion
  R2-density
  both-density
  search-mode                                                         ; Forager can be in one of 4 behavioral modes: extensive search (random), intensive search (random), direct movement (move directly to known resource location), and handling (not moving)
  step-length                                                         ; Length of step drawn by forager from distribution specified by Levy exponent
  last-handle-counter
  last-resource-handle
  ]

resources-own [
  generation                                                          ; Generation of resource - parent or offspring; used in distributing resources according to Neyman-Scott process (constrained by total number of resources)
  resource-type
  energy
  handle
  rejected?                                                           ; A switch to mark a resource as recently rejected
  R1-neighbors
  R2-neighbors
  both-neighbors
  ]

patches-own [
  R1-field                                                            ; Generalized measure of local resource density; calculated at center of patch; computationally expensive, so only calculated for visualization
  R2-field
  both-field
  ]

globals [                                                             ; Several of these variables are actually state variables for the forager but were treated as globals because they are the same for all foragers and static throughout the simulation (should be changed for increased flexibility)
  cluster-radius                                                      ; Larger of the cluster radii for the two resource types; used for visualizing landscape set-up
  perceptual-radius                                                   ; Perceptual radius where forager knows exact location of resource
  speed                                                               ; Max distance moved per tick by each forager
  sigma
  forager-count
  handling-time
  total-dist                                                          ; Total distance moved by all foragers
  energy-gained                                                       ; Total energy gained by all foragers
  resource-rejections                                                 ; Total number of R2 resources rejected
  step-num                                                            ; Number of steps drawn by all foragers
  death-times
  type-eaten
  R1-neighbor-list
  R2-neighbor-list
  both-neighbor-list
  ]

to setup
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks                                                                  ; "Resets all global variables to zero, and calls reset-ticks, clear-turtles, clear-patches, clear-drawing, clear-all-plots, and clear-output."
  set-globals                                                         ; Initializes values of global variables
  color-landscape                                                     ; Sets color of landscape for visualization
  add-parents
  add-offspring
  ask resources with [generation = "parent"][die]
  repeat forager-num [add-forager]                                    ; Adds foragers to the landscape - preliminary tests indicates that, for example, 1 forager searching for 1000 time steps is the same as 10 foragers searching for 100 time steps
  set forager-count (count foragers)
  if (calculate-neighbors?)[
    calculate-R1-neighbors
    calculate-R2-neighbors
    calculate-both-neighbors
    ]
end

to set-globals
  set perceptual-radius 0.5                                           ; Perceptual radius is initialized to small value to model forager's that are only able to determine the exact resource location in close proximity
  set speed 0.25                                                      ; Speed is set to a value that is a fraction of the perceptual radius to ensure that the forager never steps over any resources (i.e., cruise forager)
  set sigma 1
  set handling-time 0
  set energy-gained 0
  set step-num 0
  set total-dist 0
  set resource-rejections 0
  ifelse (R1-radius >= R2-radius)[set cluster-radius R1-radius][set cluster-radius R2-radius]
  set death-times [ ]
  set type-eaten [ ]
  set R1-neighbor-list [ ]
  set R2-neighbor-list [ ]
  set both-neighbor-list [ ]
end

; Landscape is 113x113 patches (i.e., grid cells) - outer boundary (red patches) absorbs foragers that move onto it leaving 111x111 area for foragers to move throughout
to color-landscape
  ask patches[
    if ( pxcor >= (-50 - cluster-radius) and pxcor <= (50 + cluster-radius) and pycor >= (-50 - cluster-radius) and pycor <= (50 + cluster-radius))  ; max extent of area occupied by parent resources; used for Neyman-Scott process
      [set pcolor blue]
    if ( pxcor >= -56 and pxcor <= 56 and pycor >= -56 and pycor <= 56)                                                                              ; absorbing boundary
      [set pcolor red]
    if ( pxcor >= -55 and pxcor <= 55 and pycor >= -55 and pycor <= 55)                                                                              ; buffer
      [set pcolor yellow]
    if ( pxcor >= -50 and pxcor <= 50 and pycor >= -50 and pycor <= 50)                                                                              ; core area
      [set pcolor green]
    ]
end

to add-parents
  set-default-shape resources "dot"                                     ; Set shape of resources to dot - foragers and resources are actually points, but can be given arbitrary dimensions for visualization
  while [count resources with [resource-type = "R1"] = 0][
    create-resources random-poisson R1-clusters [
      setxy ((random-float (101 + 2 * R1-radius)) - (50.5 + R1-radius)) ((random-float (101 + 2 * R1-radius)) - (50.5 + R1-radius))
      set color orange
      set size 1.5
      set generation "parent"
      set resource-type "R1"
      set energy R1-energy
      set handle R1-handle
      set rejected? false
      ]
    ]
  while [count resources with [resource-type = "R2"] = 0][
    create-resources random-poisson R2-clusters [
      setxy ((random-float (101 + 2 * R2-radius)) - (50.5 + R2-radius)) ((random-float (101 + 2 * R2-radius)) - (50.5 + R2-radius))
      set color white
      set size 1.5
      set generation "parent"
      set resource-type "R2"
      set energy R2-energy
      set handle R2-handle
      set rejected? false
      ]
    ]
end

to add-offspring
  set-default-shape resources "dot"                                     ; Set shape of resources to dot - foragers and resources are actually points, but can be given arbitrary dimensions for visualization
  while [count resources with [generation = "offspring" and resource-type = "R1"] < R1-num][
    ask one-of resources with [generation = "parent" and resource-type = "R1"][
      hatch-resources 1 [
      set color black
      set generation "offspring"
      rt random 360
      fd (random-float R1-radius)
      if ( [pcolor] of patch-here != green)[die]
      ]
    ]
  ]
  while [count resources with [generation = "offspring" and resource-type = "R2"] < R2-num][
    ask one-of resources with [generation = "parent" and resource-type = "R2"][
      hatch-resources 1 [
      set color red
      set generation "offspring"
      rt random 360
      fd (random-float R2-radius)
      if ( [pcolor] of patch-here != green)[die]
      ]
    ]
  ]
end

; Foragers are distributed through a 101x101 patch area centered in the larger 111x111 area according to a random uniform distribution
; Foragers can move through a buffer zone (5 patches wide on all sides) before encountering the landscape boundary
to add-forager
  set-default-shape foragers "dot"                                     ; Set shape of resources to dot - foragers and resources are actually points, but can be given arbitrary dimensions for visualization
  create-foragers 1 [                                                  ; Creates a single forager at a time - looping to create multiple foragers occurs, as needed, in setup procedure
    set color white
    setxy ((random-float 101) - 50.5) ((random-float 101) - 50.5)      ; Choose random coordinate for forager within core area
    set step-length 0                                                  ; Initialize forager's step length to zero indicating that a new step length needs to be drawn
    if (PD?)[pen-down]                                                 ; If true, the forager's path will be traced - visualization purposes only
  ]
end

to go
   while [count foragers < forager-num][
     set forager-count (forager-count + 1)
     add-forager                                                       ; Adds a new forager if one of the previous foragers has been absorbed by the boundary
     ]
   ask foragers [
     ifelse(last-handle-counter >= last-resource-handle)[
       ifelse (any? resources with [not rejected?] in-radius 0.01)[
         recognize-resource
         ][
         set-target
         move
         ]
       ][
       handle-resource
       ]
     if ( [pcolor] of patch-here = red)[die]                          ; If the forager's movements take it to the landscape boundary, then it is removed from the population (absorbing boundary), and replaced the next time through the go procedure
     ]
   tick                                                                ; Advance the tick counter
   if (not any? resources) [ stop ]                                    ; Stops run of simulation if no resources on landscape
   ask resources with [rejected?][if (not any? foragers in-radius perceptual-radius)[set rejected? false]]
end

to recognize-resource
  let closest-resource min-one-of resources [distance myself]         ; Creates an agent set (of one) indicating the identity of the nearest resource
  ifelse ([resource-type] of closest-resource = "R1")[
    consume-resource
    ][
    if(Selective?)[calculate-R1-density]
    ifelse (Selective? and R1-density > rejection-density)[
      ask closest-resource[set rejected? true]
      set resource-rejections (resource-rejections + 1)
      set step-length 0                                                  ; Encounters with resources reset step length and heading; cost of resource recognition (1 time step and reset step); forager doesn't just cruise through areas with low-quality resources
      set-target
      ][
      consume-resource
      ]
    ]
end

to consume-resource
  let closest-resource min-one-of resources [distance myself]          ; Creates an agent set (of one) indicating the identity of the nearest resource
  set last-resource-handle [handle] of closest-resource
  set energy-gained (energy-gained + [energy] of closest-resource)
  set type-eaten lput ([resource-type] of closest-resource) type-eaten
  set R1-neighbor-list lput ([R1-neighbors] of closest-resource) R1-neighbor-list
  set R2-neighbor-list lput ([R2-neighbors] of closest-resource) R2-neighbor-list
  set both-neighbor-list lput ([both-neighbors] of closest-resource) both-neighbor-list
  set death-times lput ticks death-times
  ask closest-resource [die]                                           ; consume resource
  set search-mode "handling"
  set last-handle-counter 1
  set handling-time (handling-time + 1)
end

to handle-resource
  set last-handle-counter (last-handle-counter + 1)
  set handling-time (handling-time + 1)
end

to set-target
  let available-resources (resources with [not rejected?])
  ifelse (any? available-resources in-radius perceptual-radius and search-mode != "direct")[
    let closest-resource min-one-of available-resources [distance myself]       ; Creates an agent set (of one) indicating the identity of the nearest resource
    let dist-near-resource min [distance myself] of available-resources         ; Creates a local variable with the distance from the forager to the nearest resource within its perceptual radius
    face closest-resource                                             ; set the heading of the forager to move directly to the nearest resource, and
    set step-length dist-near-resource                                ; set the step-length of the forager to move the exact distance to the nearest resource
    set search-mode "direct"
    set step-num (step-num + 1)                                       ; increment counter of number of steps drawn
    ][
    if (step-length <= 0)[
      set step-num (step-num + 1)                                     ; increment counter of number of steps drawn
      rt random 360                                                          ; turn right to orient to that heading
      ifelse (Both-GUD?) [
        calculate-both-density
        compare-both-GUD
        ][
        calculate-R1-density
        compare-R1-GUD
        ]
     ]
  ]
end

to compare-both-GUD                                                      ; Compares local resource density to threshold value (i.e., giving-up density)
  ifelse (both-density > giving-up-density )[                        ; If the local resource density > giving-up density
    set search-mode "intensive"                                              ; then search mode is set to intensive
    set step-length levy intensive-mu
    ][
    set search-mode "extensive"                                              ; else the search mode is set to extensive
    set step-length levy extensive-mu
    ]
end

to compare-R1-GUD                                                        ; Compares local resource density to threshold value (i.e., giving-up density)
  ifelse (R1-density > giving-up-density )[                        ; If the local resource density > giving-up density
    set search-mode "intensive"                                              ; then search mode is set to intensive
    set step-length levy intensive-mu
    ][
    set search-mode "extensive"                                              ; else the search mode is set to extensive
    set step-length levy extensive-mu
    ]
end

to calculate-R1-density                                             ; Same process as in visualize-gradient procedure, but saves computational time by only calculating the resource gradient for patches at the current location of the forager (and only after resource consumption or after completing a step)
  set R1-density 0                                                     ; Resets local-density for forager to 0
  let id [who] of resources with [resource-type = "R1"]
  let total count resources with [resource-type = "R1"]
  let k 0
  while [k < total ][         ; Calculate the local-density for forager by looping through all resources and calculating the distance to each resource - resources influence gradient calculation globally, but the weight of the contribution decays with distance as a normal distribution
      set R1-density R1-density + ( (1 / (sqrt(2 * pi) * sigma)) * (R1-energy / R1-handle) * exp(- (([distance myself] of resource (item k id))  ^ 2 )/(2 * (sigma ^ 2)) ))
      set k (k + 1)
    ]
end

to calculate-R2-density                                             ; Same process as in visualize-gradient procedure, but saves computational time by only calculating the resource gradient for patches at the current location of the forager (and only after resource consumption or after completing a step)
  set R2-density 0                                                     ; Resets local-density for forager to 0
  let id [who] of resources with [resource-type = "R2"]
  let total count resources with [resource-type = "R2"]
  let k 0
  while [k < total][         ; Calculate the local-density for forager by looping through all resources and calculating the distance to each resource - resources influence gradient calculation globally, but the weight of the contribution decays with distance as a normal distribution
      set R2-density R2-density + ( (1 / (sqrt(2 * pi) * sigma)) * (R2-energy / R2-handle) * exp(- (([distance myself] of resource (item k id))  ^ 2 )/(2 * (sigma ^ 2)) ))
      set k (k + 1)
    ]
end

to calculate-both-density                                             ; Same process as in visualize-gradient procedure, but saves computational time by only calculating the resource gradient for patches at the current location of the forager (and only after resource consumption or after completing a step)
  calculate-R1-density
  calculate-R2-density
  set both-density (R1-density + R2-density)
end

to calculate-R1-neighbors                                            ; Same process as in visualize-gradient procedure, but saves computational time by only calculating the resource gradient for patches at the current location of the forager (and only after resource consumption or after completing a step)
  ask resources [
    set R1-neighbors 0                                                     ; Resets R1 neighborhood for resource to 0
    ifelse(resource-type = "R1")[
      let id [who] of other resources with [resource-type = "R1"]
      let others count other resources with [resource-type = "R1"]
      let k 0
      while [k <  others][         ; Calculate the local-density for forager by looping through all resources and calculating the distance to each resource - resources influence gradient calculation globally, but the weight of the contribution decays with distance as a normal distribution
        set R1-neighbors R1-neighbors + ( (1 / (sqrt(2 * pi) * sigma)) * exp(- (([distance myself] of resource (item k id))  ^ 2 )/(2 * (sigma ^ 2)) ))
        set k (k + 1)
      ]
      ][
      let id [who] of resources with [resource-type = "R1"]
      let total count resources with [resource-type = "R1"]
      let k 0
      while [k < total ][         ; Calculate the local-density for forager by looping through all resources and calculating the distance to each resource - resources influence gradient calculation globally, but the weight of the contribution decays with distance as a normal distribution
        set R1-neighbors R1-neighbors + ( (1 / (sqrt(2 * pi) * sigma)) * exp(- (([distance myself] of resource (item k id))  ^ 2 )/(2 * (sigma ^ 2)) ))
        set k (k + 1)
      ]
    ]
  ]
end

to calculate-R2-neighbors                                            ; Same process as in visualize-gradient procedure, but saves computational time by only calculating the resource gradient for patches at the current location of the forager (and only after resource consumption or after completing a step)
  ask resources [
    set R2-neighbors 0                                                     ; Resets R1 neighborhood for resource to 0
    ifelse(resource-type = "R2")[
      let id [who] of other resources with [resource-type = "R2"]
      let others count other resources with [resource-type = "R2"]
      let k 0
      while [k < others ][         ; Calculate the local-density for forager by looping through all resources and calculating the distance to each resource - resources influence gradient calculation globally, but the weight of the contribution decays with distance as a normal distribution
        set R2-neighbors R2-neighbors + ( (1 / (sqrt(2 * pi) * sigma)) * exp(- (([distance myself] of resource (item k id))  ^ 2 )/(2 * (sigma ^ 2)) ))
        set k (k + 1)
      ]
      ][
      let id [who] of resources with [resource-type = "R2"]
      let total count resources with [resource-type = "R2"]
      let k 0
      while [k < total][         ; Calculate the local-density for forager by looping through all resources and calculating the distance to each resource - resources influence gradient calculation globally, but the weight of the contribution decays with distance as a normal distribution
        set R2-neighbors R2-neighbors + ( (1 / (sqrt(2 * pi) * sigma)) * exp(- (([distance myself] of resource (item k id))  ^ 2 )/(2 * (sigma ^ 2)) ))
        set k (k + 1)
      ]
    ]
  ]
end

to calculate-both-neighbors
  ask resources [ set both-neighbors (R1-neighbors + R2-neighbors) ]
end

to move                                                                ; Incrementally move the distance of the step length
  ifelse(step-length < speed)[                                         ; If the step length is less than the speed
      fd step-length                                                       ; forager moves forward distance of step length
      set total-dist (total-dist + step-length)
      set step-length 0                                                    ; step length has been completed - new step length will be drawn in next time step (unless forager has detected resource)
    ][
      fd speed                                                             ; forager moves forward distance specified by speed
      set total-dist (total-dist + speed)
      set step-length (step-length - speed)                                ; update distance remaining to be moved by forager along this step
    ]
end

to-report levy[mu]                                                     ; Report step length based on Levy exponent - following Viswanathan et al. Nature 1999
   ifelse(mu <= 1)[
      report random-float 100000000000                                 ; In the limit of mu to 1, the pareto distribution approaches an infinite uniform disitrubition
      ][
      ifelse(mu >= 3)[
         report abs (random-normal 0 1)                                ; In the limit of mu to 3, the pareto distribution approaches a normal distribution
         ][
         let a random-float 1
         report perceptual-radius * exp(ln(a) * (1 / (1 - mu)))        ; Draws step length from pareto distribution with specified exponent - minimum step length is set by perceptual radius
         ]
     ]
end

to visualize-R1-field                                            ; Calculates resource field for all patches on the landscape (except for the patches in the outer boundary) and scales the color of the patch to the value of the resource field
  let arena patches with [pxcor >= -55 and pxcor <= 55 and pycor >= -55 and pycor <= 55]
  ask arena[set R1-field 0]                                    ; Resets resource field for all patches to 0
  let id [who] of resources with [resource-type = "R1"]               ; Creates local list of the ID (i.e., who number) for all resources
  let i -55
  while [i <= 55 ][                                                   ; Loop through all patches (except those in outer boundary) - patches are identified by coordinates for center of patch
    let j -55
    while [j <= 55][
      let k 0
      ask patch i j [
        while [k < count resources with [resource-type = "R1"]  ][      ; Calculate the resource gradient for each patch by looping through all resources and calculating the distance to each resource - resources influence gradient calculation globally, but the weight of the contribution decays with distance as a bivariate normal distribution
          set R1-field R1-field + ( (1 / (sqrt(2 * pi) * sigma)) * (R1-energy) * exp(- 1 * ( ([distance myself] of resource (item k id)) ^ 2 ) / (2 * (sigma ^ 2)) ))
          set k (k + 1)
          ]
        ]
      set j (j + 1)
      ]
     set i (i + 1)
    ]
  let rf-max max ([R1-field] of arena)                         ; Color gradient is set based on the maximum gradient value
  ask arena[set pcolor scale-color (green) R1-field 0 rf-max]          ; lighter colors indicate higher values
end

to visualize-both-field                                            ; Calculates resource field for all patches on the landscape (except for the patches in the outer boundary) and scales the color of the patch to the value of the resource field
  let arena patches with [pxcor >= -55 and pxcor <= 55 and pycor >= -55 and pycor <= 55]
  ask arena[set R1-field 0]
  ask arena[set R2-field 0]
  ask arena[set both-field 0]
  let R1 [who] of resources with [resource-type = "R1"]               ; Creates local list of the ID (i.e., who number) for all resources
  let R2 [who] of resources with [resource-type = "R2"]               ; Creates local list of the ID (i.e., who number) for all resources
  let i -55
  while [i <= 55 ][                                                   ; Loop through all patches (except those in outer boundary) - patches are identified by coordinates for center of patch
    let j -55
    while [j <= 55][
      let k 0
      let l 0
      ask patch i j [
        while [k < count resources with [resource-type = "R1"]  ][      ; Calculate the resource gradient for each patch by looping through all resources and calculating the distance to each resource - resources influence gradient calculation globally, but the weight of the contribution decays with distance as a bivariate normal distribution
          set R1-field R1-field + ( (1 / (sqrt(2 * pi) * sigma)) * (R1-energy / R1-handle) * exp(- 1 * ( ([distance myself] of resource (item k R1)) ^ 2 ) / (2 * (sigma ^ 2)) ))
          set k (k + 1)
          ]
        while [l < count resources with [resource-type = "R2"]  ][      ; Calculate the resource gradient for each patch by looping through all resources and calculating the distance to each resource - resources influence gradient calculation globally, but the weight of the contribution decays with distance as a bivariate normal distribution
          set R2-field R2-field + ( (1 / (sqrt(2 * pi) * sigma)) * (R2-energy / R2-handle) * exp(- 1 * ( ([distance myself] of resource (item l R2)) ^ 2 ) / (2 * (sigma ^ 2)) ))
          set l (l + 1)
          ]
        ]
      set j (j + 1)
      ]
     set i (i + 1)
    ]
  ask arena[set both-field (R1-field + R2-field)]
  let rf-max max ([both-field] of arena)                         ; Color gradient is set based on the maximum gradient value
  ask arena[set pcolor scale-color (green) both-field 0 rf-max]          ; lighter colors indicate higher values
end
@#$#@#$#@
GRAPHICS-WINDOW
220
25
1144
950
-1
-1
4.0
1
10
1
1
1
0
0
0
1
-114
114
-114
114
1
1
1
ticks
30.0

BUTTON
1165
530
1231
563
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
25
90
197
123
R1-clusters
R1-clusters
1
20
15.0
1
1
NIL
HORIZONTAL

SLIDER
25
40
200
73
R1-num
R1-num
100
300
125.0
100
1
NIL
HORIZONTAL

SLIDER
25
140
197
173
R1-radius
R1-radius
8
64
64.0
56
1
NIL
HORIZONTAL

BUTTON
1275
530
1338
563
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
25
475
197
508
extensive-mu
extensive-mu
1
3
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
25
525
197
558
intensive-mu
intensive-mu
1
3
3.0
0.1
1
NIL
HORIZONTAL

SLIDER
25
575
195
608
giving-up-density
giving-up-density
0
1
0.01
0.001
1
NIL
HORIZONTAL

SWITCH
1200
470
1303
503
PD?
PD?
0
1
-1000

SLIDER
25
425
197
458
forager-num
forager-num
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
1165
35
1337
68
R2-num
R2-num
100
300
375.0
100
1
NIL
HORIZONTAL

SLIDER
1165
85
1337
118
R2-clusters
R2-clusters
1
20
15.0
1
1
NIL
HORIZONTAL

SLIDER
1165
135
1337
168
R2-radius
R2-radius
8
64
64.0
56
1
NIL
HORIZONTAL

SLIDER
25
190
197
223
R1-energy
R1-energy
10
100
100.0
90
1
NIL
HORIZONTAL

SLIDER
1165
185
1337
218
R2-energy
R2-energy
10
100
100.0
90
1
NIL
HORIZONTAL

SLIDER
25
625
197
658
rejection-density
rejection-density
0
10
100.0
0.01
1
NIL
HORIZONTAL

SWITCH
55
695
167
728
Selective?
Selective?
1
1
-1000

SLIDER
25
240
197
273
R1-handle
R1-handle
10
1000
10.0
990
1
NIL
HORIZONTAL

SLIDER
1165
235
1337
268
R2-handle
R2-handle
10
1000
1000.0
990
1
NIL
HORIZONTAL

SWITCH
20
295
207
328
calculate-neighbors?
calculate-neighbors?
0
1
-1000

SWITCH
50
755
172
788
Both-GUD?
Both-GUD?
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

This section could give a general understanding of what the model is trying to show or explain.

## HOW IT WORKS

This section could explain what rules the agents use to create the overall behavior of the model.

## HOW TO USE IT

This section could explain how to use the model, including a description of each of the items in the interface tab.

## THINGS TO NOTICE

This section could give some ideas of things for the user to notice while running the model.

## THINGS TO TRY

This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.

## EXTENDING THE MODEL

This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.

## NETLOGO FEATURES

This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.

## RELATED MODELS

This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.

## CREDITS AND REFERENCES

This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

aphid
true
14
Circle -16777216 true true 96 182 108
Circle -16777216 true true 110 127 80
Circle -16777216 true true 110 75 80
Line -16777216 true 150 100 80 30
Line -16777216 true 150 100 220 30

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bean aphid
true
0
Circle -16777216 true false 96 182 108
Circle -16777216 true false 110 127 80
Circle -16777216 true false 110 75 80
Line -16777216 false 150 100 80 30
Line -16777216 false 150 100 220 30

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

egg
true
0
Circle -1184463 true false 105 30 90
Rectangle -1184463 true false 105 75 195 240
Circle -1184463 true false 105 195 90

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

ladybug
true
0
Circle -2674135 true false 22 22 256
Circle -16777216 true false 60 90 60
Circle -16777216 true false 180 90 60
Circle -16777216 true false 60 180 60
Circle -16777216 true false 180 180 60
Line -16777216 false 150 30 150 270

ladybug larva
true
14
Rectangle -16777216 true true 105 60 195 240
Circle -16777216 true true 105 15 90
Circle -16777216 true true 105 195 90
Line -16777216 true 195 60 225 45
Line -16777216 true 195 105 255 120
Line -16777216 true 195 150 240 180
Line -16777216 true 45 120 105 105
Line -16777216 true 105 60 75 45
Line -16777216 true 105 150 60 180

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pea aphid
true
0
Circle -2064490 true false 96 182 108
Circle -2064490 true false 110 127 80
Circle -2064490 true false 110 75 80
Line -2064490 false 150 100 80 30
Line -2064490 false 150 100 220 30

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="OppBothFocal125Alt375" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
      <value value="1.0E-6"/>
      <value value="1.0E-5"/>
      <value value="1.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal125Alt375_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal250Alt250_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppBothFocal375Alt125_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal125Alt375_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal250Alt250_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="OppR1Focal375Alt125_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal125Alt375_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal250Alt250_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelBothFocal375Alt125_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal125Alt375_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal250Alt250_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_1" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="1.0E-5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_2" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_3" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_4" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_5" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_6" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_7" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="1.0E-7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.001"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_8" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_9" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_10" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_11" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_12" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_13" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_14" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_15" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SelR1Focal375Alt125_16" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>forager-count</metric>
    <metric>total-dist</metric>
    <metric>handling-time</metric>
    <metric>resource-rejections</metric>
    <metric>energy-gained</metric>
    <metric>count resources with [resource-type = "R1"]</metric>
    <metric>count resources with [resource-type = "R2"]</metric>
    <metric>death-times</metric>
    <metric>type-eaten</metric>
    <metric>R1-neighbor-list</metric>
    <metric>R2-neighbor-list</metric>
    <metric>both-neighbor-list</metric>
    <enumeratedValueSet variable="R1-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-clusters">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-radius">
      <value value="64"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-num">
      <value value="375"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-num">
      <value value="125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R1-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R2-handle">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calculate-neighbors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forager-num">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="PD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Selective?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Both-GUD?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extensive-mu">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-mu">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rejection-density">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="giving-up-density">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
