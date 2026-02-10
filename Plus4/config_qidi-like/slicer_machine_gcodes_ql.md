# MACHINE START G-CODE
```
PRINT_START BED=[bed_temperature_initial_layer_single] HOTEND=[nozzle_temperature_initial_layer] CHAMBER=[chamber_temperature] EXTRUDER=[initial_no_support_extruder]
SET_PRINT_STATS_INFO TOTAL_LAYER=[total_layer_count]
M83
T[initial_tool]
M140 S[bed_temperature_initial_layer_single]
M104 S[nozzle_temperature_initial_layer]
M141 S[chamber_temperature]
G4 P3000
G0 X{max((min(print_bed_max[0] - 12, first_layer_print_min[0] + 80) - 85), 0)} Y{max((min(print_bed_max[1] - 3, first_layer_print_min[1] + 80) - 85), 0)} Z5 F6000
G0 Z[initial_layer_print_height] F600
G1 E3 F1800
;Qidi purge line
G1 X{(min(print_bed_max[0] - 12, first_layer_print_min[0] + 80))} E{85 * 0.5 * initial_layer_print_height * nozzle_diameter[0]} F3000
G1 Y{max((min(print_bed_max[1] - 3, first_layer_print_min[1] + 80) - 85), 0) + 2} E{2 * 0.5 * initial_layer_print_height * nozzle_diameter[0]} F3000
G1 X{max((min(print_bed_max[0] - 12, first_layer_print_min[0] + 80) - 85), 0)} E{85 * 0.5 * initial_layer_print_height * nozzle_diameter[0]} F3000
G1 Y{max((min(print_bed_max[1] - 3, first_layer_print_min[1] + 80) - 85), 0) + 85} E{83 * 0.5 * initial_layer_print_height * nozzle_diameter[0]} F3000
G1 X{max((min(print_bed_max[0] - 12, first_layer_print_min[0] + 80) - 85), 0) + 2} E{2 * 0.5 * initial_layer_print_height * nozzle_diameter[0]} F3000
G1 Y{max((min(print_bed_max[1] - 3, first_layer_print_min[1] + 80) - 85), 0) + 3} E{82 * 0.5 * initial_layer_print_height * nozzle_diameter[0]} F3000
G1 X{max((min(print_bed_max[0] - 12, first_layer_print_min[0] + 80) - 85), 0) + 3} Z0
G1 X{max((min(print_bed_max[0] - 12, first_layer_print_min[0] + 80) - 85), 0) + 6}
G1 Z1 F600
;Alternatively use KAMP purge line
;LINE_PURGE
SET_PRINT_STATS_INFO CURRENT_LAYER=1
```

# MACHINE END G-CODE
```
DISABLE_BOX_HEATER
M141 S0
M140 S0
DISABLE_ALL_SENSOR
G1 E-3 F1800
G0 Z{max_layer_z + 3} F600
UNLOAD_FILAMENT T=[current_extruder]
G0 Y290 F12000
G0 X90 Y290 F12000
{if max_layer_z < max_print_height / 2}G1 Z{max_print_height / 2 + 10} F600{else}G1 Z{min(max_print_height, max_layer_z + 3)}{endif}
M104 S0
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
G1 Y304 F20000
G1 X95 F20000
G92 E0
M400
TIMELAPSE_TAKE_FRAME
G1 Y324 F5000
G1 E[retraction_length] F300
G1 X65 F5000
G1 Y290 F20000
{elsif timelapse_type == 0} ; timelapse without wipe tower
TIMELAPSE_TAKE_FRAME
{endif}
G92 E0
SET_PRINT_STATS_INFO CURRENT_LAYER={layer_num + 1}
```

# TIME LAPSE G-CODE
```
TIMELAPSE_TAKE_FRAME
```

