#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# =========================================================================
# Happy Hare + Qidi Max4 Automatic Installation Script
# =========================================================================
# This script automates the installation of Happy Hare and configures
# a Qidi Max4 for standalone usage. It can be run either from a cloned
# repository or standalone (e.g., via wget or curl).
# =========================================================================

# Ensure the script is not run as root. Klipper and the user configuration
# are expected to be owned and managed by the normal user (e.g. 'mks').
if [ "$EUID" -eq 0 ]; then
  echo "Please do not run this script as root. Run as your normal user (e.g. mks)."
  exit 1
fi

# Define paths for Klipper configuration data.
PRINTER_DATA_DIR="$HOME/printer_data"
CONFIG_DIR="$PRINTER_DATA_DIR/config"

# Verify that the expected configuration directory exists.
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Could not find Klipper config directory at $CONFIG_DIR"
    echo "This script must be run on your printer."
    exit 1
fi

# Ensure required tools are present. Qidi firmware images often ship without
# git, and the standalone mode also needs unzip + curl/wget. Auto-install any
# missing packages via apt-get (Qidi printers are Debian-based).
echo "==> Checking dependencies..."
NEEDED=()
command -v git     >/dev/null 2>&1 || NEEDED+=(git)
command -v python3 >/dev/null 2>&1 || NEEDED+=(python3)
command -v unzip   >/dev/null 2>&1 || NEEDED+=(unzip)
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    NEEDED+=(curl)
fi
if [ ${#NEEDED[@]} -gt 0 ]; then
    echo "Installing missing packages: ${NEEDED[*]}"
    if command -v sudo >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update || echo "Warning: apt-get update failed, continuing..."
        sudo apt-get install -y "${NEEDED[@]}"
    else
        echo "Error: Cannot auto-install (need sudo + apt-get). Install manually: ${NEEDED[*]}"
        exit 1
    fi
fi

# Locate the directory where this script resides.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Check if the needed configuration directories exist next to the script.
# If they do not, we assume the script is being run standalone (e.g. piped
# from wget) and we need to download the repository configuration files.
TEMP_DIR=""
function cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "==> Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}
# Register the cleanup function to run when the script exits (normally or on error).
trap cleanup EXIT

# Returns 0 if a bunnybox / Happy Hare install is detected on this printer.
is_bb_installed() {
    if [ -f "$CONFIG_DIR/bunnybox_macros.cfg" ]; then
        return 0
    fi
    if [ -f "$CONFIG_DIR/printer.cfg" ] && grep -q '\[include bunnybox_macros.cfg\]' "$CONFIG_DIR/printer.cfg"; then
        return 0
    fi
    return 1
}

# Restore pre-install printer.cfg and klipper-macros-qd/ from the oldest
# backup_hh_* directory (presumed closest to stock), while preserving the
# current bunnybox state in a new backup_revert_<ts> directory so the revert
# itself can be undone.
revert_to_stock() {
    echo ""
    echo "==> Reverting to stock configuration..."

    local oldest
    oldest=$(ls -1d "$CONFIG_DIR"/backup_hh_* 2>/dev/null | sort | head -n 1)
    if [ -z "$oldest" ] || [ ! -d "$oldest" ]; then
        echo "Error: No backup_hh_* directory found in $CONFIG_DIR."
        echo "Cannot revert — no pre-install backup exists."
        exit 1
    fi
    if [ ! -f "$oldest/printer.cfg" ]; then
        echo "Error: $oldest has no printer.cfg; cannot revert."
        exit 1
    fi
    if grep -q '\[include bunnybox_macros.cfg\]' "$oldest/printer.cfg"; then
        echo "Warning: $oldest/printer.cfg already references bunnybox_macros.cfg;"
        echo "it may not represent a pre-install state. Aborting to be safe."
        exit 1
    fi
    echo "Using backup: $oldest"

    local ts revert_dir
    ts=$(date +"%Y%m%d_%H%M%S")
    revert_dir="$CONFIG_DIR/backup_revert_$ts"
    mkdir -p "$revert_dir"

    if [ -f "$CONFIG_DIR/printer.cfg" ];         then cp "$CONFIG_DIR/printer.cfg" "$revert_dir/"; fi
    if [ -d "$CONFIG_DIR/klipper-macros-qd" ];   then cp -r "$CONFIG_DIR/klipper-macros-qd" "$revert_dir/"; fi
    if [ -f "$CONFIG_DIR/bunnybox_macros.cfg" ]; then mv "$CONFIG_DIR/bunnybox_macros.cfg" "$revert_dir/"; fi
    if [ -d "$CONFIG_DIR/mmu" ];                 then mv "$CONFIG_DIR/mmu" "$revert_dir/"; fi
    echo "Current bunnybox state preserved in $revert_dir"

    cp "$oldest/printer.cfg" "$CONFIG_DIR/"
    if [ -d "$oldest/klipper-macros-qd" ]; then
        rm -rf "$CONFIG_DIR/klipper-macros-qd"
        cp -r "$oldest/klipper-macros-qd" "$CONFIG_DIR/"
    fi

    if [ -f "$CONFIG_DIR/saved_variables.cfg" ]; then
        local tmp_sv
        tmp_sv=$(mktemp)
        sed '/^mmu__revision[[:space:]]*=/d' "$CONFIG_DIR/saved_variables.cfg" > "$tmp_sv"
        mv "$tmp_sv" "$CONFIG_DIR/saved_variables.cfg"
    fi

    echo "Restored printer.cfg and klipper-macros-qd/ from $oldest"

    echo ""
    echo "==> Restarting Klipper..."
    if command -v sudo >/dev/null 2>&1; then
        sudo systemctl restart klipper || echo "Failed to restart klipper automatically. Please restart it manually."
        sudo systemctl restart moonraker || echo "Failed to restart moonraker."
    fi

    echo ""
    echo "========================================================="
    echo "   Revert complete — stock configuration restored.       "
    echo "========================================================="
    echo "To reinstall bunnybox / Happy Hare, simply re-run this script."
    exit 0
}

if [ ! -d "$SCRIPT_DIR/config_hh-standalone" ]; then
    echo "==> Standalone execution detected. Downloading configuration files..."
    TEMP_DIR=$(mktemp -d)
    REPO_URL="https://github.com/Wazzup77/Happy-Hare-Plus4-Configs/archive/refs/heads/main.zip"
    ZIP_FILE="$TEMP_DIR/configs.zip"
    
    # Download the repository zip (prefer curl -fsSL so HTTP errors don't write a zero-byte file)
    if command -v curl >/dev/null 2>&1; then
        curl -fsSLo "$ZIP_FILE" "$REPO_URL" || rm -f "$ZIP_FILE"
    fi
    if [ ! -s "$ZIP_FILE" ] && command -v wget >/dev/null 2>&1; then
        wget -qO "$ZIP_FILE" "$REPO_URL" || rm -f "$ZIP_FILE"
    fi
    if [ ! -s "$ZIP_FILE" ]; then
        echo "Error: Failed to download configuration files."
        exit 1
    fi

    # Unzip the contents
    unzip -q "$ZIP_FILE" -d "$TEMP_DIR"
    
    # Update SCRIPT_DIR to point to the extracted Max4 folder
    # We detect the extracted folder name dynamically:
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    SCRIPT_DIR="$EXTRACTED_DIR/Max4"
    
    if [ ! -d "$SCRIPT_DIR/config_hh-standalone" ]; then
         echo "Error: Expected configuration folders not found in downloaded archive."
         exit 1
    fi
    echo "Configurations downloaded successfully."
fi



echo "========================================================="
echo "   Happy Hare + Qidi Max4 Automatic Installer "
echo "========================================================="
echo ""

if is_bb_installed; then
    echo "Existing Happy Hare / bunnybox install detected."
    echo "  1) Reinstall / update (re-apply configuration)"
    echo "  2) Revert to stock (restore pre-install printer.cfg and klipper-macros-qd/)"
    echo "  3) Cancel"
    read -p "Select [1/2/3, default 1]: " BB_ACTION </dev/tty
    case "$BB_ACTION" in
        2) revert_to_stock ;;
        3) echo "Cancelled."; exit 0 ;;
        *) echo "Proceeding with reinstall." ;;
    esac
