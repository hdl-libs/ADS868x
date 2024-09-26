// +FHEADER-------------------------------------------------------------------------------
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
// Author        : john_tito
// Module Name   : ads8684_scan_wrapper
// ---------------------------------------------------------------------------------------
// Revision      : 1.0
// Description   : File Created
// ---------------------------------------------------------------------------------------
// Synthesizable : Yes
// Clock Domains : clk
// Reset Strategy: sync reset
// -FHEADER-------------------------------------------------------------------------------

// verilog_format: off
`resetall
`timescale 1ns / 1ps
`default_nettype none
// verilog_format: on

module ads8684_scan_wrapper #(
    parameter integer CHANNEL_NUM = 8
) (
    input wire clk,
    input wire rst,

    input wire        baud_load,
    input wire [31:0] baud_div,

    input wire [7:0] cfg_ch_enable,  // SPI 传输繁忙
    input wire       cfg_auto_mode,  // 自动采样使能


    output wire sts_spi_busy,  // SPI 传输繁忙
    input  wire sync,          // 同步脉冲

    output wire spi_scsn,  // SPI片选
    output wire spi_sclk,  // SPI时钟
    output wire spi_mosi,  // SPI串行输出
    input  wire spi_miso,  // SPI串行输入

    output wire [CHANNEL_NUM*16-1:0] m_tdata,  // adc数据
    output wire                      m_tvalid  // adc数据有效
);

    wire        tx_busy;
    wire        tx_ready;
    wire        tx_valid;
    wire [31:0] tx_data;
    wire        rx_valid;
    wire [31:0] rx_data;

    ads8684_scan #(
        .CHANNEL_NUM(CHANNEL_NUM)
    ) ads8684_scan_inst (
        .clk          (clk),
        .rst         (rst),
        .cfg_ch_enable(cfg_ch_enable),
        .cfg_auto_mode(cfg_auto_mode),
        .sts_busy     (sts_spi_busy),
        .scan_req     (sync),
        .tx_busy      (tx_busy),
        .tx_ready     (tx_ready),
        .tx_valid     (tx_valid),
        .tx_data      (tx_data),
        .rx_valid     (rx_valid),
        .rx_data      (rx_data),
        .m_tdata      (m_tdata),
        .m_tvalid     (m_tvalid)
    );

    spi_master #(
        .DATA_WIDTH(32),
        .CPHA      (1'b1),
        .MSB       (1'b1)
    ) spi_master_inst (
        .clk     (clk),
        .rst    (rst),
        .load    (baud_load),
        .baud_div(baud_div),
        .spi_scsn(spi_scsn),
        .spi_sclk(spi_sclk),
        .spi_miso(spi_miso),
        .spi_mosi(spi_mosi),
        .tx_busy (tx_busy),
        .tx_ready(tx_ready),
        .tx_valid(tx_valid),
        .tx_data (tx_data),
        .rx_valid(rx_valid),
        .rx_data (rx_data),
        .tx_done ()
    );
endmodule

// verilog_format: off
`resetall
// verilog_format: on