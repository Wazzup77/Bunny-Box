
# INSTALLATION

## AUTO INSTALLATION

The easiest way to install Happy Hare on your Qidi Plus4 is to use the provided automated script. 

1. **Connect to your printer** via SSH.
2. **Download and run the script**:
   ```bash
   wget -qO - https://raw.githubusercontent.com/Wazzup77/Bunny-Box/refs/heads/main/Plus4/install-bb-p4.sh | bash
   ```
   
The script will backup your configurations, download the necessary files, prompt you for your serial ID, and automatically install Happy Hare.

## MANUAL INSTALLATION

### HAPPY HARE INSTALLATION
<details>
<summary> STEP 1: HAPPY HARE INSTALL </summary>

1. Select your config variant. At present, you can select from:

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
cd ~
git clone -b bunnybox https://github.com/Wazzup77/Happy-Hare.git
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

### STEP 2:printer.cfg CHANGES

<details>
<summary> `[printer.cfg]` CHANGES </summary>

0. Backup your printer.cfg file! Just in case you want to return to the stock config.

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

4. Make sure Happy Hare files were included during install in printer.cfg: 
```
[include mmu/base/*.cfg]
[include mmu/optional/client_macros.cfg]
```
Other mmu directories should not be included!

</details>

### STEP 3: gcode_macro.cfg CHANGES

<details>
<summary> `[gcode_macro.cfg]` CHANGES </summary>

0. Backup your gcode_macro.cfg file! Just in case you want to return to the stock config.

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

2. Remove `PAUSE` (or comment it out).

3. Remove `RESUME_PRINT` (or comment it out).

4. Remove `RESUME` (or comment it out).

5. Remove `CANCEL_PRINT` (or comment it out).

</details>


### STEP 4: USER INTERFACE

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


### STEP 5: SLICER SETTINGS

<details>
<summary> SLICER SETTINGS </summary>

Go into your pritner settings in the slicer and change them to use the [following machine g-codes](./config_hh-standalone/slicer_machine_gcodes.md).

</details>

### (optional) STEP 6: ENVIRONMENT SENSOR

<details>
<summary> ENVIRONMENT SENSOR </summary>

To be able to view temperature and humidity in the printer web interface reliably, you need to install a aht10.py module from modern Klipper. 

> [!NOTE]
> I recommend doing this step for stability, but you can skip it by changing the `[temperature_sensor box1_env]` `sensor_type` to `AHT10` in the `mmu_hardware.cfg`. If you are on mainline Klipper, Freedi or Kalico, you can skip this step altogether, though it won't hurt anything if you do it.

1. Go to the Klipper directory and clone the module

```bash
    cd klipper/klippy/extras

    sudo mv aht10.py aht10.py.bak

    wget https://raw.githubusercontent.com/Wazzup77/Bunny-Box/refs/heads/main/aht10.py
```

</details>


# ADDITIONAL TUNING

1. Speed! The default Qidi profile is very slow. You can speed it up by increasing the values in the SPEEDS section in mmu_parameters.cfg. Keep in mind that these settings will vary between different Qidi Boxes. Generally loading speeds can be increased by 20-30% without issues, but keep in mind that going fast may cause filament swaps to fail. Going too fast may also cause the filament to be ground up by the gears. Remember to recalibrate the encoder after changing speeds (its measurement will vary widely depending on speed).
2. Tip forming. The base configuration uses the cutter. Tip forming allows you to reduce filament waste by removing the whole filament piece from the hotend. The disadvantage is that good tuning is needed to avoid clogs. Although the profile in these configs has been tested on multiple filaments across multiple Plus4 printers, it may require tuning on your specific printer/filament. If you have a custom hotend, you need to update the configration too. Activate it by changing: 
`form_tip_macro: _MMU_CUT_TIP` to `form_tip_macro: _MMU_FORM_TIP`


# ADDITIONAL HELP

Refer to the [Happy Hare documentation](https://github.com/moggieuk/Happy-Hare/wiki).

# ADVANCED USERS ONLY

Happy Hare allows for a lot of configuration - we will place interesting options and more install steps here.

- [Happy Hare Standalone](hh-standalone) - focused on using Happy Hare to the best of its ability - at the cost of being incompatible with stock Qidi gcode.
-
