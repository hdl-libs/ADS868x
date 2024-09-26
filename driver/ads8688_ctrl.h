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
 * @file ads8688_ctrl.h
 * @brief
 * @author
 */

#ifndef _ADS8688_CTRL_H_
#define _ADS8688_CTRL_H_

/******************************************************************************/
/************************ Include Files ***************************************/
/******************************************************************************/

#include <stdbool.h>
#include <stdint.h>

/******************************************************************************/
/************************ Marco Definitions ***********************************/
/******************************************************************************/
#define FPGA_CLK_FREQ 120E6f

/******************************************************************************/
/************************ Types Definitions ***********************************/
/******************************************************************************/

typedef union ads8688_ctrl_status_t
{
    struct
    {
        uint32_t spi_busy : 1;    // bit 0
        uint32_t spi_done : 1;    // bit 1
        uint32_t : 2;             // bit 2:3
        uint32_t sample_busy : 1; // bit 4
        uint32_t sample_err : 1;  // bit 5
        uint32_t sample_done : 1; // bit 6
        uint32_t : 25;            // bit 7:31
    };
    uint32_t all;
} ads8688_ctrl_status_t;

typedef union ads8688_ctrl_ctrl_t
{
    struct
    {
        uint32_t cfg_spi_start : 1; // bit 0, RW, auto clr
        uint32_t : 3;
        uint32_t sample_req : 1; // bit 4, RW, auto clr
        uint32_t : 4;
        uint32_t adc_refsel : 1;    // bit 9, RW
        uint32_t cfg_auto_mode : 1; // bit 10, RW
        uint32_t baud_load : 1;     // bit 11, RW
        uint32_t : 19;              // bit 12:30
        uint32_t soft_rst : 1;      // bit 31, RW, auto clr
    };
    uint32_t all;
} ads8688_ctrl_ctrl_t;

typedef struct ads8688_ctrl_t
{
    ads8688_ctrl_ctrl_t ctrl;     // 0x00000000U , RW
    ads8688_ctrl_status_t status; // 0x00000004U , RW
    uint32_t addr;                // 0x00000008U , RW
    uint32_t wr_data;             // 0x0000000CU , RW
    uint32_t rd_data;             // 0x00000010U , RO
    uint32_t scan_period;         // 0x00000014U , RW
    uint32_t channel_en;          // 0x00000018U , RO
    uint32_t sample_num;          // 0x0000001CU , RW
    uint32_t sample_cnt;          // 0x00000020U , RO
    uint32_t baud_div;            // 0x00000024U , RW
    uint32_t base_addr;
    uint32_t max_sample_num;
} ads8688_ctrl_t;

/******************************************************************************/
/************************ Functions Declarations ******************************/
/******************************************************************************/

extern int ads8688_start_sample(ads8688_ctrl_t *dev, uint32_t sample_num, uint32_t sample_rate);
extern int ads8688_sample_check(ads8688_ctrl_t *dev);

extern int ads8688_set_spi_div(ads8688_ctrl_t *dev, int div);
extern int ads8688_spi_init(ads8688_ctrl_t **desc, int id);
extern int ads8688_spi_write_read(void *dev, uint8_t *tx_buf, uint8_t *rx_buf, uint32_t len);

/******************************************************************************/
/************************ Variable Declarations *******************************/
/******************************************************************************/

#endif // _ADS8688_CTRL_H_
