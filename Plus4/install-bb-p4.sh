#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# =========================================================================
# Happy Hare + Qidi Plus4 Automatic Installation Script
# =========================================================================
# This script automates the installation of Happy Hare and configures
# a Qidi Plus4 for standalone usage. It can be run either from a cloned
# repository or standalone (e.g., via wget or curl).
# =========================================================================

# Parse command-line arguments. --revert makes the script non-interactive
# (suitable for use in other scripts) by skipping the menu and running the
# revert flow directly.
REVERT_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --revert)
            REVERT_ONLY=1
            ;;
        -h|--help)
            cat <<EOF
Usage: $(basename "$0") [--revert] [--help]

Options:
  --revert    Restore the pre-install printer.cfg / gcode_macro.cfg from the
              oldest backup_hh_* directory and exit. Non-interactive — safe
              to call from other scripts.
  -h, --help  Show this help message and exit.

With no arguments, runs the interactive installer.
EOF
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "Use --help for usage." >&2
            exit 1
            ;;
    esac
done

# Ensure the script is not run as root. Klipper and the user configuration
# are expected to be owned and managed by the normal user (e.g. 'mks').
if [ "$EUID" -eq 0 ]; then
  echo "Please do not run this script as root. Run as your normal user (e.g. mks)."
  exit 1
fi

# Define paths for Klipper configuration data.
PRINTER_DATA_DIR="$HOME/printer_data"
CONFIG_DIR="$PRINTER_DATA_DIR/config"

# Set to 1 when we detect an existing install and the user chooses to update.
# Drives the smart-merge path instead of a blind overwrite (see
# smart_update_configs below).
BB_UPDATE=0

# Verify that the expected configuration directory exists.
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Could not find Klipper config directory at $CONFIG_DIR"
    echo "This script must be run on your printer."
    exit 1
fi

# Ensure required tools are present. Qidi firmware images often ship without
# git, and the standalone mode also needs unzip + curl/wget. Auto-install any
# missing packages via apt-get (Qidi printers are Debian-based).
# Skipped in --revert mode: revert needs none of these tools and we don't want
# scripted callers to trigger an apt-get just to roll back.
if [ "$REVERT_ONLY" -eq 0 ]; then
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

# =========================================================================
# Smart update machinery
# =========================================================================
# When updating an existing install we must not blindly overwrite the user's
# config: it holds hand-tuned parameters AND Happy Hare's calibration/state.
# Instead we keep a pristine snapshot of what we last shipped (the merge
# "base") in $CONFIG_DIR/.bunnybox_base plus a manifest recording the source
# git commit. On the next update we have all three legs of a 3-way merge
# locally (base / yours / new) without needing git history on the printer,
# and we can also show the upstream changelog from the recorded commit.

# Marker/manifest locations inside the Klipper config directory. Dot-prefixed
# so Klipper's [include ...] globs never pick them up.
BB_BASE_DIR="$CONFIG_DIR/.bunnybox_base"
BB_MANIFEST="$CONFIG_DIR/.bunnybox_manifest"

# Files that hold runtime/calibration state. These are NEVER merged or
# overwritten on update — only created if missing. mmu_vars.cfg is Happy
# Hare's calibration + state store (encoder, gear rotation distance, gate
# maps); clobbering it forces a full re-calibration.
BB_PRESERVE_FILES="mmu/mmu_vars.cfg"

bb_is_preserve() {
    case " $BB_PRESERVE_FILES " in *" $1 "*) return 0 ;; esac
    return 1
}

# Print the set of files we ship into the config dir, relative to the variant
# directory. We only manage the mmu/ tree and bunnybox_macros.cfg (the variant
# also contains README/slicer docs that are not copied to the printer).
bb_shipped_files() {
    ( cd "$SCRIPT_DIR/$CONFIG_VARIANT" 2>/dev/null && \
        find . -type f \( -path './mmu/*' -o -name 'bunnybox_macros.cfg' \) \
        | sed 's#^\./##' | sort )
}

# Show the upstream config changelog between the recorded commit and HEAD.
# Only possible when the installer is run from a git clone (not standalone
# zip) and a previous manifest recorded a real commit.
bb_print_changelog() {
    [ -f "$BB_MANIFEST" ] || return 0
    local oldc newc
    oldc=$(grep -E '^BB_COMMIT=' "$BB_MANIFEST" 2>/dev/null | head -n1 | cut -d= -f2 || true)
    [ -n "$oldc" ] && [ "$oldc" != "unknown" ] || return 0
    git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    git -C "$SCRIPT_DIR" cat-file -e "${oldc}^{commit}" 2>/dev/null || return 0
    newc=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || true)
    if [ "$oldc" = "$newc" ]; then
        echo "    Configs are already at the latest commit (${newc:0:8})."
        return 0
    fi
    echo ""
    echo "    Upstream config changes since your install (${oldc:0:8} -> ${newc:0:8}):"
    git -C "$SCRIPT_DIR" log --oneline "${oldc}..HEAD" -- "$CONFIG_VARIANT" 2>/dev/null \
        | sed 's/^/      /' || true
}