else
    echo "This script will automate the installation of Happy Hare"
    echo "and configure your Qidi Max4 for standalone usage."
    echo "Please ensure you have read the README."
    echo ""
    read -p "Do you want to continue? (y/n) " -n 1 -r </dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "==> Backing up files..."
# Create a backup of existing configurations before making any changes.
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$CONFIG_DIR/backup_hh_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

if [ -f "$CONFIG_DIR/printer.cfg" ]; then cp "$CONFIG_DIR/printer.cfg" "$BACKUP_DIR/"; fi
if [ -d "$CONFIG_DIR/klipper-macros-qd" ]; then cp -r "$CONFIG_DIR/klipper-macros-qd" "$BACKUP_DIR/"; fi
if [ -d "$CONFIG_DIR/mmu" ]; then mv "$CONFIG_DIR/mmu" "$BACKUP_DIR/"; fi
if [ -f "$CONFIG_DIR/bunnybox_macros.cfg" ]; then cp "$CONFIG_DIR/bunnybox_macros.cfg" "$BACKUP_DIR/"; fi
echo "Backups saved to $BACKUP_DIR"

echo ""
echo "==> Using Configuration Variant: config_hh-standalone (Recommended)"
CONFIG_VARIANT="config_hh-standalone"

if [ ! -d "$SCRIPT_DIR/$CONFIG_VARIANT" ]; then
    echo "Error: $CONFIG_VARIANT directory not found in $SCRIPT_DIR"
    exit 1
