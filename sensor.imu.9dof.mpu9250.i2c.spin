{
    --------------------------------------------
    Filename: sensor.imu.9dof.mpu9250.i2c.spin
    Author: Jesse Burt
    Description: Driver for the InvenSense MPU9250
    Copyright (c) 2019
    Started Sep 02, 2019
    Updated Sep 02, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_XLG           = core#SLAVE_ADDR
    SLAVE_XLG_WR        = core#SLAVE_ADDR
    SLAVE_XLG_RD        = core#SLAVE_ADDR|1

    SLAVE_MAG           = core#SLAVE_ADDR_MAG
    SLAVE_MAG_WR        = core#SLAVE_ADDR_MAG
    SLAVE_MAG_RD        = core#SLAVE_ADDR_MAG|1

    DEF_SCL             = 28
    DEF_SDA             = 29
    DEF_HZ              = 400_000
    I2C_MAX_FREQ        = core#I2C_MAX_FREQ

VAR


OBJ

    i2c : "com.i2c"                                             'PASM I2C Driver
    core: "core.con.mpu9250.spin"                           'File containing your device's register set
    time: "time"                                                'Basic timing functions

PUB Null
''This is not a top-level object

PUB Start: okay                                                 'Default to "standard" Propeller I2C pins and 400kHz

    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)    'I2C Object Started?
                time.USleep (core#TREGRW)
                if i2c.present (SLAVE_XLG)                       'Response from device?
                    if WhoAmI_XLG == core#WHO_AM_I_RESP             'Is it really an MPU9250?
                        disableI2CMaster                        ' Bypass the internal I2C master so we can read the Mag from the same bus
                        return okay

    return FALSE                                                'If we got here, something went wrong

PUB Stop
' Put any other housekeeping code here required/recommended by your device before shutting down
    i2c.terminate

PUB Mag1

    return i2c.Present (SLAVE_MAG_WR)

PUB WhoAmI_Mag

    readReg (SLAVE_MAG, core#WIA, 1, @result)

PUB WhoAmI_XLG

    readReg(SLAVE_XLG, core#WHO_AM_I, 1, @result)

PRI disableI2CMaster | tmp

    tmp := $00
    readReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)
    tmp &= core#MASK_BYPASS_EN
    tmp := (tmp | 1 << core#FLD_BYPASS_EN)
    writeReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)

PRI readReg(slave_id, reg, nr_bytes, buff_addr) | cmd_packet, tmp
'' Read num_bytes from the slave device into the address stored in buff_addr
    case reg                                                    'Basic register validation
        $00..$FF:                                               ' Consult your device's datasheet!
            cmd_packet.byte[0] := slave_id
            cmd_packet.byte[1] := reg
            i2c.start
            i2c.wr_block (@cmd_packet, 2)
            i2c.start
            i2c.write (slave_id|1)
            i2c.rd_block (buff_addr, nr_bytes, TRUE)
            i2c.stop
        OTHER:
            return

PRI writeReg(slave_id, reg, nr_bytes, buff_addr) | cmd_packet, tmp
'' Write num_bytes to the slave device from the address stored in buff_addr
    case reg                                                    'Basic register validation
        $00..$FF:                                               ' Consult your device's datasheet!
            cmd_packet.byte[0] := slave_id
            cmd_packet.byte[1] := reg
            i2c.start
            i2c.wr_block (@cmd_packet, 2)
            repeat tmp from 0 to nr_bytes-1
                i2c.write (byte[buff_addr][tmp])
            i2c.stop
        OTHER:
            return


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
