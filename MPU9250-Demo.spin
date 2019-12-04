{
    --------------------------------------------
    Filename: MPU9250-Demo.spin
    Author: Jesse Burt
    Description: Demo app for the MPU9250 driver
    Copyright (c) 2019
    Started Dec 2, 2019
    Updated Dec 4, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

    LED         = cfg#LED1
    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_HZ      = 400_000

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal"
    time    : "time"
    io      : "io"
    int     : "string.integer"
    mpu9250 : "sensor.imu.9dof.mpu9250.i2c"

VAR

    long _xl_overruns, _g_overruns, _mag_overruns
    long _xl_overflows, _g_overflows, _mag_overflows
    byte _ser_cog

PUB Main | ax, ay, az

    Setup
    mpu9250.MagADCRes (16)
    mpu9250.OpModeMag (mpu9250#CONT2)

    repeat
'        AccelRaw
'        GyroRaw
        MagRaw
    FlashLED (LED, 100)

PUB AccelRaw | x, y, z

    repeat until mpu9250.DataReadyXLG
    mpu9250.AccelData (@x, @y, @z)
    ser.Position (0, 5)                             ' and display
    ser.Str (string("X: "))
    ser.Str (int.DecPadded (x, 6))
    ser.NewLine
    
    ser.Str (string("Y: "))
    ser.Str (int.DecPadded (y, 6))
    ser.NewLine

    ser.Str (string("Z: "))
    ser.Str (int.DecPadded (z, 6))
    ser.NewLine

PUB GyroRaw | x, y, z

    repeat until mpu9250.DataReadyXLG
    mpu9250.GyroData (@x, @y, @z)
    ser.Position (0, 5)                             ' and display
    ser.Str (string("X: "))
    ser.Str (int.DecPadded (x, 6))
    ser.NewLine
    
    ser.Str (string("Y: "))
    ser.Str (int.DecPadded (y, 6))
    ser.NewLine

    ser.Str (string("Z: "))
    ser.Str (int.DecPadded (z, 6))
    ser.NewLine

PUB MagRaw | x, y, z

    repeat until mpu9250.DataReadyMag
    mpu9250.MagData (@x, @y, @z)
    ser.Position (0, 5)                             ' and display
    ser.Str (string("X: "))
    ser.Str (int.DecPadded (x, 6))
    ser.NewLine
    
    ser.Str (string("Y: "))
    ser.Str (int.DecPadded (y, 6))
    ser.NewLine

    ser.Str (string("Z: "))
    ser.Str (int.DecPadded (z, 6))
    ser.NewLine

    ser.Str (string("Overruns: "))
    ser.Dec (_mag_overruns)
    if mpu9250.MagDataOverrun
        _mag_overruns++
    ser.NewLine

    ser.Str (string("Overflows: "))
    ser.Dec (_mag_overflows)
    if mpu9250.MagOverflow
        _mag_overflows++

PUB Setup

    repeat until _ser_cog := ser.Start (115_200)
    ser.Clear
    ser.Str(string("Serial terminal started", ser#NL))
    if mpu9250.Startx (SCL_PIN, SDA_PIN, I2C_HZ)
        ser.Str (string("MPU9250 driver started", ser#NL))
    else
        ser.Str (string("MPU9250 driver failed to start - halting", ser#NL))
        mpu9250.Stop
        time.MSleep (500)
        ser.Stop
        FlashLED (LED, 500)

PUB FlashLED(led_pin, delay_ms)

    io.Output (led_pin)
    repeat
        io.Toggle (led_pin)
        time.MSleep (delay_ms)

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
