{
    --------------------------------------------
    Filename: sensor.imu.9dof.mpu9250.spin
    Author: Jesse Burt
    Description: Driver for the InvenSense MPU9250
    Copyright (c) 2022
    Started Sep 2, 2019
    Updated Oct 31, 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "sensor.accel.common.spinh"
#include "sensor.gyroscope.common.spinh"
#include "sensor.magnetometer.common.spinh"

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
    DEF_ADDR            = 0
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

' Scales and data rates used during calibration/bias/offset process
    CAL_XL_SCL          = 2
    CAL_G_SCL           = 250
    CAL_M_SCL           = 48
    CAL_XL_DR           = 400
    CAL_G_DR            = 400
    CAL_M_DR            = 100

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

    long _abias_fact[ACCEL_DOF]
    byte _mag_sens_adj[MAG_DOF]
    byte _temp_scale
    byte _addr_bits

OBJ
{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef MPU9250_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.mpu9250"
    time: "time"

PUB null{}
' This is not a top-level object

PUB start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ, DEF_ADDR)

PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start using custom I/O pins and I2C bus speed
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#TREGRW)            ' startup time
            _addr_bits := (ADDR_BITS << 1)
            ' setup to read the magnetometer from the same bus as XL & G
            i2c_mast_dis{}
            if (dev_id{} == core#DEVID_RESP)
                { read the factory accel bias }
                accel_bias(@_abias_fact[X_AXIS], @_abias_fact[Y_AXIS], @_abias_fact[Z_AXIS])
                return status
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB stop{}
' Stop the driver
    i2c.deinit{}
    longfill(@_abias_fact, 0, 3)
    bytefill(@_mag_sens_adj, 0, 4)

PUB defaults{}
' Factory default settings
'   * accel scale: 2g
'   * gyro scale: 250dps
'   * mag scale: 16Gs
'   * temp scale: Celsius
    reset{}
' NOTE: If you ever call reset() in your code, you _must_ call
'   i2c_mast_dis() _afterwards_ if you wish to read the magnetometer
'   through the same I2C bus as the Accel & Gyro

PUB preset_active{}
' Like defaults(), but
'   * sets up the MPU9250 to pass the magnetometer data through the same
'       I2C bus as the Accel and Gyro data
'   * reads magnetometer factory sensitivty adjustment values into hub
'   * sets scaling factors for all three sub-sensors
    reset{}
    i2c_mast_dis{}
    rd_mag_sens_adj{}

    ' the registers modified by the following are actually changed by the call
    ' to reset() above, but they need to be called explicitly to set the
    ' scaling factors used by the calculated output data methods
    ' accel_g(), gyro_dps(), and mag_gauss()
    accel_scale(2)
    gyro_scale(250)
    mag_scale(16)
    temp_scale(C)

PUB accel_axis_ena(xyz_mask): curr_mask
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
            xyz_mask := ((xyz_mask ^ core#DIS_INVERT) & core#DIS_XYZA_BITS) << core#DIS_XYZA
        other:
            return ((curr_mask >> core#DIS_XYZA) & core#DIS_XYZA_BITS) ^ core#DIS_INVERT

    xyz_mask := ((curr_mask & core#DIS_XYZA_MASK) | xyz_mask)
    writereg(core#PWR_MGMT_2, 1, @xyz_mask)

PUB accel_bias(x, y, z) | tmp[ACCEL_DOF]
' Read or write/manually set accelerometer calibration offset values
'   x, y, z: pointers to copy offsets to
    longfill(@tmp, 0, 3)
    readreg(core#XA_OFFS_H, 2, @tmp[X_AXIS])
    readreg(core#YA_OFFS_H, 2, @tmp[Y_AXIS])
    readreg(core#ZA_OFFS_H, 2, @tmp[Z_AXIS])

    long[x] := ~~tmp[X_AXIS]
    long[y] := ~~tmp[Y_AXIS]
    long[z] := ~~tmp[Z_AXIS]

PUB accel_set_bias(x, y, z) | tmp[ACCEL_DOF]
' Write accelerometer calibration offset values
'   Valid values:
'       -16384..16383 (clamped to range)
'   NOTE: The MPU9250 accelerometer is pre-programmed with offsets, which may
'       or may not be adequate for your application
    { read temp compensation bit }
    longfill(@tmp, 0, 3)
    readreg(core#XA_OFFS_H, 2, @tmp[X_AXIS])
    readreg(core#YA_OFFS_H, 2, @tmp[Y_AXIS])
    readreg(core#ZA_OFFS_H, 2, @tmp[Z_AXIS])

    x := ((_abias_fact[X_AXIS]-(x / 8)) & $FFFE) | (tmp[X_AXIS] & 1)
    y := ((_abias_fact[Y_AXIS]-(y / 8)) & $FFFE) | (tmp[Y_AXIS] & 1)
    z := ((_abias_fact[Z_AXIS]-(z / 8)) & $FFFE) | (tmp[Z_AXIS] & 1)

    writereg(core#XA_OFFS_H, 2, @x)
    writereg(core#YA_OFFS_H, 2, @y)
    writereg(core#ZA_OFFS_H, 2, @z)

PUB accel_data(ptr_x, ptr_y, ptr_z) | tmp[2]
' Read accelerometer data
    tmp := 0
    readreg(core#ACCEL_XOUT_H, 6, @tmp)

    long[ptr_x] := ~~tmp.word[2]
    long[ptr_y] := ~~tmp.word[1]
    long[ptr_z] := ~~tmp.word[0]

PUB accel_data_rate(rate): curr_rate
' Set accelerometer output data rate, in Hz
'   Valid values: 4..1000
'   Any other value polls the chip and returns the current setting
    return xlg_data_rate(rate)

PUB accel_data_rdy{}: flag
' Flag indicating new accelerometer data available
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    return xlg_data_rdy{}

PUB accel_lpf_freq(freq): curr_freq | lpf_byp_bit
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

    freq := (curr_freq & core#A_DLPFCFG_MASK & core#ACCEL_FCH_B_MASK) | freq | lpf_byp_bit
    writereg(core#ACCEL_CFG2, 1, @freq)

PUB accel_scale(g): curr_scl
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

PUB clock_src(src): curr_src
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

PUB dev_id{}: id | mag_tmp, xlg_tmp
' Read device ID
'   Returns: [15..8]: accel/gyro ID, [7..0]: mag ID
    readreg(core#WIA, 1, @mag_tmp)
    readreg(core#WHO_AM_I, 1, @xlg_tmp)
    return ((xlg_tmp << 8) | mag_tmp)

PUB i2c_mast_dis{} | tmp
' Disable on-chip I2C master
'   NOTE: Used to setup to read the magnetometer from the same bus as
'       accelerometer and gyroscope
    tmp := 0
    readreg(core#INT_BYPASS_CFG, 1, @tmp)
    tmp := ((tmp & core#BYPASS_EN_MASK) | (1 << core#BYPASS_EN)) & core#INT_BYPASS_CFG_MASK
    writereg(core#INT_BYPASS_CFG, 1, @tmp)

PUB fifo_ena(state): curr_state
' Enable the FIFO
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: FALSE disables the interface to the FIFO, but the chip will still write data to it,
'       if FIFO data sources are defined with fifo_src()
    curr_state := 0
    readreg(core#USER_CTRL, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#FIFOEN
            state := ((curr_state & core#FIFOEN_MASK) | state)
            writereg(core#USER_CTRL, 1, @state)
        other:
            return (((curr_state >> core#FIFOEN) & 1) == 1)

PUB fifo_full{}: flag
' Flag indicating FIFO is full
'   Returns: TRUE (-1) if FIFO is full, FALSE (0) otherwise
'   NOTE: If this flag is set, the oldest data has already been dropped from the FIFO
    readreg(core#INT_STATUS, 1, @flag)
    return (((flag >> core#FIFO_OVERFL_INT) & 1) == 1)

PUB fifo_mode(mode): curr_mode
' Set FIFO mode
'   Valid values:
'       BYPASS (0): FIFO disabled
'       STREAM (1): FIFO enabled; when full, new data overwrites old data
'       FIFO (2): FIFO enabled; when full, no new data will be written to FIFO
'   Any other value polls the chip and returns the current setting
'   NOTE: If no data sources are set using fifo_src(), the current mode returned will be
'       BYPASS (0), regardless of what the mode was previously set to
    curr_mode := 0
    readreg(core#CONFIG, 1, @curr_mode)
    case mode
        BYPASS:                                 ' If bypassing the FIFO, turn
            fifo_src(%00000000)                 ' off all FIFO data collection
            return
        STREAM, FIFO:
            mode := lookdownz(mode: STREAM, FIFO) << core#FIFO_MODE
        other:
            ' Check if a mask has been set with fifo_src(); return
            '   either STREAM or FIFO as the current mode, as applicable
            ' If not, just return BYPASS (0), as anything else
            '   doesn't make sense
            curr_mode := (curr_mode >> core#FIFO_MODE) & 1
            if fifo_src(-2)
                return lookupz(curr_mode: STREAM, FIFO)
            else
                return BYPASS
    mode := (curr_mode & core#FIFO_MODE_MASK) | mode
    writereg(core#CONFIG, 1, @mode)

PUB fifo_read(nr_bytes, ptr_data)
' Read FIFO data
    readreg(core#FIFO_R_W, nr_bytes, ptr_data)

PUB fifo_reset{} | tmp
' Reset the FIFO    XXX - expand..what exactly does it do?
    tmp := 1 << core#FIFO_RST
    writereg(core#USER_CTRL, 1, @tmp)

PUB fifo_src(mask): curr_mask
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

PUB fifo_nr_unread{}: nr_samples
' Number of unread samples stored in FIFO
'   Returns: unsigned 13bit
    readreg(core#FIFO_COUNTH, 2, @nr_samples)

PUB fsync_polarity(state): curr_state
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

PUB gyro_axis_ena(xyz_mask): curr_mask
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

PUB gyro_bias(x, y, z) | tmp[GYRO_DOF]
' Read gyroscope calibration offset values
    longfill(@tmp, 0, 3)
    readreg(core#XG_OFFS_USR, 2, @tmp[X_AXIS])
    readreg(core#YG_OFFS_USR, 2, @tmp[Y_AXIS])
    readreg(core#ZG_OFFS_USR, 2, @tmp[Z_AXIS])
    long[x] := ~~tmp[X_AXIS]
    long[y] := ~~tmp[Y_AXIS]
    long[z] := ~~tmp[Z_AXIS]

PUB gyro_set_bias(x, y, z)
' Write gyroscope calibration offset values
'   Valid values:
'       -32768..32767 (clamped to range)
    x := -((-32768 #> x <# 32767) / 4)
    y := -((-32768 #> y <# 32767) / 4)
    z := -((-32768 #> z <# 32767) / 4)
    writereg(core#XG_OFFS_USR, 2, @x)
    writereg(core#YG_OFFS_USR, 2, @y)
    writereg(core#ZG_OFFS_USR, 2, @z)

PUB gyro_data(ptr_x, ptr_y, ptr_z) | tmp[2]
' Read gyro data
    tmp := 0
    readreg(core#GYRO_XOUT_H, 6, @tmp)

    long[ptr_x] := ~~tmp.word[2]
    long[ptr_y] := ~~tmp.word[1]
    long[ptr_z] := ~~tmp.word[0]

PUB gyro_data_rate(rate): curr_rate
' Set gyroscope output data rate, in Hz
'   Valid values: 4..1000
'   Any other value polls the chip and returns the current setting
    return xlg_data_rate(rate)

PUB gyro_data_rdy{}: flag
' Flag indicating new gyroscope data available
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    return xlg_data_rdy{}

PUB gyro_lpf_freq(freq): curr_freq | lpf_byp_bits
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

PUB gyro_scale(scale): curr_scl
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

PUB int_polarity(state): curr_state
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

PUB int_clear_mode(mode): curr_mode
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

PUB interrupt{}: flag
' Indicates one or more interrupts have been asserted
'   Returns: non-zero result if any interrupts have been asserted:
'       INT_WAKE_ON_MOTION (64) - Wake on motion interrupt occurred
'       INT_FIFO_OVERFL (16) - FIFO overflowed
'       INT_FSYNC (8) - FSYNC interrupt occurred
'       INT_SENSOR_READY (1) - Sensor raw data updated
    flag := 0
    readreg(core#INT_STATUS, 1, @flag)

PUB int_latch_ena(state): curr_state
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

PUB int_mask(mask): curr_mask
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

PUB int_outp_type(mode): curr_mode
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

PUB mag_adc_res(bits): curr_res | tmp
' Set magnetometer ADC resolution, in bits
'   Valid values: *14, 16
'   Any other value polls the chip and returns the current setting
    curr_res := 0
    readreg(core#CNTL1, 1, @curr_res)
    case bits
        14, 16:
            ' set scale factor based on current ADC res
            tmp := lookdownz(bits: 14, 16)
            longfill(@_mres, lookupz(tmp: 5_997, 1_499), MAG_DOF)
            bits := lookdownz(bits: 14, 16) << core#BIT
        other:
            curr_res := (curr_res >> core#BIT) & 1
            return lookupz(curr_res: 14, 16)

    bits := ((curr_res & core#BIT_MASK) | bits)
    writereg(core#CNTL1, 1, @bits)

PUB mag_bias(x, y, z)
' Read magnetometer calibration offset values
'   x, y, z: pointers to copy offsets to
    long[x] := _mbias[X_AXIS]
    long[y] := _mbias[Y_AXIS]
    long[z] := _mbias[Z_AXIS]

PUB mag_set_bias(x, y, z)
' Write magnetometer calibration offset values
'   Valid values:
'       -32760..32760 (clamped to range)
    _mbias[X_AXIS] := -32760 #> x <# 32760
    _mbias[Y_AXIS] := -32760 #> y <# 32760
    _mbias[Z_AXIS] := -32760 #> z <# 32760

PUB mag_data(ptr_x, ptr_y, ptr_z) | tmp[2]
' Read Magnetometer data
    tmp := 0
    readreg(core#HXL, 7, @tmp)                  ' Read 6 mag data bytes, plus
                                                ' an extra (required) read of
                                                ' the status register

    tmp.word[X_AXIS] -= _mbias[X_AXIS]
    tmp.word[Y_AXIS] -= _mbias[Y_AXIS]
    tmp.word[Z_AXIS] -= _mbias[Z_AXIS]
    long[ptr_x] := ~~tmp.word[X_AXIS] * _mag_sens_adj[X_AXIS]
    long[ptr_y] := ~~tmp.word[Y_AXIS] * _mag_sens_adj[Y_AXIS]
    long[ptr_z] := ~~tmp.word[Z_AXIS] * _mag_sens_adj[Z_AXIS]

PUB mag_data_overrun{}: flag
' Flag indicating magnetometer data has overrun (i.e., new data arrived before previous measurement was read)
'   Returns: TRUE (-1) if overrun occurred, FALSE (0) otherwise
    flag := 0
    readreg(core#ST1, 1, @flag)
    return (((flag >> core#DOR) & 1) == 1)

PUB mag_data_rate(rate): curr_rate
' Set magnetometer output data rate, in Hz
'   Valid values: 8, 100
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting switches to/only affects continuous measurement mode
    case rate
        8:
            mag_opmode(CONT8)
        100:
            mag_opmode(CONT100)
        other:
            case mag_opmode(-2)
                CONT8:
                    return 8
                CONT100:
                    return 100

PUB mag_data_rdy{}: flag
' Flag indicating new magnetometer data is ready to be read
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    flag := 0
    readreg(core#ST1, 1, @flag)
    return ((flag & 1) == 1)

PUB mag_overflow{}: flag
' Flag indicating magnetometer measurement has overflowed
'   Returns: TRUE (-1) if overrun occurred, FALSE (0) otherwise
'   NOTE: If this flag is TRUE, measurement data should not be trusted
'   NOTE: This bit self-clears when the next measurement starts
    flag := 0
    readreg(core#ST2, 1, @flag)
    return (((flag >> core#HOFL) & 1) == 1)

PUB mag_scale(scale): curr_scl   'XXX revisit - return value doesn't match either possible param
' Set full-scale range of magnetometer, in Gauss
'   Valid values: 48
'   NOTE: The magnetometer has only one full-scale range. This method is provided primarily for API compatibility with other IMUs
    case mag_adc_res(-2)
        14:
            longfill(@_mres, 5_997, MAG_DOF)
        16:
            longfill(@_mres, 1_499, MAG_DOF)

    return 48

PUB mag_self_test_ena(state): curr_state
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

PUB mag_soft_reset{} | tmp
' Perform soft-reset of magnetometer: initialize all registers
    tmp := core#SOFT_RST
    writereg(core#CNTL2, 1, @tmp)

PUB mag_opmode(mode): curr_mode | tmp
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

PUB mag_meas{}
' Perform magnetometer measurement
    mag_opmode(SINGLE)

PUB rd_mag_sens_adj{}
' Read magnetometer factory sensitivity adjustment values
    mag_opmode(FUSEACCESS)
    readreg(core#ASAX, 3, @_mag_sens_adj)
    mag_opmode(CONT100)
    _mag_sens_adj[X_AXIS] := ((((((_mag_sens_adj[X_AXIS] * 1000) - 128_000) / 2) / 128) + 1_000)) {
}                            / 1000
    _mag_sens_adj[Y_AXIS] := ((((((_mag_sens_adj[Y_AXIS] * 1000) - 128_000) / 2) / 128) + 1_000)) {
}                            / 1000
    _mag_sens_adj[Z_AXIS] := ((((((_mag_sens_adj[Z_AXIS] * 1000) - 128_000) / 2) / 128) + 1_000)) {
}                            / 1000

PUB reset{}
' Perform soft-reset
    mag_soft_reset{}
    xlg_soft_reset{}

PUB temp_data_rate(rate): curr_rate
' Set temperature output data rate, in Hz
'   Valid values: 4..1000
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting affects the accelerometer and gyroscope data rate
'   (hardware limitation)
    return xlg_data_rate(rate)

PUB temperature{}: temp
' Read temperature, in hundredths of a degree
    temp := 0
    readreg(core#TEMP_OUT_H, 2, @temp)
    case _temp_scale
        F:
        other:
            return ((temp * 1_0000) / 333_87) + 21_00 'XXX unverified

PUB temp_scale(scale): curr_scl
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

PUB xlg_data_rate(rate): curr_rate
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

PUB xlg_data_rdy{}: flag
' Flag indicating new gyroscope/accelerometer data is ready to be read
'   Returns: TRUE (-1) if new data available, FALSE (0) otherwise
    flag := 0
    readreg(core#INT_STATUS, 1, @flag)
    return ((flag & 1) == 1)

PUB xlg_lpf_freq(freq): curr_freq
' Set accel/gyro/temp sensor low-pass filter cutoff frequency, in Hz
'   Valid values: 5, 10, 20, 42, 98, 188
'   Any other value polls the chip and returns the current setting (accel in lower word, gyro in upper word)
    curr_freq.word[0] := accel_lpf_freq(freq)
    curr_freq.word[1] := gyro_lpf_freq(freq)

PUB xlg_soft_reset{} | tmp
' Perform soft-reset of accelerometer and gyro: initialize all registers
    tmp := core#XLG_SOFT_RST
    writereg(core#PWR_MGMT_1, 1, @tmp)

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
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
            { accel/gyro regs }
            cmd_pkt.byte[0] := (SLAVE_XLG_WR | _addr_bits)
            cmd_pkt.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.write(SLAVE_XLG_RD | _addr_bits)
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        core#HXL, core#HYL, core#HZL, core#WIA..core#ASTC, core#I2CDIS..core#ASAZ:
            { mag regs }
            cmd_pkt.byte[0] := SLAVE_MAG_WR
            cmd_pkt.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.write(SLAVE_MAG_RD)
            i2c.rdblock_lsbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        other:
            return

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the slave device from ptr_buff
    case reg_nr                                 ' validate reg
        core#SELF_TEST_X_GYRO..core#SELF_TEST_Z_GYRO,{
}       core#SELF_TEST_X_ACCEL..core#SELF_TEST_Z_ACCEL, {
}       core#SMPLRT_DIV..core#WOM_THR, core#FIFO_EN..core#I2C_SLV4_CTRL,{
}       core#INT_BYPASS_CFG, core#INT_ENABLE, {
}       core#I2C_SLV0_DO..core#PWR_MGMT_2, core#FIFO_COUNTH..core#FIFO_R_W,{
}       core#XG_OFFS_USR, core#YG_OFFS_USR, core#ZG_OFFS_USR, core#XA_OFFS_H,{
}       core#YA_OFFS_H, core#ZA_OFFS_H:
            { accel/gyro regs }
            cmd_pkt.byte[0] := (SLAVE_XLG_WR | _addr_bits)
            cmd_pkt.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_msbf(ptr_buff, nr_bytes)
            i2c.stop{}
        core#CNTL1..core#ASTC, core#I2CDIS:
            { mag regs }
            cmd_pkt.byte[0] := SLAVE_MAG_WR
            cmd_pkt.byte[1] := reg_nr.byte[0]
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.write(byte[ptr_buff][0])
            i2c.stop{}
        other:
            return


DAT
{
Copyright 2022 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