fi

echo ""
echo "==> Copying configuration files from $CONFIG_VARIANT..."
# Copy the Happy Hare MMU directory from the chosen variant into Klipper config
cp -r "$SCRIPT_DIR/$CONFIG_VARIANT/mmu" "$CONFIG_DIR/"
# Copy the custom macros specific to the Max4 integration
cp "$SCRIPT_DIR/$CONFIG_VARIANT/bunnybox_macros.cfg" "$CONFIG_DIR/"
echo "Configurations copied."

echo ""
echo "==> Configuring Serial Address..."
# Find serial devices
SERIAL_ID=""
DETECTED_SERIAL=""
if [ -d "/dev/serial/by-id" ]; then
    DETECTED_SERIAL=$(find /dev/serial/by-id -maxdepth 1 -iname "*QIDI_BOX*" 2>/dev/null | head -n 1)
fi

if [ -n "$DETECTED_SERIAL" ]; then
    echo "Autodetected Qidi Box at: $DETECTED_SERIAL"
    read -p "Use this serial port? (Y/n) " USE_DETECTED </dev/tty
    if [[ -z "$USE_DETECTED" ]] || [[ "$USE_DETECTED" =~ ^[Yy]$ ]]; then
        SERIAL_ID="$DETECTED_SERIAL"
    fi
fi

if [ -z "$SERIAL_ID" ]; then
    echo "Available serial devices:"
    ls -1 /dev/serial/by-id/* 2>/dev/null || echo "No serial devices found!"
    echo ""
    read -p "Enter your printer's serial ID string from above (e.g., /dev/serial/by-id/usb-Klipper_...): " SERIAL_ID </dev/tty
fi
if [ -n "$SERIAL_ID" ]; then
    MMU_CFG="$CONFIG_DIR/mmu/base/mmu.cfg"
    if [ -f "$MMU_CFG" ]; then
        # Replace the serial line (anchored so only top-level `serial:` entries match,
        # not commented lines or keys like `custom_serial:`)
        tmp_cfg=$(mktemp)
        awk -v serial="$SERIAL_ID" '{sub(/^[[:space:]]*serial:.*/, "serial: " serial)} 1' "$MMU_CFG" > "$tmp_cfg"
        mv "$tmp_cfg" "$MMU_CFG"
        echo "Updated serial in mmu.cfg"
    else
        echo "Warning: mmu.cfg not found at $MMU_CFG"
    fi
