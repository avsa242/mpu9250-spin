# mpu9250-spin 
--------------

This is a P8X32A/Propeller driver object for the InvenSense MPU9250.

## Salient Features

* I2C connection at up to 400kHz
* Read accelerometer, gyroscope, magnetometer data
* Set accel, gyro full-scale
* Data-ready flags
* Set interrupt pin active state, output type, latching
* Set magnetometer ADC resolution

## Requirements

* 1 extra core/cog for the PASM I2C driver

## Limitations

* Very early in development - may malfunction, or outright fail to build
* I2C sensor slaves not supported (not currently planned)

## TODO

- [x] Confirm basic communication
- [x] Implement methods to retrieve sensor registers
- [ ] Implement scaled sensor data methods
- [ ] SPI driver variant
