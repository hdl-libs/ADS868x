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

#include "ads8688_ctrl.h"
#include "ads8688.h"
#include "xparameters.h"
#include <stdlib.h>

extern int reg_read32(uint32_t addr, uint32_t *value);
extern int reg_write32(uint32_t addr, const uint32_t *value);

uint32_t adc_baseaddr[4] = {
    XPAR_AD_H_ADS8684_WRAPPER_0_BASEADDR,
    XPAR_AD_H_ADS8684_WRAPPER_1_BASEADDR,
    XPAR_AD_H_ADS8684_WRAPPER_2_BASEADDR,
    XPAR_AD_H_ADS8684_WRAPPER_3_BASEADDR,
};

/***************************************************************************
 * @brief reset the ads8688 chip
 *
 * @param dev           - The device structure.
 *
 * @return 0 for success or negative error code.
 *******************************************************************************/
int ads8688_soft_rst(ads8688_ctrl_t *dev)
{
    // check if dev is valid
    if (dev == NULL)
        return -1;

    dev->ctrl.all = 0;
    dev->ctrl.soft_rst = 1;
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);

    do
    {
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);

        // !todo: time out check
        // if (timeout)
        //    return -5;

    } while (dev->ctrl.soft_rst);

    return 0;
}

/***************************************************************************
 * @brief set auto sample mode
 *
 * @param dev           - The device structure.
 *
 * @return 0 for success or negative error code.
 *******************************************************************************/
int ads8688_set_automode(ads8688_ctrl_t *dev, bool en)
{
    // check if dev is valid
    if (dev == NULL)
        return -1;

    // read back ctrl reg
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);
    dev->ctrl.cfg_auto_mode = en;
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);

    return 0;
}

/***************************************************************************
 * @brief set sample rate of adc chip
 *
 * @param dev           - The device structure.
 * @param sample_num    - Target sample num.
 * @param sample_rate   - Target sample rate.
 *
 * @return 0 for success or negative error code.
 *******************************************************************************/
int ads8688_start_sample(ads8688_ctrl_t *dev, uint32_t sample_num, uint32_t sample_rate)
{
    // check if dev is valid
    if (dev == NULL)
        return -1;

    // check if sample_num is valid
    if (sample_num <= 0 || sample_num > dev->max_sample_num)
        return -2;

    // check if sample_rete is valid
    if (sample_rate > FPGA_CLK_FREQ || sample_rate < 0)
        return -2;

    // check if any channel is enabled
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, channel_en), &dev->channel_en);
    if (!dev->channel_en)
    {
        return -3;
    }

    // check if sample is busy
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, status), &dev->status.all);
    if (dev->status.sample_busy)
    {
        return -4;
    }

    if ((sample_rate != 0) && (dev->channel_en != 0))
        dev->scan_period = FPGA_CLK_FREQ / sample_rate;
    else
        dev->scan_period = 0;

    ads8688_set_automode(dev, 0);

    // set sample rate
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, scan_period), &dev->scan_period);
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, scan_period), &dev->scan_period);

    // set sample num
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, sample_num), &sample_num);
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, sample_num), &dev->sample_num);

    // enable auto scan
    if (dev->scan_period > 0)
    {
        // mark sample_req bit as 1 then write ctrl reg to start sample
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);
        dev->ctrl.sample_req = 1;
        reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);
        ads8688_set_automode(dev, 1);
    }

    return 0;
}

/**
 * @brief ads8688_sample_check  ADC 采样监测
 * @param **dev                 ADC 句柄
 * @return                      0:成功
 */
int ads8688_sample_check(ads8688_ctrl_t *dev)
{
    if (dev == NULL)
        return -1;

    // wait until spi is done, this step may not be nessary for pc
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, status), &dev->status.all);
    if (dev->status.sample_busy)
    {
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, scan_period), &dev->scan_period);
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, channel_en), &dev->channel_en);
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, sample_cnt), &dev->sample_cnt);
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, sample_num), &dev->sample_num);
        return 1;
    }
    else
    {
        ads8688_set_automode(dev, 0);
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, sample_cnt), &dev->sample_cnt);
        if (dev->status.sample_err || (dev->sample_cnt != 0))
        {
            uint32_t clear = 0xff;
            reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, status), &clear);
            return -2;
        }
    }

    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, sample_num), &dev->sample_num);

    return 0;
}

/***************************************************************************
 * @brief set sample rate of adc chip
 *
 * @param dev           - The device structure.
 * @param sample_rete   - The taget sample rete , points per second,
 *  a value of 0 to disable sample.
 *
 * @return 0 for success or negative error code.
 *******************************************************************************/
