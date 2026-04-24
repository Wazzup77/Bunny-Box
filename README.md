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
    * Make the Qidi Box work on older Qidi and non-Qidi printers

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
 * **Q2** - testing in progress!
 * **Max4** - NEEDS TESTERS! work in progress. Happy Hare works, configs are not tested yet. Use at your own risk.

 Should be compatible with Beacon/Cartographer mods.

## ISSUES / TODO
* Printer screen is broken on stock Qidi firmware while in print - probably won't be fixed
* Qidi Studio sync is not working
* Power-loss recovery is disabled. Qidi's PLR depends on closed-source code (binary `.so` on Plus4, shell scripts on Q2) and cannot restore MMU tool/gate state. The stock `DETECT_INTERRUPTION` popup ("Resume last print?") would auto-cancel on timeout and, even if accepted, would resume with the wrong filament. Our `bunnybox_macros.cfg` overrides `DETECT_INTERRUPTION` to silently clear the flag so the popup never appears.

If you run into issues please report them in the issue tracker here. We are also on Qidi's Discord server [in a dedicated thread](https://discord.com/channels/1184400034641477722/1443579858679500822) if you want to chat.

## HAPPY HARE FORK

We are for now relying on a fork of Happy Hare until our new features are pulled to mainline. This is necessary for handling of the hall effect sensor in the extruder of Qidi printers and Qidi's weird cutter configuration. 

[Happy Hare Qidi Fork](https://github.com/Wazzup77/Happy-Hare/).

## HARDWARE REFERENCE

* [Qidi Box Pinout](qidi_box_pinout.md)
* [Qidi Box DFU Flashing Guide](dfu_flash.md)

## ADDITIONAL HELP

Refer to the [Happy Hare documentation](https://github.com/moggieuk/Happy-Hare/wiki).

## Frequenty Asked Questions

<details>
<summary> Do I need to flash the Qidi Box firmware? </summary>

No! Qidi Box already runs Klipper (Qidi's fork). Since the Box is a slave to the host (printer), flashing is not needed regardless of if you are connecting to a Qidi printer, a Qidi printer flashed with FreeDi or Kalico, or a non-Qidi printer. Nonetheless, you can flash it - the instructions are [here](dfu_flash.md).

</details>

<details>
<summary> How do I go back to the stock firmware?  </summary>

Just replace the `gcode_macros.cfg` and `printer.cfg` files with the backed up stock ones and restart Klipper.

</details>

<details>
<summary> Can you add support for my printer? </summary>

I only have a Plus4 and so can't really make other printers work. There are people with the Q2 who are using Bunny Box though, so that will likely come soon. For the Max4, I don't have one, so that will only come if someone else makes it. As for older ones/non-Qidi printers, you're on your own - I don't have one and think it's unlikely anyone will make one for you.

</details>

<details>
<summary> I'm a bit of a noob, can you help me? </summary>

Unfortunately I probably won't be able to help you much - I'm pretty busy and issues with Happy Hare are very difficult to diagnose without having phyiscal access to the machine and full knowledge of its configuration. If you decide to use this, be aware that you are expected to read [Happy Hare documentation](https://github.com/moggieuk/Happy-Hare/wiki) and understand what you are doing.

</details>

<details>
<summary> I changed the speeds in mmu_parameters.cfg, why are loads weird now? </summary>

Qidi's encoder is not that great unfortunately. It's measurement will vary widely depending on speed. At the same time you cannot really adjust its sensitivity parameter, since it is used for clog detetion during print (when the filament is moving slowly). In effect, you should calibrate the lengts of tubes after changing speeds (using the encoder calibration routire in HH). 

</details>

<details>
<summary> My filament is grinding in the gears </summary>

Repeated load/unload cycles without any significant extrusion will cause the filament to grind in the gears. This is normal.

</details>

<details>
<summary> I'm getting false-positive runouts on filament changes! </summary>

You probably forgot to remove the runout from your [hall_filament_width_sensor] section in printer.cfg! Comment out the runout gcode and the pause on runout parameter, or remove the entire section.

</details>

<details>
<summary> I think my config is awesome, can I share it here? </summary>
Yes! Please create a PR. If you are able to make a distint configuration (e.g. for a different printer or compatible with stock Qidi gcode) please make a new folder for it and add a README describing the configuration and installation. Small configuration tweaks can be made to the base configs, but should be well described and justified.

</details>

<details>
<summary> I love this mod! Happy Hare is great! How can I make it even better!? </summary>
Get a [proportional sensor](https://github.com/kashine6/Proportional-Sync-Feedback-Sensor) and use it instead of the stock filament tangle sensor.

</details>

## CONTRIBUTING

PRs are welcome! Just make sure to describe what system you're working with (Qidi Klipper, Klipper or Kalico) and what other mods you have.
We prefer strong defaults that should work with everyone here, even if they are not optimal. Go slower or more wasteful by default, let willing users tune it to their demands.

## SUPPORT THE PROJECT

[Support Happy Hare instead!](https://www.paypal.me/moggieuk)
