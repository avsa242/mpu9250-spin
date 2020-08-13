{
    --------------------------------------------
    Filename: core.con.mpu9250.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2020
    Started Sep 2, 2019
    Updated Aug 13, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    I2C_MAX_FREQ                = 400_000
    SLAVE_ADDR                  = $68 << 1
    SLAVE_ADDR_MAG              = $0C << 1

    DEVID_RESP                  = $7148

' Startup time
    TREGRW                      = 100               ' ms

' Accelerometer / Gyroscope registers
    SELF_TEST_X_GYRO            = $00
    SELF_TEST_Y_GYRO            = $01
    SELF_TEST_Z_GYRO            = $02
    SELF_TEST_X_ACCEL           = $0D
    SELF_TEST_Y_ACCEL           = $0E
    SELF_TEST_Z_ACCEL           = $0F

    XG_OFFS_USR                 = $13                       '..$14 (LSB)
    YG_OFFS_USR                 = $15                       '..$16 (LSB)
    ZG_OFFS_USR                 = $17                       '..$18 (LSB

    SMPLRT_DIV                  = $19

    CONFIG                      = $1A

    GYRO_CFG                    = $1B
    GYRO_CFG_MASK               = $FB
        FLD_XGYRO_CTEN          = 7
        FLD_YGYRO_CTEN          = 6
        FLD_ZGYRO_CTEN          = 5
        FLD_GYRO_FS_SEL         = 3
        FLD_FCHOICE_B           = 0
        BITS_GYRO_FS_SEL        = %11
        BITS_FCHOICE_B          = %11
        MASK_XGYRO_CTEN         = GYRO_CFG_MASK ^ (1 << FLD_XGYRO_CTEN)
        MASK_YGYRO_CTEN         = GYRO_CFG_MASK ^ (1 << FLD_YGYRO_CTEN)
        MASK_ZGYRO_CTEN         = GYRO_CFG_MASK ^ (1 << FLD_ZGYRO_CTEN)
        MASK_GYRO_FS_SEL        = GYRO_CFG_MASK ^ (BITS_GYRO_FS_SEL << FLD_GYRO_FS_SEL)
        MASK_FCHOICE_B          = GYRO_CFG_MASK ^ (BITS_FCHOICE_B << FLD_FCHOICE_B)

    ACCEL_CFG                   = $1C
    ACCEL_CFG_MASK              = $F8
        FLD_AX_ST_EN            = 7
        FLD_AY_ST_EN            = 6
        FLD_AZ_ST_EN            = 5
        FLD_ACCEL_FS_SEL        = 3
        BITS_ACCEL_FS_SEL       = %11
        MASK_AX_ST_EN           = ACCEL_CFG_MASK ^ (1 << FLD_AX_ST_EN)
        MASK_AY_ST_EN           = ACCEL_CFG_MASK ^ (1 << FLD_AY_ST_EN)
        MASK_AZ_ST_EN           = ACCEL_CFG_MASK ^ (1 << FLD_AZ_ST_EN)
        MASK_ACCEL_FS_SEL       = ACCEL_CFG_MASK ^ (BITS_ACCEL_FS_SEL << FLD_ACCEL_FS_SEL)

    ACCEL_CFG2                  = $1D

    LP_ACCEL_ODR                = $1E

    WOM_THR                     = $1F

    FIFO_EN                     = $23

    I2C_MST_CTRL                = $24
    I2C_SLV0_ADDR               = $25
    I2C_SLV0_REG                = $26
    I2C_SLV0_CTRL               = $27
    I2C_SLV1_ADDR               = $28
    I2C_SLV1_REG                = $29
    I2C_SLV1_CTRL               = $2A
    I2C_SLV2_ADDR               = $2B
    I2C_SLV2_REG                = $2C
    I2C_SLV2_CTRL               = $2D
    I2C_SLV3_ADDR               = $2E
    I2C_SLV3_REG                = $2F
    I2C_SLV3_CTRL               = $30
    I2C_SLV4_ADDR               = $31
    I2C_SLV4_REG                = $32
    I2C_SLV4_DO                 = $33
    I2C_SLV4_CTRL               = $34
    I2C_SLV4_DI                 = $35
    I2C_MST_STATUS              = $36

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

    INT_ENABLE                  = $38
    INT_ENABLE_MASK             = $59
        FLD_WOM_EN              = 6
        FLD_FIFO_OVERFLOW_EN    = 4
        FLD_FSYNC_INT_EN        = 3
        FLD_RAW_RDY_EN          = 0
        MASK_WOM_EN             = INT_ENABLE_MASK ^ (1 << FLD_WOM_EN)
        MASK_FIFO_OVERFLOW_EN   = INT_ENABLE_MASK ^ (1 << FLD_FIFO_OVERFLOW_EN)
        MASK_FSYNC_INT_EN       = INT_ENABLE_MASK ^ (1 << FLD_FSYNC_INT_EN)
        MASK_RAW_RDY_EN         = INT_ENABLE_MASK ^ (1 << FLD_RAW_RDY_EN)

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

    EXT_SENS_DATA_00            = $49
    EXT_SENS_DATA_01            = $4A
    EXT_SENS_DATA_02            = $4B
    EXT_SENS_DATA_03            = $4C
    EXT_SENS_DATA_04            = $4D
    EXT_SENS_DATA_05            = $4E
    EXT_SENS_DATA_06            = $4F
    EXT_SENS_DATA_07            = $50
    EXT_SENS_DATA_08            = $51
    EXT_SENS_DATA_09            = $52
    EXT_SENS_DATA_10            = $53
    EXT_SENS_DATA_11            = $54
    EXT_SENS_DATA_12            = $55
    EXT_SENS_DATA_13            = $56
    EXT_SENS_DATA_14            = $57
    EXT_SENS_DATA_15            = $58
    EXT_SENS_DATA_16            = $59
    EXT_SENS_DATA_17            = $5A
    EXT_SENS_DATA_18            = $5B
    EXT_SENS_DATA_19            = $5C
    EXT_SENS_DATA_20            = $5D
    EXT_SENS_DATA_21            = $5E
    EXT_SENS_DATA_22            = $5F
    EXT_SENS_DATA_23            = $60

    I2C_SLV0_DO                 = $63
    I2C_SLV1_DO                 = $64
    I2C_SLV2_DO                 = $65
    I2C_SLV3_DO                 = $66

    I2C_MST_DELAY_CTRL          = $67

    SIGNAL_PATH_RESET           = $68

    MOT_DETECT_CTRL             = $69

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

    PWR_MGMT_1                  = $6B
    PWR_MGMT_1_MASK             = $FF
        FLD_H_RESET             = 7
        MASK_H_RESET            = PWR_MGMT_1_MASK ^ (1 << FLD_H_RESET)

    PWR_MGMT_2                  = $6C
    PWR_MGMT_2_MASK             = $3F
        FLD_DISABLE_XYZA        = 3
        FLD_DISABLE_XYZG        = 0
        BITS_DISABLE_XYZA       = %111
        BITS_DISABLE_XYZG       = %111
        MASK_DISABLE_XYZA       = PWR_MGMT_2_MASK ^ (BITS_DISABLE_XYZA << FLD_DISABLE_XYZA)
        MASK_DISABLE_XYZG       = PWR_MGMT_2_MASK ^ (BITS_DISABLE_XYZG << FLD_DISABLE_XYZG)
        DISABLE_INVERT          = %111

    FIFO_COUNTH                 = $72
    FIFO_COUNTL                 = $73
    FIFO_R_W                    = $74

    WHO_AM_I                    = $75
        WHO_AM_I_RESP           = $71

    XA_OFFS_H                   = $77                       ' ..$78 (LSB)
    YA_OFFS_H                   = $7A                       ' ..$7B (LSB)
    ZA_OFFS_H                   = $7D                       ' ..$7E (LSB)

' Magnetometer registers
    WIA                         = $00
        WIA_RESP                = $48

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
        MASK_SELF               = ASTC_MASK ^ (1 << FLD_SELF)

' TEST 1 - $0D
' TEST 2 - $0E

    I2CDIS                      = $0F

    ASAX                        = $10
    ASAY                        = $11
    ASAZ                        = $12

PUB Null
'' This is not a top-level object
