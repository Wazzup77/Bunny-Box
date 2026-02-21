
## INSTALLATION

### AUTO INSTALLATION

TODO - installer script will be made available in the future.

### MANUAL INSTALLATION


#### HAPPY HARE INSTALLATION
<details>
<summary> HAPPY HARE INSTALL </summary>

1. Select your config variant. At present, you can select from:

- NOT CURRENTLY WORKING [`config_qidi-like`](./config_qidi-like/README.md) - Qidi's stock box config, aiming to be as close to stock as possible and compatible with stock Qidi Box gcode
- [`config_hh-standalone`](./config_hh-standalone/README.md) - Happy Hare focused config, taking advantage of its features for a more Happy-Hare experience

2. Copy the configs (`mmu` folder and `bunnybox_macros.cfg`) from the selected variant to your printer's config folder.

3. Add your printer's serial address to `mmu/base/mmu.cfg`. To do this, connect to your printer via SSH and run:

```bash
ls /dev/serial/by-id/*
```

This will give you a list of USB devices. It should say something like:

```bash
/dev/serial/by-id/usb-Klipper_QIDI_BOX_V1_1.1.1_xxxxxxxxxxxxxxxxxxxxxxxxxx
```

Copy that into your mmu.cfg in the `serial:` parameter, replacing the old value.

