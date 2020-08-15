{
    --------------------------------------------
    Filename: sensor.imu.9dof.mpu9250.i2c.spin
    Author: Jesse Burt
    Description: Driver for the InvenSense MPU9250
    Copyright (c) 2020
    Started Sep 2, 2019
    Updated Aug 15, 2020
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
    DEF_HZ              = 100_000
    I2C_MAX_FREQ        = core#I2C_MAX_FREQ

    X_AXIS              = 0
    Y_AXIS              = 1
    Z_AXIS              = 2

    R                   = 0
    W                   = 1

' Magnetometer operating modes
    POWERDOWN           = %0000
    SINGLE              = %0001
    CONT8               = %0010
    CONT100             = %0110
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

' Interrupt sources
    INT_WAKE_ON_MOTION  = 64
    INT_FIFO_OVERFLOW   = 16
    INT_FSYNC           = 8
    INT_SENSOR_READY    = 1

' Temperature scales
    C                   = 0
    F                   = 1

VAR

    long _mag_bias[3]
    word _accel_cnts_per_lsb, _gyro_cnts_per_lsb, _mag_cnts_per_lsb
    byte _mag_sens_adj[3]
    byte _temp_scale

OBJ

    i2c : "com.i2c"
    core: "core.con.mpu9250.spin"
    time: "time"

PUB Null
''This is not a top-level object

PUB Start{}: okay                                               ' Default to "standard" Propeller I2C pins and 100kHz

    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)    ' I2C Object Started?
                time.usleep (core#TREGRW)
                if i2c.present (SLAVE_XLG)                      ' Response from device?
                    disablei2cmaster{}                          ' Bypass the internal I2C master so we can read the Mag from the same bus
                    if deviceid{} == core#DEVID_RESP            ' Is it really an MPU9250?
                        readmagadj{}
                        magsoftreset{}
                        return okay

    return FALSE                                                ' If we got here, something went wrong

PUB Defaults
' Factory default settings
    accelscale(2)
    gyroscale(250)
    magopmode(CONT100)
    magscale(16)
    tempscale(C)

PUB Stop{}
' Put any other housekeeping code here required/recommended by your device before shutting down
    i2c.terminate

PUB AccelAxisEnabled(xyz_mask): curr_mask
' Enable data output for Accelerometer - per axis
'   Valid values: 0 or 1, for each axis:
'       Bits    210
'               XYZ
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#PWR_MGMT_2, 1, @curr_mask)
    case xyz_mask
        %000..%111:
            xyz_mask := ((xyz_mask ^ core#DISABLE_INVERT) & core#BITS_DISABLE_XYZA) << core#FLD_DISABLE_XYZA
        other:
            return ((curr_mask >> core#FLD_DISABLE_XYZA) & core#BITS_DISABLE_XYZA) ^ core#DISABLE_INVERT

    xyz_mask := ((curr_mask & core#MASK_DISABLE_XYZA) | xyz_mask) & core#PWR_MGMT_2_MASK
    writereg(core#PWR_MGMT_2, 1, @xyz_mask)

PUB AccelBias(ptr_x, ptr_y, ptr_z, rw) | tmp[3], tc_bit[3]
' Read or write/manually set accelerometer calibration offset values
'   Valid values:
'       When rw == W (1, write)
'           ptr_x, ptr_y, ptr_z: -16384..16383
'       When rw == R (0, read)
'           ptr_x, ptr_y, ptr_z:
'               Pointers to variables to hold current settings for respective axes
'   NOTE: The MPU9250 accelerometer is pre-programmed with offsets, which may or may not be adequate for your application
    readreg(core#XA_OFFS_H, 2, @tmp[X_AXIS])                ' Discrete reads because the three axes
    readreg(core#YA_OFFS_H, 2, @tmp[Y_AXIS])                '   aren't contiguous register pairs
    readreg(core#ZA_OFFS_H, 2, @tmp[Z_AXIS])

    case rw
        W:
            tc_bit[X_AXIS] := tmp[X_AXIS] & 1               ' LSB of each axis' data is a temperature compensation flag
            tc_bit[Y_AXIS] := tmp[Y_AXIS] & 1
            tc_bit[Z_AXIS] := tmp[Z_AXIS] & 1

            ptr_x := (ptr_x & $FFFE) | tc_bit[X_AXIS]
            ptr_y := (ptr_y & $FFFE) | tc_bit[Y_AXIS]
            ptr_z := (ptr_z & $FFFE) | tc_bit[Z_AXIS]

            writereg(core#XA_OFFS_H, 2, @ptr_x)
            writereg(core#YA_OFFS_H, 2, @ptr_y)
            writereg(core#ZA_OFFS_H, 2, @ptr_z)

        R:
            long[ptr_x] := ~~tmp[X_AXIS]
            long[ptr_y] := ~~tmp[Y_AXIS]
            long[ptr_z] := ~~tmp[Z_AXIS]
        other:
            return

PUB AccelData(ptr_x, ptr_y, ptr_z) | tmp[2]
' Read accelerometer data
    tmp := $00
    readreg(core#ACCEL_XOUT_H, 6, @tmp)

    long[ptr_x] := ~~tmp.word[2]
    long[ptr_y] := ~~tmp.word[1]
    long[ptr_z] := ~~tmp.word[0]

PUB AccelDataReady{}: flag
' Flag indicating new accelerometer data available
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    return xlgdataready{}

PUB AccelG(ptr_x, ptr_y, ptr_z) | tmpx, tmpy, tmpz
' Read accelerometer data, calculated
'   Returns: Linear acceleration in millionths of a g
    acceldata(@tmpx, @tmpy, @tmpz)
    long[ptr_x] := (tmpx * _accel_cnts_per_lsb)
    long[ptr_y] := (tmpy * _accel_cnts_per_lsb)
    long[ptr_z] := (tmpz * _accel_cnts_per_lsb)

PUB AccelScale(g): curr_scl
' Set accelerometer full-scale range, in g's
'   Valid values: *2, 4, 8, 16
'   Any other value polls the chip and returns the current setting
    curr_scl := 0
    readreg(core#ACCEL_CFG, 1, @curr_scl)
    case g
        2, 4, 8, 16:
            g := lookdownz(g: 2, 4, 8, 16) << core#FLD_ACCEL_FS_SEL
            _accel_cnts_per_lsb := lookupz(g >> core#FLD_ACCEL_FS_SEL: 61, 122, 244, 488)   ' 1/16384, 1/8192, 1/4096, 1/2048 * 1_000_000
        other:
            curr_scl := (curr_scl >> core#FLD_ACCEL_FS_SEL) & core#BITS_ACCEL_FS_SEL
            return lookupz(curr_scl: 2, 4, 8, 16)

    g := ((curr_scl & core#MASK_ACCEL_FS_SEL) | g) & core#ACCEL_CFG_MASK
    writereg(core#ACCEL_CFG, 1, @g)

PUB DeviceID{}: id
' Read device ID
    id := 0
    readreg(core#WIA, 1, @id.byte[0])
    readreg(core#WHO_AM_I, 1, @id.byte[1])

PUB FSYNCActiveState(state): curr_state
' Set FSYNC pin active state/logic level
'   Valid values: LOW (1), *HIGH (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_state)
    case state
        LOW, HIGH:
            state := state << core#FLD_ACTL_FSYNC
        other:
            return (curr_state >> core#FLD_ACTL_FSYNC) & %1

    state := ((curr_state & core#MASK_ACTL_FSYNC) | state) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @state)

PUB GyroAxisEnabled(xyz_mask): curr_mask
' Enable data output for Gyroscope - per axis
'   Valid values: 0 or 1, for each axis:
'       Bits    210
'               XYZ
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#PWR_MGMT_2, 1, @curr_mask)
    case xyz_mask
        %000..%111:
            xyz_mask := ((xyz_mask ^ core#DISABLE_INVERT) & core#BITS_DISABLE_XYZG) << core#FLD_DISABLE_XYZG
        other:
            return ((curr_mask >> core#FLD_DISABLE_XYZG) & core#BITS_DISABLE_XYZG) ^ core#DISABLE_INVERT

    xyz_mask := ((curr_mask & core#MASK_DISABLE_XYZG) | xyz_mask) & core#PWR_MGMT_2_MASK
    writereg(core#PWR_MGMT_2, 1, @xyz_mask)

PUB GyroBias(ptr_x, ptr_y, ptr_z, rw) | tmp[3]
' Read or write/manually set gyroscope calibration offset values
'   Valid values:
'       When rw == W (1, write)
'           ptr_x, ptr_y, ptr_z: -32768..32767
'       When rw == R (0, read)
'           ptr_x, ptr_y, ptr_z:
'               Pointers to variables to hold current settings for respective axes
    case rw
        W:
            writereg(core#XG_OFFS_USR, 2, @ptr_x)
            writereg(core#YG_OFFS_USR, 2, @ptr_y)
            writereg(core#ZG_OFFS_USR, 2, @ptr_z)

        R:
            readreg(core#XG_OFFS_USR, 2, @tmp[X_AXIS])
            readreg(core#YG_OFFS_USR, 2, @tmp[Y_AXIS])
            readreg(core#ZG_OFFS_USR, 2, @tmp[Z_AXIS])
            long[ptr_x] := ~~tmp[X_AXIS]
            long[ptr_y] := ~~tmp[Y_AXIS]
            long[ptr_z] := ~~tmp[Z_AXIS]
        other:
            return

PUB GyroData(ptr_x, ptr_y, ptr_z) | tmp[2]
' Read gyro data
    tmp := $00
    readreg(core#GYRO_XOUT_H, 6, @tmp)

    long[ptr_x] := ~~tmp.word[2]
    long[ptr_y] := ~~tmp.word[1]
    long[ptr_z] := ~~tmp.word[0]

PUB GyroDataReady{}: flag
' Flag indicating new gyroscope data available
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    return xlgdataready{}

PUB GyroDPS(gx, gy, gz) | tmpx, tmpy, tmpz
'Read gyroscope calibrated data (micro-degrees per second)
    gyrodata(@tmpx, @tmpy, @tmpz)
    long[gx] := (tmpx * _gyro_cnts_per_lsb)
    long[gy] := (tmpy * _gyro_cnts_per_lsb)
    long[gz] := (tmpz * _gyro_cnts_per_lsb)

PUB GyroScale(dps): curr_scl
' Set gyroscope full-scale range, in degrees per second
'   Valid values: *250, 500, 1000, 2000
'   Any other value polls the chip and returns the current setting
    curr_scl := 0
    readreg(core#GYRO_CFG, 1, @curr_scl)
    case dps
        250, 500, 1000, 2000:
            dps := lookdownz(dps: 250, 500, 1000, 2000) << core#FLD_GYRO_FS_SEL
            _gyro_cnts_per_lsb := lookupz(dps >> core#FLD_GYRO_FS_SEL: 7633, 15_267, 30_487, 60_975)    ' 1/131, 1/65.5, 1/32.8, 1/16.4 * 1_000_000
        other:
            curr_scl := (curr_scl >> core#FLD_GYRO_FS_SEL) & core#BITS_GYRO_FS_SEL
            return lookupz(curr_scl: 250, 500, 1000, 2000)

    dps := ((curr_scl & core#MASK_GYRO_FS_SEL) | dps) & core#GYRO_CFG_MASK
    writereg(core#GYRO_CFG, 1, @dps)

PUB IntActiveState(state): curr_state
' Set interrupt pin active state/logic level
'   Valid values: LOW (1), *HIGH (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_state)
    case state
        LOW, HIGH:
            state := state << core#FLD_ACTL
        other:
            return (curr_state >> core#FLD_ACTL) & %1

    state := ((curr_state & core#MASK_ACTL) | state) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @state)

PUB IntClearedBy(method): curr_setting
' Select method by which interrupt status may be cleared
'   Valid values:
'      *READ_INT_FLAG (0): Only by reading interrupt flags
'       ANY (1): By any read operation
'   Any other value polls the chip and returns the current setting
    curr_setting := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_setting)
    case method
        ANY, READ_INT_FLAG:
            method := method << core#FLD_INT_ANYRD_2CLEAR
        other:
            return (curr_setting >> core#FLD_INT_ANYRD_2CLEAR) & %1

    method := ((curr_setting & core#MASK_INT_ANYRD_2CLEAR) | method) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @method)

PUB Interrupt{}: flag
' Indicates one or more interrupts have been asserted
'   Returns: non-zero result if any interrupts have been asserted:
'       INT_WAKE_ON_MOTION (64) - Wake on motion interrupt occurred
'       INT_FIFO_OVERFLOW (16) - FIFO overflowed
'       INT_FSYNC (8) - FSYNC interrupt occurred
'       INT_SENSOR_READY (1) - Sensor raw data updated
    flag := 0
    readreg(core#INT_STATUS, 1, @flag)

PUB IntLatchEnabled(enable): curr_setting
' Latch interrupt pin when interrupt asserted
'   Valid values:
'      *FALSE (0): Interrupt pin is pulsed (width = 50uS)
'       TRUE (-1): Interrupt pin is latched, and must be cleared explicitly
'   Any other value polls the chip and returns the current setting
    curr_setting := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_setting)
    case ||(enable)
        0, 1:
            enable := (||(enable) << core#FLD_LATCH_INT_EN)
        other:
            return ((curr_setting >> core#FLD_LATCH_INT_EN) & %1) == 1

    enable := ((curr_setting & core#MASK_LATCH_INT_EN) | enable) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @enable)

PUB IntMask(mask): curr_mask
' Allow interrupts to assert INT pin, set by mask, or by ORing together symbols shown below
'   Valid values:
'       Bits: %x6x43xx0 (bit positions marked 'x' aren't supported by the device; setting any of them to '1' will be considered invalid and will query the current setting, instead)
'               Function                                Symbol              Value
'           6: Enable interrupt for wake on motion      INT_WAKE_ON_MOTION (64)
'           4: Enable interrupt for FIFO overflow       INT_FIFO_OVERFLOW) (16)
'           3: Enable FSYNC interrupt                   INT_FSYNC           (8)
'           1: Enable raw Sensor Data Ready interrupt   INT_SENSOR_READY    (1)
'   Any other value polls the chip and returns the current setting
    case mask & (core#INT_ENABLE_MASK ^ $FF)                                    ' Check the mask param passed to us against the inverse (xor $FF) of the
        0:                                                                      ' allowed bits(INT_ENABLE_MASK). If only allowed bits are set, the result should be 0
            mask &= core#INT_ENABLE_MASK
            writereg(core#INT_ENABLE, 1, @mask)
        other:                                                                  ' and it will be considered valid.
            curr_mask := 0
            readreg(core#INT_ENABLE, 1, @curr_mask)
            return curr_mask & core#INT_ENABLE_MASK

PUB IntOutputType(pp_od): curr_setting
' Set interrupt pin output type
'   Valid values:
'      *INT_PP (0): Push-pull
'       INT_OD (1): Open-drain
'   Any other value polls the chip and returns the current setting
    curr_setting := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_setting)
    case pp_od
        INT_PP, INT_OD:
            pp_od := pp_od << core#FLD_OPEN
        other:
            return (curr_setting >> core#FLD_OPEN) & %1

    pp_od := ((curr_setting & core#MASK_OPEN) | pp_od) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @pp_od)

PUB MagADCRes(bits): curr_res
' Set magnetometer ADC resolution, in bits
'   Valid values: *14, 16
'   Any other value polls the chip and returns the current setting
    curr_res := 0
    readreg(core#CNTL1, 1, @curr_res)
    case bits
        14, 16:
            bits := lookdownz(bits: 14, 16) << core#FLD_BIT
        other:
            curr_res := (curr_res >> core#FLD_BIT) & %1
            return lookupz(curr_res: 14, 16)

    bits := ((curr_res & core#MASK_BIT) | bits) & core#CNTL1_MASK
    writereg(core#CNTL1, 1, @bits)

PUB MagBias(ptr_x, ptr_y, ptr_z, rw)
' Read or write/manually set magnetometer calibration offset values
'   Valid values:
'       When rw == W (1, write)
'           ptr_x, ptr_y, ptr_z: -32760..32760
'       When rw == R (0, read)
'           ptr_x, ptr_y, ptr_z:
'               Pointers to variables to hold current settings for respective axes
    case rw
        W:
            _mag_bias[X_AXIS] := ptr_x
            _mag_bias[Y_AXIS] := ptr_y
            _mag_bias[Z_AXIS] := ptr_z
        R:
            long[ptr_x] := _mag_bias[X_AXIS]
            long[ptr_y] := _mag_bias[Y_AXIS]
            long[ptr_z] := _mag_bias[Z_AXIS]
        other:
            return

PUB MagData(ptr_x, ptr_y, ptr_z) | tmp[2]
' Read Magnetometer data
    tmp := $00
    readreg(core#HXL, 7, @tmp)                              ' Read 6 magnetometer data bytes, plus an extra (required) read of the status register

    long[ptr_x] := ~~tmp.word[X_AXIS] * ((((((_mag_sens_adj[X_AXIS] * 1000) - 128_000) / 2)) / 128) + 1_000) + _mag_bias[X_AXIS]
    long[ptr_y] := ~~tmp.word[Y_AXIS] * ((((((_mag_sens_adj[X_AXIS] * 1000) - 128_000) / 2)) / 128) + 1_000) + _mag_bias[Y_AXIS]
    long[ptr_z] := ~~tmp.word[Z_AXIS] * ((((((_mag_sens_adj[X_AXIS] * 1000) - 128_000) / 2)) / 128) + 1_000) + _mag_bias[Z_AXIS]

PUB MagDataOverrun{}: flag
' Flag indicating magnetometer data has overrun (i.e., new data arrived before previous measurement was read)
'   Returns: TRUE (-1) if overrun occurred, FALSE (0) otherwise
    flag := 0
    readreg(core#ST1, 1, @flag)
    return ((flag >> core#FLD_DOR) & %1) == 1

PUB MagDataRate(Hz)
' Set magnetometer output data rate, in Hz
'   Valid values: 8, 100
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting switches to/only affects continuous measurement mode
    case Hz
        8:
            magopmode(CONT8)
        100:
            magopmode(CONT100)
        other:
            case magopmode(-2)
                CONT8:
                    return 8
                CONT100:
                    return 100

PUB MagDataReady{}: flag
' Flag indicating new magnetometer data is ready to be read
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    flag := 0
    readreg(core#ST1, 1, @flag)
    return (flag & %1) == 1

PUB MagGauss(mx, my, mz) | tmpx, tmpy, tmpz ' XXX unverified

    magdata(@tmpx, @tmpy, @tmpz)
    long[mx] := (tmpx * _mag_cnts_per_lsb)
    long[my] := (tmpy * _mag_cnts_per_lsb)
    long[mz] := (tmpz * _mag_cnts_per_lsb)

PUB MagOverflow{}: flag
' Flag indicating magnetometer measurement has overflowed
'   Returns: TRUE (-1) if overrun occurred, FALSE (0) otherwise
'   NOTE: If this flag is TRUE, measurement data should not be trusted
'   NOTE: This bit self-clears when the next measurement starts
    flag := 0
    readreg(core#ST2, 1, @flag)
    return ((flag >> core#FLD_HOFL) & %1) == 1

PUB MagScale(scale): curr_scl ' XXX PRELIMINARY
' Set full-scale range of magnetometer, in bits
'   Valid values: 14, 16
    case scale
        14:
            _mag_cnts_per_lsb := 5_997
        16:
            _mag_cnts_per_lsb := 1_499
        other:
            return magadcres(-2)

    magadcres(scale)

PUB MagSelfTestEnabled(state): curr_state
' Enable magnetometer self-test mode (generates magnetic field)
'   Valid values: TRUE (-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#ASTC, 1, @curr_state)
    case ||(state)
        0, 1:
            state := (||(state) << core#FLD_SELF) & core#ASTC_MASK
        other:
            return ((curr_state >> core#FLD_SELF) & %1) == 1

    state := (curr_state & core#MASK_SELF) | state
    writereg(core#ASTC, 1, @state)

PUB MagSoftReset{} | tmp
' Perform soft-reset of magnetometer: initialize all registers
    tmp := %1 & core#CNTL2_MASK
    writereg(core#CNTL2, 1, @tmp)

PUB MagTesla(mx, my, mz) | tmpx, tmpy, tmpz ' XXX unverified
' Read magnetomer data, calculated
'   Returns: Magnetic field strength, in thousandths of a micro-Tesla/nano-Tesla (i.e., 12000 = 12uT)
    magdata(@tmpx, @tmpy, @tmpz)
    long[mx] := (((tmpx * 1_000) - 128_000) / 256 + 1_000) * 4912 / 32760
    long[my] := (((tmpy * 1_000) - 128_000) / 256 + 1_000) * 4912 / 32760
    long[mz] := (((tmpz * 1_000) - 128_000) / 256 + 1_000) * 4912 / 32760

PUB MagOpMode(mode): curr_mode
' Set magnetometer operating mode
'   Valid values:
'      *POWERDOWN (0): Power down
'       SINGLE (1): Single measurement mode
'       CONT8 (2): Continuous measurement mode, 8Hz updates
'       CONT100 (6): Continuous measurement mode, 100Hz updates
'       EXT_TRIG (4): External trigger measurement mode
'       SELFTEST (8): Self-test mode
'       FUSEACCESS (15): Fuse ROM access mode
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#CNTL1, 1, @curr_mode)
    case mode
        POWERDOWN, SINGLE, CONT8, CONT100, EXT_TRIG, SELFTEST, FUSEACCESS:
        other:
            return curr_mode & core#BITS_MODE

    mode := ((curr_mode & core#MASK_MODE) | mode) & core#CNTL1_MASK
    writereg(core#CNTL1, 1, @mode)

PUB MeasureMag{}
' Perform magnetometer measurement
    magopmode(SINGLE)

PUB ReadMagAdj{}
' Read magnetometer factory sensitivity adjustment values
    magopmode(FUSEACCESS)
    readreg(core#ASAX, 3, @_mag_sens_adj)
    magopmode(CONT100)

PUB Reset{}
' Perform soft-reset
    magsoftreset{}
    xlgsoftreset{}

PUB Temperature{}: temp
' Read temperature, in hundredths of a degree
    temp := 0
    readreg(core#TEMP_OUT_H, 2, @temp)
    case _temp_scale
        F:
        other:
            return ((temp * 1_0000) / 333_87) + 21_00 'XXX unverified

PUB TempScale(scale)
' Set temperature scale used by Temperature method
'   Valid values:
'       C (0): Celsius
'       F (1): Fahrenheit
'   Any other value returns the current setting
    case scale
        C, F:
            _temp_scale := scale
        other:
            return _temp_scale

PUB XLGDataReady{}: flag
' Flag indicating new gyroscope/accelerometer data is ready to be read
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    readreg(core#INT_STATUS, 1, @flag)
    return (flag & %1) == 1

PUB XLGSoftReset{} | tmp
' Perform soft-reset of accelerometer and gyro: initialize all registers
    tmp := 1 << core#FLD_H_RESET
    writereg(core#PWR_MGMT_1, 1, @tmp)

PRI disableI2CMaster{} | tmp

    tmp := 0
    readreg(core#INT_BYPASS_CFG, 1, @tmp)
    tmp &= core#MASK_BYPASS_EN
    tmp := (tmp | 1 << core#FLD_BYPASS_EN)
    writereg(core#INT_BYPASS_CFG, 1, @tmp)

PRI readReg(reg_nr, nr_bytes, buff_addr) | cmd_packet, tmp
' Read nr_bytes from the slave device buff_addr
    case reg_nr                                             ' Basic register validation (device ID is embedded in the upper byte of each register symbol
        core#SELF_TEST_X_GYRO..core#SELF_TEST_Z_GYRO, core#SELF_TEST_X_ACCEL..core#SELF_TEST_Z_ACCEL, core#SMPLRT_DIV..core#WOM_THR, core#FIFO_EN..core#INT_ENABLE, core#INT_STATUS, core#EXT_SENS_DATA_00..core#EXT_SENS_DATA_23, core#I2C_SLV0_DO..core#USER_CTRL, core#PWR_MGMT_2, core#FIFO_COUNTH..core#WHO_AM_I, core#XG_OFFS_USR, core#YG_OFFS_USR, core#ZG_OFFS_USR, core#XA_OFFS_H, core#YA_OFFS_H, core#ZA_OFFS_H, core#ACCEL_XOUT_H..core#ACCEL_ZOUT_L, core#GYRO_XOUT_H..core#GYRO_ZOUT_L, core#TEMP_OUT_H:
            cmd_packet.byte[0] := SLAVE_XLG_WR              ' Accel/Gyro regs
            cmd_packet.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wr_block (@cmd_packet, 2)
            i2c.start{}
            i2c.write (SLAVE_XLG_RD)
            repeat tmp from nr_bytes-1 to 0                 ' Read MSB to LSB (* relevant only to multi-byte registers)
                byte[buff_addr][tmp] := i2c.read(tmp == 0)
            i2c.stop{}
        core#HXL, core#HYL, core#HZL, core#WIA..core#ASTC, core#I2CDIS..core#ASAZ:
            cmd_packet.byte[0] := SLAVE_MAG_WR              ' Mag regs
            cmd_packet.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wr_block (@cmd_packet, 2)
            i2c.start{}
            i2c.write (SLAVE_MAG_RD)
            repeat tmp from 0 to nr_bytes-1                 ' Read LSB to MSB (* relevant only to multi-byte registers)
                byte[buff_addr][tmp] := i2c.read(tmp == nr_bytes-1)
            i2c.stop{}
        other:
            return

PRI writeReg(reg_nr, nr_bytes, buff_addr) | cmd_packet, tmp
' Write nr_bytes to the slave device from buff_addr
    case reg_nr                                             ' Basic register validation (device ID is embedded in the upper byte of each register symbol
        core#SELF_TEST_X_GYRO..core#SELF_TEST_Z_GYRO, core#SELF_TEST_X_ACCEL..core#SELF_TEST_Z_ACCEL, core#SMPLRT_DIV..core#WOM_THR, core#FIFO_EN..core#I2C_SLV4_CTRL, core#INT_BYPASS_CFG, core#INT_ENABLE, core#I2C_SLV0_DO..core#PWR_MGMT_2, core#FIFO_COUNTH..core#FIFO_R_W, core#XG_OFFS_USR, core#YG_OFFS_USR, core#ZG_OFFS_USR, core#XA_OFFS_H, core#YA_OFFS_H, core#ZA_OFFS_H:
            cmd_packet.byte[0] := SLAVE_XLG_WR              ' Accel/Gyro regs
            cmd_packet.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wr_block (@cmd_packet, 2)
            repeat tmp from nr_bytes-1 to 0                 ' Write MSB to LSB (* relevant only to multi-byte registers)
                i2c.write (byte[buff_addr][tmp])
            i2c.stop{}
        core#CNTL1..core#ASTC, core#I2CDIS:
            cmd_packet.byte[0] := SLAVE_MAG_WR              ' Mag regs
            cmd_packet.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wr_block(@cmd_packet, 2)
            i2c.write (byte[buff_addr][0])
            i2c.stop{}
        other:
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
