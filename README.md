# Bunny Box - the Qidi Box Happy Hare conversion

## FEATURES

 * Open source alternative to Qidi's Box control
    * No more .so files (you can update Python again)
    * Full control over Qidi Box configuration

 * Compatible with gcode generated for stock Qidi printers
    * printer profiles to make Orca Slicer or Prusa Slicer behave like Qidi Slicer also available
    * alternatively, use of a typical Happy Hare printer profile is also supported

 * Fully featured Happy Hare
    * Tip forming - save filament by reducing waste
    * the entire loading process can be tinkered with - increase loading speeds, change toolchange sequences, etc.
    * Spoolman support for better filament management
    * configurable LED effects depending on print / filament state

 **NOT SUPPORTED:**
 * RFID tags - maybe in the future, but honestly who cares?

## DEVELOPMENT STATUS

 * **Happy Hare** - the Qidi fork has been developed and tested, but not yet pulled into mainline. You can find it [here](https://github.com/Wazzup77/Happy-Hare). The `bunnybox` branch is used as the installation source.
 * **Plus4** - works with  [here](Plus4), tested on Qidi's 1.7.3, FreeDi (so stock Klipper) and Kalico (with minor issues still to be resolved).
 * **Q2** - some people have it working already (note XX and YY), to be added here soon.

 Should be compatible with Beacon/Cartographer mods.

## ISSUES / TODO
* Cutter support
* Printer screen is broken
* Error handling could be improved I guess
* Qidi Studio sync is not working

If you run into issues please report them in the issue tracker here. We are also on Qidi's Discord server [in a dedicated thread](https://discord.com/channels/1184400034641477722/1443579858679500822) if you want to chat.

## HAPPY HARE FORK

We are for now relying on a fork of Happy Hare until our new features are pulled to mainline. This is necessary for handling of the hall effect sensor in the extruder of Qidi printers. 

[Happy Hare Qidi Fork](https://github.com/Wazzup77/Happy-Hare/).

## HARDWARE REFERENCE

* [Qidi Box Pinout](qidi_box_pinout.md)

## ADDITIONAL HELP

Refer to the [Happy Hare documentation](https://github.com/moggieuk/Happy-Hare/wiki).