# CHANGE FILAMENT G-CODE
```
{ if current_extruder != next_extruder }
{if max_layer_z < 12}
G1 Z15 F1200
{else}
G1 Z{max_layer_z + 3.0} F1200
{endif}
TOOL_CHANGE_START F=[current_extruder] T=[next_extruder]
DISABLE_ALL_SENSOR
{if long_retractions_when_cut[previous_extruder]}
MOVE_TO_TRASH
G1 E-{retraction_distances_when_cut[previous_extruder]} F{old_filament_e_feedrate}
M400
{else}
G1 E-5 F{old_filament_e_feedrate}
{endif}
CUT_FILAMENT T=[current_extruder]
MOVE_TO_TRASH
M400
{if nozzle_temperature_range_high[current_extruder] >= nozzle_temperature_range_high[next_extruder]}
M104 S{nozzle_temperature_range_high[current_extruder]}
{else}
M104 S{nozzle_temperature_range_high[next_extruder]}
{endif}
M106 S0
M106 P2 S0
UNLOAD_T[current_extruder]
G92 E0
M83
G1 E2 F50
T[next_extruder]
{if nozzle_temperature_range_high[current_extruder] >= nozzle_temperature_range_high[next_extruder]}
SET_HEATER_TEMPERATURE HEATER=extruder TARGET={nozzle_temperature_range_high[current_extruder]} WAIT=1
{else}
SET_HEATER_TEMPERATURE HEATER=extruder TARGET={nozzle_temperature_range_high[next_extruder]} WAIT=1
{endif}
{if long_retractions_when_cut[previous_extruder]}
G1 E{retraction_distances_when_cut[previous_extruder]} F{old_filament_e_feedrate}
{endif}
M400
M106 S60
; FLUSH_START
G1 E1 F50
G1 E{65.5 * 0.58} F{old_filament_e_feedrate}
G1 E{65.5 * 0.02} F50
G1 E{65.5 * 0.18} F{old_filament_e_feedrate}
G1 E{65.5 * 0.02} F50
G1 E{65.5 * 0.18} F{old_filament_e_feedrate}
G1 E{65.5 * 0.02} F50
G1 E-[old_retract_length_toolchange] F1800
; FLUSH_END
{if flush_length_1 > 1}
M400
M106 S255
G91
G1 X-5 F60
G1 X5 F60
G90
CLEAR_FLUSH
M400
M106 S60
; FLUSH_START
G1 E[old_retract_length_toolchange] F300
G1 E{flush_length_1 * 0.58} F{new_filament_e_feedrate}
G1 E{flush_length_1 * 0.02} F50
G1 E{flush_length_1 * 0.18} F{new_filament_e_feedrate}
G1 E{flush_length_1 * 0.02} F50
G1 E{flush_length_1 * 0.18} F{new_filament_e_feedrate}
G1 E{flush_length_1 * 0.02} F50
G1 E-[old_retract_length_toolchange] F1800
; FLUSH_END
{endif}
{if flush_length_2 > 1}
M400
M106 S255
G91
G1 X-5 F60
G1 X5 F60
G90
CLEAR_FLUSH
M400
M106 S60
; FLUSH_START
G1 E[old_retract_length_toolchange] F300
G1 E{flush_length_2 * 0.58} F{new_filament_e_feedrate}
G1 E{flush_length_2 * 0.02} F50
G1 E{flush_length_2 * 0.18} F{new_filament_e_feedrate}
G1 E{flush_length_2 * 0.02} F50
G1 E{flush_length_2 * 0.18} F{new_filament_e_feedrate}
G1 E{flush_length_2 * 0.02} F50
G1 E-[new_retract_length_toolchange] F1800
; FLUSH_END
{endif}
{if flush_length_3 > 1}
M400
M106 S255
G91
G1 X-5 F60
G1 X5 F60
G90
CLEAR_FLUSH
M400
M106 S60
; FLUSH_START
G1 E[new_retract_length_toolchange] F300
G1 E{flush_length_3 * 0.58} F{new_filament_e_feedrate}
G1 E{flush_length_3 * 0.02} F50
G1 E{flush_length_3 * 0.18} F{new_filament_e_feedrate}
G1 E{flush_length_3 * 0.02} F50
G1 E{flush_length_3 * 0.18} F{new_filament_e_feedrate}
G1 E{flush_length_3 * 0.02} F50
G1 E-[new_retract_length_toolchange] F1800
; FLUSH_END
{endif}
{if flush_length_4 > 1}
M400
M106 S255
G91
G1 X-5 F60
G1 X5 F60
G90
CLEAR_FLUSH
M400
M106 S60
; FLUSH_START
G1 E[new_retract_length_toolchange] F300
G1 E{flush_length_4 * 0.58} F{new_filament_e_feedrate}
G1 E{flush_length_4 * 0.02} F50
G1 E{flush_length_4 * 0.18} F{new_filament_e_feedrate}
G1 E{flush_length_4 * 0.02} F50
G1 E{flush_length_4 * 0.18} F{new_filament_e_feedrate}
G1 E{flush_length_4 * 0.02} F50
G1 E-[new_retract_length_toolchange] F1800
; FLUSH_END
{endif}
M104 S[new_filament_temp]
M400
M106 S255
G91
G1 X-5 F60
G1 X5 F60
G90
M109 S[new_filament_temp]
G92 E0
M400
CLEAR_FLUSH
CLEAR_OOZE
M400
M106 S0
TOOL_CHANGE_END
G1 Y305 F9000
ENABLE_ALL_SENSOR
{endif}
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