4. Install Happy Hare from the [WIP repo](https://github.com/Wazzup77/Happy-Hare). To do this, connect to your printer via SSH and run:

```bash
git clone https://github.com/Wazzup77/Happy-Hare.git
```

5. Run the install script `Happy-Hare/install.sh` and pray that it does not break stuff.

```bash
./Happy-Hare/install.sh
```

6. Add `mmu__revision = 0` to `saved_variables.cfg'

```bash
echo "mmu__revision = 0" >> printer_data/config/saved_variables.cfg
```

7. Restart Klipper

```bash
sudo service klipper restart
```
</details>

#### printer.cfg CHANGES

<details>
<summary> `[printer.cfg]` CHANGES </summary>

1. Remove Qidi's stock box config `[include box.cfg]`.

2. Add `[include bunnybox_macros.cfg]` at the top.

3. Modify the `[hall_filament_width_sensor]` section as follows (removing or commenting out the red lines):
```diff
[hall_filament_width_sensor]
adc1: PA2
adc2: PA3
cal_dia1: 1.50
cal_dia2: 2.0
raw_dia1: 14197
raw_dia2: 15058
default_nominal_filament_diameter: 1.75
max_difference: 0
measurement_delay: 50
enable: false
measurement_interval: 10
logging: False
-min_diameter: 0.3
-use_current_dia_while_delay: False
-pause_on_runout:True
-runout_gcode:
-            RESET_FILAMENT_WIDTH_SENSOR
-            M118 Filament run out
-            {% set can_auto_reload = printer.save_variables.variables.auto_reload_detect|default(0) %}
-            {% if can_auto_reload == 1 %}
-              AUTO_RELOAD_FILAMENT
-            {% endif %}
-event_delay: 3.0
-pause_delay: 0.5
```

4. Make sure Happy Hare files were included during install in printer.cfg: `[include mmu/base/*.cfg]`. Other mmu directories should not be included!

</details>

#### gcode_macro.cfg CHANGES

<details>
<summary> `[gcode_macro.cfg]` CHANGES </summary>

1. In PRINT_START we need to change Box detection logic:
```diff
[gcode_macro PRINT_START]
gcode:
[...]
-    {% if printer.save_variables.variables.box_count >= 1 %} 
+    {% if printer.mmu.num_gates >= 4 %} 
        SAVE_VARIABLE VARIABLE=load_retry_num VALUE=0 # saved variables probably need a rework
        SAVE_VARIABLE VARIABLE=retry_step VALUE=None
        SAVE_VARIABLE VARIABLE=is_tool_change VALUE=0
        {% for i in range(16) %}
            SAVE_VARIABLE VARIABLE=runout_{i} VALUE=0
            G4 P100
        {% endfor %}
        SAVE_VARIABLE VARIABLE=extrude_state VALUE=-1
-        {% if printer.save_variables.variables.enable_box == 1 %}
+        {% if printer.mmu.enabled %}
            BOX_PRINT_START EXTRUDER={extruder} HOTENDTEMP={hotendtemp}
            M400
            EXTRUSION_AND_FLUSH HOTEND={hotendtemp}
        {% endif %}
[...]
```

2. In `PAUSE`
```diff
[gcode_macro PAUSE]
rename_existing: BASE_PAUSE
gcode:

(...)

        SET_IDLE_TIMEOUT TIMEOUT=86400
        SET_STEPPER_ENABLE STEPPER=extruder enable=0
-        {% set slot_sync = printer.save_variables.variables.slot_sync|default("slot-1") %}
-        {% if printer['box_stepper ' ~ slot_sync] %}
-            SET_STEPPER_ENABLE STEPPER='box_stepper '{slot_sync} enable=0
+        {% if printer.mmu.sync_drive %}
+            {% set slot_sync = printer.mmu.tool|default("-1") %}
+            {% if printer.mmu.tool == 0 %}
+                SET_STEPPER_ENABLE STEPPER='stepper_mmu_gear' enable=0
+            {% elif printer.mmu.tool > 0 %}
+                SET_STEPPER_ENABLE STEPPER=('stepper_mmu_gear_' ~ {slot_sync}) enable=0
        {% endif %}
```

3. In `RESUME_PRINT`

```diff
[gcode_macro RESUME_PRINT]
    
    (...)

    {% if printer['pause_resume'].is_paused|int == 1 %}
-        {% if printer.save_variables.variables.box_count >= 1 and printer.save_variables.variables.enable_box == 1 and printer.save_variables.variables.is_tool_change == 1 %} 
+        {% if printer.mmu.num_gates >= 4 and printer.mmu.enabled and printer.save_variables.variables.is_tool_change == 1 %} 
            SET_IDLE_TIMEOUT TIMEOUT={printer.configfile.settings.idle_timeout.timeout}
            MOVE_TO_TRASH
            {% if etemp > 0 %}
                M109 S{etemp|int}
            {% endif %}
            M83
            RESTORE_GCODE_STATE NAME=PAUSEPARK2 MOVE=1 MOVE_SPEED=200                            
            RESTORE_GCODE_STATE NAME=PAUSE MOVE=1 MOVE_SPEED=15
            BASE_RESUME  
        {% else %}
            SET_IDLE_TIMEOUT TIMEOUT={printer.configfile.settings.idle_timeout.timeout}
            {% if etemp > 0 %}
                M109 S{etemp|int}
            {% endif %}
-            {% if printer.save_variables.variables.box_count >= 1 %} 
+            {% if printer.mmu.num_gates >= 4 %} 
                SAVE_VARIABLE VARIABLE=retry_step VALUE=None
            {% endif %}
    
    (...)
```

4. In `RESUME`

```diff
[gcode_macro RESUME]
rename_existing: BASE_RESUME
gcode:    
    {% if printer['pause_resume'].is_paused|int == 1 %}
-        {% if printer.save_variables.variables.box_count >= 1 %} 
+        {% if printer.mmu.num_gates >= 4 %} 
-            {% if printer.save_variables.variables.enable_box == 1 %}
+            {% if printer.mmu.enabled %}
                TRY_RESUME_PRINT
            {% else %}
                {% if printer['hall_filament_width_sensor'].Diameter > 0.5 %}
                    RESUME_PRINT
                {% else %}
                    M118 Printer resume failed
                {% endif %}
            {% endif %}
        {% else %}
            {% if printer['hall_filament_width_sensor'].Diameter > 0.5 %}
                RESUME_PRINT
            {% else %}
                M118 Printer resume failed
            {% endif %}
        {% endif %}
    {% endif %}
```
</details>


#### BOX TEMPERATURE AND HUMIDITY SENSOR

<details>
<summary> BOX TEMPERATURE & HUMIDITY SENSOR </summary>

The Qidi Box has a AHT20_F temperature sensor, which unfortunately is not compatible with the stock AHT10 or AHT20 drivers available in Klipper and will crash in some scenarios. Use the [modified file provided here](aht20_f.py). Simply SSH into your printer and do:

```bash
cd /home/mks/klipper/klippy/extras

cp aht20_f.py aht20_f.py.bak # It's OK if this fails

wget https://raw.githubusercontent.com/Wazzup77/Happy-Hare-Plus4-Configs/main/aht20_f.py
```

If you are on Qidi's Klipper, no further action is necessary.

If you are on stock or other Klipper, you need to add [aht20_f] to your `klipper/klippy/extras/temperature_sensors.cfg`, like so:

```bash
########################################
# Module loading
########################################

# other sensors here...

[aht10] # other sensors here

# Load "AHT20_F" and "AHT20_BB" sensors via our aht20_f.py modified module
[aht20_f]

# other sensors here...

########################################
# Default thermistors
########################################
```

</details>

#### USER INTERFACE

<details>
<summary> USER INTERFACE </summary>

If you want to have a section in your printer web interface, install baseline fluidd or mainsail, which both have HH implemented. You can do that via kiauh, which comes preinstalled on Qidi printers.

1. Update kiauh

```bash
    cd kiauh
    git pull
```

2. Run kiauh to reinstall fluidd or mainsail

```bash
    ./kiauh.sh
```

You want to REMOVE the existing Fluidd installation and install it again - this will move you from the Qidi version to mainline, which supports Happy Hare.
Alternatively you can also install Mainsail instead of Fluidd.

</details>

## SLICER SETTINGS

None! The mod is intended to be transparent for the slicer. If your gcode works with a stock Plus4, it should work with Happy Hare. 
Tested on Orca Slicer using the [following g-codes](slicer_machine_gcodes.md), which are meant to replicate the Qidi Slicer profile.

## ADDITIONAL TUNING

1. Speed! The default Qidi profile is very slow. You can speed it up by increasing the values in the SPEEDS section in mmu_parameters.cfg. Keep in mind that these settings will vary between different Qidi Boxes. Generally loading speeds can be increased by 20-30% without issues, but keep in mind that going fast may cause filament swaps to fail. Going too fast may also cause the filament to be ground up by the gears. Remember to recalibrate the encoder after changing speeds (its measurement will vary widely depending on speed).
2. Tip forming. The base configuration uses simple tip forming, i.e. it removes molten filament from the nozzle. Although it has been tested on multiple filaments across multiple Plus4 printers, it may require tuning on your specific printer/filament. If you have a custom hotend, you need to update the configration too. Cutter support is not implemented yet, but is planned.
3. 

## FREQUENTLY ASKED QUESTIONS

TODO


## ADDITIONAL HELP

Refer to the [Happy Hare documentation](https://github.com/moggieuk/Happy-Hare/wiki).

## ADVANCED USERS ONLY

Happy Hare allows for a lot of configuration - we will place interesting options and more install steps here.

- [Happy Hare Standalone](hh-standalone) - focused on using Happy Hare to the best of its ability - at the cost of being incompatible with stock Qidi gcode.