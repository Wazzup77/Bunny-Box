# STANDALONE HAPPY HARE

The goal of this config is to have a configuration that uses Happy Hare as much as possible. In this way we have access to all the advanced features of Happy Hare and can configure the printer to our liking via mmu configuration files.

>[!WARNING]
>Gcodes for this config differ from Qidi's stock box gcode. Do not use old Qidi Box gcodes or the stock Qidi slicer profile!

## STATUS

Working - issues should be minor.

Known issues:
- none!

Report new issues via the Github "Issues" tab.

## ABOUT THESE FILES (maintainers)

At install time the Bunny Box installer copies this `mmu/` tree, then runs Happy
Hare's `install.sh` in upgrade mode. That installer **owns most of these files**:

* `mmu_cut_tip.cfg`, `mmu_form_tip.cfg`, `mmu_sequence.cfg`, `mmu_purge.cfg`,
  `mmu_leds.cfg`, `mmu_software.cfg`, `mmu_state.cfg`, `optional/*.cfg` — replaced
  with **symlinks** into `~/Happy-Hare`. The copies here are reference mirrors of
  the Happy Hare fork and are **not** the live config. Any Qidi-specific change to
  this logic must go into the [Happy Hare fork](https://github.com/Wazzup77/Happy-Hare)
  (`bunnybox` branch) — editing it here does nothing. Keep them in sync with the
  fork so the repo isn't misleading.
* `mmu_parameters.cfg`, `mmu_macro_vars.cfg`, `addons/*.cfg` (non-`_hw`) — Happy
  Hare re-templates these but **carries your values forward**, so the *values*
  here act as install-time defaults.

Bunny Box genuinely owns (Happy Hare leaves them frozen): `mmu_hardware.cfg`,
`mmu.cfg`, `addons/*_hw.cfg`, and the top-level `bunnybox_macros.cfg`. These are
the files the installer's smart-update 3-way-merges on re-install.

## INSTALLATION

1. Replace your bunnybox_macros.cfg with the one in this folder.

2. Replace your mmu folder with the one in this folder.

3. In the slicer, set your profile to use the machine gcodes [following g-codes](slicer_machine_gcodes_hh.md)

4. Make sure your gcode_macros.cfg follows the following rule (in addition to the common changes made during installation):

    * nothing that requires filament happens in PRINT_START
