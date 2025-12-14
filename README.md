# Bunny Box - the Qidi Box Happy Hare conversion

## FEATURES

 * Open source alternative to Qidi's Box control (
    * No more .so files (you can update Python again)
    * Full control over Qidi Box configuration
 )
 * Compatible with gcode generated for stock Qidi printers (
    * printer profiles to make Orca Slicer or Prusa Slicer behave like Qidi Slicer also available
    * alternatively, use of a typical Happy Hare printer profile is also supported
 )
 * Fully featured Happy Hare (
    * the entire loading process can be tinkered with - increase loading speeds, change toolchange sequences, etc.
    * Spoolman support for better filament management
    * configurable LED effects depending on print / filament state
 )

 NOT SUPPORTED:
 * RFID tags - maybe in the future, but honestly who cares?

## DEVELOPMENT STATUS

 * Happy Hare - the Qidi fork has been developed and tested, but not yet pulled into mainline. You can find it [here](https://github.com/Wazzup77/Happy-Hare).
 * Plus4 - in beta, configs are available [here](Plus4), tested on 1.7.3.
 * Q2 - in development, configs will be available. Happy Hare should work, but you will need to configure it yourself if you want to use it now.

 Currently developed and tested on stock firmware. Other versions will likely be supported in the future - especially FreeDi!

 Should be compatible with Beacon/Cartographer mods.

## ISSUES / TODO
* Printer screen is broken
* Error handling could be improved I guess

If you run into issues please report them in the issue tracker here. We are also on Qidi's Discord server [in a dedicated thread](https://discord.com/channels/1184400034641477722/1443579858679500822) if you want to chat.

## ADDITIONAL HELP

Refer to the [Happy Hare documentation](https://github.com/moggieuk/Happy-Hare/wiki).