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

#include "ads8688.h"
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

/**
 * @brief ads8688_write_reg   		ADC 寄存器写入
 * @param *dev                   	ADC 句柄
 * @param addr                   	地址
 * @param data                   	数据源
 * @return                      	0:成功
 */
int ads8688_write_reg(ads8688_dev_t *dev, uint8_t addr, uint8_t data)
{
    if (dev == NULL)
    {
        return -1;
    }

    uint8_t buf[2];
    if (addr & 0x80)
        buf[0] = addr;
    else
        buf[0] = (uint8_t)ADS8688_REG_WR(addr);

    buf[1] = data;
    ads8688_spi_write_read(dev->spi_desc, buf, NULL, 2);
    return 0;
}

/**
 * @brief ads8688_read_reg   		ADC 寄存器读取
 * @param *dev                   	ADC 句柄
 * @param addr                   	地址
 * @param data                   	数据空间
 * @return                      	0:成功
 */
int ads8688_read_reg(ads8688_dev_t *dev, uint8_t addr, uint8_t *data)
{
    if (dev == NULL || data == NULL)
    {
        return -1;
    }

    uint8_t buf[3] = {ADS8688_REG_RD(addr), 0, 0};
    ads8688_spi_write_read(dev->spi_desc, buf, buf, 3);
    *data = buf[1];
    return 0;
}

/**
 * @brief ads8688_reset   		ADC 复位
 * @param dev                   ADC 句柄
 * @return                      0:成功
 */
int ads8688_reset(ads8688_dev_t *dev)
{
    if (dev == NULL)
    {
        return -1;
    }
    return ads8688_write_reg(dev, ADS8688_REG_RST, 0);
}

/**
 * @brief ads8688_set_en   		设置 ADC 通道使能
 * @param dev                   ADC 句柄
 * @param ch                    ADC4 路采样通道（0-3:分别代表 4 路  4:全部 4 路）
 * @param en                    ADC4 路使能状态
 * @return                      0:成功
 */
int ads8688_set_en(ads8688_dev_t *dev, uint8_t ch, uint8_t en)
{
    uint8_t old_state;
    ads8688_read_reg(dev, ADS8688_REG_CH_EN, &old_state);

    old_state = (ch == ADS8688_MAX_CH_NUM) ? en
                                           : ((en) ? (uint8_t)(old_state | 1 << ch)
                                                   : (uint8_t)(old_state & ~(1 << ch)));

    return ads8688_write_reg(dev, ADS8688_REG_CH_EN, old_state);
}

/**
 * @brief ads8688_get_en   		获取 ADC 通道使能
 * @param dev                   ADC 句柄
 * @param ch                    ADC4 路采样通道（0-3:分别代表 4 路  4:全部 4 路）
 * @param en                    ADC4 路使能状态
 * @return                      0:成功
 */
int ads8688_get_en(ads8688_dev_t *dev, uint8_t ch, uint8_t *en)
{
    int ret = ads8688_read_reg(dev, ADS8688_REG_CH_EN, en);
    *en = (ch == ADS8688_MAX_CH_NUM) ? (*en) : ((*en >> ch) & 0x01U);
    return ret;
}

/**
 * @brief ads8688_set_pd   		设置 ADC 通道下电
 * @param dev                   ADC 句柄
 * @param ch                    ADC4 路采样通道（0-3:分别代表 4 路  4:全部 4 路）
 * @param pd                    ADC4 路下电状态
 * @return                      0:成功
 */
int ads8688_set_pd(ads8688_dev_t *dev, uint8_t ch, uint8_t pd)
{
    uint8_t old_state;
    ads8688_read_reg(dev, ADS8688_REG_CH_PD, &old_state);

    old_state = (ch == ADS8688_MAX_CH_NUM) ? pd
                                           : ((pd) ? (uint8_t)(old_state | 1 << ch)
                                                   : (uint8_t)(old_state & ~(1 << ch)));

    return ads8688_write_reg(dev, ADS8688_REG_CH_PD, old_state);
}

/**
 * @brief ads8688_get_pd   		获取 ADC 通道下电
 * @param *dev                  ADC 句柄
 * @param ch                    ADC4 路采样通道（0-3:分别代表 4 路  4:全部 4 路）
 * @param *pd                   ADC4 路下电状态
 * @return                      0:成功
 */
int ads8688_get_pd(ads8688_dev_t *dev, uint8_t ch, uint8_t *pd)
{
    int ret = ads8688_read_reg(dev, ADS8688_REG_CH_PD, pd);
    *pd = (ch == ADS8688_MAX_CH_NUM) ? (*pd) : ((*pd >> ch) & 0x01U);
    return ret;
}

