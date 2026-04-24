
> [!CAUTION]
> **Max4 support is experimental — hackers wanted, do not install on a working printer.** The Max4 firmware stack is materially more complex than Plus4 or Q2 and the HH integration is only partially mapped out. If something fails, you are expected to diagnose and fix it.
>
> **What's different about the Max4:**
> - It adds a second closed-source state machine, `multi_color_controller.so`, on top of the `box_extras` / `box_autofeed` / `box_stepper` / `box_rfid` stack shared with Plus4/Q2. `multi_color_controller` implements both local orchestration and a USB-JSON protocol to the second-gen box.
> - The macro layer is built on [Justin Schuh's klipper-macros](https://github.com/jschuh/klipper-macros) (packaged as `klipper-macros-qd`) with a phased `PRINT_START` (`_PRINT_START_PHASE_INIT` → `_PRINT_START_BOX_PREPAR` → `_PRINT_START_PHASE_PREHEAT` → `_PRINT_START_PHASE_PROBING` → `_PRINT_START_PHASE_EXTRUDER`) rather than the single flat `gcode_macro.cfg` pattern of Plus4/Q2. Lowercase section names (`[gcode_macro pause]`, `[gcode_macro clear_pause]`) are used. This is more complex to modify and will require live testing which I cannot do (I do not own a Max4).
> - Closed-source dependencies extend beyond the box: `probe_air`, `multi_color_controller`, `d_bus_service_manager`, `ai_func_manager`, `print_stats_manager`, `smart_output_pin`, `cl_interface`, `closed_loop`. This should be avoidable, since Happy Hare allows us to remove Qidi box-related configs and thus prevent the .so files from loading. However, for the Max4, the .so files extend further beyond the Plus4/Q2 scope, so hidden dependancies may emerge.

# INSTALLATION

## AUTO INSTALLATION

The easiest way to install Happy Hare on your Qidi Max4 is to use the provided automated script. 

1. **Connect to your printer** via SSH.
2. **Download and run the script**:
   ```bash
   wget -qO - https://raw.githubusercontent.com/Wazzup77/Bunny-Box/refs/heads/main/Max4/install-bb-max4.sh | bash
   ```
   
The script will backup your configurations, download the necessary files, prompt you for your serial ID, and automatically install Happy Hare.
Don't forget to update the machine gcodes in the slicer to use the ones provided in the [slicer_machine_gcodes.md](./config_hh-standalone/slicer_machine_gcodes.md).

## MANUAL INSTALLATION

### STEP 1: HAPPY HARE INSTALLATION
<details>
<summary> HAPPY HARE INSTALL </summary>

1. Select your config variant. At present, you can select from:

- [`config_hh-standalone`](./config_hh-standalone/README.md) - Happy Hare focused config, taking advantage of its features for a more Happy-Hare experience

2. Copy the configs (`mmu` folder and `bunnybox_macros.cfg`) from the selected variant to your printer's config folder.

3. Add your printer's serial address to `mmu/base/mmu.cfg`. To do this, connect to your printer via SSH and run:

```bash
ls /dev/serial/by-id/*
```

This will give you a list of USB devices. It should say something like:

```bash
/dev/serial/by-id/usb-Klipper_QIDI_BOX_xxxxxxxxxxxxxxxxxxxxxxxxxx
```

Copy that into your mmu.cfg in the `serial:` parameter, replacing the old value.

4. Install Happy Hare from the [mainline Happy Hare repo](https://github.com/moggieuk/Happy-Hare). To do this, connect to your printer via SSH and run:

```bash
cd ~
git clone https://github.com/moggieuk/Happy-Hare.git
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

### STEP 2: printer.cfg CHANGES

<details>
<summary> `[printer.cfg]` CHANGES </summary>

0. Backup your printer.cfg file! Just in case you want to return to the stock config.

1. Remove Qidi's stock box config `[include box.cfg]` and `[multi_color_controller]`.

2. Modify the `[filament_switch_sensor filament_switch_sensor]` section (HH takes care of runout). **Important:** Set `pause_on_runout` to `False` — do not comment it out, as Klipper defaults to `True`:
```diff
+[duplicate_pin_override]
+pins: THR:PA0
+
[filament_switch_sensor filament_switch_sensor]
-pause_on_runout: True
+pause_on_runout: False
-runout_gcode:
-            M118 Filament run out
-            {% set can_auto_reload = printer.save_variables.variables.auto_reload_detect|default(0) %}
-            {% if can_auto_reload == 1 %}
-              AUTO_RELOAD_FILAMENT
-            {% endif %}
-insert_gcode:             # Code executed when inserting consumables
event_delay: 3.0          # event delay time
pause_delay: 0.5          # pause delay time
switch_pin:!THR:PA0       # Detect switch pin
```
3. Add `[include bunnybox_macros.cfg]` at the top.

4. Make sure Happy Hare files were included during install in printer.cfg: 
```
[include mmu/base/*.cfg]
[include mmu/optional/client_macros.cfg]
```
Other mmu directories should not be included!

</details>

### STEP 3: klipper-macros-qd CHANGES

<details>
<summary> `klipper-macros-qd` CHANGES </summary>

0. Backup your `klipper-macros-qd` folder! Just in case you want to return to the stock config.

1. In `start_end.cfg`:
```diff
[gcode_macro print_start]
description: Usage: PRINT_START BED=<temp> HOTEND=<temp> [CHAMBER=<temp>] EXTRUDER = <num>
                     [MESH_MIN=<x,y>] [MESH_MAX=<x,y>] [LAYERS=<num>]
                     [NOZZLE_SIZE=<mm>]
gcode:
  # Set the printing master status to the starting stage
  SET_PRINT_MAIN_STATUS MAIN_STATUS=print_start
  # ===Print the four core stages of startup ===
  _PRINT_START_PHASE_INIT {rawparams}   # Phase 1: Initialize setup and start bed/chamber preheating
-  _PRINT_START_BOX_PREPAR               # Stage 2: Multi-color consumable preparation and switching

  _PRINT_START_PHASE_PREHEAT            # Phase 3: Temperature stabilization and shaft return
  _PRINT_START_PHASE_PROBING            # Stage 4: Detection calibration (bed net/gantry leveling)
  _PRINT_START_PHASE_EXTRUDER           # Stage 5: Final warm-up of the extruder
  # Switch to official printing status
  SET_PRINT_MAIN_STATUS MAIN_STATUS=printing
```
2. In `pause_resume_cancel.cfg`:
    - Remove `PAUSE` (or comment it out).
    - Remove `RESUME_PRINT` (or comment it out).
    - Remove `RESUME` (or comment it out).
    - Remove `CANCEL_PRINT` (or comment it out).

3. In `start_end.cfg`, comment out any `save_last_file` call inside `PRINT_START`. This is Qidi's power-loss recovery hook and sets `was_interrupted=True` in `saved_variables.cfg` on every print start; PLR is disabled under Happy Hare (see [DETECT_INTERRUPTION override](./config_hh-standalone/bunnybox_macros.cfg)) so the call is wasteful.

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

Use the [following machine g-codes](./config_hh-standalone/slicer_machine_gcodes_hh.md) with your slicer.

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
To additionally improve the movement logic on tip forming (by moving to the purge chute first) add `toolchange` to the list of paramters at `variable_enable_park_printing` as such:
`variable_enable_park_printing   : 'toolchange,runout,load,complete,pause,cancel'	; Empty '' to disable parking`
If you ever want to switch back to cutting, remove the `toolchange` and revert to `form_tip_macro: _MMU_CUT_TIP`.


# ADDITIONAL HELP

Refer to the [Happy Hare documentation](https://github.com/moggieuk/Happy-Hare/wiki).

# ADVANCED USERS ONLY

Happy Hare allows for a lot of configuration - we will place interesting options and more install steps here.

- [Happy Hare Standalone](hh-standalone) - focused on using Happy Hare to the best of its ability - at the cost of being incompatible with stock Qidi gcode.
-
