{
    --------------------------------------------
    Filename: core.con.mpu9250.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2019
    Started Sep 2, 2019
    Updated Dec 4, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    I2C_MAX_FREQ                = 400_000
    SLAVE_ADDR                  = $68 << 1
    SLAVE_ADDR_MAG              = $0C << 1

' Startup time
    TREGRW                      = 100               ' ms

' Accelerometer / Gyroscope registers
    INT_BYPASS_CFG              = $37
    INT_BYPASS_CFG_MASK         = $FE
        FLD_BYPASS_EN           = 1
        FLD_FSYNC_INT_MODE_EN   = 2
        FLD_ACTL_FSYNC          = 3
        FLD_INT_ANYRD_2CLEAR    = 4
        FLD_LATCH_INT_EN        = 5
        FLD_OPEN                = 6
        FLD_ACTL                = 7
        MASK_BYPASS_EN          = INT_BYPASS_CFG_MASK ^ (1 << FLD_BYPASS_EN)
        MASK_FSYNC_INT_MODE_EN  = INT_BYPASS_CFG_MASK ^ (1 << FLD_FSYNC_INT_MODE_EN)
        MASK_ACTL_FSYNC         = INT_BYPASS_CFG_MASK ^ (1 << FLD_ACTL_FSYNC)
        MASK_INT_ANYRD_2CLEAR   = INT_BYPASS_CFG_MASK ^ (1 << FLD_INT_ANYRD_2CLEAR)
        MASK_LATCH_INT_EN       = INT_BYPASS_CFG_MASK ^ (1 << FLD_LATCH_INT_EN)
        MASK_OPEN               = INT_BYPASS_CFG_MASK ^ (1 << FLD_OPEN)
        MASK_ACTL               = INT_BYPASS_CFG_MASK ^ (1 << FLD_ACTL)

    INT_STATUS                  = $3A
    INT_STATUS_MASK             = $59
        FLD_WOM_INT             = 6
        FLD_FIFO_OVERFLOW_INT   = 4
        FLD_FSYNC_INT           = 3
        FLD_RAW_DATA_RDY_INT    = 0

    ACCEL_XOUT_H                = $3B
    ACCEL_XOUT_L                = $3C
    ACCEL_YOUT_H                = $3D
    ACCEL_YOUT_L                = $3E
    ACCEL_ZOUT_H                = $3F
    ACCEL_ZOUT_L                = $40

    TEMP_OUT_H                  = $41
    TEMP_OUT_L                  = $42

    GYRO_XOUT_H                 = $43
    GYRO_XOUT_L                 = $44
    GYRO_YOUT_H                 = $45
    GYRO_YOUT_L                 = $46
    GYRO_ZOUT_H                 = $47
    GYRO_ZOUT_L                 = $48

    USER_CTRL                   = $6A
    USER_CTRL_MASK              = $77
        FLD_SIG_COND_RST        = 0
        FLD_I2C_MST_RST         = 1
        FLD_FIFO_RST            = 2
        FLD_I2C_IF_DIS          = 4
        FLD_I2C_MST_EN          = 5
        FLD_FIFO_EN             = 6
        MASK_SIG_COND_RST       = USER_CTRL_MASK ^ (1 << FLD_SIG_COND_RST)
        MASK_I2C_MST_RST        = USER_CTRL_MASK ^ (1 << FLD_I2C_MST_RST)
        MASK_FIFO_RST           = USER_CTRL_MASK ^ (1 << FLD_FIFO_RST)
        MASK_I2C_IF_DIS         = USER_CTRL_MASK ^ (1 << FLD_I2C_IF_DIS)
        MASK_I2C_MST_EN         = USER_CTRL_MASK ^ (1 << FLD_I2C_MST_EN)
        MASK_FIFO_EN            = USER_CTRL_MASK ^ (1 << FLD_FIFO_EN)

    WHO_AM_I                    = $75
    WHO_AM_I_RESP               = $71

' Magnetometer registers
    WIA                         = $00
    WIA_RESP                    = $48

    INFO                        = $01
    ST1                         = $02
    ST1_MASK                    = $03
        FLD_DOR                 = 1
        FLD_DRDY                = 0

    HXL                         = $03
    HXH                         = $04
    HYL                         = $05
    HYH                         = $06
    HZL                         = $07
    HZH                         = $08

    ST2                         = $09
    ST2_MASK                    = $18
        FLD_BITM                = 4
        FLD_HOFL                = 3

    CNTL1                       = $0A
    CNTL1_MASK                  = $1F
        FLD_BIT                 = 4
        FLD_MODE                = 0
        BITS_MODE               = %1111
        MASK_BIT                = CNTL1_MASK ^ (1 << FLD_BIT)
        MASK_MODE               = CNTL1_MASK ^ (BITS_MODE << FLD_MODE)

    CNTL2                       = $0B
    CNTL2_MASK                  = $01
        FLD_SRST                = 0

' RESERVED - $0B

    ASTC                        = $0C
    ASTC_MASK                   = $40
        FLD_SELF                = 6

' TEST 1 - $0D
' TEST 2 - $0E

    I2CDIS                      = $0F

    ASAX                        = $10
    ASAY                        = $11
    ASAZ                        = $12

PUB Null
'' This is not a top-level object