/**
 * @brief ads8688_set_range   	设置 ADC 通道电压范围
 * @param dev                   ADC 句柄
 * @param ch                    ADC4 路采样通道（0-3:分别代表 4 路）
 * @param range                 ADC4 路范围
 * @return                      0:成功
 */
int ads8688_set_range(ads8688_dev_t *dev, uint8_t ch, uint8_t range)
{
    if (dev == NULL || ch > ADS8688_MAX_CH_NUM)
    {
        return -1;
    }
    return ads8688_write_reg(dev, ADS8688_REG_RANGE_SELECT(ch), range);
}

/**
 * @brief ads8688_get_range   	获取 ADC 通道电压范围
 * @param dev                   ADC 句柄
 * @param ch                    ADC4 路采样通道（0-3:分别代表 4 路）
 * @param range                 ADC4 路范围
 * @return                      0:成功
 */
int ads8688_get_range(ads8688_dev_t *dev, uint8_t ch, uint8_t *range)
{
    if (dev == NULL || ch > ADS8688_MAX_CH_NUM - 1)
    {
        return -1;
    }
    return ads8688_read_reg(dev, ADS8688_REG_RANGE_SELECT(ch), range);
}

int ads8688_set_mode(ads8688_dev_t *dev, enum ADS8688_MODE mode)
{
    if (dev == NULL)
    {
        return -1;
    }
    uint8_t tmp = ((uint8_t)mode & 0x07) | (uint8_t)0B00101000;
    ads8688_write_reg(dev, ADS8688_REG_FEATURE_SELECT, tmp);
    return ads8688_read_reg(dev, ADS8688_REG_FEATURE_SELECT, &tmp);
}

/**
 * @brief ads8688_open   		ADC 打开
 * @param **dev_p               ADC 句柄
 * @param id                    ADC 序号
 * @param channel_en            ADC4 路采样通道使能
 * @return                      0:成功
 */
int ads8688_open(ads8688_dev_t **dev_p, int id, int *channel_en, enum ADS8688_RANGE range)
{
    if (dev_p == NULL || channel_en == NULL)
        return -1;

    ads8688_dev_t *ads_handel = (ads8688_dev_t *)calloc(1, sizeof(ads8688_dev_t));

    /* Initializes the SPI peripheral */
    int ret = ads8688_spi_init(&ads_handel->spi_desc, id);
    if (ret)
        return ret;

    ads8688_set_spi_div(ads_handel->spi_desc, (int)(FPGA_CLK_FREQ / ADS8688_MAX_SPI_FREQ));

    ret = ads8688_reset(ads_handel); // ads 复位
    if (ret)
        return ret;

    ads8688_set_mode(ads_handel, ADS8688_MODE_0);

    for (size_t i = 0; i < ADS8688_MAX_CH_NUM; i++)
    {
        ads8688_set_range(ads_handel, (uint8_t)i, (uint8_t)range);
        ads8688_get_range(ads_handel, (uint8_t)i, &ads_handel->config.range[i]);
    }

    uint8_t ch_en = (uint8_t)(channel_en[0] + (channel_en[1] << 1) + (channel_en[2] << 2) + (channel_en[3] << 3));

    ads8688_set_en(ads_handel, ADS8688_MAX_CH_NUM, ch_en);
    ads8688_get_en(ads_handel, ADS8688_MAX_CH_NUM, &ads_handel->config.channel_en);
    ads8688_set_pd(ads_handel, ADS8688_MAX_CH_NUM, ~ch_en);
    ads8688_get_pd(ads_handel, ADS8688_MAX_CH_NUM, &ads_handel->config.channel_pd);

    ads_handel->is_opened = 1;

    *dev_p = ads_handel;

    return 0;
}

/**
 * @brief ads8688_close   		ADC 关闭
 * @param **dev_p               ADC 句柄
 * @return                      0:成功
 */
int ads8688_close(ads8688_dev_t **dev_p)
{
    if ((dev_p == NULL) || (*dev_p == NULL))
    {
        return -1;
    }

    if ((*dev_p)->is_opened)
    {
        (*dev_p)->config.channel_en = 0;
        (*dev_p)->config.channel_pd = 0xff;

        ads8688_set_en(*dev_p, ADS8688_MAX_CH_NUM, (*dev_p)->config.channel_en);
        ads8688_set_pd(*dev_p, ADS8688_MAX_CH_NUM, (*dev_p)->config.channel_pd);
    }

    free(*dev_p);
    *dev_p = NULL;

    return 0;
}
