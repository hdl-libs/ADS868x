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
// Module Name   : ads8684_wrapper
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

module ads8684_wrapper #(
    parameter integer C_APB_DATA_WIDTH = 32,
    parameter integer C_APB_ADDR_WIDTH = 16,
    parameter integer C_S_BASEADDR     = 0,
    parameter integer CHANNEL_NUM      = 4
) (
    //
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_apb:m:spi, ASSOCIATED_RESET rstn" *)
    input  wire                          clk,        //  (required)
    //
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rstn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                          rstn,       //  (required)
    //
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PADDR" *)
    input  wire [(C_APB_ADDR_WIDTH-1):0] s_paddr,    // Address (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PSEL" *)
    input  wire                          s_psel,     // Slave Select (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PENABLE" *)
    input  wire                          s_penable,  // Enable (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PWRITE" *)
    input  wire                          s_pwrite,   // Write Control (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PWDATA" *)
    input  wire [(C_APB_DATA_WIDTH-1):0] s_pwdata,   // Write Data (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PREADY" *)
    output wire                          s_pready,   // Slave Ready (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PRDATA" *)
    output wire [(C_APB_DATA_WIDTH-1):0] s_prdata,   // Read Data (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PSLVERR" *)
    output wire                          s_pslverr,  // Slave Error Response (required)

    output wire spi_scsn,  // SPI片选
    output wire spi_sclk,  // SPI时钟
    output wire spi_mosi,  // SPI串行输出
    input  wire spi_miso,  // SPI串行输入

    output wire adc_rstn,   // adc芯片复位
    output wire adc_refsel, // adc芯片参考电压选择

    output wire [63:0] m_tdata,
    output wire [ 7:0] m_tkeep,
    output wire        m_tvalid,
    output wire        m_tlast,
    input  wire        m_tready
);


    wire                        baud_load;
    wire [                31:0] baud_div;

    wire [                 7:0] conf_spi_addr;
    wire [                 7:0] conf_spi_wr_data;
    wire [                15:0] conf_spi_rd_data;
    wire                        conf_spi_start;
    wire                        conf_spi_busy;
    wire                        conf_spi_done;

    wire                        conf_spi_scsn;
    wire                        conf_spi_sclk;
    wire                        conf_spi_mosi;
    wire                        conf_spi_miso;

    wire                        scan_spi_busy;
    wire                        scan_req;

    wire                        scan_spi_scsn;
    wire                        scan_spi_sclk;
    wire                        scan_spi_mosi;
    wire                        scan_spi_miso;

    wire                        soft_rst;
    wire                        sts_spi_busy;
    wire [                 7:0] cfg_ch_enable;
    wire                        cfg_auto_mode;

    wire [(CHANNEL_NUM*16-1):0] adc_tdata;
    wire                        adc_tvalid;

    wire                        sample_req;
    wire [                31:0] sample_num;
    wire [                31:0] sample_progress;
    wire                        sample_busy;
    wire                        sample_err;
    wire                        sample_done;

    assign spi_scsn      = (cfg_auto_mode == 1'b0) ? conf_spi_scsn : scan_spi_scsn;
    assign spi_sclk      = (cfg_auto_mode == 1'b0) ? conf_spi_sclk : scan_spi_sclk;
    assign spi_mosi      = (cfg_auto_mode == 1'b0) ? conf_spi_mosi : scan_spi_mosi;

    assign conf_spi_miso = spi_miso;
    assign scan_spi_miso = spi_miso;

    assign sts_spi_busy  = conf_spi_busy | scan_spi_busy;

    ads8688_ui #(
        .C_APB_DATA_WIDTH(C_APB_DATA_WIDTH),
        .C_APB_ADDR_WIDTH(C_APB_ADDR_WIDTH),
        .C_S_BASEADDR    (C_S_BASEADDR)
    ) ads8688_ui_inst (
        .clk            (clk),
        .rstn           (rstn),
        .s_paddr        (s_paddr),
        .s_psel         (s_psel),
        .s_penable      (s_penable),
        .s_pwrite       (s_pwrite),
        .s_pwdata       (s_pwdata),
        .s_pready       (s_pready),
        .s_prdata       (s_prdata),
        .s_pslverr      (s_pslverr),
        .baud_load      (baud_load),
        .baud_div       (baud_div),
        .sample_req     (sample_req),
        .sample_num     (sample_num),
        .sample_progress(sample_progress),
        .sample_busy    (sample_busy),
        .sample_err     (sample_err),
        .sample_done    (sample_done),
        .cfg_addr       (conf_spi_addr),
        .cfg_wr_data    (conf_spi_wr_data),
        .cfg_rd_data    (conf_spi_rd_data),
        .cfg_spi_start  (conf_spi_start),
        .sts_spi_done   (conf_spi_done),
        .sts_spi_busy   (sts_spi_busy),
        .cfg_auto_mode  (cfg_auto_mode),
        .cfg_ch_enable  (cfg_ch_enable),
        .sync           (scan_req),
        .soft_rst       (soft_rst),
        .adc_refsel     (adc_refsel),
        .adc_rstn       (adc_rstn)
    );

    ads8684_conf_wrapper ads8684_conf_wrapper_inst (
        .clk          (clk),
        .rst          (soft_rst),
        .baud_load    (baud_load),
        .baud_div     (baud_div),
        .cfg_auto_mode(cfg_auto_mode),
        .cfg_ch_enable(cfg_ch_enable),
        .cfg_addr     (conf_spi_addr),
        .cfg_wr_data  (conf_spi_wr_data),
        .cfg_rd_data  (conf_spi_rd_data),
        .cfg_spi_start(conf_spi_start),
        .sts_spi_busy (conf_spi_busy),
        .sts_spi_done (conf_spi_done),
        .spi_scsn     (conf_spi_scsn),
        .spi_sclk     (conf_spi_sclk),
        .spi_mosi     (conf_spi_mosi),
        .spi_miso     (conf_spi_miso)
    );

    ads8684_scan_wrapper #(
        .CHANNEL_NUM(CHANNEL_NUM)
    ) ads8684_scan_wrapper_inst (
        .clk          (clk),
        .rst          (soft_rst),
        .baud_load    (baud_load),
        .baud_div     (baud_div),
        .cfg_auto_mode(cfg_auto_mode),
        .cfg_ch_enable(cfg_ch_enable),
        .sts_spi_busy (scan_spi_busy),
        .sync         (scan_req),
        .spi_scsn     (scan_spi_scsn),
        .spi_sclk     (scan_spi_sclk),
        .spi_mosi     (scan_spi_mosi),
        .spi_miso     (scan_spi_miso),
        .m_tdata      (adc_tdata),
        .m_tvalid     (adc_tvalid)
    );

    sample_core #(
        .TDATA_NUM_BYTES(CHANNEL_NUM * 2)
    ) sample_core_inst (
        .clk            (clk),
        .rst            (soft_rst),
        .sample_req     (sample_req),
        .sample_num     (sample_num),
        .sample_progress(sample_progress),
        .sample_busy    (sample_busy),
        .sample_err     (sample_err),
        .sample_done    (sample_done),
        .s_tdata        (adc_tdata),
        .s_tvalid       (adc_tvalid),
        .m_tdata        (m_tdata),
        .m_tkeep        (m_tkeep),
        .m_tvalid       (m_tvalid),
        .m_tlast        (m_tlast),
        .m_tready       (m_tready)
    );

endmodule

// verilog_format: off
`resetall
// verilog_format: on