else
    echo "Warning: No serial ID provided. You will need to update mmu.cfg manually."
fi

echo ""
echo "==> Installing Happy Hare..."
# Install the core Happy Hare software from the mainline repository.
HH_DIR="$HOME/Happy-Hare"
if [ -d "$HH_DIR" ]; then
    echo "Happy-Hare repository already exists at $HH_DIR. Pulling latest..."
    cd "$HH_DIR"
    git fetch
    git checkout main
    git pull --rebase || {
        echo "Warning: git pull failed. Resetting to match remote..."
        git reset --hard origin/main
    }
    cd - >/dev/null
else
    git clone https://github.com/moggieuk/Happy-Hare.git "$HH_DIR"
fi

echo "Running Happy Hare install script..."
if [ -f "$HH_DIR/install.sh" ]; then
    echo "Happy Hare install script may prompt you for inputs."
    cd "$HH_DIR"
    ./install.sh </dev/tty
    cd - >/dev/null
else
    echo "Error: install.sh not found in Happy-Hare repo!"
fi

echo ""
echo "==> Setting mmu__revision = 0 in saved_variables.cfg"
# Required by Happy Hare: It looks for 'mmu__revision' in the saved_variables.cfg.
SV_CFG="$CONFIG_DIR/saved_variables.cfg"
if [ ! -f "$SV_CFG" ]; then
    echo "[Variables]" > "$SV_CFG"
fi
# safely remove existing variable and append it again
tmp_sv=$(mktemp)
sed '/^mmu__revision[[:space:]]*=/d' "$SV_CFG" > "$tmp_sv"
echo "mmu__revision = 0" >> "$tmp_sv"
mv "$tmp_sv" "$SV_CFG"

echo ""
echo "==> Modifying printer.cfg and macro files..."

# We use python because it handles multiline parsing and regex matching safely.
# This prevents bash escaping issues when modifying the configuration files.
export CONFIG_DIR
python3 - << 'EOF'
import os
import re

config_dir = os.environ.get("CONFIG_DIR", os.path.expanduser("~/printer_data/config"))
printer_cfg_path = os.path.join(config_dir, "printer.cfg")
start_end_cfg_path = os.path.join(config_dir, "klipper-macros-qd", "start_end.cfg")
pause_resume_cancel_cfg_path = os.path.join(config_dir, "klipper-macros-qd", "pause_resume_cancel.cfg")