# Pretty-print one report category (skips empty categories).
bb_report_list() {
    local title="$1"; shift
    [ "$#" -eq 0 ] && return 0
    echo "    $title:"
    local f
    for f in "$@"; do echo "      - $f"; done
}

# The core smart update. Walks every shipped file and decides, per file,
# whether to keep, auto-update, 3-way merge, or ask the user.
smart_update_configs() {
    local src="$SCRIPT_DIR/$CONFIG_VARIANT"
    local have_base=0
    [ -d "$BB_BASE_DIR" ] && have_base=1

    # Report buckets (global so they survive the loop / nested logic).
    R_UPDATED=(); R_MERGED=(); R_KEPT=(); R_TOOKNEW=()
    R_MARKERS=(); R_ADDED=(); R_PRESERVED=(); R_REMOVED=()

    echo ""
    echo "==> Smart update: merging new configuration with your existing setup..."
    if [ "$have_base" -eq 0 ]; then
        echo "    No base snapshot found (this printer was set up before smart-update"
        echo "    support). A 3-way merge isn't possible, so for any file that differs"
        echo "    you'll be asked whether to keep yours or take the new one. Your"
        echo "    calibration (mmu_vars.cfg) is always kept, and a full backup already"
        echo "    exists in $BACKUP_DIR."
    fi
    bb_print_changelog

    local rel new mine bcopy merged ans
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        new="$src/$rel"
        mine="$CONFIG_DIR/$rel"
        bcopy="$BB_BASE_DIR/$rel"
        mkdir -p "$(dirname "$mine")"

        # 1. Calibration/state files: never touch an existing one.
        if bb_is_preserve "$rel"; then
            if [ ! -f "$mine" ]; then
                cp "$new" "$mine"; R_ADDED+=("$rel (state template)")
            else
                R_PRESERVED+=("$rel")
            fi
            continue
        fi

        # 2. Brand-new file we didn't ship before.
        if [ ! -f "$mine" ]; then
            cp "$new" "$mine"; R_ADDED+=("$rel"); continue
        fi

        # 3. Already identical to the new version — nothing to do.
        if cmp -s "$mine" "$new"; then continue; fi

        # 4. We have a merge base for this file -> classify precisely.
        if [ "$have_base" -eq 1 ] && [ -f "$bcopy" ]; then
            if cmp -s "$new" "$bcopy"; then
                # Upstream unchanged; the difference is the user's own edit.
                R_KEPT+=("$rel (your customisation, no upstream change)")
                continue
            fi
            if cmp -s "$mine" "$bcopy"; then
                # User never edited it; upstream changed -> adopt new default.
                cp "$new" "$mine"; R_UPDATED+=("$rel"); continue
            fi
            # Both sides changed -> attempt a clean 3-way merge.
            merged=$(mktemp)
            if git merge-file -p "$mine" "$bcopy" "$new" > "$merged" 2>/dev/null; then
                cp "$merged" "$mine"; rm -f "$merged"; R_MERGED+=("$rel"); continue
            fi
            rm -f "$merged"
            # Conflict -> ask the user.
            echo ""
            echo "  CONFLICT: $rel"
            echo "    Your edits overlap with new upstream changes in the same place."
            while true; do
                echo "      [k] keep YOUR version (default)"
                echo "      [n] take the NEW version (your file is safe in the backup)"
                echo "      [m] write a merged copy with <<< conflict markers >>> to"
                echo "          ${rel}.bbmerge (your live file is left untouched)"
                echo "      [d] show the merge with markers, then ask again"
                read -p "    Choose [k/n/m/d]: " ans </dev/tty || ans="k"
                case "${ans:-k}" in
                    k|K|"") R_KEPT+=("$rel (conflict — kept yours)"); break ;;
                    n|N)    cp "$new" "$mine"; R_TOOKNEW+=("$rel"); break ;;
                    m|M)    git merge-file -p --diff3 "$mine" "$bcopy" "$new" \
                                > "${mine}.bbmerge" 2>/dev/null || true
                            R_MARKERS+=("${rel}.bbmerge"); break ;;
                    d|D)    git merge-file -p --diff3 "$mine" "$bcopy" "$new" 2>/dev/null \
                                | sed 's/^/      | /' || true ;;
                    *)      echo "    Please choose k, n, m, or d." ;;
                esac
            done
            continue
        fi

        # 5. No merge base for this file: differs, can't merge -> ask.
        echo ""
        echo "  CHANGED (no merge base): $rel"
        echo "    Your file differs from the new version and there is no recorded"
        echo "    base to merge against."
        while true; do
            echo "      [k] keep YOUR version (default)"
            echo "      [n] take the NEW version (your file is safe in the backup)"
            echo "      [d] show the diff (yours vs new), then ask again"
            read -p "    Choose [k/n/d]: " ans </dev/tty || ans="k"
            case "${ans:-k}" in
                k|K|"") R_KEPT+=("$rel (no base — kept yours)"); break ;;
                n|N)    cp "$new" "$mine"; R_TOOKNEW+=("$rel"); break ;;
                d|D)    diff -u "$mine" "$new" | sed 's/^/      | /' || true ;;
                *)      echo "    Please choose k, n, or d." ;;
            esac
        done
    done < <(bb_shipped_files)

    # Report files that existed in the old base but are gone upstream. We do
    # not delete them automatically (they may be user-added or still wanted).
    if [ "$have_base" -eq 1 ]; then
        local brel
        while IFS= read -r brel; do
            [ -n "$brel" ] || continue
            if [ ! -f "$src/$brel" ] && [ -f "$CONFIG_DIR/$brel" ]; then
                R_REMOVED+=("$brel")
            fi
        done < <( cd "$BB_BASE_DIR" 2>/dev/null && find . -type f | sed 's#^\./##' | sort )
    fi

    echo ""
    echo "  ---------------- Update summary ----------------"
    bb_report_list "Auto-updated (no local edits)"            "${R_UPDATED[@]}"
    bb_report_list "Merged (your edits + new defaults)"       "${R_MERGED[@]}"
    bb_report_list "Kept your version"                        "${R_KEPT[@]}"
    bb_report_list "Replaced with new version"                "${R_TOOKNEW[@]}"
    bb_report_list "Conflict copies to resolve manually"      "${R_MARKERS[@]}"
    bb_report_list "New files added"                          "${R_ADDED[@]}"
    bb_report_list "Calibration/state preserved"              "${R_PRESERVED[@]}"
    bb_report_list "Removed upstream (left in place for you)" "${R_REMOVED[@]}"
    echo "  ------------------------------------------------"
    echo "  Full backup of your previous config: $BACKUP_DIR"
}

