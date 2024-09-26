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
// Module Name   : ads8684_scan
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

module ads8684_scan #(
    parameter integer CHANNEL_NUM = 8
) (
    input wire clk,
    input wire rst,

    input  wire       scan_req,
    input  wire [7:0] cfg_ch_enable,
    input  wire       cfg_auto_mode,
    output reg        sts_busy,

    input  wire        tx_busy,
    input  wire        tx_ready,
    output reg         tx_valid,
    output reg  [31:0] tx_data,
    input  wire        rx_valid,
    input  wire [31:0] rx_data,

    output wire [(CHANNEL_NUM*16-1):0] m_tdata,
    output reg                         m_tvalid
);

    localparam FSM_IDLE = 8'd0;
    localparam FSM_CMD = 8'd1;
    localparam FSM_CMD_WAIT = 8'd2;
    localparam FSM_DIN = 8'd3;
    localparam FSM_WAIT = 8'd4;
    localparam FSM_END = 8'd5;

    reg [7:0] cstate = FSM_IDLE;
    reg [7:0] nstate = FSM_IDLE;

    genvar ii;
    reg         auto_scan_en = 1'b0;
    reg  [15:0] rx_data_reg         [0:(CHANNEL_NUM-1)];
    reg  [ 2:0] current_index;
    reg  [ 7:0] current_bin;
    wire [ 2:0] next_index;
    wire [ 7:0] next_bin;
    wire        roll_over;

    reg  [31:0] scan_stack;

    always @(posedge clk) begin
        if (rst) begin
            auto_scan_en <= 1'b0;
        end else begin
            if (cfg_auto_mode) begin
                if (m_tvalid && (scan_stack == 1) && ~scan_req) begin
                    auto_scan_en <= 1'b0;
                end else if (scan_req | (|scan_stack)) begin
                    auto_scan_en <= 1'b1;
                end
            end else begin
                auto_scan_en <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            scan_stack <= 0;
        end else begin
            if (cfg_auto_mode) begin
                if (scan_req) begin
                    if (~(&scan_stack)) begin
                        scan_stack <= scan_stack + 1;
                    end
                end else if (m_tvalid) begin
                    if (|scan_stack) begin
                        scan_stack <= scan_stack - 1;
                    end
                end
            end else begin
                scan_stack <= 0;
            end
        end
    end

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
                    if (auto_scan_en & (|cfg_ch_enable) & ~tx_busy) begin
                        nstate = FSM_CMD;
                    end else begin
                        nstate = FSM_IDLE;
                    end
                end
                FSM_CMD: begin
                    if (tx_valid & tx_ready) begin
                        nstate = FSM_CMD_WAIT;
                    end else begin
                        nstate = FSM_CMD;
                    end
                end
                FSM_CMD_WAIT: begin
                    if (!tx_busy) begin
                        nstate = FSM_DIN;
                    end else begin
                        nstate = FSM_CMD_WAIT;
                    end
                end
                FSM_DIN: begin
                    if (tx_valid & tx_ready) begin
                        nstate = FSM_WAIT;
                    end else begin
                        nstate = FSM_DIN;
                    end
                end
                FSM_WAIT: begin
                    if (!tx_busy) begin
                        if (roll_over) begin
                            if (auto_scan_en & (|cfg_ch_enable)) begin
                                nstate = FSM_DIN;
                            end else begin
                                nstate = FSM_END;
                            end
                        end else begin
                            nstate = FSM_DIN;
                        end
                    end else begin
                        nstate = FSM_WAIT;
                    end
                end
                default: nstate = FSM_IDLE;

            endcase
        end
    end

    // *******************************************************************************
    // provide data for transmitters
    // *******************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            tx_data  <= 0;
            tx_valid <= 1'b0;
        end else begin
            case (nstate)
                FSM_CMD: begin
                    tx_data  <= 32'hA0000000;
                    tx_valid <= 1'b1;
                end
                FSM_DIN: begin
                    tx_data  <= 0;
                    tx_valid <= 1'b1;
                end
                default: begin
                    tx_data  <= 0;
                    tx_valid <= 1'b0;
                end
            endcase
        end
    end

    // *******************************************************************************
    // save received data to corresponding channel
    // *******************************************************************************

    generate
        for (ii = 0; ii < CHANNEL_NUM; ii = ii + 1) begin
            always @(posedge clk) begin
                if (rst) begin
                    rx_data_reg[ii] <= 16'h0000;
                end else begin
                    case (nstate)
                        FSM_WAIT: begin
                            if (rx_valid && current_bin[ii]) begin
                                rx_data_reg[ii] <= rx_data[15:0];
                            end
                        end
                        default: rx_data_reg[ii] <= rx_data_reg[ii];
                    endcase
                end
            end
            assign m_tdata[ii*16+:16] = rx_data_reg[ii];
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            m_tvalid <= 1'b0;
        end else begin
            case (nstate)
                FSM_WAIT: begin
                    m_tvalid <= rx_valid & roll_over;
                end
                default: m_tvalid <= 1'b0;
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

    // *******************************************************************************
    // round check on all enabled channel
    // *******************************************************************************
    round_arb #(
        .SCAN_DIR   (1'b0),
        .CHANNEL_NUM(8),
        .INDEX_WIDTH(3)
    ) round_arb_inst (
        .clk          (clk),
        .rst          (rst),
        .ch_enable    (cfg_ch_enable),
        .current_index(current_index),
        .next_index   (next_index),
        .roll_over    (roll_over),
        .next_bin     (next_bin)
    );

    always @(posedge clk) begin
        if (rst) begin
            current_index <= 7;
            current_bin   <= 8'h80;
        end else begin
            case (cstate)
                FSM_IDLE: begin
                    current_index <= 7;
                    current_bin   <= 8'h80;
                end
                FSM_DIN: begin
                    if (tx_valid & tx_ready) begin
                        current_index <= next_index;
                        current_bin   <= next_bin;
                    end
                end
                default: ;
            endcase
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on
