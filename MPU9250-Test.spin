{
    --------------------------------------------
    Filename: MPU9250-Test.spin
    Author: Jesse Burt
    Description: Test of the MPU9250 driver
    Copyright (c) 2019
    Started Sep 2, 2019
    Updated Dec 4, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

    COL_REG     = 0
    COL_SET     = COL_REG+14
    COL_READ    = COL_SET+12
    COL_PF      = COL_READ+12

    LED         = cfg#LED1
    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_HZ      = 400_000

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal"
    time    : "time"
    io      : "io"
    mpu9250 : "sensor.imu.9dof.mpu9250.i2c"

VAR

    long _fails, _expanded
    byte _ser_cog, _row

PUB Main | ax, ay, az

    Setup
    _row := 3
    ser.Position (0, _row)
    _expanded := TRUE

    LATCH_INT_EN (1)
    OPEN (1)
    ACTL (1)
    ACCEL_FS_SEL (1)
    GYRO_FS_SEL (1)
    MAGASTC(1)
    MAGMODE(1)
    MAGBIT(1)
    mpu9250.MagSoftReset
    FlashLED (LED, 100)

PUB LATCH_INT_EN(reps) | tmp, read

    _row++
    repeat reps
        repeat tmp from -1 to 0
            mpu9250.IntLatchEnabled (tmp)
            read := mpu9250.IntLatchEnabled (-2)
            Message (string("LATCH_INT_EN"), tmp, read)

PUB OPEN(reps) | tmp, read

    _row++
    repeat reps
        repeat tmp from 0 to 1
            mpu9250.IntOutputType (tmp)
            read := mpu9250.IntOutputType (-2)
            Message (string("OPEN"), tmp, read)

PUB ACTL(reps) | tmp, read

    _row++
    repeat reps
        repeat tmp from 0 to 1
            mpu9250.IntActiveState (tmp)
            read := mpu9250.IntActiveState (-2)
            Message (string("ACTL"), tmp, read)

PUB ACCEL_FS_SEL(reps) | tmp, read

    _row++
    repeat reps
        repeat tmp from 1 to 4
            mpu9250.AccelScale (lookup(tmp: 2, 4, 8, 16))
            read := mpu9250.AccelScale (-2)
            Message (string("ACCEL_FS_SEL"), lookup(tmp: 2, 4, 8, 16), read)

PUB GYRO_FS_SEL(reps) | tmp, read

    _row++
    repeat reps
        repeat tmp from 1 to 4
            mpu9250.GyroScale (lookup(tmp: 250, 500, 1000, 2000))
            read := mpu9250.GyroScale (-2)
            Message (string("GYRO_FS_SEL"), lookup(tmp: 250, 500, 1000, 2000), read)

PUB MAGASTC(reps) | tmp, read

    _row++
    repeat reps
        repeat tmp from -1 to 0
            mpu9250.MagSelfTestEnabled (tmp)
            read := mpu9250.MagSelfTestEnabled (-2)
            Message (string("ASTC"), tmp, read)

PUB MAGBIT(reps) | tmp, read

    _row++
    repeat reps
        repeat tmp from 1 to 2
            mpu9250.MagADCRes (lookup(tmp: 14, 16))
            read := mpu9250.MagADCRes (-2)
            Message (string("MAGBIT"), lookup(tmp: 14, 16), read)

PUB MAGMODE(reps) | tmp, read

    _row++
    repeat reps
        repeat tmp from 1 to 7
            mpu9250.OpModeMag (lookup(tmp: mpu9250#POWERDOWN, mpu9250#SINGLE, mpu9250#CONT1, mpu9250#CONT2, mpu9250#EXT_TRIG, mpu9250#SELFTEST, mpu9250#FUSEACCESS))
            read := mpu9250.OpModeMag (-2)
            Message (string("MAGMODE"), lookup(tmp: mpu9250#POWERDOWN, mpu9250#SINGLE, mpu9250#CONT1, mpu9250#CONT2, mpu9250#EXT_TRIG, mpu9250#SELFTEST, mpu9250#FUSEACCESS), read)

    mpu9250.OpModeMag (mpu9250#SINGLE)

PUB TrueFalse(num)

    case num
        0: ser.Str (string("FALSE"))
        -1: ser.Str (string("TRUE"))
        OTHER: ser.Str (string("???"))

PUB Message(field, arg1, arg2)

   case _expanded
        TRUE:
            ser.PositionX (COL_REG)
            ser.Str (field)

            ser.PositionX (COL_SET)
            ser.Str (string("SET: "))
            ser.Dec (arg1)

            ser.PositionX (COL_READ)
            ser.Str (string("READ: "))
            ser.Dec (arg2)
            ser.Chars (32, 3)
            ser.PositionX (COL_PF)
            PassFail (arg1 == arg2)
            ser.NewLine

        FALSE:
            ser.Position (COL_REG, _row)
            ser.Str (field)

            ser.Position (COL_SET, _row)
            ser.Str (string("SET: "))
            ser.Dec (arg1)

            ser.Position (COL_READ, _row)
            ser.Str (string("READ: "))
            ser.Dec (arg2)

            ser.Position (COL_PF, _row)
            PassFail (arg1 == arg2)
            ser.NewLine
        OTHER:
            ser.Str (string("DEADBEEF"))

PUB PassFail(num)

    case num
        0: ser.Str (string("FAIL"))
        -1: ser.Str (string("PASS"))
        OTHER: ser.Str (string("???"))

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