# Record what we just installed: a pristine snapshot of the shipped config
# files (the merge base for the NEXT update) and a manifest with the source
# git commit. Called on both fresh installs and updates so the base always
# tracks the version currently on disk.
write_install_manifest() {
    rm -rf "$BB_BASE_DIR"
    mkdir -p "$BB_BASE_DIR/mmu"
    cp -r "$SCRIPT_DIR/$CONFIG_VARIANT/mmu/." "$BB_BASE_DIR/mmu/"
    if [ -f "$SCRIPT_DIR/$CONFIG_VARIANT/bunnybox_macros.cfg" ]; then
        cp "$SCRIPT_DIR/$CONFIG_VARIANT/bunnybox_macros.cfg" "$BB_BASE_DIR/"
    fi
    local commit="unknown"
    if git -C "$SCRIPT_DIR" rev-parse HEAD >/dev/null 2>&1; then
        commit=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
    fi
    cat > "$BB_MANIFEST" <<EOF
BB_PRINTER=Plus4
BB_VARIANT=$CONFIG_VARIANT
BB_COMMIT=$commit
BB_INSTALL_DATE=$(date +"%Y-%m-%d %H:%M:%S")
EOF
    echo "==> Recorded install manifest (.bunnybox_manifest) and base snapshot (.bunnybox_base) for smart updates."
}

# Restore pre-install printer.cfg and gcode_macro.cfg from the oldest
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

    if [ -f "$CONFIG_DIR/printer.cfg" ];       then cp "$CONFIG_DIR/printer.cfg" "$revert_dir/"; fi
    if [ -f "$CONFIG_DIR/gcode_macro.cfg" ];   then cp "$CONFIG_DIR/gcode_macro.cfg" "$revert_dir/"; fi
    if [ -f "$CONFIG_DIR/bunnybox_macros.cfg" ]; then mv "$CONFIG_DIR/bunnybox_macros.cfg" "$revert_dir/"; fi
    if [ -d "$CONFIG_DIR/mmu" ];               then mv "$CONFIG_DIR/mmu" "$revert_dir/"; fi
    # Stash the smart-update markers too, so a reverted (stock) config dir is
    # left clean. They're regenerated on the next install.
    if [ -d "$CONFIG_DIR/.bunnybox_base" ];     then mv "$CONFIG_DIR/.bunnybox_base" "$revert_dir/"; fi
    if [ -f "$CONFIG_DIR/.bunnybox_manifest" ]; then mv "$CONFIG_DIR/.bunnybox_manifest" "$revert_dir/"; fi
    echo "Current bunnybox state preserved in $revert_dir"

    cp "$oldest/printer.cfg" "$CONFIG_DIR/"
    if [ -f "$oldest/gcode_macro.cfg" ]; then cp "$oldest/gcode_macro.cfg" "$CONFIG_DIR/"; fi

    if [ -f "$CONFIG_DIR/saved_variables.cfg" ]; then
        local tmp_sv
        tmp_sv=$(mktemp)
        sed '/^mmu__revision[[:space:]]*=/d' "$CONFIG_DIR/saved_variables.cfg" > "$tmp_sv"
        mv "$tmp_sv" "$CONFIG_DIR/saved_variables.cfg"
    fi

    echo "Restored printer.cfg and gcode_macro.cfg from $oldest"

    KLIPPY_PY="$HOME/klipper/klippy/klippy.py"
    if [ -f "${KLIPPY_PY}.bunnybox.bak" ]; then
        echo "Restoring original klippy.py from ${KLIPPY_PY}.bunnybox.bak"
        KLIPPY_SUDO=""
        if [ ! -w "$KLIPPY_PY" ] && command -v sudo >/dev/null 2>&1; then
            KLIPPY_SUDO="sudo"
        fi
        $KLIPPY_SUDO mv "${KLIPPY_PY}.bunnybox.bak" "$KLIPPY_PY"
    fi

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

