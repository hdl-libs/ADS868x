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
// Module Name   : round_arb
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

module round_arb #(
    parameter         SCAN_DIR    = 1'b0,
    parameter integer CHANNEL_NUM = 8,
    parameter integer INDEX_WIDTH = 3
) (
    input wire clk,
    input wire rst,

    input  wire [CHANNEL_NUM-1:0] ch_enable,
    input  wire [INDEX_WIDTH-1:0] current_index,
    output reg  [INDEX_WIDTH-1:0] next_index,
    output reg  [CHANNEL_NUM-1:0] next_bin,
    output reg                    roll_over
);

    integer                     cnt;

    reg     [(INDEX_WIDTH-1):0] max_index;
    reg     [(INDEX_WIDTH-1):0] min_index;

    function [INDEX_WIDTH : 0] get_arb(input [INDEX_WIDTH-1:0] current_index, input [CHANNEL_NUM-1:0] arb_req);
        integer ii;
        begin

            get_arb = {1'b0, current_index};

            if (SCAN_DIR) begin
                if (current_index <= min_index) begin
                    get_arb = {1'b1, max_index};
                end else if (current_index > max_index) begin
                    get_arb = {1'b0, max_index};
                end else begin
                    for (ii = 0; ii < current_index; ii = ii + 1) begin
                        if (arb_req[ii]) begin
                            get_arb = {1'b0, ii[2:0]};
                        end
                    end
                end
            end else begin
                if (current_index >= max_index) begin
                    get_arb = {1'b1, min_index};
                end else if (current_index < min_index) begin
                    get_arb = {1'b0, min_index};
                end else begin
                    for (ii = CHANNEL_NUM - 1; ii > current_index; ii = ii - 1) begin
                        if (arb_req[ii]) begin
                            get_arb = {1'b0, ii[2:0]};
                        end
                    end
                end
            end
        end
    endfunction

    function [CHANNEL_NUM-1:0] get_arb_bin(input [INDEX_WIDTH-1:0] current_index, input [CHANNEL_NUM-1:0] arb_req);
        integer ii;
        begin

            get_arb_bin = 0;

            if (SCAN_DIR) begin
                if ((current_index <= min_index) || (current_index > max_index)) begin
                    get_arb_bin = 1 << max_index;
                end else begin
                    for (ii = 0; ii < current_index; ii = ii + 1) begin
                        if (arb_req[ii]) begin
                            get_arb_bin = 1'b1 << (CHANNEL_NUM - 1 - ii);
                        end
                    end
                end
            end else begin
                if ((current_index >= max_index) || (current_index < min_index)) begin
                    get_arb_bin = 1 << min_index;
                end else begin
                    for (ii = CHANNEL_NUM - 1; ii > current_index; ii = ii - 1) begin
                        if (arb_req[ii]) begin
                            get_arb_bin = 1'b1 << ii;
                        end
                    end
                end
            end
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            next_index <= 8'h00;
            next_bin   <= 0;
            roll_over  <= 1'b0;
        end else begin
            if (|ch_enable) begin
                {roll_over, next_index} <= get_arb(current_index, ch_enable);
                next_bin                <= get_arb_bin(current_index, ch_enable);
            end else begin
                next_index <= next_index;
                next_bin   <= 0;
                roll_over  <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            max_index <= CHANNEL_NUM - 1;
            min_index <= 0;
        end else begin
            for (cnt = CHANNEL_NUM; cnt > 0; cnt = cnt - 1) begin
                if (ch_enable[cnt-1]) begin
                    min_index <= cnt - 1;
                end
            end

            for (cnt = 0; cnt < CHANNEL_NUM; cnt = cnt + 1) begin
                if (ch_enable[cnt]) begin
                    max_index <= cnt;
                end
            end
        end
    end
endmodule

// verilog_format: off
`resetall
// verilog_format: on
