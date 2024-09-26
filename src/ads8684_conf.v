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
// Module Name   : ads8684_conf
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

module ads8688_conf (
    input wire clk,
    input wire rst,

    input  wire [ 7:0] cfg_addr,       // SPI操作地址
    input  wire [ 7:0] cfg_wr_data,    // SPI写数据
    output reg  [15:0] cfg_rd_data,    // SPI读数据
    input  wire        cfg_start,      // SPI传输开始
    input  wire        cfg_auto_mode,  // ADC 自动扫描
    output reg  [ 7:0] cfg_ch_enable,  // ADC 通道使能
    output reg         sts_busy,       // SPI 传输繁忙
    output reg         sts_done,       // SPI 传输完成
    input  wire        tx_busy,
    input  wire        tx_ready,
    output reg         tx_valid,
    output reg  [31:0] tx_data,
    input  wire        rx_valid,
    input  wire [31:0] rx_data
);
    localparam [7:0] ADDR_CH_EN = (8'h01 << 1) | 8'h01;
    localparam [7:0] ADDR_CH_PD = (8'h02 << 1) | 8'h01;

    localparam FSM_IDLE = 4'd0;
    localparam FSM_INIT = 4'd1;
    localparam FSM_CMD = 4'd2;
    localparam FSM_WAIT = 4'd5;

    reg  [7:0] cstate = FSM_IDLE;
    reg  [7:0] nstate = FSM_IDLE;

    reg  [7:0] cfg_addr_reg = 'd0;
    reg  [7:0] cfg_wr_data_reg = 'd0;
    reg  [7:0] ch_en_reg = 'd0;
    reg  [7:0] ch_pd_reg = 'd0;

    wire       is_read;
    wire       is_cmd;

    assign is_cmd  = cfg_addr_reg[7] | ~(|cfg_addr_reg);
    assign is_read = ~cfg_addr_reg[0] & ~is_cmd;

    // *******************************************************************************
    // fsm body
    // *******************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            cstate <= FSM_IDLE;
        end else begin
            cstate <= nstate;
        end
    end

    always @(*) begin
        if (rst) begin
            nstate = FSM_IDLE;
        end else begin
            case (cstate)
                FSM_IDLE: begin
                    if (~cfg_auto_mode & cfg_start & ~tx_busy & tx_ready) begin
                        nstate = FSM_INIT;
                    end else begin
                        nstate = FSM_IDLE;
                    end
                end
                FSM_INIT: begin
                    nstate = FSM_CMD;
                end
                FSM_CMD: begin
                    if (tx_ready & tx_valid) begin
                        nstate = FSM_WAIT;
                    end else begin
                        nstate = FSM_CMD;
                    end
                end
                FSM_WAIT: begin
                    if (!tx_busy) begin
                        nstate = FSM_IDLE;
                    end else begin
                        nstate = FSM_WAIT;
                    end
                end
                default: begin
                    nstate = FSM_IDLE;
                end
            endcase
        end
    end

    // *******************************************************************************
    // provide data for transmitters
    // *******************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            tx_valid <= 1'b0;
            tx_data  <= 0;
        end else begin
            case (nstate)
                FSM_CMD: begin
                    tx_valid <= 1'b1;
                    tx_data  <= {cfg_addr_reg, cfg_wr_data_reg, 16'h0000};
                end
                default: begin
                    tx_valid <= 1'b0;
                    tx_data  <= 0;
                end
            endcase
        end
    end

    // *******************************************************************************
    // latch the data read from external device
    // clean the data when FSM start
    // *******************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            cfg_rd_data <= 16'h0000;
        end else begin
            case (nstate)
                FSM_INIT: begin
                    cfg_rd_data <= 16'h0000;
                end
                FSM_WAIT: begin
                    if (rx_valid) begin
                        cfg_rd_data <= rx_data[15:0];
                    end else begin
                        cfg_rd_data <= cfg_rd_data;
                    end
                end
                default: cfg_rd_data <= cfg_rd_data;
            endcase
        end
    end

    // *******************************************************************************
    // generate busy state flag for user
    // *******************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            sts_busy <= 1'b1;
        end else begin
            case (nstate)
                FSM_IDLE: sts_busy <= 1'b0;
                default:  sts_busy <= 1'b1;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            sts_done <= 1'b0;
        end else begin
            case (cstate)
                FSM_WAIT: sts_done <= ~tx_busy;
                default:  sts_done <= 1'b0;
            endcase
        end
    end

    // *******************************************************************************
    // latch config data in case user changes these things when in thansfer
    // *******************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            cfg_addr_reg    <= 8'h00;
            cfg_wr_data_reg <= 8'h00;
        end else begin
            case (nstate)
                FSM_INIT: begin
                    cfg_addr_reg    <= cfg_addr;
                    cfg_wr_data_reg <= cfg_wr_data;
                end
                default: ;
            endcase
        end
    end

    // *******************************************************************************
    // record channel enable state
    // *******************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            cfg_ch_enable <= 8'h00;
            ch_en_reg     <= 8'h00;
            ch_pd_reg     <= 8'hFF;
        end else begin
            if (cfg_start) begin
                if (cfg_addr == ADDR_CH_EN) begin
                    ch_en_reg <= cfg_wr_data;
                end
                if (cfg_addr == ADDR_CH_PD) begin
                    ch_pd_reg <= cfg_wr_data;
                end
            end
            cfg_ch_enable <= ch_en_reg & (~ch_pd_reg);
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on