# Non-interactive revert path (--revert flag): run the revert flow now and
# exit. revert_to_stock calls `exit 0` on success, so control never returns.
if [ "$REVERT_ONLY" -eq 1 ]; then
    if ! is_bb_installed; then
        echo "No bunnybox / Happy Hare install detected — nothing to revert."
        exit 1
    fi
    revert_to_stock
fi

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
    
    # Update SCRIPT_DIR to point to the extracted Plus4 folder
    # We detect the extracted folder name dynamically:
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    SCRIPT_DIR="$EXTRACTED_DIR/Plus4"
    
    if [ ! -d "$SCRIPT_DIR/config_hh-standalone" ]; then
         echo "Error: Expected configuration folders not found in downloaded archive."
         exit 1
    fi
    echo "Configurations downloaded successfully."
fi



echo "========================================================="
echo "   Happy Hare + Qidi Plus4 Automatic Installer "
echo "========================================================="
echo ""

if is_bb_installed; then
    BB_UPDATE=1
    echo "Existing Happy Hare / bunnybox install detected."
    echo "  1) Reinstall / update (re-apply configuration)"
    echo "  2) Revert to stock (restore pre-install printer.cfg and gcode_macro.cfg)"
    echo "  3) Cancel"
    read -p "Select [1/2/3, default 1]: " BB_ACTION </dev/tty
    case "$BB_ACTION" in
        2) revert_to_stock ;;
        3) echo "Cancelled."; exit 0 ;;
        *) echo "Proceeding with reinstall." ;;
    esac
else
    echo "This script will automate the installation of Happy Hare"
    echo "and configure your Qidi Plus4 for standalone usage."
    echo "Please ensure you have read the README."
    echo ""
    echo "IMPORTANT: Unload all filament from the box BEFORE installing."
    echo "After install you cannot load/unload until calibration, and gear"
    echo "calibration needs the filament cut flush at the gate (not loaded)."
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
if [ -f "$CONFIG_DIR/gcode_macro.cfg" ]; then cp "$CONFIG_DIR/gcode_macro.cfg" "$BACKUP_DIR/"; fi
# Copy (don't move) the mmu/ tree: the smart-update merge below reads the live
# config in place, so it must stay. A full copy here is still the safety net.
if [ -d "$CONFIG_DIR/mmu" ]; then cp -r "$CONFIG_DIR/mmu" "$BACKUP_DIR/"; fi
if [ -f "$CONFIG_DIR/bunnybox_macros.cfg" ]; then cp "$CONFIG_DIR/bunnybox_macros.cfg" "$BACKUP_DIR/"; fi
echo "Backups saved to $BACKUP_DIR"

echo ""
echo "==> Using Configuration Variant: config_hh-standalone (Recommended)"
CONFIG_VARIANT="config_hh-standalone"

if [ ! -d "$SCRIPT_DIR/$CONFIG_VARIANT" ]; then
    echo "Error: $CONFIG_VARIANT directory not found in $SCRIPT_DIR"
    exit 1
fi

if [ "$BB_UPDATE" -eq 1 ]; then
    # Existing install: merge new defaults into the user's config instead of
    # overwriting, preserving customisations and calibration.
    smart_update_configs
else
    echo ""
    echo "==> Copying configuration files from $CONFIG_VARIANT..."
    # Copy the Happy Hare MMU directory from the chosen variant into Klipper config
    cp -r "$SCRIPT_DIR/$CONFIG_VARIANT/mmu" "$CONFIG_DIR/"
    # Copy the custom macros specific to the Plus4 integration
    cp "$SCRIPT_DIR/$CONFIG_VARIANT/bunnybox_macros.cfg" "$CONFIG_DIR/"
    echo "Configurations copied."
fi

