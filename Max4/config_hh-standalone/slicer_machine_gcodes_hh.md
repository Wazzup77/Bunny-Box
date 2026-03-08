<p align="center">
  <h1 align="center"> Max4 Happy Hare Standalone Slicer Machine G-Codes</h1>
</p>

# MACHINE START G-CODE

Possible to modify - the general idea is:
```
*****CONCEPTUAL - DO NOT COPY WITHOUT MODIFICATION*****

MMU_START_SETUP INITIAL_TOOL={initial_tool} TOTAL_TOOLCHANGES=!total_toolchanges! REFERENCED_TOOLS=!referenced_tools! TOOL_COLORS=!colors! TOOL_TEMPS=!temperatures! TOOL_MATERIALS=!materials! FILAMENT_NAMES=!filament_names! PURGE_VOLUMES=!purge_volumes!
MMU_START_CHECK

; your homing, preheating, leveling, etc goes here
; nothing that requires filament in the extruder though!

MMU_START_LOAD_INITIAL_TOOL

; your purging logic goes here

SET_PRINT_STATS_INFO CURRENT_LAYER=1
SET_PRINT_STATS_INFO TOTAL_LAYER={total_layer_count}
```

```
;===== HAPPY HARE SETUP =====
MMU_START_SETUP INITIAL_TOOL={initial_tool} TOTAL_TOOLCHANGES=!total_toolchanges! REFERENCED_TOOLS=!referenced_tools! TOOL_COLORS=!colors! TOOL_TEMPS=!temperatures! TOOL_MATERIALS=!materials! FILAMENT_NAMES=!filament_names! PURGE_VOLUMES=!purge_volumes!

;===== PRINT_PHASE_INIT =====
SET_PRINT_STATS_INFO TOTAL_LAYER=[total_layer_count]
SET_PRINT_MAIN_STATUS MAIN_STATUS=print_start
M220 S100
M221 S100
SET_INPUT_SHAPER SHAPER_TYPE_X=mzv
SET_INPUT_SHAPER SHAPER_TYPE_Y=mzv
DISABLE_ALL_SENSOR
M1002 R1
M107
CLEAR_PAUSE
M140 S[bed_temperature_initial_layer_single]
M141 S[chamber_temperatures]
G29.0
G28

;===== HAPPY HARE CHECK =====
MMU_START_CHECK

;===== PRINT_START =====
SET_PRINT_MAIN_STATUS MAIN_STATUS=printing
MMU_START_LOAD_INITIAL_TOOL
M140 S[bed_temperature_initial_layer_single]
M104 S[nozzle_temperature_initial_layer]
M141 S[chamber_temperatures]
G0 X195 Y1 F20000
G0 Z10 F480
G92 Z{10 - ((nozzle_temperature_initial_layer[initial_tool] - 130) / 14 - 5.0) / 100}
G4 P3000
probe samples=1
G91
G0 Z5 F480
G90
G1 X170 Y1 F20000
G91
G0 Z{initial_layer_print_height-5} F480
G90
G0 X190 E8 F{outer_wall_volumetric_speed/(24/20) * 60}
G0 X195 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5)/4 * 60}
G0 X200 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5) * 60}
G0 X205 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5)/4 * 60}
G0 X210 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5) * 60}
G0 X215 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5)/4 * 60}
G91
G1 X1 Z{-1+initial_layer_print_height+0.1}
G1 X4
G1 Z1 F480
G1 X-50 Y1.5 F20000
G1 Z{1-initial_layer_print_height-0.1} F480
G90
G0 X190 E10 F{outer_wall_volumetric_speed/(24/20) * 60}
G0 X195 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5)/4 * 60}
G0 X200 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5) * 60}
G0 X205 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5)/4 * 60}
G0 X210 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5) * 60}
G0 X215 E.3742 F{outer_wall_volumetric_speed/(0.3*0.5)/4 * 60}
G91
G1 X1 Z{-initial_layer_print_height-0.1}
G1 X4
G1 Z1 F480
G90```

# MACHINE END G-CODE
```
MMU_END
DISABLE_BOX_HEATER
M141 S0
M140 S0
DISABLE_ALL_SENSOR
G1 E-3 F1800
G0 Z{max_layer_z + 3} F600
G0 Y380 F12000
G0 X128 Y380 F12000
{if max_layer_z < max_print_height / 2}G1 Z{max_print_height / 2 + 10} F600{else}G1 Z{min(max_print_height, max_layer_z + 3)}{endif}
M104 S0
PRINT_END
```
# BEFORE LAYER CHANGE G-CODE
```
;BEFORE_LAYER_CHANGE
;[layer_z]
G92 E0
```

# LAYER CHANGE G-CODE
```
{if timelapse_type == 1} ; timelapse with wipe tower
G92 E0
G1 E-[retraction_length] F1800
G2 Z{layer_z + 0.4} I0.86 J0.86 P1 F20000 ; spiral lift a little
MOVE_TO_TRASH
{if layer_z <=25}
G1 Z25
{endif}
G92 E0
M400
TIMELAPSE_TAKE_FRAME
G1 E[retraction_length] F300
G1 X180 F8000
G1 Y380
{if layer_z <=25}
G1 Z[layer_z]
{endif}
{elsif timelapse_type == 0} ; timelapse without wipe tower
TIMELAPSE_TAKE_FRAME
{endif}
_MMU_UPDATE_HEIGHT HEIGHT={layer_num + 1} 
G92 E0
SET_PRINT_STATS_INFO CURRENT_LAYER={layer_num + 1}
```

# TIME LAPSE G-CODE
```
TIMELAPSE_TAKE_FRAME
```

# CHANGE FILAMENT G-CODE
```
T[next_extruder]
```

# CHANGE EXTRUSION ROLE G-CODE
```

```

# PAUSE G-CODE
```
M0
```

# TEMPLATE CUSTOM G-CODE
```

```