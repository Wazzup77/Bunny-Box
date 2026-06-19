# Bunny-Box Session Handoff Log

## Session: 2026-06-19 — Strip Backup/Revert Logic

**Branch:** `claude/loving-curie-79ogp0`

### What was done
Removed all backup and revert logic from the three install scripts:
- `Q2/install-bb-q2.sh`
- `Max4/install-bb-max4.sh`
- `Plus4/install-bb-p4.sh`

The AIO installer (`aio_menu.sh`) owns a full backup/restore system via `BUNNYBOX_INSTALLER`. Having a second, weaker backup baked into these scripts was redundant and created noise.

**Removed per script (identical pattern across all three):**
1. `--revert` CLI flag and its `REVERT_ONLY` variable
2. `revert_to_stock()` function
3. `REVERT_ONLY` dispatch block (non-interactive revert path)
4. "Revert to stock" option from the interactive menu (renumbered: Cancel is now option 2)
5. Main backup creation block (`backup_hh_<timestamp>` directories)
6. `aht10.py.bak` pre-overwrite backup in the aht10 module install section
7. Two `$BACKUP_DIR` references inside `smart_update_configs()` that would have become dangling references

**Verification:** `bash -n` passes on all three scripts; no `backup`, `revert`, `REVERT_ONLY`, `BACKUP_DIR`, or `TIMESTAMP` strings remain.

---

## Known Issues (carried forward)

### Problem B: T0–T3 / UNLOAD_T0-T3 not restored on uninstall (AIO repo)
After reverting from BunnyBox, T0–T3 and UNLOAD_T0-T3 buttons in OrcaSlicer do nothing. These macros live in `box1.cfg` on the printer. They are disabled by `fix_known_klipper_conflicts()` in `aio_menu.sh` (~lines 5021–5039) using a `## AIO_DISABLED:` prefix. `restore_aio_disabled_macros()` is supposed to reverse this on uninstall but likely has a bug. **Investigate in a future session.**
