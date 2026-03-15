<p align="center">
  <h1 align="center"> Q2 Happy Hare Standalone Slicer Machine G-Codes</h1>
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
MMU_START_CHECK

;===== QIDI PRINT START AND PREHEAT =====
; NOTE: no purging allowed in print start
PRINT_START BED=[bed_temperature_initial_layer_single] HOTEND=[nozzle_temperature_initial_layer] CHAMBER=[chamber_temperature] EXTRUDER=[initial_no_support_extruder]
SET_PRINT_STATS_INFO TOTAL_LAYER=[total_layer_count]
M83
M140 S[bed_temperature_initial_layer_single]
M104 S[nozzle_temperature_initial_layer]
M141 S[chamber_temperature]
G4 P3000

;===== HAPPY HARE LOAD INITIAL TOOL =====
MMU_START_LOAD_INITIAL_TOOL

;===== QIDI PURGE SEQUENCE =====
G1 X108.000 Y1 F30000
G0 Z[initial_layer_print_height] F600
;G1 E3 F1800
G90
M83
G0 X128 E8  F{outer_wall_volumetric_speed/(24/20)    * 60}
G0 X133 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)/4     * 60}
G0 X138 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)     * 60}
G0 X143 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)/4     * 60}
G0 X148 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)     * 60}
G0 X153 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)/4     * 60}
G91
G1 X1 Z-0.300
G1 X4
G1 Z1 F1200
G90
M400
G1 X108.000 Y2.5 F30000
G0 Z[initial_layer_print_height] F600
M83
G0 X128 E10  F{outer_wall_volumetric_speed/(24/20)    * 60}
G0 X133 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)/4     * 60}
G0 X138 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)     * 60}
G0 X143 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)/4     * 60}
G0 X148 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)     * 60}
G0 X153 E.3742  F{outer_wall_volumetric_speed/(0.3*0.5)/4     * 60}
G91
G1 X1 Z-0.300
G1 X4
G1 Z1 F1200
G90
M400
G1 Z1 F600

```

# MACHINE END G-CODE
```
MMU_END
DISABLE_BOX_HEATER
M141 S0
M140 S0
DISABLE_ALL_SENSOR
G1 E-3 F1800
G0 Z{max_layer_z + 3} F600
UNLOAD_FILAMENT T=[current_extruder]
G0 Y270 F12000
G0 X90 Y270 F12000
{if max_layer_z < max_print_height / 2}G1 Z{max_print_height / 2 + 10} F600{else}G1 Z{min(max_print_height, max_layer_z + 3)}{endif}
M104 S0
```
# BEFORE LAYER CHANGE G-CODE
```

```

# LAYER CHANGE G-CODE
```
{if timelapse_type == 1} ; timelapse with wipe tower
G92 E0
G1 E-[retraction_length] F1800
G2 Z{layer_z + 0.4} I0.86 J0.86 P1 F20000 ; spiral lift a little
G1 Y235 F20000
G1 X97 F20000
{if layer_z <=25}
G1 Z25
{endif}
G1 Y254 F2000
G92 E0
M400
TIMELAPSE_TAKE_FRAME
G1 E[retraction_length] F300
G1 X85 F2000
G1 X97 F2000
G1 Y220 F2000
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