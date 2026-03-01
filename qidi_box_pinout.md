# Qidi Box Pinout (Reverse Engineered from v1)

The Qidi Box uses the [STM32F402RCT6](https://www.st.com/resource/en/datasheet/stm32f401cc.pdf) microcontroller.

**Note:** The stepper motor drivers (TMC2009) are not connected by UART, the configuration is done via resistors. UART connection requires reworking the board (soldering of 0402 resistors, tightly packed) and is thus not recommended.

| No | Pin \ Slot | Function | Comment |
| :--- | :--- | :--- | :--- |
| 1 | VBAT | VBAT | |
| 2 | PC13 | STEP | |
| 3 | PC14 | DIR | |
| 4 | PC15 | nEN | |
| 5 | OSC_IN | osc_in | 8 MHz quartz |
| 6 | OSC_OUT | osc_out | 8 MHz quartz |
| 7 | NRST | nRST | |
| 8 | PC0 | nEN | |
| 9 | PC1 | Temp1_Ain | NTC 100K MGB18-104F39050L32 |
| 10 | PC2 | Temp2_Ain | NTC 100K MGB18-104F39050L32 |
| 11 | PC3 | | |
| 12 | VSSA | VSS | |
| 13 | VDDA | VDD | |
| 14 | PA0 | RUNOUT | |
| 15 | PA1 | WHITE | |
| 16 | PA2 | RED | |
| 17 | PA3 | Heater | Sensor AHT20_F over i2c |
| 18 | VSS | VSS | |
| 19 | VDD | VDD | |
| 20 | PA4 | HeaterFanA | |
| 21 | PA5 | HeaterFanB | |
| 22 | PA6 | Board fan | |
| 23 | PA7 | RUNOUT | |
| 24 | PC4 | WHITE | |
| 25 | PC5 | RED | |
| 26 | PB0 | Motion sensor | |
| 27 | PB1 | B button | ? IDK what this is - might be for daisy chaining boxes (to share hub endstop) |
| 28 | PB2 | DIR | |
| 29 | PB10 | | |
| 30 | VCAP_1 | VCAP | |
| 31 | VSS | VSS | |
| 32 | VDD | VDD | |
| 33 | PB12 | | |
| 34 | PB13 | SPI2_SCK | Used for RFID |
| 35 | PB14 | SPI2_MISO | Used for RFID |
| 36 | PB15 | SPI2_MOSI | Used for RFID |
| 37 | PC6 | RFID1_CS | |
| 38 | PC7 | RFID2_CS | |
| 39 | PC8 | STEP | |
| 40 | PC9 | I2C3_SDA | |
| 41 | PA8 | I2C3_SCL | |
| 42 | PA9 | B endstop | Connected to PA10 with 1k. Stepper driver UART TX (unconnected, requires board rework) |
| 43 | PA10 | E endstop | Connected to PA9 with 1k. Stepper driver UART TX (unconnected, requires board rework) |
| 44 | PA11 | USB | |
| 45 | PA12 | USB | |
| 46 | PA13 | RUNOUT | |
| 47 | VSS | VSS | |
| 48 | VDD | VDD | |
| 49 | PA14 | WHITE | |
| 50 | PA15 | RED | |
| 51 | PC10 | nEN | |
| 52 | PC11 | DIR | |
| 53 | PC12 | STEP | |
| 54 | PD2 | EN | |
| 55 | PB3 | RUNOUT | |
| 56 | PB4 | WHITE | |
| 57 | PB5 | RED | |
| 58 | PB6 | | |
| 59 | PB7 | | |
| 60 | BOOT0 | BOOT0 | |
| 61 | PB8 | DIR | |
| 62 | PB9 | STEP | |
| 63 | VSS | VSS | |
| 64 | VDD | VDD | |
