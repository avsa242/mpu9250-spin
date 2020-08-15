{
    --------------------------------------------
    Filename: core.con.mpu9250.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2020
    Started Sep 2, 2019
    Updated Aug 15, 2020
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
    SELF_TEST_X_GYRO            = $7100
    SELF_TEST_Y_GYRO            = $7101
    SELF_TEST_Z_GYRO            = $7102
    SELF_TEST_X_ACCEL           = $710D
    SELF_TEST_Y_ACCEL           = $710E
    SELF_TEST_Z_ACCEL           = $710F

    XG_OFFS_USR                 = $7113                       '..$14 (LSB)
    YG_OFFS_USR                 = $7115                       '..$16 (LSB)
    ZG_OFFS_USR                 = $7117                       '..$18 (LSB

    SMPLRT_DIV                  = $7119

    CONFIG                      = $711A

    GYRO_CFG                    = $711B
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

    ACCEL_CFG                   = $711C
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

    ACCEL_CFG2                  = $711D

    LP_ACCEL_ODR                = $711E

    WOM_THR                     = $711F

    FIFO_EN                     = $7123

    I2C_MST_CTRL                = $7124
    I2C_SLV0_ADDR               = $7125
    I2C_SLV0_REG                = $7126
    I2C_SLV0_CTRL               = $7127
    I2C_SLV1_ADDR               = $7128
    I2C_SLV1_REG                = $7129
    I2C_SLV1_CTRL               = $712A
    I2C_SLV2_ADDR               = $712B
    I2C_SLV2_REG                = $712C
    I2C_SLV2_CTRL               = $712D
    I2C_SLV3_ADDR               = $712E
    I2C_SLV3_REG                = $712F
    I2C_SLV3_CTRL               = $7130
    I2C_SLV4_ADDR               = $7131
    I2C_SLV4_REG                = $7132
    I2C_SLV4_DO                 = $7133
    I2C_SLV4_CTRL               = $7134
    I2C_SLV4_DI                 = $7135
    I2C_MST_STATUS              = $7136

    INT_BYPASS_CFG              = $7137
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

    INT_ENABLE                  = $7138
    INT_ENABLE_MASK             = $59
        FLD_WOM_EN              = 6
        FLD_FIFO_OVERFLOW_EN    = 4
        FLD_FSYNC_INT_EN        = 3
        FLD_RAW_RDY_EN          = 0
        MASK_WOM_EN             = INT_ENABLE_MASK ^ (1 << FLD_WOM_EN)
        MASK_FIFO_OVERFLOW_EN   = INT_ENABLE_MASK ^ (1 << FLD_FIFO_OVERFLOW_EN)
        MASK_FSYNC_INT_EN       = INT_ENABLE_MASK ^ (1 << FLD_FSYNC_INT_EN)
        MASK_RAW_RDY_EN         = INT_ENABLE_MASK ^ (1 << FLD_RAW_RDY_EN)

    INT_STATUS                  = $713A
    INT_STATUS_MASK             = $59
        FLD_WOM_INT             = 6
        FLD_FIFO_OVERFLOW_INT   = 4
        FLD_FSYNC_INT           = 3
        FLD_RAW_DATA_RDY_INT    = 0

    ACCEL_XOUT_H                = $713B
    ACCEL_XOUT_L                = $713C
    ACCEL_YOUT_H                = $713D
    ACCEL_YOUT_L                = $713E
    ACCEL_ZOUT_H                = $713F
    ACCEL_ZOUT_L                = $7140

    TEMP_OUT_H                  = $7141
    TEMP_OUT_L                  = $7142

    GYRO_XOUT_H                 = $7143
    GYRO_XOUT_L                 = $7144
    GYRO_YOUT_H                 = $7145
    GYRO_YOUT_L                 = $7146
    GYRO_ZOUT_H                 = $7147
    GYRO_ZOUT_L                 = $7148

    EXT_SENS_DATA_00            = $7149
    EXT_SENS_DATA_01            = $714A
    EXT_SENS_DATA_02            = $714B
    EXT_SENS_DATA_03            = $714C
    EXT_SENS_DATA_04            = $714D
    EXT_SENS_DATA_05            = $714E
    EXT_SENS_DATA_06            = $714F
    EXT_SENS_DATA_07            = $7150
    EXT_SENS_DATA_08            = $7151
    EXT_SENS_DATA_09            = $7152
    EXT_SENS_DATA_10            = $7153
    EXT_SENS_DATA_11            = $7154
    EXT_SENS_DATA_12            = $7155
    EXT_SENS_DATA_13            = $7156
    EXT_SENS_DATA_14            = $7157
    EXT_SENS_DATA_15            = $7158
    EXT_SENS_DATA_16            = $7159
    EXT_SENS_DATA_17            = $715A
    EXT_SENS_DATA_18            = $715B
    EXT_SENS_DATA_19            = $715C
    EXT_SENS_DATA_20            = $715D
    EXT_SENS_DATA_21            = $715E
    EXT_SENS_DATA_22            = $715F
    EXT_SENS_DATA_23            = $7160

    I2C_SLV0_DO                 = $7163
    I2C_SLV1_DO                 = $7164
    I2C_SLV2_DO                 = $7165
    I2C_SLV3_DO                 = $7166

    I2C_MST_DELAY_CTRL          = $7167

    SIGNAL_PATH_RESET           = $7168

    MOT_DETECT_CTRL             = $7169

    USER_CTRL                   = $716A
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

    PWR_MGMT_2                  = $716C
    PWR_MGMT_2_MASK             = $3F
        FLD_DISABLE_XYZA        = 3
        FLD_DISABLE_XYZG        = 0
        BITS_DISABLE_XYZA       = %111
        BITS_DISABLE_XYZG       = %111
        MASK_DISABLE_XYZA       = PWR_MGMT_2_MASK ^ (BITS_DISABLE_XYZA << FLD_DISABLE_XYZA)
        MASK_DISABLE_XYZG       = PWR_MGMT_2_MASK ^ (BITS_DISABLE_XYZG << FLD_DISABLE_XYZG)
        DISABLE_INVERT          = %111

    FIFO_COUNTH                 = $7172
    FIFO_COUNTL                 = $7173
    FIFO_R_W                    = $7174

    WHO_AM_I                    = $7175
        WHO_AM_I_RESP           = $71

    XA_OFFS_H                   = $7177                       ' ..$78 (LSB)
    YA_OFFS_H                   = $717A                       ' ..$7B (LSB)
    ZA_OFFS_H                   = $717D                       ' ..$7E (LSB)

' Magnetometer registers
    WIA                         = $4800
        WIA_RESP                = $48

    INFO                        = $4801

    ST1                         = $4802
    ST1_MASK                    = $03
        FLD_DOR                 = 1
        FLD_DRDY                = 0

    HXL                         = $4803
    HXH                         = $4804
    HYL                         = $4805
    HYH                         = $4806
    HZL                         = $4807
    HZH                         = $4808

    ST2                         = $4809
    ST2_MASK                    = $18
        FLD_BITM                = 4
        FLD_HOFL                = 3

    CNTL1                       = $480A
    CNTL1_MASK                  = $1F
        FLD_BIT                 = 4
        FLD_MODE                = 0
        BITS_MODE               = %1111
        MASK_BIT                = CNTL1_MASK ^ (1 << FLD_BIT)
        MASK_MODE               = CNTL1_MASK ^ (BITS_MODE << FLD_MODE)

    CNTL2                       = $480B
    CNTL2_MASK                  = $01
        FLD_SRST                = 0

' RESERVED - $0B

    ASTC                        = $480C
    ASTC_MASK                   = $40
        FLD_SELF                = 6
        MASK_SELF               = ASTC_MASK ^ (1 << FLD_SELF)

' TEST 1 - $0D
' TEST 2 - $0E

    I2CDIS                      = $480F

    ASAX                        = $4810
    ASAY                        = $4811
    ASAZ                        = $4812

PUB Null
'' This is not a top-level object
