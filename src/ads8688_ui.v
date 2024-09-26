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
// Module Name   : ads8688_ui
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

module ads8688_ui #(
    parameter integer C_APB_ADDR_WIDTH = 16,
    parameter integer C_APB_DATA_WIDTH = 32,
    parameter integer C_S_BASEADDR     = 0
) (
    //
    input  wire                          clk,
    input  wire                          rstn,
    //
    input  wire [(C_APB_ADDR_WIDTH-1):0] s_paddr,
    input  wire                          s_psel,
    input  wire                          s_penable,
    input  wire                          s_pwrite,
    input  wire [(C_APB_DATA_WIDTH-1):0] s_pwdata,
    output wire                          s_pready,
    output wire [(C_APB_DATA_WIDTH-1):0] s_prdata,
    output wire                          s_pslverr,
    //
    output reg                           baud_load,
    output reg  [                  31:0] baud_div,
    //
    output reg                           sample_req,
    output reg  [                  31:0] sample_num,
    input  wire [                  31:0] sample_progress,
    input  wire                          sample_busy,
    input  wire                          sample_err,
    input  wire                          sample_done,
    //
    output reg  [                   7:0] cfg_addr,         // SPI操作地址
    output reg  [                   7:0] cfg_wr_data,      // SPI写数据
    input  wire [                  15:0] cfg_rd_data,      // SPI读数据
    output reg                           cfg_spi_start,    // SPI传输开始
    input  wire                          sts_spi_busy,     // SPI 传输繁忙
    input  wire                          sts_spi_done,     // SPI 传输完成
    //
    output wire                          cfg_auto_mode,    // SPI自动扫描
    input  wire [                   7:0] cfg_ch_enable,    //
    //
    output reg                           sync,             // 同步脉冲
    output reg                           soft_rst,         // 软件复位
    output reg                           adc_rstn,         // adc芯片复位
    output wire                          adc_refsel        // adc芯片参考电压选择
);

    // verilog_format: off
    localparam [7:0] ADDR_CTRL          = C_S_BASEADDR;
    localparam [7:0] ADDR_STATE         = ADDR_CTRL     + 8'h4;
    localparam [7:0] ADDR_ADDR          = ADDR_STATE    + 8'h4;
    localparam [7:0] ADDR_WR_DATA       = ADDR_ADDR     + 8'h4;
    localparam [7:0] ADDR_RD_DATA       = ADDR_WR_DATA  + 8'h4;
    //
    localparam [7:0] ADDR_SCAN_PRRIOD   = ADDR_RD_DATA      + 8'h4;
    localparam [7:0] ADDR_ENABLE_CH     = ADDR_SCAN_PRRIOD  + 8'h4;
    localparam [7:0] ADDR_SAMPLE_NUM    = ADDR_ENABLE_CH    + 8'h4;
    localparam [7:0] ADDR_SAMPLE_CNT    = ADDR_SAMPLE_NUM   + 8'h4;
    localparam [7:0] ADDR_BAUD_DIV      = ADDR_SAMPLE_CNT   + 8'h4;
    // verilog_format: on

    reg        rstn_i = 0;
    reg [ 7:0] rst_cnt;
    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg [31:0] scan_period;
    reg [31:0] scan_cnt;

    //------------------------------------------------------------------------------------

    localparam [31:0] IPIDENTIFICATION = 32'hF7DEC7A5;
    localparam [31:0] REVISION = "V1.0";
    localparam [31:0] BUILDTIME = 32'h20231013;

    reg  [                31:0] test_reg;
    wire                        wr_active;
    wire                        rd_active;

    wire                        user_reg_rreq;
    wire                        user_reg_wreq;
    reg                         user_reg_rack;
    reg                         user_reg_wack;
    wire [C_APB_ADDR_WIDTH-1:0] user_reg_raddr;
    reg  [C_APB_DATA_WIDTH-1:0] user_reg_rdata;
    wire [C_APB_ADDR_WIDTH-1:0] user_reg_waddr;
    wire [C_APB_DATA_WIDTH-1:0] user_reg_wdata;

    assign user_reg_rreq  = ~s_pwrite & s_psel & s_penable;
    assign user_reg_wreq  = s_pwrite & s_psel & s_penable;
    assign s_pready       = user_reg_rack | user_reg_wack;
    assign user_reg_raddr = s_paddr;
    assign user_reg_waddr = s_paddr;
    assign s_prdata       = user_reg_rdata;
    assign user_reg_wdata = s_pwdata;
    assign s_pslverr      = 1'b0;

    assign rd_active      = user_reg_rreq;
    assign wr_active      = user_reg_wreq & user_reg_wack;

    always @(posedge clk) begin
        user_reg_rack <= user_reg_rreq & ~user_reg_rack;
        user_reg_wack <= user_reg_wreq & ~user_reg_wack;
    end

    //------------------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            soft_rst <= 1'b1;
        end else begin
            if (wr_active && (user_reg_waddr == ADDR_CTRL) && user_reg_wdata[31]) begin
                soft_rst <= 1'b1;
            end else begin
                soft_rst <= 1'b0;
            end
        end
    end

    //-------------------------------------------------------------------------------------------------------------------------------------------
    //Read Register
    //-------------------------------------------------------------------------------------------------------------------------------------------
    always @(posedge clk) begin
        if (soft_rst) begin
            user_reg_rdata <= 32'd0;
        end else begin
            user_reg_rdata <= 32'd0;
            if (user_reg_rreq) begin
                case (user_reg_raddr)
                    ADDR_CTRL:        user_reg_rdata <= ctrl_reg;
                    ADDR_STATE:       user_reg_rdata <= status_reg;
                    ADDR_ADDR:        user_reg_rdata <= cfg_addr;
                    ADDR_WR_DATA:     user_reg_rdata <= cfg_wr_data;
                    ADDR_RD_DATA:     user_reg_rdata <= cfg_rd_data;
                    ADDR_ENABLE_CH:   user_reg_rdata <= cfg_ch_enable;
                    ADDR_SCAN_PRRIOD: user_reg_rdata <= scan_period;
                    ADDR_SAMPLE_NUM:  user_reg_rdata <= sample_num;
                    ADDR_SAMPLE_CNT:  user_reg_rdata <= sample_progress;
                    ADDR_BAUD_DIV:    user_reg_rdata <= baud_div;
                    default:          user_reg_rdata <= 32'hdeadbeef;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (soft_rst) begin
            cfg_addr    <= 0;
            cfg_wr_data <= 0;
            scan_period <= 0;
            sample_num  <= 0;
            baud_div    <= 8;
        end else begin
            cfg_addr    <= cfg_addr;
            cfg_wr_data <= cfg_wr_data;
            scan_period <= scan_period;
            sample_num  <= sample_num;
            baud_div    <= baud_div;
            if (wr_active) begin
                case (user_reg_waddr)
                    ADDR_ADDR:        cfg_addr <= user_reg_wdata;
                    ADDR_WR_DATA:     cfg_wr_data <= user_reg_wdata;
                    ADDR_SCAN_PRRIOD: scan_period <= user_reg_wdata;
                    ADDR_SAMPLE_NUM:  sample_num <= user_reg_wdata;
                    ADDR_BAUD_DIV:    baud_div <= user_reg_wdata;
                    default:          ;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (soft_rst) begin
            status_reg <= 0;
        end else begin
            if (wr_active && (user_reg_waddr == ADDR_STATE)) begin
                status_reg <= status_reg & ~user_reg_wdata;
            end else begin
                status_reg[0] <= sts_spi_busy;
                status_reg[1] <= (status_reg[1] | sts_spi_done) & (~cfg_spi_start);

                status_reg[4] <= sample_busy;
                status_reg[5] <= (status_reg[5] | sample_err) & (~sample_req);
                status_reg[6] <= (status_reg[6] | sample_done) & (~sample_req);
            end
        end
    end

    always @(posedge clk) begin
        if (soft_rst) begin
            ctrl_reg <= 0;
        end else begin
            if (wr_active && (user_reg_waddr == ADDR_CTRL)) begin
                ctrl_reg <= user_reg_wdata;
            end else begin
                ctrl_reg <= {cfg_auto_mode, adc_refsel, ~adc_rstn, 3'b000, sample_req, 3'b000, cfg_spi_start};
            end
        end
    end

    // ctrl[0]
    always @(posedge clk) begin
        if (soft_rst) begin
            cfg_spi_start <= 1'b0;
        end else begin
            if (wr_active && (user_reg_waddr == ADDR_CTRL) && user_reg_wdata[0]) begin
                cfg_spi_start <= ~sts_spi_busy;
            end else begin
                cfg_spi_start <= 1'b0;
            end
        end
    end

    // ctrl[4]
    always @(posedge clk) begin
        if (soft_rst) begin
            sample_req <= 1'b0;
        end else begin
            if (wr_active && (user_reg_waddr == ADDR_CTRL) && user_reg_wdata[4]) begin
                sample_req <= ~sts_spi_busy;
            end else begin
                sample_req <= 1'b0;
            end
        end
    end

    // ctrl[8]
    always @(posedge clk) begin
        if (soft_rst) begin
            rst_cnt  <= 8'hFF;
            adc_rstn <= 1'b0;
        end else begin
            if (wr_active && (user_reg_waddr == ADDR_CTRL) && user_reg_wdata[8]) begin
                rst_cnt  <= 8'hFF;
                adc_rstn <= 1'b0;
            end else begin
                if (rst_cnt > 0) begin
                    rst_cnt  <= rst_cnt - 1;
                    adc_rstn <= 1'b0;
                end else begin
                    rst_cnt  <= 0;
                    adc_rstn <= 1;
                end
            end
        end
    end

    assign adc_refsel    = ctrl_reg[9];
    assign cfg_auto_mode = ctrl_reg[10];

    // ctrl[11]
    always @(posedge clk) begin
        if (soft_rst) begin
            baud_load <= 1'b0;
        end else begin
            if (wr_active && (user_reg_waddr == ADDR_CTRL) && user_reg_wdata[11]) begin
                baud_load <= 1'b1;
            end else begin
                baud_load <= 1'b0;
            end
        end
    end


    always @(posedge clk) begin
        if (soft_rst) begin
            scan_cnt <= 0;
            sync     <= 1'b0;
        end else begin
            if (cfg_auto_mode && (scan_period > 0)) begin
                if (scan_cnt < scan_period - 1) begin
                    scan_cnt <= scan_cnt + 1;
                    sync     <= 1'b0;
                end else begin
                    scan_cnt <= 0;
                    sync     <= 1'b1;
                end
            end else begin
                scan_cnt <= 0;
                sync     <= 1'b0;
            end
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on
