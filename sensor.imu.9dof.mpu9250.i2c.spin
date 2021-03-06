{
    --------------------------------------------
    Filename: sensor.imu.9dof.mpu9250.i2c.spin
    Author: Jesse Burt
    Description: Driver for the InvenSense MPU9250
    Copyright (c) 2021
    Started Sep 2, 2019
    Updated Jan 22, 2021
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

' Indicate to user apps how many Degrees of Freedom each sub-sensor has
'   (also imply whether or not it has a particular sensor)
    ACCEL_DOF           = 3
    GYRO_DOF            = 3
    MAG_DOF             = 3
    BARO_DOF            = 0
    DOF                 = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

' Bias adjustment (AccelBias(), GyroBias(), MagBias()) read or write
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
    INT_FIFO_OVERFL     = 16
    INT_FSYNC           = 8
    INT_SENSOR_READY    = 1

' Temperature scales
    C                   = 0
    F                   = 1

' FIFO modes
    BYPASS              = 0
    STREAM              = 1
    FIFO                = 2

' Clock sources
    INT20               = 0
    AUTO                = 1
    CLKSTOP             = 7

VAR

    long _mag_bias[3]
    word _ares, _gres, _mres
    byte _mag_sens_adj[3]
    byte _temp_scale

OBJ

    i2c : "com.i2c"
    core: "core.con.mpu9250.spin"
    time: "time"

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom I/O pins and I2C bus speed
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#TREGRW)            ' startup time
            if i2c.present(SLAVE_XLG)           ' check device bus presence
                ' setup to read the magnetometer from the same bus as XL & G
                disablei2cmaster{}
                if deviceid{} == core#DEVID_RESP
                    return status
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB Defaults{}
' Factory default settings
{   ' This is what _would_ be set:
    accelscale(2)
    gyroscale(250)
    magopmode(CONT100)
    magscale(16)
    tempscale(C)
}
' to save code space, just perform soft-reset, instead:
    reset{}
' NOTE: If you ever call this method in your code, you _must_ call
'   DisableI2CMaster() _afterwards_ if you wish to read the magnetometer
'   through the same I2C bus as the Accel & Gyro

PUB Preset_XL_G_M{}
' Like Defaults(), but
'   * sets up the MPU9250 to pass the magnetometer data through the same
'       I2C bus as the Accel and Gyro data
'   * reads magnetometer factory sensitivty adjustment values into hub
'   * sets scaling factors for all three sub-sensors
    reset{}
    disablei2cmaster{}
    readmagadj{}

    ' the registers modified by the following are actually changed by the call
    ' to Reset() above, but they need to be called explicitly to set the
    ' scaling factors used by the calculated output data methods
    ' AccelG(), GyroDPS(), and MagGauss()
    accelscale(2)
    gyroscale(250)
    magscale(16)
    tempscale(C)

PUB Stop{}
' Stop/deinitialize driver
    i2c.deinit{}

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
            ' invert bits because the logic in the chip is actually the reverse
            ' of the method name, i.e., a bit set to 1 _disables_ that axis
            xyz_mask := ((xyz_mask ^ core#DIS_INVERT) & {
}           core#DIS_XYZA_BITS) << core#DIS_XYZA
        other:
            return ((curr_mask >> core#DIS_XYZA) & core#DIS_XYZA_BITS){
}           ^ core#DIS_INVERT

    xyz_mask := ((curr_mask & core#DIS_XYZA_MASK) | xyz_mask)
    writereg(core#PWR_MGMT_2, 1, @xyz_mask)

PUB AccelBias(ptr_x, ptr_y, ptr_z, rw) | tmp[3], tc_bit[3]
' Read or write/manually set accelerometer calibration offset values
'   Valid values:
'       When rw == W (1, write)
'           ptr_x, ptr_y, ptr_z: -16384..16383
'       When rw == R (0, read)
'           ptr_x, ptr_y, ptr_z:
'               Pointers to variables to hold current settings for respective axes
'   NOTE: The MPU9250 accelerometer is pre-programmed with offsets, which may
'       or may not be adequate for your application
    ' Discrete reads because the three axes aren't contiguous register pairs
    readreg(core#XA_OFFS_H, 2, @tmp[X_AXIS])
    readreg(core#YA_OFFS_H, 2, @tmp[Y_AXIS])
    readreg(core#ZA_OFFS_H, 2, @tmp[Z_AXIS])

    case rw
        W:
            ' preserve temperature compensation bit
            tc_bit[X_AXIS] := tmp[X_AXIS] & 1
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
' Read accelerometer data   'xxx flag to choose data path? i.e., pull live data from sensor or from fifo... hub var
    tmp := 0
    readreg(core#ACCEL_XOUT_H, 6, @tmp)

    long[ptr_x] := ~~tmp.word[2]
    long[ptr_y] := ~~tmp.word[1]
    long[ptr_z] := ~~tmp.word[0]

PUB AccelDataRate(rate): curr_rate
' Set accelerometer output data rate, in Hz
'   Valid values: 4..1000
'   Any other value polls the chip and returns the current setting
    return xlgdatarate(rate)

PUB AccelDataReady{}: flag
' Flag indicating new accelerometer data available
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    return xlgdataready{}

PUB AccelG(ptr_x, ptr_y, ptr_z) | tmpx, tmpy, tmpz
' Read accelerometer data, calculated
'   Returns: Linear acceleration in millionths of a g
    acceldata(@tmpx, @tmpy, @tmpz)
    long[ptr_x] := (tmpx * _ares)
    long[ptr_y] := (tmpy * _ares)
    long[ptr_z] := (tmpz * _ares)

PUB AccelLowPassFilter(freq): curr_freq | lpf_byp_bit
' Set accelerometer output data low-pass filter cutoff frequency, in Hz
'   Valid values: 0 (disable), 5, 10, 20, 42, 98, 188
'   Any other value polls the chip and returns the current setting
    curr_freq := lpf_byp_bit := 0
    readreg(core#ACCEL_CFG2, 1, @curr_freq)
    case freq
        0:                                      ' Disable/bypass the LPF
            lpf_byp_bit := (1 << core#ACCEL_FCH_B)
        5, 10, 20, 42, 98, 188:
            freq := lookdown(freq: 188, 98, 42, 20, 10, 5)
        other:
            if (curr_freq >> core#ACCEL_FCH_B) & 1
                return 0                        ' LPF bypass bit set; return 0
            else
                curr_freq &= core#A_DLPFCFG_BITS
                return lookup(curr_freq: 188, 98, 42, 20, 10, 5)

    freq := (curr_freq & core#A_DLPFCFG_MASK & core#ACCEL_FCH_B_MASK) | {
}   freq | lpf_byp_bit
    writereg(core#ACCEL_CFG2, 1, @freq)

PUB AccelScale(g): curr_scl
' Set accelerometer full-scale range, in g's
'   Valid values: *2, 4, 8, 16
'   Any other value polls the chip and returns the current setting
    curr_scl := 0
    readreg(core#ACCEL_CFG, 1, @curr_scl)
    case g
        2, 4, 8, 16:
            g := lookdownz(g: 2, 4, 8, 16) << core#ACCEL_FS_SEL
            _ares := lookupz(g >> core#ACCEL_FS_SEL: 61, 122, 244, 488)
            ' (1/16384, 1/8192, 1/4096, 1/2048) * 1_000_000
        other:
            curr_scl := (curr_scl >> core#ACCEL_FS_SEL) & core#ACCEL_FS_SEL_BITS
            return lookupz(curr_scl: 2, 4, 8, 16)

    g := ((curr_scl & core#ACCEL_FS_SEL_MASK) | g) & core#ACCEL_CFG_MASK
    writereg(core#ACCEL_CFG, 1, @g)

PUB CalibrateAccel{} | tmpx, tmpy, tmpz, tmpbiasraw[3], axis, samples, {
}factory_bias[3], orig_scale, orig_datarate, orig_lpf
' Calibrate the accelerometer
'   NOTE: The accelerometer must be oriented with the package top facing up
'   for this method to be successful
    longfill(@tmpx, 0, 14)                      ' Initialize variables to 0
    orig_scale := accelscale(-2)                ' Preserve original settings
    orig_datarate := acceldatarate(-2)
    orig_lpf := accellowpassfilter(-2)

    accelscale(2)                               ' Set to most sensitive scale,
    acceldatarate(1000)                         '   fastest sample rate,
    accellowpassfilter(188)                     '   and a LPF of 188Hz

                                                ' MPU9250 accel has factory bias offsets,
                                                '   so read them in first
    accelbias(@factory_bias[X_AXIS], @factory_bias[Y_AXIS], @factory_bias[Z_AXIS], 0)

    samples := 40                               ' # samples to use for averaging

    repeat samples
        repeat until acceldataready
        acceldata(@tmpx, @tmpy, @tmpz)
        tmpbiasraw[X_AXIS] += tmpx
        tmpbiasraw[Y_AXIS] += tmpy
        tmpbiasraw[Z_AXIS] += tmpz - (1_000_000 / _ares)

    repeat axis from X_AXIS to Z_AXIS
        tmpbiasraw[axis] /= samples
        tmpbiasraw[axis] := (factory_bias[axis] - (tmpbiasraw[axis]/8))

    accelbias(tmpbiasraw[X_AXIS], tmpbiasraw[Y_AXIS], tmpbiasraw[Z_AXIS], W)

    accelscale(orig_scale)                      ' Restore user settings
    acceldatarate(orig_datarate)
    accellowpassfilter(orig_lpf)

PUB CalibrateGyro{} | tmpx, tmpy, tmpz, tmpbias[3], axis, samples, orig_scl, orig_drate, orig_lpf
' Calibrate the gyroscope
    longfill(@tmpx, 0, 11)                      ' Initialize variables to 0
    orig_scl := gyroscale(-2)                   ' Preserve original settings
    orig_drate := xlgdatarate(-2)
    orig_lpf := gyrolowpassfilter(-2)

    gyroscale(250)                              ' Set to most sensitive scale,
    gyrodatarate(1000)                          '   fastest sample rate,
    gyrolowpassfilter(188)                      '   and a LPF of 188Hz
    gyrobias(0, 0, 0, W)                        ' Reset gyroscope bias offsets
    samples := 40                               ' # samples to use for average

    repeat samples                              ' Accumulate samples to be averaged
        repeat until gyrodataready
        gyrodata(@tmpx, @tmpy, @tmpz)
        tmpbias[X_AXIS] -= tmpx                 ' offsets are _added_ by the
        tmpbias[Y_AXIS] -= tmpy                 ' chip, so negate the samples
        tmpbias[Z_AXIS] -= tmpz

                                                ' Write offsets to sensor (scaled to expected range)
    gyrobias((tmpbias[X_AXIS]/samples) / 4, (tmpbias[Y_AXIS]/samples) / 4,{
}   (tmpbias[Z_AXIS]/samples) / 4, W)

    gyroscale(orig_scl)                         ' Restore user settings
    gyrodatarate(orig_drate)
    gyrolowpassfilter(orig_lpf)

PUB CalibrateMag{} | magmin[3], magmax[3], magtmp[3], axis, samples, orig_opmd
' Calibrate the magnetometer
    longfill(@magmin, 0, 13)                    ' Initialize variables to 0
    orig_opmd := magopmode(-2)                  ' Preserve original settings,
    magopmode(CONT100)
    magbias(0, 0, 0, W)                         ' Reset magnetometer bias offsets
    samples := 10                               ' # samples to use for mean

    ' Establish initial minimum and maximum values:
    ' Start as the same value to avoid skewing the
    '   calcs (because vars were initialized with 0)
    magdata(@magtmp[X_AXIS], @magtmp[Y_AXIS], @magtmp[Z_AXIS])
    magmax[X_AXIS] := magmin[X_AXIS] := magtmp[X_AXIS]
    magmax[Y_AXIS] := magmin[Y_AXIS] := magtmp[Y_AXIS]
    magmax[Z_AXIS] := magmin[Z_AXIS] := magtmp[Z_AXIS]

    repeat samples
        repeat until magdataready{}
        magdata(@magtmp[X_AXIS], @magtmp[Y_AXIS], @magtmp[Z_AXIS])
        repeat axis from X_AXIS to Z_AXIS
            ' Find the maximum value seen during sampling
            '   as well as the minimum, for each axis
            magmax[axis] := magtmp[axis] #> magmax[axis]
            magmin[axis] := magtmp[axis] <# magmin[axis]

    magbias((magmax[X_AXIS] + magmin[X_AXIS]) / 2, (magmax[Y_AXIS] + magmin[Y_AXIS]) / 2, (magmax[Z_AXIS] + magmin[Z_AXIS]) / 2, W) ' Write the average of the samples just gathered as new bias offsets
    magopmode(orig_opmd)                        ' Restore user settings

PUB CalibrateXLG{}
' Calibrate accelerometer and gyroscope
    calibrateaccel{}
    calibrategyro{}

PUB ClockSource(src): curr_src
' Set sensor clock source
'   Valid values:
'       INT20 (0): Internal 20MHz oscillator
'      *AUTO (1): Automatically select best choice (PLL if ready, else internal oscillator)
'       CLKSTOP (7): Stop clock and hold in reset
    curr_src := 0
    readreg(core#PWR_MGMT_1, 1, @curr_src)
    case src
        INT20, AUTO, CLKSTOP:
        other:
            return curr_src & core#CLKSEL_BITS

    src := (curr_src & core#CLKSEL_MASK) | src
    writereg(core#PWR_MGMT_1, 1, @src)

PUB DeviceID{}: id
' Read device ID
'   Returns: AK8963 ID (LSB), MPU9250 ID (MSB)
    id := 0
    readreg(core#WIA, 1, @id.byte[0])
    readreg(core#WHO_AM_I, 1, @id.byte[1])

PUB DisableI2CMaster{} | tmp
' Disable on-chip I2C master
'   NOTE: Used to setup to read the magnetometer from the same bus as
'       accelerometer and gyroscope
    tmp := 0
    readreg(core#INT_BYPASS_CFG, 1, @tmp)
    tmp := ((tmp & core#BYPASS_EN_MASK) | (1 << core#BYPASS_EN)) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @tmp)

PUB FIFOEnabled(state): curr_state
' Enable the FIFO
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This disables the interface to the FIFO, but the chip will still write data to it, if FIFO data sources are defined with FIFOSource()
    curr_state := 0
    readreg(core#USER_CTRL, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#FIFOEN
            state := ((curr_state & core#FIFOEN_MASK) | state)
            writereg(core#USER_CTRL, 1, @state)
        other:
            return (((curr_state >> core#FIFOEN) & 1) == 1)

PUB FIFOFull{}: flag
' Flag indicating FIFO is full
'   Returns: TRUE (-1) if FIFO is full, FALSE (0) otherwise
'   NOTE: If this flag is set, the oldest data has already been dropped from the FIFO
    readreg(core#INT_STATUS, 1, @flag)
    return (((flag >> core#FIFO_OVERFL_INT) & 1) == 1)

PUB FIFOMode(mode): curr_mode
' Set FIFO mode
'   Valid values:
'       BYPASS (0): FIFO disabled
'       STREAM (1): FIFO enabled; when full, new data overwrites old data
'       FIFO (2): FIFO enabled; when full, no new data will be written to FIFO
'   Any other value polls the chip and returns the current setting
'   NOTE: If no data sources are set using FIFOSource(), the current mode returned will be BYPASS (0), regardless of what the mode was previously set to
    curr_mode := 0
    readreg(core#CONFIG, 1, @curr_mode)
    case mode
        BYPASS:                                 ' If bypassing the FIFO, turn
            fifosource(%00000000)               ' off all FIFO data collection
            return
        STREAM, FIFO:
            mode := lookdownz(mode: STREAM, FIFO) << core#FIFO_MODE
        other:
            ' Check if a mask has been set with FIFOSource(); return
            '   either STREAM or FIFO as the current mode, as applicable
            ' If not, just return BYPASS (0), as anything else
            '   doesn't make sense
            curr_mode := (curr_mode >> core#FIFO_MODE) & 1
            if fifosource(-2)
                return lookupz(curr_mode: STREAM, FIFO)
            else
                return BYPASS
    mode := (curr_mode & core#FIFO_MODE_MASK) | mode
    writereg(core#CONFIG, 1, @mode)

PUB FIFORead(nr_bytes, ptr_data)
' Read FIFO data
    readreg(core#FIFO_R_W, nr_bytes, ptr_data)

PUB FIFOReset{} | tmp
' Reset the FIFO    XXX - expand..what exactly does it do?
    tmp := 1 << core#FIFO_RST
    writereg(core#USER_CTRL, 1, @tmp)

PUB FIFOSource(mask): curr_mask
' Set FIFO source data, as a bitmask
'   Valid values:
'       Bits: 76543210
'           7: Temperature
'           6: Gyro X-axis
'           5: Gyro Y-axis
'           4: Gyro Z-axis
'           3: Accelerometer
'           2: I2C Slave #2
'           1: I2C Slave #1
'           0: I2C Slave #0
'   Any other value polls the chip and returns the current setting
'   NOTE: If any one of the Gyro axis bits or the temperature bits are set,
'   all will be buffered, even if they're not explicitly enabled (chip limitation)
    case mask
        %00000000..%11111111:
            writereg(core#FIFO_EN, 1, @mask)
        other:
            curr_mask := 0
            readreg(core#FIFO_EN, 1, @curr_mask)
            return

PUB FIFOUnreadSamples{}: nr_samples
' Number of unread samples stored in FIFO
'   Returns: unsigned 13bit
    readreg(core#FIFO_COUNTH, 2, @nr_samples)

PUB FSYNCActiveState(state): curr_state
' Set FSYNC pin active state/logic level
'   Valid values: LOW (1), *HIGH (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_state)
    case state
        LOW, HIGH:
            state := state << core#ACTL_FSYNC
        other:
            return (curr_state >> core#ACTL_FSYNC) & 1

    state := ((curr_state & core#ACTL_FSYNC_MASK) | state) & core#INT_BYPASS_CFG_MASK
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
            ' invert bits because the logic in the chip is actually the reverse
            ' of the method name, i.e., a bit set to 1 _disables_ that axis
            xyz_mask := ((xyz_mask ^ core#DIS_INVERT) & core#DIS_XYZG_BITS) << core#DIS_XYZG
        other:
            return ((curr_mask >> core#DIS_XYZG) & core#DIS_XYZG_BITS) ^ core#DIS_INVERT

    xyz_mask := ((curr_mask & core#DIS_XYZG_MASK) | xyz_mask)
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
    tmp := 0
    readreg(core#GYRO_XOUT_H, 6, @tmp)

    long[ptr_x] := ~~tmp.word[2]
    long[ptr_y] := ~~tmp.word[1]
    long[ptr_z] := ~~tmp.word[0]

PUB GyroDataRate(rate): curr_rate
' Set gyroscope output data rate, in Hz
'   Valid values: 4..1000
'   Any other value polls the chip and returns the current setting
    return xlgdatarate(rate)

PUB GyroDataReady{}: flag
' Flag indicating new gyroscope data available
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    return xlgdataready{}

PUB GyroDPS(gx, gy, gz) | tmpx, tmpy, tmpz
'Read gyroscope calibrated data (micro-degrees per second)
    gyrodata(@tmpx, @tmpy, @tmpz)
    long[gx] := (tmpx * _gres)
    long[gy] := (tmpy * _gres)
    long[gz] := (tmpz * _gres)

PUB GyroLowPassFilter(freq): curr_freq | lpf_byp_bits
' Set gyroscope output data low-pass filter cutoff frequency, in Hz
'   Valid values: 5, 10, 20, 42, 98, 188
'   Any other value polls the chip and returns the current setting
    curr_freq := lpf_byp_bits := 0
    readreg(core#CONFIG, 1, @curr_freq)
    readreg(core#GYRO_CFG, 1, @lpf_byp_bits)
    case freq
        0:                                      ' Disable/bypass the LPF
            ' Store the new setting into the 2nd byte of the variable
            lpf_byp_bits.byte[1] := (%11 << core#FCH_B)
        5, 10, 20, 42, 98, 188:
            freq := lookdown(freq: 188, 98, 42, 20, 10, 5)
        other:
            if lpf_byp_bits & core#FCH_B_BITS <> %00
                ' LPF bypass bit set; return 0
                return 0
            else
                ' not set; return the current LPF cutoff freq.
                return lookup(curr_freq & core#DLPF_CFG_BITS: 188, 98, 42, 20, 10, 5)

    lpf_byp_bits := (lpf_byp_bits.byte[0] & core#DLPF_CFG_MASK) | lpf_byp_bits.byte[1]
    freq := (curr_freq & core#DLPF_CFG_MASK) | freq
    writereg(core#CONFIG, 1, @freq)
    writereg(core#GYRO_CFG, 1, @lpf_byp_bits)

PUB GyroScale(scale): curr_scl
' Set gyroscope full-scale range, in degrees per second
'   Valid values: *250, 500, 1000, 2000
'   Any other value polls the chip and returns the current setting
    curr_scl := 0
    readreg(core#GYRO_CFG, 1, @curr_scl)
    case scale
        250, 500, 1000, 2000:
            scale := lookdownz(scale: 250, 500, 1000, 2000) << core#GYRO_FS_SEL
            _gres := lookupz(scale >> core#GYRO_FS_SEL: 7633, 15_267, 30_487, 60_975)
            ' (1/131, 1/65.5, 1/32.8, 1/16.4) * 1_000_000
        other:
            curr_scl := (curr_scl >> core#GYRO_FS_SEL) & core#GYRO_FS_SEL_BITS
            return lookupz(curr_scl: 250, 500, 1000, 2000)

    scale := ((curr_scl & core#GYRO_FS_SEL_MASK) | scale)
    writereg(core#GYRO_CFG, 1, @scale)

PUB IntActiveState(state): curr_state
' Set interrupt pin active state/logic level
'   Valid values: LOW (1), *HIGH (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_state)
    case state
        LOW, HIGH:
            state := state << core#ACTL
        other:
            return ((curr_state >> core#ACTL) & 1)

    state := ((curr_state & core#ACTL_MASK) | state) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @state)

PUB IntClearedBy(mode): curr_mode
' Select mode by which interrupt status may be cleared
'   Valid values:
'      *READ_INT_FLAG (0): Only by reading interrupt flags
'       ANY (1): By any read operation
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_mode)
    case mode
        ANY, READ_INT_FLAG:
            mode := mode << core#INT_ANYRD_2CLR
        other:
            return ((curr_mode >> core#INT_ANYRD_2CLR) & 1)

    mode := ((curr_mode & core#INT_ANYRD_2CLR_MASK) | mode) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @mode)

PUB Interrupt{}: flag
' Indicates one or more interrupts have been asserted
'   Returns: non-zero result if any interrupts have been asserted:
'       INT_WAKE_ON_MOTION (64) - Wake on motion interrupt occurred
'       INT_FIFO_OVERFL (16) - FIFO overflowed
'       INT_FSYNC (8) - FSYNC interrupt occurred
'       INT_SENSOR_READY (1) - Sensor raw data updated
    flag := 0
    readreg(core#INT_STATUS, 1, @flag)

PUB IntLatchEnabled(state): curr_state
' Latch interrupt pin when interrupt asserted
'   Valid values:
'      *FALSE (0): Interrupt pin is pulsed (width = 50uS)
'       TRUE (-1): Interrupt pin is latched, and must be cleared explicitly
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#LATCH_INT_EN
        other:
            return (((curr_state >> core#LATCH_INT_EN) & 1) == 1)

    state := ((curr_state & core#LATCH_INT_EN_MASK) | state) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @state)

PUB IntMask(mask): curr_mask
' Allow interrupts to assert INT pin, set by mask, or by ORing together symbols shown below
'   Valid values:
'       Bits: %x6x43xx0 (bit positions marked 'x' aren't supported by the device; setting any of them to '1' will be considered invalid and will query the current setting, instead)
'               Function                                Symbol              Value
'           6: Enable interrupt for wake on motion      INT_WAKE_ON_MOTION (64)
'           4: Enable interrupt for FIFO overflow       INT_FIFO_OVERFL  (16)
'           3: Enable FSYNC interrupt                   INT_FSYNC           (8)
'           1: Enable raw Sensor Data Ready interrupt   INT_SENSOR_READY    (1)
'   Any other value polls the chip and returns the current setting
    case mask & (core#INT_ENABLE_MASK ^ $FF)    ' check for any invalid bits:
        0:                                      ' result should be 0 if all ok
            mask &= core#INT_ENABLE_MASK
            writereg(core#INT_ENABLE, 1, @mask)
        other:                                  ' one or more invalid bits;
            curr_mask := 0                      ' return current setting
            readreg(core#INT_ENABLE, 1, @curr_mask)
            return curr_mask & core#INT_ENABLE_MASK

PUB IntOutputType(mode): curr_mode
' Set interrupt pin output mode
'   Valid values:
'      *INT_PP (0): Push-pull
'       INT_OD (1): Open-drain
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#INT_BYPASS_CFG, 1, @curr_mode)
    case mode
        INT_PP, INT_OD:
            mode := mode << core#OPEN
        other:
            return ((curr_mode >> core#OPEN) & 1)

    mode := ((curr_mode & core#OPEN_MASK) | mode) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @mode)

PUB MagADCRes(bits): curr_res
' Set magnetometer ADC resolution, in bits
'   Valid values: *14, 16
'   Any other value polls the chip and returns the current setting
    curr_res := 0
    readreg(core#CNTL1, 1, @curr_res)
    case bits
        14, 16:
            ' set scale factor based on current ADC res
            _mres := lookdownz(bits: 14, 16)
            _mres := lookupz(_mres: 5_997, 1_499)
            bits := lookdownz(bits: 14, 16) << core#BIT
        other:
            curr_res := (curr_res >> core#BIT) & 1
            return lookupz(curr_res: 14, 16)

    bits := ((curr_res & core#BIT_MASK) | bits)
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
    tmp := 0
    readreg(core#HXL, 7, @tmp)                  ' Read 6 mag data bytes, plus
                                                ' an extra (required) read of
                                                ' the status register

    tmp.word[X_AXIS] -= _mag_bias[X_AXIS]
    tmp.word[Y_AXIS] -= _mag_bias[Y_AXIS]
    tmp.word[Z_AXIS] -= _mag_bias[Z_AXIS]
    long[ptr_x] := ~~tmp.word[X_AXIS] * _mag_sens_adj[X_AXIS]
    long[ptr_y] := ~~tmp.word[Y_AXIS] * _mag_sens_adj[Y_AXIS]
    long[ptr_z] := ~~tmp.word[Z_AXIS] * _mag_sens_adj[Z_AXIS]

PUB MagDataOverrun{}: flag
' Flag indicating magnetometer data has overrun (i.e., new data arrived before previous measurement was read)
'   Returns: TRUE (-1) if overrun occurred, FALSE (0) otherwise
    flag := 0
    readreg(core#ST1, 1, @flag)
    return (((flag >> core#DOR) & 1) == 1)

PUB MagDataRate(rate): curr_rate
' Set magnetometer output data rate, in Hz
'   Valid values: 8, 100
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting switches to/only affects continuous measurement mode
    case rate
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
    return ((flag & 1) == 1)

PUB MagGauss(mx, my, mz) | tmpx, tmpy, tmpz ' XXX unverified
' Read magnetomer data, calculated
'   Returns: Magnetic field strength, in micro-Gauss (i.e., 1_000_000 = 1Gs)
    magdata(@tmpx, @tmpy, @tmpz)
    long[mx] := (tmpx * _mres)
    long[my] := (tmpy * _mres)
    long[mz] := (tmpz * _mres)

PUB MagOverflow{}: flag
' Flag indicating magnetometer measurement has overflowed
'   Returns: TRUE (-1) if overrun occurred, FALSE (0) otherwise
'   NOTE: If this flag is TRUE, measurement data should not be trusted
'   NOTE: This bit self-clears when the next measurement starts
    flag := 0
    readreg(core#ST2, 1, @flag)
    return (((flag >> core#HOFL) & 1) == 1)

PUB MagScale(scale): curr_scl   'XXX revisit - return value doesn't match either possible param
' Set full-scale range of magnetometer, in Gauss
'   Valid values: 48
'   NOTE: The magnetometer has only one full-scale range. This method is provided primarily for API compatibility with other IMUs
    case magadcres(-2)
        14:
            _mres := 5_997
        16:
            _mres := 1_499

    return 48

PUB MagSelfTestEnabled(state): curr_state
' Enable magnetometer self-test mode (generates magnetic field)
'   Valid values: TRUE (-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#ASTC, 1, @curr_state)
    case ||(state)
        0, 1:
            state := (||(state) << core#SELF) & core#ASTC_MASK
        other:
            return (((curr_state >> core#SELF) & 1) == 1)

    state := (curr_state & core#SELF_MASK) | state
    writereg(core#ASTC, 1, @state)

PUB MagSoftReset{} | tmp
' Perform soft-reset of magnetometer: initialize all registers
    tmp := core#SOFT_RST
    writereg(core#CNTL2, 1, @tmp)

PUB MagTesla(mx, my, mz) | tmpx, tmpy, tmpz ' XXX unverified
' Read magnetomer data, calculated
'   Returns: Magnetic field strength, in thousandths of a micro-Tesla/nano-Tesla (i.e., 12000 = 12uT)
    magdata(@tmpx, @tmpy, @tmpz)
    long[mx] := (tmpx * _mres) * 100
    long[my] := (tmpy * _mres) * 100
    long[mz] := (tmpz * _mres) * 100

PUB MagOpMode(mode): curr_mode | tmp
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
            return curr_mode & core#MODE_BITS

    mode := ((curr_mode & core#MODE_MASK) | mode) & core#CNTL1_MASK
    tmp := POWERDOWN
    writereg(core#CNTL1, 1, @tmp)               ' power down state
    time.msleep(100)                            ' wait 100ms first
    writereg(core#CNTL1, 1, @mode)              ' switch to the selected mode

PUB MeasureMag{}
' Perform magnetometer measurement
    magopmode(SINGLE)

PUB ReadMagAdj{}
' Read magnetometer factory sensitivity adjustment values
    magopmode(FUSEACCESS)
    readreg(core#ASAX, 3, @_mag_sens_adj)
    magopmode(CONT100)
    _mag_sens_adj[X_AXIS] := ((((((_mag_sens_adj[X_AXIS] * 1000) - 128_000){
}   / 2) / 128) + 1_000)) / 1000
    _mag_sens_adj[Y_AXIS] := ((((((_mag_sens_adj[Y_AXIS] * 1000) - 128_000){
}   / 2) / 128) + 1_000)) / 1000
    _mag_sens_adj[Z_AXIS] := ((((((_mag_sens_adj[Z_AXIS] * 1000) - 128_000){
}   / 2) / 128) + 1_000)) / 1000

PUB Reset{}
' Perform soft-reset
    magsoftreset{}
    xlgsoftreset{}

PUB TempDataRate(rate): curr_rate
' Set temperature output data rate, in Hz
'   Valid values: 4..1000
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting affects the accelerometer and gyroscope data rate
'   (hardware limitation)
    return xlgdatarate(rate)

PUB Temperature{}: temp
' Read temperature, in hundredths of a degree
    temp := 0
    readreg(core#TEMP_OUT_H, 2, @temp)
    case _temp_scale
        F:
        other:
            return ((temp * 1_0000) / 333_87) + 21_00 'XXX unverified

PUB TempScale(scale): curr_scl
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

PUB XLGDataRate(rate): curr_rate
' Set accelerometer/gyro/temp sensor output data rate, in Hz
'   Valid values: 4..1000
'   Any other value polls the chip and returns the current setting
    case rate
        4..1000:
            rate := (1000 / rate) - 1
            writereg(core#SMPLRT_DIV, 1, @rate)
        other:
            curr_rate := 0
            readreg(core#SMPLRT_DIV, 1, @curr_rate)
            return 1000 / (curr_rate + 1)

PUB XLGDataReady{}: flag
' Flag indicating new gyroscope/accelerometer data is ready to be read
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    readreg(core#INT_STATUS, 1, @flag)
    return ((flag & 1) == 1)

PUB XLGLowPassFilter(freq): curr_freq
' Set accel/gyro/temp sensor low-pass filter cutoff frequency, in Hz
'   Valid values: 5, 10, 20, 42, 98, 188
'   Any other value polls the chip and returns the current setting (accel in lower word, gyro in upper word)
    curr_freq.word[0] := accellowpassfilter(freq)
    curr_freq.word[1] := gyrolowpassfilter(freq)

PUB XLGSoftReset{} | tmp
' Perform soft-reset of accelerometer and gyro: initialize all registers
    tmp := core#XLG_SOFT_RST
    writereg(core#PWR_MGMT_1, 1, @tmp)

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the slave device ptr_buff
    case reg_nr                                 ' validate reg
        core#SELF_TEST_X_GYRO..core#SELF_TEST_Z_GYRO, {
}       core#SELF_TEST_X_ACCEL..core#SELF_TEST_Z_ACCEL, {
}       core#SMPLRT_DIV..core#WOM_THR, core#FIFO_EN..core#INT_ENABLE,{
}       core#INT_STATUS, core#EXT_SENS_DATA_00..core#EXT_SENS_DATA_23,{
}       core#I2C_SLV0_DO..core#USER_CTRL, core#PWR_MGMT_2, {
}       core#FIFO_COUNTH..core#WHO_AM_I, core#XG_OFFS_USR, core#YG_OFFS_USR,{
}       core#ZG_OFFS_USR, core#XA_OFFS_H, core#YA_OFFS_H, core#ZA_OFFS_H, {
}       core#ACCEL_XOUT_H..core#ACCEL_ZOUT_L, {
}       core#GYRO_XOUT_H..core#GYRO_ZOUT_L, core#TEMP_OUT_H:
            cmd_pkt.byte[0] := SLAVE_XLG_WR     ' Accel/Gyro regs
            cmd_pkt.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.write(SLAVE_XLG_RD)
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        core#HXL, core#HYL, core#HZL, core#WIA..core#ASTC, core#I2CDIS..core#ASAZ:
            cmd_pkt.byte[0] := SLAVE_MAG_WR     ' Mag regs
            cmd_pkt.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.write(SLAVE_MAG_RD)
            i2c.rdblock_lsbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        other:
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the slave device from ptr_buff
    case reg_nr                                 ' validate reg
        core#SELF_TEST_X_GYRO..core#SELF_TEST_Z_GYRO,{
}       core#SELF_TEST_X_ACCEL..core#SELF_TEST_Z_ACCEL, {
}       core#SMPLRT_DIV..core#WOM_THR, core#FIFO_EN..core#I2C_SLV4_CTRL,{
}       core#INT_BYPASS_CFG, core#INT_ENABLE, {
}       core#I2C_SLV0_DO..core#PWR_MGMT_2, core#FIFO_COUNTH..core#FIFO_R_W,{
}       core#XG_OFFS_USR, core#YG_OFFS_USR, core#ZG_OFFS_USR, core#XA_OFFS_H,{
}       core#YA_OFFS_H, core#ZA_OFFS_H:
            cmd_pkt.byte[0] := SLAVE_XLG_WR     ' Accel/Gyro regs
            cmd_pkt.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_msbf(ptr_buff, nr_bytes)
            i2c.stop{}
        core#CNTL1..core#ASTC, core#I2CDIS:
            cmd_pkt.byte[0] := SLAVE_MAG_WR     ' Mag regs
            cmd_pkt.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.write(byte[ptr_buff][0])
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
