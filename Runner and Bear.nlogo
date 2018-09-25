;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; globals
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
globals [current-sensorID observation-buffer roads node-precision file-name bear-obs runner-obs]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; breeds
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
breed [nodes node]
breed [runners runner]
breed [bears bear]
runners-own [to-node from-node v sensor-id heart-rate breed-output-file num-breed]
bears-own [target sensor-id breed-output-file num-breed]


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; setup
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  no-display ; hide display durring setup
  clear-all
  reset-ticks
  random-seed 10
  set observation-buffer []


  if-else path = "square"[

    ask patches with [abs pxcor <= (grid-size) and abs pycor <= (grid-size)][
      sprout-nodes 1 [ set color lime ]
    ]

    ask nodes [
      let neighbor-nodes turtle-set [nodes-here] of neighbors4
      create-links-with neighbor-nodes
      setxy
      (xcor * (max-pxcor - (2 * border)) / (grid-size) + border)
      (ycor * (max-pycor - (2 * border)) / (grid-size) + border)
    ]

    if count nodes > 0 [
      repeat num-runners [ ask one-of nodes [hatch-runners 1
        [ set to-node one-of [link-neighbors] of myself
          set from-node to-node ;; this works because to-node changes on first call to go
          face to-node
      ]]]
      ask runners [ fd random distance to-node]
    ]
    ask links [set color lime]
  ]
  [  ;; else, random walk
    repeat num-runners [ask one-of patches [sprout-runners 1]]
  ]


  ask runners [setup-runners]


  ;;; create the bear
  ask patches with [pxcor = (round ((max-pxcor - min-pxcor) / 2)) and  pycor = (round ((max-pycor - min-pycor) / 2))][
    sprout-bears num-bears [
      set color white
      set size 30
      set shape "wolf 7"
      set heading random 360
      set target  nobody
      set sensor-id create-sensorID
      set breed-output-file (word "bears=" num-bears ".csv")
    ]
  ]

  display ; display final setup

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; go
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go

  no-display

  if-else path != "random"[
    ask runners [
      face to-node
      fd min list v distance to-node
      set v base-velocity + random-float velocity-delta
      if distance to-node < .0001 [ ;; round off error fix
        set from-node to-node
        set to-node one-of [link-neighbors] of to-node
        face to-node ]]
  ][
    ask runners [
      set v base-velocity + random-float velocity-delta
      fd v
      set heading (heading - 1 + random 2) ;; randomize heading to prevent getting stuck in corners
      if-else (abs (xcor - min-pxcor)) < 1 or (abs (xcor - max-pxcor)) < 1[
        set heading (360 - heading )
      ][
        if-else (abs (ycor - min-pycor)) < 1 or (abs (ycor - max-pycor)) < 1[
          set heading (540 - heading )
        ]
        [
          set heading (heading + ((random-normal 90 7) - 90))
      ]]
  ]]

  ask runners[
    set heart-rate 100 + random-poisson 10

    if any? bears with [distance myself < 20][
      set heart-rate heart-rate + 70
    ]
    write-observation-buffer-breed heart-rate
  ]


  ask bears[

    ifelse target = nobody
      [
        ;; random walk
        if-else (abs (xcor - min-pxcor)) < 1 or (abs (xcor - max-pxcor)) < 1[
          set heading (360 - heading)
        ][
          if-else (abs (ycor - min-pycor)) < 1 or (abs (ycor - max-pycor)) < 1[
            set heading (540 - heading )
          ][
            set heading (heading + (random-normal 90 7) - 90)
        ]]

        fd 2

        select-target
    ]
    [ ;; else, follow a runner
      move-towards-target
      select-target
    ]
    write-observation-buffer-breed target

  ]

  display

  if count bears = 1 and count runners = 1 [
    write-observation-runner-with-bear
  ]
  tick
end




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; sub procedures
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



to select-target  ;; bear procedure
  let targets runners in-cone 20 360
  if any? targets [
    set target one-of targets
  ]
end

to move-towards-target  ;; bear procedure
  face target
  set heading (heading + (random-normal 20 10) - 20)
  let delta 1.25 * (random-float velocity-delta) - 1.25 * (random-float velocity-delta)
  fd (base-velocity + delta)
end


to setup-runners
  set color pink
  set size 30
  set shape "person"
  set v base-velocity + random-float velocity-delta
  show-turtle
  set sensor-id create-sensorID
  set heart-rate random-poisson 100
  set breed-output-file (word "runners=" num-runners ".csv")
  set num-breed num-runners
end

to-report create-sensorID
  set current-sensorID current-sensorID + 1
  report current-sensorID
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; file output
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to write-observation-buffer-breed [data]
  let observation (word sensor-id "," breed "," patch-to-lat-long xcor ycor "," ticks "," data)
  if-else breed = runners
    [set runner-obs observation]
  [set bear-obs observation]
  set observation-buffer fput observation observation-buffer
  file-open breed-output-file
  foreach observation-buffer [
    obs -> file-print obs ;; print each observation
    file-flush ;; flush write to file
  ]
  file-close
  set observation-buffer []
end


;; Combined runner and bear observations on one line
to write-observation-runner-with-bear
  let observation (word runner-obs "," bear-obs)
  set observation-buffer fput observation observation-buffer
  file-open (word "runners_and_bears=" num-runners ".csv")
  foreach observation-buffer [
    obs -> file-print obs ;; print each observation
    file-flush ;; flush write to file
  ]
  file-close
  set observation-buffer []
end