def modify_printer_cfg():
    if not os.path.exists(printer_cfg_path):
        print(f"Warning: {printer_cfg_path} not found.")
        return

    with open(printer_cfg_path, 'r') as f:
        content = f.read()

    # 1. Comment Qidi's stock box config `[include box.cfg]`
    content = re.sub(r'(?m)^\[include\s+box\.cfg\].*$', '# [include box.cfg] # Removed by Happy Hare installer', content)

    # Comment out `[multi_color_controller]`
    content = re.sub(r'(?m)^\[multi_color_controller\].*$', '# [multi_color_controller] # Removed by Happy Hare installer', content)

    # 2. Add `[include bunnybox_macros.cfg]` at the top if not present
    if '[include bunnybox_macros.cfg]' not in content:
        content = '[include bunnybox_macros.cfg]\n' + content
        
    # 4. Make sure Happy Hare files are included: `[include mmu/base/*.cfg]`
    # Happy Hare splits its logic into multiple base configs that are necessary for operation.
    if '[include mmu/base/*.cfg]' not in content:
        content = '[include mmu/base/*.cfg]\n' + content
    if '[include mmu/optional/client_macros.cfg]' not in content:
        content = '[include mmu/optional/client_macros.cfg]\n' + content

    # Ensure THR:PA0 is declared in [duplicate_pin_override]. HH's
    # mmu_hardware.cfg uses `extruder_switch_pin: !THR:PA0`, which collides
    # with the stock `[filament_switch_sensor filament_switch_sensor]
    # switch_pin: !THR:PA0`. Klipper needs the pin listed in
    # duplicate_pin_override or it errors at load.
    #
    # Stock Max4 printer.cfg already declares an empty `[duplicate_pin_override]`
    # section, so a naive insert creates a duplicate section and fails to parse.
    # Handle both cases: merge into the existing section if present, otherwise
    # inject a fresh one before the sensor.
    if re.search(r'(?m)^\[duplicate_pin_override\]', content):
        def _merge_pin(m):
            existing = m.group('pins').strip()
            if not existing:
                return f"{m.group('header')}pins: THR:PA0"
            pins = [p.strip() for p in existing.split(',') if p.strip()]
            if 'THR:PA0' in pins:
                return m.group(0)
            pins.append('THR:PA0')
            return f"{m.group('header')}pins: {', '.join(pins)}"

        content = re.sub(
            r'(?m)(?P<header>^\[duplicate_pin_override\][^\n]*\n)pins:(?P<pins>[^\n]*)',
            _merge_pin,
            content,
            count=1,
        )
    elif '[filament_switch_sensor filament_switch_sensor]' in content:
        content = content.replace(
            '[filament_switch_sensor filament_switch_sensor]',
            '[duplicate_pin_override]\npins: THR:PA0\n\n[filament_switch_sensor filament_switch_sensor]',
        )

    lines = content.split('\n')
    in_sensor = False
    new_lines = []
    
    # These properties from the stock filament switch sensor MUST be disabled
    # or they will conflict directly with the MMU operation.
    lines_to_comment = [
        'runout_gcode',
        'M118 Filament run out',
        'can_auto_reload',
        'AUTO_RELOAD_FILAMENT',
        '{% endif %}',
        '{% if',
        'insert_gcode'
    ]

    for line in lines:
        if line.strip().startswith('[filament_switch_sensor filament_switch_sensor]'):
            in_sensor = True
            new_lines.append(line)
            continue
        elif in_sensor and line.strip().startswith('['):
            in_sensor = False

        if in_sensor and line.strip():
            if not line.strip().startswith('#'):
                # Explicitly set pause_on_runout to False instead of commenting it out,
                # because Klipper defaults to True when the line is commented out.
                if 'pause_on_runout' in line:
                    line = 'pause_on_runout: False'
                else:
                    should_comment = False
                    for p in lines_to_comment:
                        if p in line:
                            should_comment = True
                            break
                    if should_comment:
                        line = '# ' + line

        new_lines.append(line)

    with open(printer_cfg_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print("Modified printer.cfg successfully.")

def modify_start_end_cfg():
    if not os.path.exists(start_end_cfg_path):
        print(f"Warning: {start_end_cfg_path} not found.")
        return

    with open(start_end_cfg_path, 'r') as f:
        content = f.read()

    # Comment out `_PRINT_START_BOX_PREPAR` inside PRINT_START, and the
    # `save_last_file` call site(s). save_last_file is Qidi's power-loss
    # recovery hook (sets was_interrupted=True in saved_variables.cfg on
    # every print start). PLR is disabled under HH (see DETECT_INTERRUPTION
    # override in bunnybox_macros.cfg), so we stop it being called —
    # otherwise was_interrupted would be written True every print and only
    # cleared at next boot, which is harmless but untidy.
    lines = content.split('\n')
    new_lines = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('#'):
            new_lines.append(line)
            continue
        if '_PRINT_START_BOX_PREPAR' in line:
            new_lines.append('# ' + line)
        elif stripped.lower() == 'save_last_file':
            new_lines.append('# ' + line)
        else:
            new_lines.append(line)

    with open(start_end_cfg_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print("Modified start_end.cfg successfully.")

def modify_pause_resume_cancel_cfg():
    if not os.path.exists(pause_resume_cancel_cfg_path):
        print(f"Warning: {pause_resume_cancel_cfg_path} not found.")
        return

    with open(pause_resume_cancel_cfg_path, 'r') as f:
        content = f.read()

    # 2. Comment out PAUSE, RESUME_PRINT, RESUME, CANCEL_PRINT, CLEAR_PAUSE
    # blocks entirely. Klipper gcode command names are case-insensitive, so
    # the match here is too — Max4 stock config uses lowercase
    # `[gcode_macro pause]` / `[gcode_macro clear_pause]`. CLEAR_PAUSE is
    # included because Max4's stock clear_pause references variables on
    # RESUME_PRINT; leaving it active after we delete RESUME_PRINT would make
    # the UI's "Clear Pause" button throw at runtime.
    lines = content.split('\n')
    new_lines = []
    in_macro_to_comment = False
    macros_to_comment = {'pause', 'resume_print', 'resume', 'cancel_print', 'clear_pause'}
    section_re = re.compile(r'^\[gcode_macro\s+([A-Za-z_][A-Za-z0-9_]*)\s*\]')

    for line in lines:
        stripped = line.strip()
        match = section_re.match(stripped)
        if match and match.group(1).lower() in macros_to_comment:
            in_macro_to_comment = True
        elif in_macro_to_comment and stripped.startswith('['):
            in_macro_to_comment = False

        if in_macro_to_comment and not stripped.startswith('#'):
            new_lines.append('# ' + line)
        else:
            new_lines.append(line)

    with open(pause_resume_cancel_cfg_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print("Modified pause_resume_cancel.cfg successfully.")

try:
    modify_printer_cfg()
    modify_start_end_cfg()
    modify_pause_resume_cancel_cfg()
except Exception as e:
    print(f"Error during python modification script: {e}")

EOF

echo ""
echo "==> Environment Sensor Installation..."
read -p "Do you want to install the custom AHT10 environment sensor module? (Recommended) (Y/n) " INSTALL_AHT10 </dev/tty
if [[ -z "$INSTALL_AHT10" ]] || [[ "$INSTALL_AHT10" =~ ^[Yy]$ ]]; then
    echo "Installing custom aht10.py module..."
    EXTRAS_DIR="$HOME/klipper/klippy/extras"
    if [ -d "$EXTRAS_DIR" ]; then
        cd "$EXTRAS_DIR"
        
        # Backup existing file if it exists
        if [ -f "aht10.py" ]; then
            if command -v sudo >/dev/null 2>&1; then
                sudo mv aht10.py aht10.py.bak
            else
                mv aht10.py aht10.py.bak
            fi
            echo "Backed up existing aht10.py to aht10.py.bak"
        fi
        
        # Download to temp file first, verify integrity, then move into place.
        # Prefer curl -fsSL (fails on HTTP errors); fall back to wget.
        tmp_aht=$(mktemp)
        AHT10_URL="https://raw.githubusercontent.com/Wazzup77/Bunny-Box/refs/heads/main/aht10.py"
        dl_ok=1
        if command -v curl >/dev/null 2>&1; then
            curl -fsSLo "$tmp_aht" "$AHT10_URL" && dl_ok=0
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$tmp_aht" "$AHT10_URL" && dl_ok=0
        fi
        if [ $dl_ok -eq 0 ] && [ -s "$tmp_aht" ]; then
            mv "$tmp_aht" aht10.py
            echo "Successfully downloaded custom aht10.py module"
        else
            echo "Failed to download custom aht10.py module"
            rm -f "$tmp_aht"
        fi
        
        cd - >/dev/null
    else
        echo "Error: Could not find klipper extras directory at $EXTRAS_DIR"
    fi
else
    echo "Skipping custom environment sensor module installation."
fi

echo ""
echo "==> Restarting Klipper..."
if command -v sudo >/dev/null 2>&1; then
    sudo systemctl restart klipper || echo "Failed to restart klipper automatically. Please restart it manually."
    sudo systemctl restart moonraker || echo "Failed to restart moonraker."
else
    echo "Could not find sudo. Please restart klipper manually."
fi

echo ""
echo "========================================================="
echo "   Installation Complete!                                "
echo "========================================================="
echo "Please remember to update slicer machine gcodes as specified in the README!"
echo "If Happy Hare installation had any issues, check its output above."
echo ""
echo "Note: The installer added [duplicate_pin_override] so the stock"
echo "[filament_switch_sensor] and the MMU can share THR:PA0. For the"
echo "cleanest setup you may comment out the stock [filament_switch_sensor"
echo "filament_switch_sensor] section once the MMU is verified working."
echo ""
