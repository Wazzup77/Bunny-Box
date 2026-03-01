<p align="center">
  <img src="https://github.com/Wazzup77/Bunny-Box/blob/main/logo.jpg" alt='A bunny in the style of the Qidi Box' width='30%'>
  <h1 align="center">Bunny Box</h1>
</p>

<p align="center">
Qidi Box open source makeover using Happy Hare
</p>

Bunny Box is the Qidi Box mod that allows you to ditch Qidi's closed-source, proprietary firmware and use [Happy Hare](https://github.com/moggieuk/Happy-Hare/) to control your Box. With added support for Qidi-specific qirks such as the extruder hall sensor and above-extruder cutter placement, this allows Qidi Box use with Freedi and Kalico as well as using non-Qidi multimaterial units with Qidi printers. Strong defaults are provided, but the beauty of Happy Hare is that almost anything can be tweaked!

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
 * **Q2** - some people have it working already (note [53Aries](https://github.com/53Aries/Qidi-Q2-Box-Happy-Hare) and YY), to be added here soon.
 * **Max4** - nobody is currently working on this (I don't have this printer) - will be added if someone creates the configs

 Should be compatible with Beacon/Cartographer mods.

## ISSUES / TODO
* Printer screen is broken on stock Qidi firmware while in print - probably won't be fixed
* Qidi Studio sync is not working

If you run into issues please report them in the issue tracker here. We are also on Qidi's Discord server [in a dedicated thread](https://discord.com/channels/1184400034641477722/1443579858679500822) if you want to chat.

## HAPPY HARE FORK

We are for now relying on a fork of Happy Hare until our new features are pulled to mainline. This is necessary for handling of the hall effect sensor in the extruder of Qidi printers and Qidi's weird cutter configuration. 

[Happy Hare Qidi Fork](https://github.com/Wazzup77/Happy-Hare/).

## HARDWARE REFERENCE

* [Qidi Box Pinout](qidi_box_pinout.md)

## ADDITIONAL HELP

Refer to the [Happy Hare documentation](https://github.com/moggieuk/Happy-Hare/wiki).

## CONTRIBUTING

PRs are welcome! Just make sure to describe what system you're working with (Qidi Klipper, Klipper or Kalico) and what other mods you have.
We prefer strong defaults that should work with everyone here, even if they are not optimal. Go slower or more wasteful by default, let willing users tune it to their demands.

## SUPPORT THE PROJECT

[Support Happy Hare instead!](https://www.paypal.me/moggieuk)
