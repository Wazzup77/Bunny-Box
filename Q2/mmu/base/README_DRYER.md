# Filament Dryer System

A non-blocking filament drying system for Klipper using any heater (like `heater_mmu`).

## Features

- **Non-blocking**: Runs in the background without interfering with other Klipper operations
- **Preset support**: Pre-configured drying cycles for common filament types
- **Manual mode**: Specify custom temperature and duration
- **Status tracking**: Monitor progress, remaining time, and current temperature
- **Auto-shutoff**: Automatically turns off heater when cycle completes

## Installation

1. Ensure the `mmu_dryer.py` file is in your `klipper/klippy/extras/` directory
2. Add the following to your `printer.cfg` or include the `mmu_dryer.cfg` file:
   ```
   [include mmu/base/mmu_dryer.cfg]
   ```
3. **Configure the heater name** in `mmu_dryer.cfg` if you're not using `heater_mmu`:
   ```ini
   [mmu_dryer]
   heater: heater_mmu  # or heater_box, chamber_heater, etc.
   ```
4. Restart Klipper

## Usage

### Using Presets

Start a drying cycle using a preset:
```
START_FILAMENT_DRYING PRESET=pla
START_FILAMENT_DRYING PRESET=petg
START_FILAMENT_DRYING PRESET=abs
START_FILAMENT_DRYING PRESET=nylon
START_FILAMENT_DRYING PRESET=tpu
```

Or use the convenience macros:
```
START_PLA_DRYING
START_PETG_DRYING
START_ABS_DRYING
START_NYLON_DRYING
START_TPU_DRYING
```

### Manual Mode

Specify custom temperature (°C) and duration (hours):
```
START_FILAMENT_DRYING TEMP=50 DURATION=4
START_FILAMENT_DRYING TEMP=65 DURATION=8
```

### Control Commands

Stop the current drying cycle:
```
STOP_FILAMENT_DRYING
# or use the macro
STOP_DRYING
```

Check drying status:
```
DRYER_STATUS
# or use the macro
CHECK_DRYER
```

List available presets:
```
LIST_DRYER_PRESETS
```

## Default Presets

| Filament | Temperature | Duration |
|----------|-------------|----------|
| PLA      | 50°C        | 4 hours  |
| PETG     | 55°C        | 6 hours  |
| ABS      | 60°C        | 4 hours  |
| Nylon    | 70°C        | 12 hours |
| TPU      | 50°C        | 4 hours  |

## Configuration

### Specifying Your Heater

The dryer works with **any heater** defined in your Klipper config. Edit the `heater:` parameter in `mmu_dryer.cfg`:

```ini
[mmu_dryer]
heater: heater_mmu          # For MMU heater
# heater: heater_box        # Alternative MMU heater name
# heater: chamber_heater    # For chamber heating
# heater: filament_dryer    # Custom heater_generic name
```

The heater must be:
- A `[heater_generic]` section in your config
- Or any other controllable heater (extruder, heater_bed can work but not recommended)
- Properly configured with min_temp, max_temp, and safety limits

### Adding Custom Presets

Edit `mmu_dryer.cfg` to customize or add presets:

```ini
[mmu_dryer]
heater: heater_mmu
presets: pla, petg, abs, nylon, tpu, custom

# Add a custom preset
preset_custom_temp: 55
preset_custom_duration: 8
```

Then use it with:
```
START_FILAMENT_DRYING PRESET=custom
```

## Safety Notes

- The dryer uses your existing heater configuration
- Ensure your heater is properly configured with appropriate safety limits
- The system respects the `min_temp`, `max_temp`, and `target_max_temp` settings from your heater configuration
- When stopping a cycle, the heater returns to its previous target temperature (usually 0)

## Troubleshooting

**Error: "Unable to find heater 'heater_mmu'"**
- Ensure your heater is properly defined in your config (e.g., `[heater_generic heater_mmu]`)
- Check that the heater name matches in both the heater config and `mmu_dryer.cfg`
- Verify the heater config loads before the dryer config (the 'z_' prefix ensures proper load order)

**Drying cycle doesn't start**
- Check that no other drying cycle is already running (`DRYER_STATUS`)
- Verify the heater is functioning correctly
- Check Klipper logs for errors

**Want to use a different heater**
- Edit the `heater:` parameter in `[mmu_dryer]` section of `mmu_dryer.cfg`
- Example: Change `heater: heater_mmu` to `heater: heater_box`
- The heater must be defined elsewhere in your Klipper config (typically as a `[heater_generic]`)

## Integration with Macros

You can integrate dryer status into your macros:

```gcode
[gcode_macro MY_PRINT_START]
gcode:
    # Check if dryer is running
    {% set dryer = printer['mmu_dryer'] %}
    {% if dryer.is_drying %}
        RESPOND MSG="Filament drying in progress: {dryer.remaining/3600|round(1)} hours remaining"
    {% endif %}
    # ... rest of your print start macro
```

## Technical Details

- Uses Klipper's reactor for non-blocking timer events
- Updates every second during drying cycle
- Minimal CPU overhead
- Safe to use during prints (though not recommended for temperature stability)
- Properly manages heater state to avoid conflicts with other systems
