{
    --------------------------------------------
    Filename: MPU9250-Demo.spin
    Author: Jesse Burt
    Description: Demo of the MPU9250 driver
    Copyright (c) 2020
    Started Sep 2, 2019
    Updated Jun 7, 2020
    See end of file for terms of use.
    --------------------------------------------
}
' Uncomment one of the following to choose which interface the MPU9250 is connected to
'#define MPU9250_I2C
#define MPU9250_SPI
CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    LED         = cfg#LED1
    SER_RX      = 31
    SER_TX      = 30
    SER_BAUD    = 115_200

    SCL_PIN     = 5                                        ' SPI, I2C
    SDA_PIN     = 4                                        ' SPI, I2C
    I2C_HZ      = 400_000                                  ' I2C
' --

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    io      : "io"
    int     : "string.integer"
    imu     : "sensor.imu.9dof.mpu9250.i2c"

VAR

    long _overruns

PUB Main | dispmode

    Setup

'    imu.AccelADCRes(10)                                   ' 8, 10, 12 (low-power, normal, high-res, resp.)
    imu.AccelScale(2)                                     ' 2, 4, 8, 16 (g's)
'    imu.AccelDataRate(100)                                ' 0, 1, 10, 25, 50, 100, 200, 400, 1344, 1600
'    imu.AccelAxisEnabled(%111)                            ' 0 or 1 for each bit (%xyz)

    imu.GyroScale(250)                                      ' 250, 500, 1000, 2000

    ser.HideCursor
    dispmode := 0

    ser.position(0, 3)                                      ' Read back the settings from above
    ser.str(string("AccelScale: "))                         '
    ser.dec(imu.AccelScale(-2))                           '
    ser.newline                                             '
'    ser.str(string("AccelADCRes: "))                        '
'    ser.dec(imu.AccelADCRes(-2))                          '
'    ser.newline                                             '
'    ser.str(string("AccelDataRate: "))                      '
'    ser.dec(imu.AccelDataRate(-2))                        '
'    ser.newline                                             '
'    ser.str(string("FIFOMode: "))                           '
'    ser.dec(imu.FIFOMode(-2))                             '
'    ser.newline                                             '
'    ser.str(string("IntThresh: "))                          '
'    ser.dec(imu.IntThresh(-2))                            '
'    ser.newline                                             '
    ser.str(string("IntMask: "))                            '
    ser.bin(imu.IntMask(-2), 6)                           '
    ser.newline                                             '

    repeat
        case ser.RxCheck
            "q", "Q":                                       ' Quit the demo
                ser.Position(0, 15)
                ser.str(string("Halting"))
                imu.Stop
                time.MSleep(5)
                ser.Stop
                quit
            "c", "C":                                       ' Perform calibration
                Calibrate
            "r", "R":                                       ' Change display mode: raw/calculated
                ser.Position(0, 10)
                repeat 2
                    ser.ClearLine(ser#CLR_CUR_TO_END)
                    ser.Newline
                dispmode ^= 1

        ser.Position (0, 10)
        case dispmode
            0:
                AccelRaw
                GyroRaw
                MagRaw
            1:
                AccelCalc
                GyroCalc
                MagCalc

        ser.position (0, 15)
        ser.str(string("Interrupt: "))
        ser.str(lookupz(imu.Interrupt >> 6: string("No "), string("Yes")))

    ser.ShowCursor
    FlashLED(LED, 100)

PUB AccelCalc | ax, ay, az

    repeat until imu.AccelDataReady
    imu.AccelG (@ax, @ay, @az)
'    if imu.AccelDataOverrun
'        _overruns++
    ser.Str (string("Accel micro-g: "))
    ser.Str (int.DecPadded (ax, 10))
    ser.Str (int.DecPadded (ay, 10))
    ser.Str (int.DecPadded (az, 10))
    ser.Newline
'    ser.Str (string("Overruns: "))
'    ser.Dec (_overruns)

PUB AccelRaw | ax, ay, az

    repeat until imu.AccelDataReady
    imu.AccelData (@ax, @ay, @az)
'    if imu.AccelDataOverrun
'        _overruns++
    ser.Str (string("Raw Accel: "))
    ser.Str (int.DecPadded (ax, 7))
    ser.Str (int.DecPadded (ay, 7))
    ser.Str (int.DecPadded (az, 7))
    ser.Newline
'    ser.Str (string("Overruns: "))
'    ser.Dec (_overruns)
'    ser.newline

PUB GyroCalc | gx, gy, gz

    repeat until imu.GyroDataReady
    imu.GyroDPS (@gx, @gy, @gz)
    ser.Str (string("Gyro:  "))
    ser.Str (int.DecPadded (gx, 11))
    ser.Str (int.DecPadded (gy, 11))
    ser.Str (int.DecPadded (gz, 11))
    ser.newline

PUB GyroRaw | gx, gy, gz

    repeat until imu.GyroDataReady
    imu.GyroData (@gx, @gy, @gz)
    ser.Str (string("Gyro:  "))
    ser.Str (int.DecPadded (gx, 7))
    ser.Str (int.DecPadded (gy, 7))
    ser.Str (int.DecPadded (gz, 7))
    ser.newline

PUB MagCalc | mx, my, mz

    repeat until imu.MagDataReady
    imu.MagGauss (@mx, @my, @mz)
    ser.Str (string("Mag:   "))
    ser.Str (int.DecPadded (mx, 10))
    ser.Str (int.DecPadded (my, 10))
    ser.Str (int.DecPadded (mz, 10))
    ser.newline

PUB MagRaw | mx, my, mz

    repeat until imu.MagDataReady
    imu.MagData (@mx, @my, @mz)
    ser.Str (string("Mag:  "))
    ser.Str (int.DecPadded (mx, 7))
    ser.Str (int.DecPadded (my, 7))
    ser.Str (int.DecPadded (mz, 7))
    ser.newline

PUB Calibrate

    ser.Position (0, 12)
    ser.Str(string("Calibrating..."))
'    imu.Calibrate
    ser.Position (0, 12)
    ser.Str(string("              "))

PUB Setup

    repeat until ser.StartRXTX (SER_RX, SER_TX, 0, SER_BAUD)
    time.MSleep(30)
    ser.Clear
    ser.Str(string("Serial terminal started", ser#CR, ser#LF))
    if imu.Startx(SCL_PIN, SDA_PIN, I2C_HZ)
        imu.Defaults
        ser.str(string("MPU9250 driver started (I2C)", ser#CR, ser#LF))
    else
        ser.str(string("MPU9250 driver failed to start - halting", ser#CR, ser#LF))
        imu.Stop
        time.MSleep(5)
        ser.Stop
        FlashLED(LED, 500)

#include "lib.utility.spin"

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