to-report patch-to-lat-long [patch-x patch-y]
  if-else WGS84 [
    let x (((patch-x + 0.5) / (max-pxcor + 1)) * 0.02 + -68.67)
    let y (((patch-y + 0.5) / (max-pycor + 1)) * 0.02 + 44.90)
    report (word x ", " y)]
  [
    report (word patch-x ", " patch-y)
  ]
  report "can't convert patch to lat/lon"
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
722
531
-1
-1
0.33
1
10
1
1
1
0
0
0
1
0
511
0
511
1
1
1
ticks
30.0

BUTTON
8
50
74
83
setup
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

BUTTON
134
50
197
83
go
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

BUTTON
73
50
136
83
go
go
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
15
279
187
312
num-runners
num-runners
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
15
311
187
344
base-velocity
base-velocity
0
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
14
343
186
376
velocity-delta
velocity-delta
0
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
15
95
187
128
grid-size
grid-size
0
10
1.0
1
1
NIL
HORIZONTAL

CHOOSER
15
170
185
215
path
path
"square" "random"
0

SWITCH
20
395
123
428
WGS84
WGS84
0
1
-1000

SLIDER
15
125
187
158
border
border
0
200
70.0
10
1
NIL
HORIZONTAL

SLIDER
15
245
187
278
num-bears
num-bears
0
5
1.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model shows runners who are afraid of bears and bears who like to chase runners. 

## HOW IT WORKS

The runners may either run randomly or follow a trail. Here a network of trails are represented by a network grid. 


## HOW TO USE IT

Specify the desired numer of runners and bears and the type of path runners should take (square grid or random walk). 

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

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

banana
false
0
Polygon -7500403 false true 25 78 29 86 30 95 27 103 17 122 12 151 18 181 39 211 61 234 96 247 155 259 203 257 243 245 275 229 288 205 284 192 260 188 249 187 214 187 188 188 181 189 144 189 122 183 107 175 89 158 69 126 56 95 50 83 38 68
Polygon -7500403 true true 39 69 26 77 30 88 29 103 17 124 12 152 18 179 34 205 60 233 99 249 155 260 196 259 237 248 272 230 289 205 284 194 264 190 244 188 221 188 185 191 170 191 145 190 123 186 108 178 87 157 68 126 59 103 52 88
Line -16777216 false 54 169 81 195
Line -16777216 false 75 193 82 199
Line -16777216 false 99 211 118 217
Line -16777216 false 241 211 254 210
Line -16777216 false 261 224 276 214
Polygon -16777216 true false 283 196 273 204 287 208
Polygon -16777216 true false 36 114 34 129 40 136
Polygon -16777216 true false 46 146 53 161 53 152
Line -16777216 false 65 132 82 162
Line -16777216 false 156 250 199 250
Polygon -16777216 true false 26 77 30 90 50 85 39 69

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

cat
false
0
Line -7500403 true 285 240 210 240
Line -7500403 true 195 300 165 255
Line -7500403 true 15 240 90 240
Line -7500403 true 285 285 195 240
Line -7500403 true 105 300 135 255
Line -16777216 false 150 270 150 285
Line -16777216 false 15 75 15 120
Polygon -7500403 true true 300 15 285 30 255 30 225 75 195 60 255 15
Polygon -7500403 true true 285 135 210 135 180 150 180 45 285 90
Polygon -7500403 true true 120 45 120 210 180 210 180 45
Polygon -7500403 true true 180 195 165 300 240 285 255 225 285 195
Polygon -7500403 true true 180 225 195 285 165 300 150 300 150 255 165 225
Polygon -7500403 true true 195 195 195 165 225 150 255 135 285 135 285 195
Polygon -7500403 true true 15 135 90 135 120 150 120 45 15 90
Polygon -7500403 true true 120 195 135 300 60 285 45 225 15 195
Polygon -7500403 true true 120 225 105 285 135 300 150 300 150 255 135 225
Polygon -7500403 true true 105 195 105 165 75 150 45 135 15 135 15 195
Polygon -7500403 true true 285 120 270 90 285 15 300 15
Line -7500403 true 15 285 105 240
Polygon -7500403 true true 15 120 30 90 15 15 0 15
Polygon -7500403 true true 0 15 15 30 45 30 75 75 105 60 45 15
Line -16777216 false 164 262 209 262
Line -16777216 false 223 231 208 261
Line -16777216 false 136 262 91 262
Line -16777216 false 77 231 92 261

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

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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

wolf 7
false
0
Circle -16777216 true false 183 138 24
Circle -16777216 true false 93 138 24
Polygon -7500403 true true 30 105 30 150 90 195 120 270 120 300 180 300 180 270 210 195 270 150 270 105 210 75 90 75
Polygon -7500403 true true 255 105 285 60 255 0 210 45 195 75
Polygon -7500403 true true 45 105 15 60 45 0 90 45 105 75
Circle -16777216 true false 90 135 30
Circle -16777216 true false 180 135 30
Polygon -16777216 true false 120 300 150 255 180 300

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="test2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <enumeratedValueSet variable="num-sensors">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="16"/>
      <value value="32"/>
      <value value="64"/>
      <value value="128"/>
      <value value="256"/>
      <value value="512"/>
      <value value="1024"/>
      <value value="2048"/>
      <value value="4096"/>
      <value value="8192"/>
      <value value="16384"/>
      <value value="32768"/>
      <value value="65536"/>
      <value value="131072"/>
      <value value="262144"/>
      <value value="524288"/>
      <value value="1048576"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="file-number">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SIGSPATIAL 2013" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="107"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="percent-sensing">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="phenomena-type">
      <value value="&quot;radiation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-between-file-write">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-sensors">
      <value value="262144"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="WGS84">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="moving-agents">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="file-number">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grid-size">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="velocity-delta">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="street-network">
      <value value="&quot;cambridge&quot;"/>
      <value value="&quot;japan&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-velocity">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sense-every">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensing">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="6"/>
    <enumeratedValueSet variable="num-sensors">
      <value value="1048576"/>
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
