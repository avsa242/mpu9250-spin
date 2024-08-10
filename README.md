# mpu9250-spin 
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the InvenSense MPU9250.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.


## Salient Features

* I2C connection at up to 400kHz
* Read accelerometer (raw, micro-g's), gyroscope (raw, micro-dps), magnetometer data (raw, gauss (untested/unverified), nano-Teslas (untested/unverified))
* Set accel, gyro full-scale, mag ADC res
* Data-ready flags
* Interrupt support: pin active state, output type, latching, read state
* Set magnetometer ADC resolution
* Set bias offsets
* Set output data rates
* Set optional accel/gyro/temp data low-pass filter
* Magnetometer calibration
* Clock source: internal oscillator, automatic
* FIFO modes, status flags


## Requirements

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C engine
* sensor.accel.common.spinh (provided by spin-standard-library)
* sensor.gyroscope.common.spinh (provided by spin-standard-library)
* sensor.magnetometer.common.spinh (provided by spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* sensor.accel.common.spin2h (provided by p2-spin-standard-library)
* sensor.gyroscope.common.spin2h (provided by p2-spin-standard-library)
* sensor.magnetometer.common.spin2h (provided by p2-spin-standard-library)


## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.9.4)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.9.4)       | Native/PASM  | Runtime issues        |
| P2        | SPIN2    | FlexSpin (6.9.4)       | NuCode       | Runtime issues        |
| P2        | SPIN2    | FlexSpin (6.9.4)       | Native/PASM2 | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Limitations

* Very early in development - may malfunction, or outright fail to build
* I2C sensor slaves not supported (not currently planned)
* DMP not supported (not currently planned)