int ads8688_set_sample_rate(ads8688_ctrl_t *dev, double sample_rate)
{
    // check if dev is valid
    if (dev == NULL)
        return -1;

    // check if sample_rate is valid
    if (sample_rate > FPGA_CLK_FREQ || sample_rate < 0)
        return -2;

    // check if any channel is enabled
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, channel_en), &dev->channel_en);

    if ((sample_rate != 0) && (dev->channel_en != 0))
        dev->scan_period = FPGA_CLK_FREQ / sample_rate;
    else
        dev->scan_period = 0;

    // disbale auto scan
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);
    dev->ctrl.cfg_auto_mode = 0;
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);

    // set sample rate
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, scan_period), &dev->scan_period);
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, scan_period), &dev->scan_period);

    // enable auto scan
    if (dev->scan_period > 0)
    {
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);
        dev->ctrl.cfg_auto_mode = 1;
        reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);
    }

    return 0;
}

/***************************************************************************
 * @brief Writes data into a register.
 *
 * @param dev      - The device structure.
 * @param spi_addr - The address of the register to be written.
 * @param spi_data  - The value to be written into the register.
 *
 * @return Returns 0 in case of success or negative error code.
 *******************************************************************************/
int ads8688_spi_transfer(ads8688_ctrl_t *dev, uint8_t spi_addr, uint16_t spi_wdata, uint16_t *spi_rdata)
{
    // check if dev is valid
    if (dev == NULL)
        return -1;

    // !todo: check if spi_addr is valid
    // if (...)
    //    return -2;

    // check if spi is busy
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, status), &dev->status.all);
    if (dev->status.spi_busy)
        return -3;

    // set addr
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, addr), (uint32_t *)&spi_addr);

    // set write data
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, wr_data), (uint32_t *)&spi_wdata);

    // set addr
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, addr), (uint32_t *)&dev->addr);

    // set write data
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, wr_data), (uint32_t *)&dev->wr_data);

    // read back ctrl reg
    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);

    // mark spi start bit as 1 then write ctrl reg to start spi
    dev->ctrl.cfg_spi_start = 1;
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);

    // wait until spi is done, this step may not be nessary for pc
    do
    {
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, status), &dev->status.all);

        // !todo: time out check
        // if (timeout)
        //    return -4;

    } while (dev->status.spi_busy);

    if (!dev->status.spi_done)
        return -5;

    // printf("[I]: addr:%2x, wdata:%2x\r\n", spi_addr, spi_wdata);
    // takeout spi read data
    if (spi_rdata)
    {
        reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, rd_data), &dev->rd_data);
        *spi_rdata = (uint16_t)(dev->rd_data);
        // printf("[I]: addr:%2x, rdata:%x\r\n", spi_addr, dev->rd_data);
    }

    return 0;
}

int ads8688_spi_write_read(void *dev, uint8_t *tx_buf, uint8_t *rx_buf, uint32_t len)
{
    // check if dev is valid
    if (dev == NULL)
        return -1;

    uint8_t addr = tx_buf[0];
    uint16_t wdata = tx_buf[1];
    uint16_t rdata = 0;

    ads8688_ctrl_t *dev_int = (ads8688_ctrl_t *)dev;

    if (tx_buf && rx_buf && (len == 3))
    {
        // read data
        if (ads8688_spi_transfer(dev_int, addr, wdata, &rdata))
            return -2;

        rx_buf[0] = addr;
        rx_buf[1] = (uint8_t)(rdata >> 8);
        rx_buf[2] = (uint8_t)rdata;
    }
    else if (tx_buf && !rx_buf && (len == 2))
    {
        // write data
        if (ads8688_spi_transfer(dev_int, addr, wdata, NULL))
            return -3;
    }
    else
    {
        return -4;
    }

    return 0;
}

int ads8688_set_spi_div(ads8688_ctrl_t *dev, int div)
{
    if (dev == NULL)
        return -1;

    // check if div is valid
    if (div > FPGA_CLK_FREQ || div <= 0)
        return -2;

    div = (div < 4) ? 4 : div;

    dev->baud_div = div;
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, baud_div), &dev->baud_div);

    reg_read32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);
    dev->ctrl.baud_load = 1;
    reg_write32(dev->base_addr + offsetof(ads8688_ctrl_t, ctrl), &dev->ctrl.all);

    return 0;
}

int ads8688_spi_init(ads8688_ctrl_t **desc, int id)
{
    if (desc == NULL)
        return -1;

    ads8688_ctrl_t *ads8688_ctrl = (ads8688_ctrl_t *)calloc(1, sizeof(ads8688_ctrl_t));

    ads8688_ctrl->base_addr = adc_baseaddr[id];
    ads8688_ctrl->max_sample_num = 65536;

    // soft reset
    if (ads8688_soft_rst(ads8688_ctrl))
        return -3;

    *desc = ads8688_ctrl;

    return 0;
}
