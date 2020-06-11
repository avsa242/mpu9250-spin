# mpu9250-spin 
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the InvenSense MPU9250.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Read accelerometer (raw, micro-g's), gyroscope (raw, micro-dps), magnetometer data (raw, nano-T)
* Set accel, gyro full-scale, mag ADC res
* Data-ready flags
* Set interrupt pin active state, output type, latching
* Set magnetometer ADC resolution

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C driver

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* P2/SPIN2: FastSpin (tested with 4.1.10-beta)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build
* I2C sensor slaves not supported (not currently planned)

## TODO

- [x] Confirm basic communication
- [x] Implement methods to retrieve sensor registers
- [x] Port to P2/SPIN2
- [ ] Add support for sensor calibration offsets - WIP
- [ ] Implement scaled sensor data methods
- [ ] SPI driver variant
