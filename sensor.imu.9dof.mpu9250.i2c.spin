{
    --------------------------------------------
    Filename: sensor.imu.9dof.mpu9250.i2c.spin
    Author: Jesse Burt
    Description: Driver for the InvenSense MPU9250
    Copyright (c) 2019
    Started Sep 2, 2019
    Updated Dec 4, 2019
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

    X_AXIS              = 0
    Y_AXIS              = 1
    Z_AXIS              = 2

' Magnetometer operating modes
    POWERDOWN           = %0000
    SINGLE              = %0001
    CONT1               = %0010
    CONT2               = %0110
    EXT_TRIG            = %0100
    SELFTEST            = %1000
    FUSEACCESS          = %1111

' Interrupt active level
    HIGH                = 0
    LOW                 = 1

' Interrupt output type
    INT_PP              = 0
    INT_OD              = 1

' Clear interrupt status options
    READ_INT_FLAG       = 0
    ANY                 = 1

VAR

    byte _mag_sens_adj[3]

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
                if i2c.present (SLAVE_XLG)                      'Response from device?
                    if DeviceID(SLAVE_XLG) == core#WHO_AM_I_RESP'Is it really an MPU9250?
                        disableI2CMaster                        ' Bypass the internal I2C master so we can read the Mag from the same bus
                        ReadMagAdj
                        return okay

    return FALSE                                                'If we got here, something went wrong

PUB Stop
' Put any other housekeeping code here required/recommended by your device before shutting down
    i2c.terminate

PUB AccelData(ptr_x, ptr_y, ptr_z) | tmp[2], tmpx, tmpy, tmpz
' Read accelerometer data
    tmp := $00
    readReg(SLAVE_XLG, core#ACCEL_XOUT_H, 6, @tmp)

    tmpx := (tmp.byte[0] << 8) | (tmp.byte[1])
    tmpy := (tmp.byte[2] << 8) | (tmp.byte[3])
    tmpz := (tmp.byte[4] << 8) | (tmp.byte[5])

    long[ptr_x] := ~~tmpx
    long[ptr_y] := ~~tmpy
    long[ptr_z] := ~~tmpz

PUB AccelScale(g) | tmp
' Set accelerometer full-scale range, in g's
'   Valid values: *2, 4, 8, 16
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_XLG, core#ACCEL_CFG, 1, @tmp)
    case g
        2, 4, 8, 16:
            g := lookdownz(g: 2, 4, 8, 16) << core#FLD_ACCEL_FS_SEL
        OTHER:
            tmp := (tmp >> core#FLD_ACCEL_FS_SEL) & core#BITS_ACCEL_FS_SEL
            result := lookupz(tmp: 2, 4, 8, 16)
            return

    tmp &= core#MASK_ACCEL_FS_SEL
    tmp := (tmp | g) & core#ACCEL_CFG_MASK
    writeReg(SLAVE_XLG, core#ACCEL_CFG, 1, @tmp)

PUB DataReadyMag
' Indicates new magnetometer data is ready to be read
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    readReg(SLAVE_MAG, core#ST1, 1, @result)
    result := (result & %1) * TRUE

PUB DataReadyXLG
' Indicates new gyroscope/accelerometer data is ready to be read
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    readReg(SLAVE_XLG, core#INT_STATUS, 1, @result)
    result := (result & %1) * TRUE

PUB DeviceID(sub_device)
' Read device ID from sub_device
'   Valid values:
'       SLAVE_XLG($68): Return device ID from accelerometer/gyro
'       SLAVE_MAG($0C): Return device ID from magnetometer
'   Any other value is ignored
    case sub_device
        SLAVE_MAG:
            readReg (SLAVE_MAG, core#WIA, 1, @result)
        SLAVE_XLG:
            readReg (SLAVE_XLG, core#WHO_AM_I, 1, @result)
        OTHER:
            return FALSE

PUB FSYNCActiveState(state) | tmp
' Set FSYNC pin active state/logic level
'   Valid values: LOW (1), *HIGH (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)
    case state
        LOW, HIGH:
            state := state << core#FLD_ACTL_FSYNC
        OTHER:
            result := (tmp >> core#FLD_ACTL_FSYNC) & %1
            return

    tmp &= core#MASK_ACTL_FSYNC
    tmp := (tmp | state) & core#INT_BYPASS_CFG_MASK
    writeReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)

PUB GyroData(ptr_x, ptr_y, ptr_z) | tmp[2], tmpx, tmpy, tmpz
' Read gyro data
    tmp := $00
    readReg(SLAVE_XLG, core#GYRO_XOUT_H, 6, @tmp)

    tmpx := (tmp.byte[0] << 8) | (tmp.byte[1])
    tmpy := (tmp.byte[2] << 8) | (tmp.byte[3])
    tmpz := (tmp.byte[4] << 8) | (tmp.byte[5])

    long[ptr_x] := ~~tmpx
    long[ptr_y] := ~~tmpy
    long[ptr_z] := ~~tmpz

PUB GyroScale(dps) | tmp
' Set gyroscope full-scale range, in degrees per second
'   Valid values: *250, 500, 1000, 2000
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_XLG, core#GYRO_CFG, 1, @tmp)
    case dps
        250, 500, 1000, 2000:
            dps := lookdownz(dps: 250, 500, 1000, 2000) << core#FLD_GYRO_FS_SEL
        OTHER:
            tmp := (tmp >> core#FLD_GYRO_FS_SEL) & core#BITS_GYRO_FS_SEL
            result := lookupz(tmp: 250, 500, 1000, 2000)
            return

    tmp &= core#MASK_GYRO_FS_SEL
    tmp := (tmp | dps) & core#GYRO_CFG_MASK
    writeReg(SLAVE_XLG, core#GYRO_CFG, 1, @tmp)

PUB IntActiveState(state) | tmp
' Set interrupt pin active state/logic level
'   Valid values: LOW (1), *HIGH (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)
    case state
        LOW, HIGH:
            state := state << core#FLD_ACTL
        OTHER:
            result := (tmp >> core#FLD_ACTL) & %1
            return

    tmp &= core#MASK_ACTL
    tmp := (tmp | state) & core#INT_BYPASS_CFG_MASK
    writeReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)

PUB IntClearedBy(method) | tmp
' Select method by which interrupt status may be cleared
'   Valid values:
'      *READ_INT_FLAG (0): Only by reading interrupt flags
'       ANY (1): By any read operation
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)
    case method
        ANY, READ_INT_FLAG:
            method := method << core#FLD_INT_ANYRD_2CLEAR
        OTHER:
            result := (tmp >> core#FLD_INT_ANYRD_2CLEAR) & %1
            return

    tmp &= core#MASK_INT_ANYRD_2CLEAR
    tmp := (tmp | method) & core#INT_BYPASS_CFG_MASK
    writeReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)

PUB IntLatchEnabled(enable) | tmp
' Latch interrupt pin when interrupt asserted
'   Valid values:
'      *FALSE (0): Interrupt pin is pulsed (width = 50uS)
'       TRUE (-1): Interrupt pin is latched, and must be cleared explicitly
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)
    case ||enable
        0, 1:
            enable := (||enable << core#FLD_LATCH_INT_EN)
        OTHER:
            result := ((tmp >> core#FLD_LATCH_INT_EN) & %1) * TRUE
            return

    tmp &= core#MASK_LATCH_INT_EN
    tmp := (tmp | enable) & core#INT_BYPASS_CFG_MASK
    writeReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)

PUB IntMask(mask) | tmp
' Allow interrupts to assert INT pin, set by mask, or by ORing together symbols shown below
'   Valid values:
'       Bits: %x6x43xx0 (bit positions marked 'x' aren't supported by the device; setting any of them to '1' will be considered invalid and will query the current setting, instead)
'               Function                                Symbol              Value
'           6: Enable interrupt for wake on motion      INT_WAKE_ON_MOTION (64)
'           4: Enable interrupt for FIFO overflow       INT_FIFO_OVERFLOW) (16)
'           3: Enable FSYNC interrupt                   INT_FSYNC           (8)
'           0: Enable raw Sensor Data Ready interrupt   INT_SENSOR_READY    (1)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_XLG, core#INT_ENABLE, 1, @tmp)
    case mask & (core#INT_ENABLE_MASK ^ $FF)                                    ' Check the mask param passed to us against the inverse (xor $FF) of the
        0:                                                                      ' allowed bits(INT_ENABLE_MASK). If only allowed bits are set, the result should be 0
        OTHER:                                                                  ' and it will be considered valid.
            result := tmp & core#INT_ENABLE_MASK
            return

    tmp := mask & core#INT_ENABLE_MASK
    writeReg(SLAVE_XLG, core#INT_ENABLE, 1, @tmp)

PUB IntOutputType(pp_od) | tmp
' Set interrupt pin output type
'   Valid values:
'      *INT_PP (0): Push-pull
'       INT_OD (1): Open-drain
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)
    case pp_od
        INT_PP, INT_OD:
            pp_od := pp_od << core#FLD_OPEN
        OTHER:
            result := (tmp >> core#FLD_OPEN) & %1
            return

    tmp &= core#MASK_OPEN
    tmp := (tmp | pp_od) & core#INT_BYPASS_CFG_MASK
    writeReg(SLAVE_XLG, core#INT_BYPASS_CFG, 1, @tmp)

PUB MagADCRes(bits) | tmp
' Set magnetometer ADC resolution, in bits
'   Valid values: *14, 16
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_MAG, core#CNTL1, 1, @tmp)
    case bits
        14, 16:
            bits := lookdownz(bits: 14, 16) << core#FLD_BIT
        OTHER:
            tmp := (tmp >> core#FLD_BIT) & %1
            result := lookupz(tmp: 14, 16)
            return

    tmp &= core#MASK_BIT
    tmp := (tmp | bits) & core#CNTL1_MASK
    writeReg(SLAVE_MAG, core#CNTL1, 1, @tmp)

PUB MagData(ptr_x, ptr_y, ptr_z) | tmp[2], tmpx, tmpy, tmpz
' Read Magnetometer data
    tmp := $00
    readReg(SLAVE_MAG, core#HXL, 7, @tmp)

    tmpx := (tmp.byte[0] << 8) | (tmp.byte[1])
    tmpy := (tmp.byte[2] << 8) | (tmp.byte[3])
    tmpz := (tmp.byte[4] << 8) | (tmp.byte[5])
'    tmpx := tmpx * (( ((_mag_sens_adj[X_AXIS]-128)*1000) / 2) / 128) + 1
'    tmpy := tmpy * (( ((_mag_sens_adj[Y_AXIS]-128)*1000) / 2) / 128) + 1
'    tmpz := tmpz * (( ((_mag_sens_adj[Z_AXIS]-128)*1000) / 2) / 128) + 1
    long[ptr_x] := ~~tmpx
    long[ptr_y] := ~~tmpy
    long[ptr_z] := ~~tmpz

PUB MagDataOverrun
' Indicates magnetometer data has overrun (i.e., new data arrived before previous measurement was read)
'   Returns: TRUE (-1) if overrun occurred, FALSE (0) otherwise
    result := $00
    readReg(SLAVE_MAG, core#ST1, 1, @result)
    result := ((result >> core#FLD_DOR) & %1) * TRUE

PUB MagOverflow
' Indicates magnetometer measurement has overflowed
'   Returns: TRUE (-1) if overrun occurred, FALSE (0) otherwise
'   NOTE: If this flag is TRUE, measurement data should not be trusted
'   NOTE: This bit self-clears when the next measurement starts
    result := $00
    readReg(SLAVE_MAG, core#ST2, 1, @result)
    result := ((result >> core#FLD_HOFL) & %1) * TRUE

PUB MagSelfTestEnabled(enable) | tmp
' Enable magnetometer self-test mode (generates magnetic field)
'   Valid values: TRUE (-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_MAG, core#ASTC, 1, @tmp)
    case ||enable
        0, 1:
            enable := (||enable << core#FLD_SELF) & core#ASTC_MASK
        OTHER:
            tmp := (tmp >> core#FLD_SELF) & %1
            result := tmp * TRUE
            return

    tmp &= core#MASK_SELF
    tmp := (tmp | enable)
    writeReg(SLAVE_MAG, core#ASTC, 1, @tmp)

PUB MagSoftReset | tmp
' Perform soft-reset of magnetometer: initialize all registers
    tmp := %1 & core#CNTL2_MASK
    writeReg(SLAVE_MAG, core#CNTL2, 1, @tmp)

PUB MeasureMag
' Perform magnetometer measurement
    OpModeMag(SINGLE)

PUB OpModeMag(mode) | tmp
' Set magnetometer operating mode
'   Valid values:
'      *POWERDOWN (0): Power down
'       SINGLE (1): Single measurement mode
'       CONT1 (2): Continuous measurement mode 1
'       CONT2 (6): Continuous measurement mode 2
'       EXT_TRIG (4): External trigger measurement mode
'       SELFTEST (8): Self-test mode
'       FUSEACCESS (15): Fuse ROM access mode
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readReg(SLAVE_MAG, core#CNTL1, 1, @tmp)
    case mode
        POWERDOWN, SINGLE, CONT1, CONT2, EXT_TRIG, SELFTEST, FUSEACCESS:
        OTHER:
            result := tmp & core#BITS_MODE
            return

    tmp &= core#MASK_MODE
    tmp := (tmp | mode) & core#CNTL1_MASK
    writeReg(SLAVE_MAG, core#CNTL1, 1, @tmp)

PUB ReadMagAdj
' Read magnetometer factory sensitivity adjustment values
    readReg(SLAVE_MAG, core#ASAX, 3, @_mag_sens_adj)

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