# Record the manifest + pristine base snapshot so the NEXT update can do a
# 3-way merge and show a changelog. Runs for both fresh installs and updates.
write_install_manifest

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
    SERIAL_DEVICES=()
    while IFS= read -r dev; do
        SERIAL_DEVICES+=("$dev")
    done < <(find /dev/serial/by-id -mindepth 1 -maxdepth 1 2>/dev/null | sort)

    if [ ${#SERIAL_DEVICES[@]} -eq 0 ]; then
        echo "No serial devices found in /dev/serial/by-id"
        echo ""
        read -p "Enter your printer's serial ID path manually: " SERIAL_ID </dev/tty
    else
        echo "Available serial devices:"
        for i in "${!SERIAL_DEVICES[@]}"; do
            printf "  %d) %s\n" "$((i+1))" "${SERIAL_DEVICES[$i]}"
        done
        echo ""
        read -p "Select serial device (1-${#SERIAL_DEVICES[@]}, or paste a full path): " SERIAL_SELECTION </dev/tty
        if [[ "$SERIAL_SELECTION" =~ ^[0-9]+$ ]] && [ "$SERIAL_SELECTION" -ge 1 ] && [ "$SERIAL_SELECTION" -le "${#SERIAL_DEVICES[@]}" ]; then
            SERIAL_ID="${SERIAL_DEVICES[$((SERIAL_SELECTION-1))]}"
            echo "Selected: $SERIAL_ID"
        else
            SERIAL_ID="$SERIAL_SELECTION"
        fi
    fi
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
echo "==> Installing Happy Hare from WIP repo..."
# Install the core Happy Hare software from its repository on the 'bunnybox' branch.
HH_DIR="$HOME/Happy-Hare"
if [ -d "$HH_DIR" ]; then
    echo "Happy-Hare repository already exists at $HH_DIR. Pulling latest..."
    cd "$HH_DIR"
    git fetch
    git checkout bunnybox
    git pull --rebase || {
        echo "Warning: git pull failed (likely due to upstream rebase). Resetting to match remote..."
        git reset --hard origin/bunnybox
    }
    cd - >/dev/null
else
    git clone -b bunnybox https://github.com/Wazzup77/Happy-Hare.git "$HH_DIR"
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
echo "==> Modifying printer.cfg and gcode_macro.cfg..."

echo ""
echo "==> Checking [idle_timeout] for drying state exclusion..."
# Happy Hare's MMU_HEATER DRY=1 keeps the box heater running for hours. If the
# stock [idle_timeout] fires during a drying cycle it will TURN_OFF_HEATERS and
# kill the dry. Issue #29 — wrap the existing gcode so that drying-active idle
# timeouts only zero the main printer heaters and leave the box untouched.
APPLY_DRYING_EXCLUSION=0
if [ -f "$CONFIG_DIR/printer.cfg" ] && grep -qE '^\[[[:space:]]*idle_timeout[[:space:]]*\]' "$CONFIG_DIR/printer.cfg"; then
    echo "Found [idle_timeout] section in printer.cfg."
    echo ""
    echo "Happy Hare's filament drying (MMU_HEATER DRY=1) keeps the box heater"
    echo "running for hours. With the stock idle_timeout gcode this will kill"
    echo "the heaters mid-dry. The installer can wrap the gcode so that, when"
    echo "drying is active, only extruder/heater_bed/chamber are zeroed and"
    echo "the box heaters keep running. When not drying, the original gcode"
    echo "runs unchanged."
    read -p "Apply this modification? (Recommended) (Y/n) " DRYING_ANSWER </dev/tty
    if [[ -z "$DRYING_ANSWER" ]] || [[ "$DRYING_ANSWER" =~ ^[Yy]$ ]]; then
        APPLY_DRYING_EXCLUSION=1
    fi
else
    echo "No [idle_timeout] section found in printer.cfg - skipping drying exclusion."
fi
export APPLY_DRYING_EXCLUSION

# We use python because it handles multiline parsing and regex matching safely.
# This prevents bash escaping issues when modifying the configuration files.
export CONFIG_DIR
python3 - << 'EOF'
import os
import re

config_dir = os.environ.get("CONFIG_DIR", os.path.expanduser("~/printer_data/config"))
printer_cfg_path = os.path.join(config_dir, "printer.cfg")
gcode_macro_cfg_path = os.path.join(config_dir, "gcode_macro.cfg")

def modify_printer_cfg():
    if not os.path.exists(printer_cfg_path):
        print(f"Warning: {printer_cfg_path} not found.")
        return

    with open(printer_cfg_path, 'r') as f:
        content = f.read()

    # 1. Comment Qidi's stock box config `[include box.cfg]`
    content = re.sub(r'(?m)^\[include\s+box\.cfg\].*$', '# [include box.cfg] # Removed by Happy Hare installer', content)

    # 2. Add `[include bunnybox_macros.cfg]` at the top if not present
    if '[include bunnybox_macros.cfg]' not in content:
        content = '[include bunnybox_macros.cfg]\n' + content
        
    # 3. Make sure Happy Hare files are included: `[include mmu/base/*.cfg]`
    # Happy Hare splits its logic into multiple base configs that are necessary for operation.
    if '[include mmu/base/*.cfg]' not in content:
        content = '[include mmu/base/*.cfg]\n' + content
    if '[include mmu/optional/client_macros.cfg]' not in content:
        content = '[include mmu/optional/client_macros.cfg]\n' + content

    lines = content.split('\n')
    in_hall_sensor = False
    in_fila_sensor = False
    new_lines = []

    # These properties from the stock filament sensors MUST be disabled or they
    # conflict with MMU operation. Happy Hare handles runout itself, so leaving
    # pause_on_runout: True on a stock sensor lets it pause prints outside HH's
    # control (and on the Qidi screen that pause can turn into a full cancel).
    # The Plus4 has BOTH a [hall_filament_width_sensor] (ADC PA2/PA3) and a
    # [filament_switch_sensor fila] (microswitch on PC3); both must be neutralised.
    lines_to_comment = [
        'min_diameter',
        'use_current_dia_while_delay',
        'runout_gcode',
        'RESET_FILAMENT_WIDTH_SENSOR',
        'M118 Filament run out',
        'Filament tangle detected',
        'can_auto_reload',
        'AUTO_RELOAD_FILAMENT',
        '{% endif %}',
        '{% if',
        'event_delay',
        'pause_delay'
    ]

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('[hall_filament_width_sensor]'):
            in_hall_sensor, in_fila_sensor = True, False
            new_lines.append(line)
            continue
        elif stripped.startswith('[filament_switch_sensor fila]'):
            in_hall_sensor, in_fila_sensor = False, True
            new_lines.append(line)
            continue
        elif (in_hall_sensor or in_fila_sensor) and stripped.startswith('['):
            in_hall_sensor = in_fila_sensor = False

        if (in_hall_sensor or in_fila_sensor) and stripped and not stripped.startswith('#'):
            # Explicitly set pause_on_runout to False instead of commenting it out,
            # because Klipper defaults to True when the line is commented out.
            if 'pause_on_runout' in line:
                line = 'pause_on_runout: False'
            elif any(p in line for p in lines_to_comment):
                line = '# ' + line

        new_lines.append(line)

    with open(printer_cfg_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print("Modified printer.cfg successfully.")

def modify_gcode_macro_cfg():
    if not os.path.exists(gcode_macro_cfg_path):
        print(f"Warning: {gcode_macro_cfg_path} not found.")
        return

    with open(gcode_macro_cfg_path, 'r') as f:
        content = f.read()

    # 1. Modify PRINT_START conditions
    # This matches spacing safely
    content = content.replace(
        '{% if printer.save_variables.variables.box_count >= 1 %}',
        '{% if printer.mmu.num_gates >= 4 %}'
    )
    content = content.replace(
        '{% if printer.save_variables.variables.enable_box == 1 %}',
        '{% if printer.mmu.enabled %}'
    )

    # 2. Comment out PAUSE, RESUME_PRINT, RESUME, CANCEL_PRINT, CLEAR_PAUSE,
    # DETECT_INTERRUPTION blocks entirely. Klipper gcode command names are
    # case-insensitive, so the match here is too — the Max4 stock config, for
    # example, uses lowercase `[gcode_macro pause]`. CLEAR_PAUSE is included
    # because some stock variants override it with a macro that references
    # variables on RESUME_PRINT; leaving it active after we delete
    # RESUME_PRINT would make the UI's "Clear Pause" button throw at runtime.
    # DETECT_INTERRUPTION is commented out because bunnybox_macros.cfg
    # provides a no-op replacement. We comment rather than `rename_existing`
    # so it also works on mainline Klipper / FreeDi installs where the stock
    # macro may be absent — `rename_existing` would otherwise fail with
    # "Existing command 'DETECT_INTERRUPTION' not found in gcode_macro rename".
    lines = content.split('\n')
    new_lines = []
    in_macro_to_comment = False
    macros_to_comment = {'pause', 'resume_print', 'resume', 'cancel_print', 'clear_pause', 'detect_interruption'}
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

    # 3. Comment out the `save_last_file` call site(s) in PRINT_START.
    # save_last_file is Qidi's power-loss recovery hook (stashes file path,
    # temps, and sets was_interrupted=True in saved_variables.cfg on every
    # print start). PLR is disabled under HH (see DETECT_INTERRUPTION
    # override in bunnybox_macros.cfg), so we stop it being called in the
    # first place — otherwise was_interrupted would be written True every
    # print and only cleared at next boot by our DETECT_INTERRUPTION
    # override, which is fine but untidy.
    out_lines = []
    for line in new_lines:
        stripped = line.strip()
        if stripped == 'save_last_file' or stripped.lower() == 'save_last_file':
            out_lines.append('# ' + line)
        else:
            out_lines.append(line)
    new_lines = out_lines

    with open(gcode_macro_cfg_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print("Modified gcode_macro.cfg successfully.")

def modify_idle_timeout():
    # Issue #29: Happy Hare's filament drying (MMU_HEATER DRY=1) keeps the box
    # heater running for hours, but the stock [idle_timeout] gcode (Klipper's
    # default TURN_OFF_HEATERS+M84, or Qidi's PRINT_END) will kill the heaters
    # during the dry. Wrap whatever gcode is in [idle_timeout] so that when
    # drying is active only the main printer heaters are zeroed; otherwise the
    # original gcode runs unchanged.
    if os.environ.get("APPLY_DRYING_EXCLUSION", "0") != "1":
        return
    if not os.path.exists(printer_cfg_path):
        return

    with open(printer_cfg_path, 'r') as f:
        content = f.read()

    lines = content.split('\n')
    section_re = re.compile(r'^\s*\[([^\]]+)\]\s*$')

    start = -1
    for idx, ln in enumerate(lines):
        m = section_re.match(ln)
        if m and m.group(1).strip() == 'idle_timeout':
            start = idx
            break
    if start < 0:
        print("No [idle_timeout] section in printer.cfg - skipping drying exclusion.")
        return

    end = len(lines)
    for idx in range(start + 1, len(lines)):
        if section_re.match(lines[idx]):
            end = idx
            break

    # Idempotent guard: re-running the installer must not double-wrap. Scope
    # the check to uncommented lines inside [idle_timeout] so that incidental
    # matches elsewhere in printer.cfg (commented remnants of a prior wrap,
    # unrelated macros that reference drying_state, etc.) don't suppress the
    # modification.
    already_wrapped = any(
        'printer.mmu.drying_state' in ln
        for ln in lines[start:end]
        if not ln.lstrip().startswith('#')
    )
    if already_wrapped:
        print("[idle_timeout] already has drying state exclusion - skipping.")
        return

    gcode_idx = -1
    for idx in range(start + 1, end):
        if re.match(r'^\s*gcode\s*:', lines[idx]):
            gcode_idx = idx
            break

    DRY_ON = [
        "SET_HEATER_TEMPERATURE HEATER=extruder TARGET=0",
        "SET_HEATER_TEMPERATURE HEATER=heater_bed TARGET=0",
        "SET_HEATER_TEMPERATURE HEATER=chamber TARGET=0",
    ]
    GUARD = "{% if printer.mmu is defined and printer.mmu.drying_state[0] == 'active' %}"
    ELSE = "{% else %}"
    ENDIF = "{% endif %}"

    if gcode_idx == -1:
        # No gcode: key in the section — Klipper falls back to its implicit
        # default of TURN_OFF_HEATERS + M84. Insert a new gcode: block at the
        # end of the section (before any trailing blank lines).
        indent = '    '
        inner = indent + '  '
        block = ['gcode:', indent + GUARD]
        for cmd in DRY_ON:
            block.append(inner + cmd)
        block.append(indent + ELSE)
        block.append(inner + "TURN_OFF_HEATERS")
        block.append(inner + "M84")
        block.append(indent + ENDIF)

        insert_at = end
        while insert_at > start + 1 and lines[insert_at - 1].strip() == '':
            insert_at -= 1
        new_lines = lines[:insert_at] + block + lines[insert_at:]
        with open(printer_cfg_path, 'w') as f:
            f.write('\n'.join(new_lines))
        print("Added gcode: block with drying state exclusion to [idle_timeout].")
        return

    # Existing gcode: block — wrap its body.
    gcode_line = lines[gcode_idx]
    _, inline = gcode_line.split(':', 1)
    inline_stripped = inline.strip()

    body_start = gcode_idx + 1
    body_end = body_start
    indent = None
    while body_end < end:
        ln = lines[body_end]
        if ln.strip() == '':
            body_end += 1
            continue
        if ln[:1] not in (' ', '\t'):
            break
        if indent is None:
            indent = ln[:len(ln) - len(ln.lstrip())]
        body_end += 1

    # Roll back past trailing blank lines so they stay outside the wrapper.
    while body_end - 1 >= body_start and lines[body_end - 1].strip() == '':
        body_end -= 1

    if indent is None:
        indent = '    '
    inner = indent + '  '

    body = lines[body_start:body_end]
    if inline_stripped:
        body = [indent + inline_stripped] + body

    wrapped = [indent + GUARD]
    for cmd in DRY_ON:
        wrapped.append(inner + cmd)
    wrapped.append(indent + ELSE)
    for b in body:
        if b.strip() == '':
            wrapped.append(b)
        else:
            wrapped.append('  ' + b)
    wrapped.append(indent + ENDIF)

    # Strip any inline content from the gcode: line — it was hoisted into body.
    new_gcode_line = re.sub(r'^(\s*gcode\s*:).*$', r'\1', gcode_line)

    new_lines = lines[:gcode_idx] + [new_gcode_line] + wrapped + lines[body_end:]
    with open(printer_cfg_path, 'w') as f:
        f.write('\n'.join(new_lines))
    print("Wrapped [idle_timeout] gcode with drying state exclusion.")

try:
    modify_printer_cfg()
    modify_gcode_macro_cfg()
    modify_idle_timeout()
except Exception as e:
    print(f"Error during python modification script: {e}")

EOF

echo ""
echo "==> Patching klippy.py to remove QIDI box_detect dependency..."
# QIDI's stock Klipper image ships a customised klippy.py that imports the
# closed-source `extras/box_detect.so` and calls into it during _connect.
# That .so is missing on mainline Klipper / Kalico / FreeDi and breaks any
# attempt to update Python, so we strip the four QIDI-injected sites here.
# Detection is by string match — stock/mainline/Kalico klippy.py contains
# nothing like it and the patch is a no-op there.
KLIPPY_PY="$HOME/klipper/klippy/klippy.py"
if [ ! -f "$KLIPPY_PY" ]; then
    echo "Note: klippy.py not found at $KLIPPY_PY; skipping."
elif ! grep -q "^from extras import box_detect" "$KLIPPY_PY"; then
    echo "No QIDI box_detect references found in klippy.py — skipping (stock/mainline/Kalico)."
else
    echo "QIDI box_detect references detected — patching klippy.py..."
    KLIPPY_SUDO=""
    if [ ! -w "$KLIPPY_PY" ] && command -v sudo >/dev/null 2>&1; then
        KLIPPY_SUDO="sudo"
    fi
    KLIPPY_OWNER=""
    KLIPPY_OWNER=$(stat -c '%U:%G' "$KLIPPY_PY" 2>/dev/null || true)
    if [ ! -f "${KLIPPY_PY}.bunnybox.bak" ]; then
        $KLIPPY_SUDO cp "$KLIPPY_PY" "${KLIPPY_PY}.bunnybox.bak"
        echo "Original saved to ${KLIPPY_PY}.bunnybox.bak"
    fi
    tmp_klippy=$(mktemp)
    KLIPPY_PY_PATH="$KLIPPY_PY" python3 - "$tmp_klippy" <<'PYEOF'
import os, re, sys
src = os.environ["KLIPPY_PY_PATH"]
dst = sys.argv[1]
with open(src, 'r') as f:
    content = f.read()
content = re.sub(r'(?m)^from extras import box_detect[ \t]*\r?\n', '', content)
content = re.sub(r'(?m)^import pyudev, shutil, configparser[ \t]*\r?\n', '', content)
content = re.sub(
    r'(?m)^[ \t]*for m in \[box_detect\]:[ \t]*\r?\n[ \t]+m\.add_printer_objects\(config\)[ \t]*\r?\n',
    '',
    content,
)
content = re.sub(
    r'(?m)^[ \t]*box_detect\.monitor_serial_devices\(self\)[ \t]*\r?\n',
    '',
    content,
)
with open(dst, 'w') as f:
    f.write(content)
PYEOF
    if [ -s "$tmp_klippy" ]; then
        $KLIPPY_SUDO mv "$tmp_klippy" "$KLIPPY_PY"
        if [ -n "$KLIPPY_SUDO" ] && [ -n "$KLIPPY_OWNER" ]; then
            $KLIPPY_SUDO chown "$KLIPPY_OWNER" "$KLIPPY_PY" || echo "Warning: failed to restore ownership of klippy.py"
        fi
        echo "Patched klippy.py — QIDI box_detect references removed."
    else
        echo "Error: patched klippy.py would be empty; aborting patch."
        rm -f "$tmp_klippy"
    fi
fi

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
echo "---------------------------------------------------------"
echo "  RECOMMENDED: Remove [hall_filament_width_sensor]       "
echo "---------------------------------------------------------"
echo "The stock [hall_filament_width_sensor] in printer.cfg reads adc1: PA2"
echo "and adc2: PA3 - the same pins the MMU uses for extruder_switch_pin"
echo "and extruder_switch_pin2. Two ADC readers on the same pins can"
echo "cause 'Timer too close' MCU crashes under load."
echo ""
echo "The MMU already provides filament detection, so the stock hall"
echo "sensor is redundant. It is STRONGLY recommended to comment out or"
echo "delete the entire [hall_filament_width_sensor] section from your"
echo "printer.cfg after verifying the MMU is working."
echo ""
echo "#########################################################"
echo "##                                                     ##"
echo "##   !!  STOP  -  CALIBRATION IS REQUIRED  !!          ##"
echo "##                                                     ##"
echo "#########################################################"
echo ""
echo "Happy Hare is INSTALLED but NOT yet CALIBRATED. It will NOT"
echo "load filament or print reliably until you calibrate it."
echo ""
echo "On the Plus4 you MUST do BOTH of these before your first print:"
echo "  1. GEAR calibration    -> MMU_CALIBRATE_GEAR"
echo "  2. ENCODER calibration -> MMU_CALIBRATE_ENCODER"
echo ""
echo "Optional (recommended later): MMU_CALIBRATE_BOWDEN, MMU_CALIBRATE_GATES"
echo ""
echo "Follow the step-by-step CALIBRATION section in the README, and the"
echo "official guide here:"
echo "  https://github.com/moggieuk/Happy-Hare/wiki/MMU-Calibration-TypeB"
echo ""
echo "#########################################################"
echo ""
