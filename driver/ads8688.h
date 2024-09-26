// ---------------------------------------------------------------------------------------
// Copyright (c) 2024 john_tito All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// ---------------------------------------------------------------------------------------

/**
 * @file ads8688.h
 * @brief
 * @author
 */

#ifndef _ADS8688_H_
#define _ADS8688_H_

/******************************************************************************/
/************************ Include Files ***************************************/
/******************************************************************************/

#include <stdbool.h>
#include <stdint.h>
#include "ads8688_ctrl.h"

/******************************************************************************/
/************************ Marco Definitions ***********************************/
/******************************************************************************/

#define ADS8688_MAX_SPI_FREQ 17E6f
#define ADS8688_MAX_CH_NUM 8

#define ADS8688_REG_WR(addr) ((addr) << 1 | 0x01)
#define ADS8688_REG_RD(addr) ((addr) << 1 & 0xFE)

#define ADS8688_REG_NO_OP 0x00U
#define ADS8688_REG_STDBY 0x82U
#define ADS8688_REG_PWR_DN 0x83U
#define ADS8688_REG_RST 0x85U
#define ADS8688_REG_AUTO_RST 0xA0U
#define ADS8688_REG_MAN_CH(n) ((n) * 0x4U + 0xC0U) // n:0~8, 8:aux

#define ADS8688_REG_CH_EN 0x01U // 1:enable, 0:disable
#define ADS8688_REG_CH_PD 0x02U // 1:power down, 0:power on
#define ADS8688_REG_FEATURE_SELECT 0x03U
#define ADS8688_REG_RANGE_SELECT(n) ((n) + 5U) // n:0~7

/******************************************************************************/
/************************ Types Definitions ***********************************/
/******************************************************************************/

enum ADS8688_MODE
{
    // [24:9], [8:5], [4:3] [2:0]
    ADS8688_MODE_0 = 0, //  DATA, LOW, LOW, LOW
    ADS8688_MODE_1 = 1, //  DATA, Channel_ADDR, Low, Low
    ADS8688_MODE_2 = 2, //  DATA, Channel_ADDR, DEVICE_ADDR, Low
    ADS8688_MODE_3 = 3, //  DATA, Channel_ADDR, DEVICE_ADDR, RANGE
};

enum ADS8688_RANGE
{
    ADS8688_RANGE_2V5 = 0,    // ±2.5 x VREF
    ADS8688_RANGE_1V25 = 1,   // ±1.25 x VREF
    ADS8688_RANGE_0V625 = 2,  // ±0.625 x VREF
    ADS8688_RANGE_0_2V5 = 5,  // 0 to 2.5 x VREF
    ADS8688_RANGE_0_1V25 = 6, // 0 to 1.25 x VREF
};

typedef struct ads8688_config_t
{
    uint8_t channel_en; // 每个 bit 代表一个通道
    uint8_t channel_pd; // 每个 bit 代表一个通道	powerdown
    uint8_t range[8];
} ads8688_config_t;

typedef struct ads8688_dev_t
{
    ads8688_ctrl_t *spi_desc; /* SPI */
    ads8688_config_t config;  /* Device Settings */
    int is_opened;
} ads8688_dev_t;

/******************************************************************************/
/************************ Functions Declarations ******************************/
/******************************************************************************/
extern int ads8688_open(ads8688_dev_t **dev_p, int id, int *channel_en, enum ADS8688_RANGE range);
extern int ads8688_close(ads8688_dev_t **dev_p);

/******************************************************************************/
/************************ Variable Declarations *******************************/
/******************************************************************************/
#endif // _ADS8688_H_
