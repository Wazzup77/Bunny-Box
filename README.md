# Qidi Plus 4 Mainline Klipper/Kalico Guide with MKS-PI Armbian image

# ⚠️ WARNING

**absolutely no guarantees, you do everything at your own risk.**  

This is **work in progress**. Do not use any of these configs or instructions unless you know what you're doing!
These modifications are for experienced users. If you are not comfortable with a command line, linux, and electronics, please stop here!

**ALSO NOTE: YOUR OEM SCREEN WILL NOT WORK AFTER FOLLOWING THESE STEPS**

You can opt to replace the screen and move to a KlipperScreen setup to get a functioning display.

Another option to use the OEM screen is [Klipmin](https://github.com/ctbenergy/qidi-plus4-klipmi)

# Introduction

Flashing mainline klipper/kalico on the Qidi Plus4 is relatively easy but does require some effort to flash the toolhead board. You will need an ST-Link programmer or clone to flash the toolhead.

# Backup

Before proceeding, backup any and all data in your printer configs, particularly your `printer.cfg`, `gcode_macros.cfg` and any other files
you may want to save. This can be done via the fluidd interface.

# Flashing the host with an updated Armbian image

redrathnure MKS-PI now merged in armbian build (https://github.com/armbian/build/pull/7553).

## Tools required:

* USB EMMC reader such as [this one](https://www.amazon.com/Vacatga-Adapter-EMMC-Adapter-52-6x16x10mm-2-07x0-63x0-39in/dp/B0D1MY7943?gQT=1)
* A spare eMMC card (optional but recommended) if you want to preserve the original stock card

## Flashing Steps

1. Power down your printer and remove the eMMC card from the printer motherboard. It is held down with 2 screws.

2. Download the following image:

    - Community maintained armbian MKS PI (https://www.armbian.com/mks-pi/).
    - Debian 13 Trixie Image (https://dl.armbian.com/mkspi/Trixie_current_minimal).

3. Write the image to your eMMC card via your preferred method (Rufus, Balena Etcher, dd, etc)

4. Automatic first boot configuration

    - If you need wireless networking then following this guide (https://docs.armbian.com/User-Guide_Autoconfig/).

5. Unmount the eMMC card and re-install it into your printer and power on. If everything worked, you should now be able to access your printer via SSH.

6. SSH into your printer.

    - Using the default username `root` and the password is `1234`

7. Install updates
    Lets make sure our system is up-to-date with the latest software.
    ```
    sudo apt update && sudo apt upgrade
    sudo apt install git -y
    ```

### Disable debug console

By default, the Plus4 uses `/dev/ttyS2` to communicate with the toolhead. The fresh armbian image you just flashed uses `/dev/ttyS2` as a
kernel debug console, so we need to disable that:
```bash
echo 'console=none' > sudo tee -a /boot/armbianEnv.txt

# Grant user permissions and prevent getty from taking over the port
echo 'KERNEL=="ttyS2",MODE="0660"' > /etc/udev/rules.d/99-ttyS2.rules
systemctl mask serial-getty@ttyS2.service
```

For more information on these changes, see here: https://github.com/redrathnure/armbian-mkspi?tab=readme-ov-file#disable-debug-console-uart2--or-freeup-uart1-interface

### USB autosuspend

```bash
echo 'extraargs=usbcore.autosuspend=-1' > sudo tee -a /boot/armbianEnv.txt
```

## Installing klipper/kalico, moonraker, fluidd/mainsail and friends

Now that we have a clean, fresh system, we can start installing the software needed to run the printer. If you want to do this manually, you certainly can.
For everyone else, I recommend installing KIAUH.

## Installing KIAUH

KIAUH is a helper script to install klipper/kalico, mainsail, fluidd, crowsnest, moonraker, and many other things you may need or want.
The following steps will get KIAUH installed:

```bash
  cd ~
  git clone https://github.com/dw-0/kiauh.git
  ./kiauh/kiauh.sh
```

You will now be entered into the KIAUH main menu where you can install the software needed. At a minium install
* Klipper (or Kalico)
* moonraker
* fluidd (or mainsail)

KIAUH should automatically install all the required modules and start the services for you.

After everything is installed, we can move our backed up configurations over to the new setup:
Copy your `printer.cfg` and `gcode_macros` to `~/printer_data/config`

# Flashing the main MCU

## Flashing Katapult Deployer

These steps will build the Katapult deployer application. Make sure that you already have your ST-LINK programmer (or clone) on hand. If something goes wrong,
you will have to recover with the programmer. [Further details of Katapult deployer can be found here.](https://github.com/Arksine/katapult?tab=readme-ov-file#katapult-deployer)

1. SSH into your printer

2. Download Katapult and configure for the main board:
    ```
    cd ~/
    git clone https://github.com/Arksine/katapult
    cd katapult
    make menuconfig
    ```
    Once you are in `make menuconfig`, you want to build katapult with the following options:
    ![image](doc/images/main-mcu-katapult-menuconfig.png)

    After you are sure your menuconfig matches the above settings, you can quit menuconfig (press q then y to save)
3. run `make -j4` to build katapult

4. Copy `~/katapult/out/deployer.bin` to your computer via your favorite method (scp, sftp, or using the fluidd interface)

5. On your computer, format the microSD card as FAT32

6. Copy the `deployer.bin` file to the microSD card and rename it `qd_mcu.bin`

7. Eject the microSD card and plug it into the microSD card slot on the printer.

8. Once the card is inserted, find the button labeled "RESET" on the main board and press it

9. Wait 30-60 seconds
    - You can verify that the flash worked by checking the file on the microSD card - it should be renamed to `qd_mcu.CUR`

10. Eject the microSD card. Katapult should now be flashed to the main MCU.

Update Katapult Deployer from Github.

```
cd ~/katapult
git pull origin master
```

## Flashing Klipper on the main MCU

1. SSH into your printer

2. Install the `pyserial` Python package. This package is needed to run the katapult flashtool script.

   ```
   python -m pip install pyserial
   ```

4. Execute the following to build Klipper
    ```
    cd ~/klipper
    make menuconfig
    ```
    Configure the make arguments in `menuconfig` to match these settings:
    ![image](doc/images/main-mcu-klipper-menuconfig.png)

5. Save and quit by pressing `q` then `y` to save

6. Build klipper by running `make clean; make -j4`

7. Prepare to flash. Double-click the "RESET" button on the board to load katapult. The button must be pressed twice within 500ms.

    ![image](doc/images/main-mcu-reset-button.png)

8. Flash via katapult by doing the following:
    ```
    cd ~/katapult/scripts
    python3 flashtool.py -b 500000 -d /dev/ttyS0 -f ~/klipper/out/klipper.bin
    ```
    You should see output similar to the following if the flash worked:
    <!-- ![image](doc/images/main-mcu-klipper-flash-success.png) -->

    ```
    mks@mkspi:~/katapult/scripts$ python3 flashtool.py -b 500000 -d /dev/ttyS0 -f ~/klipper/out/klipper.bin
    Connecting to Serial Device /dev/ttyS2, baud 500000
    Detected Klipper binary version v0.13.0-454-ge60fe3d9, MCU: stm32f103xe
    Attempting to connect to bootloader
    Katapult Connected
    Software Version: v0.0.1-110-gb0bf421
    Protocol Version: 1.1.0
    Block Size: 64 bytes
    Application Start: 0x8008000
    MCU type: stm32f401xc
    Flashing '/home/mks/klipper/out/klipper.bin'...

    [##################################################]

    Write complete: 3 pages
    Verifying (block count = 604)...

    [##################################################]

    Verification Complete: SHA = 80CFBE7C1F402006A87EFCCF8CCE92141DC2DC42
    Programming Complete
    ```

9. Klipper is now flashed to the main MCU. We can now move on to the toolhead.

# Flashing the toolhead MCU

The toolhead takes quite a bit more work to flash. You will need to solder some pins on the board and you will also need an ST-Link programmer (or clone).

The Chinese ST-LINK/V2 clone programmer is what I used.

![image](doc/images/st-link-v2-mini.png)

You can purchase the official ST-LINK programmer from [Digikey](https://www.digikey.com/en/products/detail/stmicroelectronics/ST-LINK-V2/2214535)

## Preparing the toolhead

Begin by unsliding the back cover of the toolhead, disconnecting all connectors, and unscrewing the board from the toolhead.

[QIDI Plus4 | How to replace the adapter plates](https://www.youtube.com/watch?v=jD4cqVDlX6U)

Next, you need to solder a 6 pin header on the board like the below image:

![image](doc/images/toolhead-mcu-6-pin-connector.png)

Once the header is soldered, we need to wire it to the ST-LINK:

![image](doc/images/toolhead-mcu-wiring-st-link-v2-mini.png)

ST-LINK V2 Clone Header:

![image](doc/images/st-link-v2-clone-header.png)

## Flashing Katapult on the toolhead

I used the printer itself to flash the toolhead but you can use any other computer available to build and flash.

1. Plug your ST-Link into the top usb port of the printer

2. Install the ST-Link tools: `sudo apt install stlink-tools`

3. Check that your ST-Link is recognized (and recognizing the toolhead): `st-info --probe`. You should see output similar to this:
<!--- ![image](doc/images/st-info-probe.png) --->

```bash
mks@mkspi:~$ st-info --probe
Found 1 stlink programmers
  version:    V2J32S7
  serial:     55FF72065187565351411967
  flash:      131072 (pagesize: 2048)
  sram:       65536
  chipid:     0x414
  dev-type:   F1xx_HD
```

  Note that your output might not match exactly. What you are looking for is that it found an stlink programmer, and it detects a chip (above we see `chipid: 0x414` and `dev-type: F1xx_HD`).
  If you don't see these things, double check your wiring.

4. Next, we need to build katapult for the toolhead:
    ```
    cd ~/katapult
    make menuconfig
    ```

    Make sure your menuconfig matches this:

    ![image](doc/images/toolhead-mcu-katapult-menuconfig.png)

    ```
    make clean
    make -j4
    ```

5. Now we can flash katapult via the ST-Link:

    ```
    st-flash write ~/katapult/out/katapult.bin 0x8000000
    ```

    You should see a message like this:
    <!-- ![image](doc/images/toolhead-mcu-katapult-flash-success.png) --> 

    ```
    mks@mkspi:~/katapult$ st-flash write ~/katapult/out/katapult.bin 0x8000000
    st-flash 1.8.0
    2025-12-06T14:50:14 INFO common.c: F1xx_HD: 64 KiB SRAM, 128 KiB flash in at least 2 KiB pages.
    file /home/mks/katapult/out/katapult.bin md5 checksum: a22175da3f6ecb9817502312c535e19f, stlink checksum: 0x00044f04
    2025-12-06T14:50:14 INFO common_flash.c: Attempting to write 3060 (0xbf4) bytes to stm32 address: 134217728 (0x8000000)
    -> Flash page at 0x8000800 erased (size: 0x800)
    2025-12-06T14:50:14 INFO flash_loader.c: Starting Flash write for VL/F0/F3/F1_XL
    2025-12-06T14:50:14 INFO flash_loader.c: Successfully loaded flash loader in sram
    2025-12-06T14:50:14 INFO flash_loader.c: Clear DFSR
    2/2   pages written
    2025-12-06T14:50:14 INFO common_flash.c: Starting verification of write complete
    2025-12-06T14:50:14 INFO common_flash.c: Flash written and verified! jolly good!
    ```

6. Unhook your ST-Link from the USB port, disconnect all ST-Link wires from the toolhead, put the toolhead covers back onto the toolhead and reboot the printer.

## Flashing Klipper on the toolhead

This is the same basic process that we used to flash klipper on the main MCU

1. Build klipper

    ```
    cd ~/klipper
    make menuconfig
    ```
    Your menuconfig should match this for the toolhead:

    ![image](doc/images/toolhead-mcu-klipper-menuconfig.png)

    ```
    make clean
    make -j4
    ```

2. Double click the reset button on the toolhead within 500ms to enter Katapult

    ![image](doc/images/toolhead-mcu-reset-button.png)

3. Flash klipper:

    ```
    cd ~/katapult/scripts
    python3 flashtool.py -b 500000 -d /dev/ttyS2 -f ~/klipper/out/klipper.bin
    ```

    You should see a successful flash like this:
    <!-- ![image](doc/images/toolhead-mcu-klipper-flash-success.png) -->

    ```
    mks@mkspi:~/katapult/scripts$ python3 flashtool.py -b 500000 -d /dev/ttyS2 -f ~/klipper/out/klipper.bin
    Connecting to Serial Device /dev/ttyS2, baud 500000
    Detected Klipper binary version v0.13.0-454-ge60fe3d9, MCU: stm32f103xe
    Attempting to connect to bootloader
    Katapult Connected
    Software Version: v0.0.1-110-gb0bf421
    Protocol Version: 1.1.0
    Block Size: 64 bytes
    Application Start: 0x8002000
    MCU type: stm32f103xe
    Flashing '/home/mks/klipper/out/klipper.bin'...

    [##################################################]

    Write complete: 36 pages
    Verifying (block count = 575)...

    [##################################################]

    Verification Complete: SHA = 4C71B043812F67EECBAC1A641C231B8685D36226
    Programming Complete
    ```

4. Reboot the printer and you're done - you can now start configuring!

# Flashing the Qidi Box

## Flashing Katapult on the Qidi Box

1. Build katapult

    ```
    cd ~/katapult
    make menuconfig
    ```
    Make sure your menuconfig matches this:

    ![image](doc/images/mmu-mcu-katapult-menuconfig.png)

    ```
    make clean
    make -j4
    ```

2. Make sure the klipper service stopped

    ```
    sudo service klipper stop
    ```

3. Put MCU into DFU mode

    ```
    cd ~/katapult/scripts/
    python3 flashtool.py -d /dev/serial/by-id/usb-Klipper_QIDI_BOX_V1_1.1.1_56003A001051353033353536-if00 -b 500000 -r
    Connecting to Serial Device /dev/serial/by-id/usb-Klipper_QIDI_BOX_V1_1.1.1_56003A001051353033353536-if00, baud 500000
    Detected USB device running Klipper
    Requesting USB bootloader for /dev/serial/by-id/usb-Klipper_QIDI_BOX_V1_1.1.1_56003A001051353033353536-if00...
    Waiting for USB Reconnect...done
    Detected new USB Device: 0483:5740 mks color boot
    Device is not Katapult, exiting...
    Bootloader Request Complete
    ```

4. Check if MCU into DFU mode

    ```
    lsusb
    Bus 002 Device 006: ID 0483:df11 STMicroelectronics STM Device in DFU Mode
    ```

5. Flash katapult:

    ```
    sudo dfu-util -R -a 0 -s 0x08000000:mass-erase:force:leave -D ~/katapult/out/katapult.bin -d 0483:df11

    ```

    You should see a successful flash like this:

    <!-- ![image](doc/images/mmu-mcu-katapult-flash-success.png) -->

    ```
    Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
    Copyright 2010-2021 Tormod Volden and Stefan Schmidt
    This program is Free Software and has ABSOLUTELY NO WARRANTY
    Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

    dfu-util: Warning: Invalid DFU suffix signature
    dfu-util: A valid DFU suffix will be required in a future dfu-util release
    Opening DFU capable USB device...
    Device ID 0483:df11
    Device DFU version 011a
    Claiming USB DFU Interface...
    Setting Alternate Interface #0 ...
    Determining device status...
    DFU state(10) = dfuERROR, status(10) = Device's firmware is corrupt. It cannot return to run-time (non-DFU) operations
    Clearing status
    Determining device status...
    DFU state(2) = dfuIDLE, status(0) = No error condition is present
    DFU mode device DFU version 011a
    Device returned transfer size 2048
    DfuSe interface name: "Internal Flash  "
    Performing mass erase, this can take a moment
    Setting timeout to 35 seconds
    Downloading element to address = 0x08000000, size = 4980
    Erase           [=========================] 100%         4980 bytes
    Erase    done.
    Download        [=========================] 100%         4980 bytes
    Download done.
    File downloaded successfully
    Submitting leave request...
    Transitioning to dfuMANIFEST state
    dfu-util: can't detach
    Resetting USB to switch back to Run-Time mode
    ```

## Flashing Klipper on the Qidi Box

1. Build klipper

    ```
    cd ~/klipper
    make menuconfig
    ```
    Make sure your menuconfig matches this:

    <!-- ![image](doc/images/mmu-mcu-klipper-menuconfig.png) -->

    ```
    make clean
    make -j4
    ```

2. Make sure the klipper service stopped

    ```
    sudo service klipper stop
    ```

3. Get device name:

    ```
    ls -all /dev/serial/by-id/
    lrwxrwxrwx 1 root root 13 Feb  8 10:49 usb-katapult_stm32f401xc_56003A001051353033353536-if00 -> ../../ttyACM1

4. Flash klipper:

    ```
    cd ~/katapult/scripts
    python3 flashtool.py -b 500000 -d /dev/ttyACM1 -f ~/klipper/out/klipper.bin
    ```
    You should see a successful flash like this:

    <!-- ![image](doc/images/mmu-mcu-klipper-flash-success.png) --> 

    ```
    Connecting to Serial Device /dev/ttyACM1, baud 500000
    Detected USB device running Katapult
    Detected Klipper binary version v2026.02.00-0-gc70d21ab-dirty-20260207_161419-mkspi, MCU: stm32f401xc
    Attempting to connect to bootloader
    Katapult Connected
    Software Version: v0.0.1-110-gb0bf421
    Protocol Version: 1.1.0
    Block Size: 64 bytes
    Application Start: 0x8008000
    MCU type: stm32f401xc
    Flashing '/home/mks/klipper/out/klipper.bin'...

    [##################################################]

    Write complete: 3 pages
    Verifying (block count = 575)...

    [##################################################]

    Verification Complete: SHA = 676832F629B1902388F24738047FA78BE9F9F047
    Programming Complete
    ```

5. Get device name:

    ```
    ls -all /dev/serial/by-id/
    usb-Klipper_stm32f401xc_56003A001051353033353536-if00 -> ../../ttyACM1

# Configuring the newly flashed printer

# Plugins

## KAMP

[Klipper Adaptive Meshing & Purging](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging) 

```
cd ~
git clone https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging.git
ln -s ~/Klipper-Adaptive-Meshing-Purging/Configuration printer_data/config/KAMP
cp ~/Klipper-Adaptive-Meshing-Purging/Configuration/KAMP_Settings.cfg ~/printer_data/config/KAMP_Settings.cfg
```

## Klipper Backup

[Klipper-Backup](https://github.com/Staubgeborener/Klipper-Backup.git) 

[Klipper Backup - Save Your Klipper Config - Before You Lose It!](https://youtu.be/RCWWtzrI-e8) 

```
cd ~
git clone https://https://github.com/Staubgeborener/Klipper-Backup.git
```

```
Section 'gcode_shell_command update_git_script' is not a valid config section
```

### Moonraker Integration
```
#[update_manager klipper-backup]
#type: git_repo
#path: ~/klipper-backup
#origin: https://github.com/Staubgeborener/klipper-backup.git
#managed_services: moonraker
#primary_branch: main
```

## Beacon Klipper

[Beacon Klipper](https://github.com/beacon3d/beacon_klipper.git) 

### Install Beacon Module

Beacon Klipper require additional software dependencies not installed by default. First, run on your host the following commands:

```
sudo apt update
sudo apt install python3-numpy python3-matplotlib libopenblas-dev
```

Install script, clone `beacon_klipper` from git and run the install script:
```
cd ~
git clone https://github.com/beacon3d/beacon_klipper.git
./beacon_klipper/install.sh
```

```
beacon: installing python requirements to env, this may take 10+ minutes.
beacon: linking klippy to beacon.py.
beacon: installation successful.
Updating firmware.
Beacon '4E7A04345157383837202020FF02091C' is already flashed with the current firmware version '2.1.0'. Skipping.
To force update, re-run `update_firmware.py` with the `--force` flag set.
```

#### printer.cfg changes

First, on an ssh command shell to the printer, run ls /dev/serial/by-id/usb-Beacon* to find your Beacon serial number

```
mks@mkspi:~$ ls /dev/serial/by-id/usb-Beacon*
/dev/serial/by-id/usb-Beacon_Beacon_RevH_4E7A04345157383837202020FF02091C-if00
```

[Beacon3D RevH Normal Installation and Configuration Guide](https://github.com/qidi-community/Plus4-Wiki/blob/main/content/bed-scanning-probes/Beacon3D/RevH-Normal/README.md) 

[Beacon Probe USB Cable Mount for Chain Cable Qidi Plus 4](https://cults3d.com/en/3d-model/tool/beacon-probe-usb-cable-mount-for-chain-cable-qidi-plus-4?utm_source=chatgpt.com) 

[Beacon3D mount for Qidi Plus4](https://www.printables.com/model/1170120-beacon3d-mount-for-qidi-plus4/comments) 

### Moonraker Integration

```
[update_manager beacon]
type: git_repo
channel: dev
path: ~/beacon_klipper
origin: https://github.com/beacon3d/beacon_klipper.git
env: ~/klippy-env/bin/python
requirements: requirements.txt
install_script: install.sh
is_system_service: False
managed_services: klipper
info_tags:
    desc=Beacon Surface Scanner
```

## Klippain-ShakeTune

[Klipper Shake&Tune plugin](https://github.com/Frix-x/klippain-shaketune.git) 

Install script, execute the following command over SSH:
```
wget -O - https://raw.githubusercontent.com/Frix-x/klippain/main/install.sh | bash
```

Uninstall script, execute the following command over SSH:
```
cd ~
wget -O - https://raw.githubusercontent.com/Frix-x/klippain/main/uninstall.sh | bash
```


## KlipperFleet

[KlipperFleet](https://github.com/JohnBaumb/KlipperFleet) is a "one-stop-shop" for managing Klipper (and Kalico) firmware across your entire fleet of MCUs on a single printer. It provides a modern web interface (integrated into Mainsail) to configure, build, and flash firmware without ever touching the command line.

### Prerequisites

The service needs passwordless sudo for systemctl

1. Edit the sudoers file using the visudo command. This ensures that the file is locked and prevents simultaneous edits:
```
sudo visudo
```
2. Add a line to grant passwordless sudo access.
For a specific user:
```
# User privilege specification
root    ALL=(ALL:ALL) ALL
mks     ALL=(ALL) NOPASSWD: ALL
```
3. Verify
You can test it by running a sudo command:
```
sudo ls /root
```

### Installation

```
cd ~
git clone https://github.com/JohnBaumb/KlipperFleet.git
cd KlipperFleet
sudo chmod +x install.sh
sudo ./install.sh
```

### Moonraker Integration

To enable one-click updates and integrate KlipperFleet into your Mainsail sidebar, add the following to your `moonraker.conf`:

```
[update_manager klipperfleet]
type: git_repo
path: /home/pi/KlipperFleet
origin: https://github.com/JohnBaumb/KlipperFleet.git
primary_branch: main
managed_services: klipperfleet
install_script: install.sh
is_system_service: False
```

## Klipper TMC Autotune

[Klipper TMC Autotune](https://github.com/andrewmcgr/klipper_tmc_autotune.git) is a Klipper extension for automatic configuration and tuning of TMC drivers.

### Installation 

```
cd ~
wget -O - https://raw.githubusercontent.com/andrewmcgr/klipper_tmc_autotune/main/install.sh | bash
```

### Configuration 

Motor data in printer.cfg

```
[motor_constants qidi_xy_motors]
resistance: 1.4
inductance: 0.0026
holding_torque: 0.41
max_current: 1.5
steps_per_revolution: 200

[motor_constants qidi_z_motors]
resistance: 2.0
inductance: 0.0034
holding_torque: 0.28
max_current: 1.5
steps_per_revolution: 200

[motor_constants qidi_extruder_motors]
resistance: 2.0
inductance: 0.0013
holding_torque: 0.1
max_current: 1.0
steps_per_revolution: 200
```

Tuning goal in printer.cfg

```
[autotune_tmc extruder]
motor: qidi_extruder_motors
tuning_goal: performance
```
```
[autotune_tmc stepper_x]
motor: qidi_xy_motors
tuning_goal: performance
```
```
[autotune_tmc stepper_y]
motor: qidi_xy_motors
tuning_goal: performance
```
```
[autotune_tmc stepper_z]
motor: qidi_z_motors
tuning_goal: silent
```
```
[autotune_tmc stepper_z1]
motor: qidi_z_motors
tuning_goal: silent
```

### Moonraker Integration
```
[update_manager klipper_tmc_autotune]
type: git_repo
channel: dev
path: ~/klipper_tmc_autotune
origin: https://github.com/andrewmcgr/klipper_tmc_autotune.git
managed_services: klipper
primary_branch: main
install_script: install.sh
```




## KlipperMaintenance

[KlipperMaintenance](https://3dcoded.xyz/KlipperMaintenance/) supports the following features:

* Maintenance reminders in the terminal
* Maintenance reminders on the printer display
* Print time thresholds
* Filament thresholds
* Time thresholds


---

# Credits

- [redrathnure](https://github.com/redrathnure) for MKS-PI Armbian image 
- [phrac](https://github.com/phrac) for Qidi Plus 4 Mainline flashing
- [DrFate09](https://github.com/DrFate09) for Qidi Plus 4 Mainline configuration
- [Wazzup77](https://github.com/Wazzup77) for Qidi Plus 4 Happy-Hare
- [frap129](https://github.com/frap129) for [Klip]per for H[MI] displays like TJC and Nextion
