# STANDALONE HAPPY HARE

The goal of this config is to have a configuration that uses Happy Hare as much as possible. In this way we have access to all the advanced features of Happy Hare and can configure the printer to our liking via mmu configuration files.

>[!WARNING]
>Gcodes for this config differ from Qidi's stock box gcode. Do not use old Qidi Box gcodes or the stock Qidi slicer profile!

## STATUS

Working - issues should be minor.

Known issues:
- none!

Report new issues via the Github "Issues" tab.

## INSTALLATION

1. Replace your bunnybox_macros.cfg with the one in this folder.

2. Replace your mmu folder with the one in this folder.

3. In the slicer, set your profile to use the machine gcodes [following g-codes](slicer_machine_gcodes_hh.md)

4. Make sure your gcode_macros.cfg follows the following rule (in addition to the common changes made during installation):

    * nothing that requires filament happens in PRINT_START

5. If you are using the Conch hotend, you will need to modify the mmu_macro_vars.cfg file to use the values for the Conch hotend. They are present inside the file already (in the Tip Forming section), just uncomment them out and remove the stock hotend values.
