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
// Module Name   : sample_core
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

module sample_core #(
    parameter integer TDATA_NUM_BYTES = 16
) (
    input wire clk,
    input wire rst,

    input  wire        sample_req,
    input  wire [31:0] sample_num,
    output wire [31:0] sample_progress,
    output reg         sample_busy,
    output reg         sample_err,
    output reg         sample_done,

    input wire [(TDATA_NUM_BYTES*8-1):0] s_tdata,
    input wire                           s_tvalid,

    output reg  [(TDATA_NUM_BYTES*8-1):0] m_tdata,
    output reg  [(  TDATA_NUM_BYTES-1):0] m_tkeep,
    output reg                            m_tvalid,
    output reg                            m_tlast,
    input  wire                           m_tready
);

    reg [31:0] sample_cnt;
    always @(posedge clk) begin
        if (rst) begin
            sample_cnt <= 0;
        end else begin
            if (sample_cnt > 0) begin
                if (m_tvalid & m_tready) begin
                    sample_cnt <= sample_cnt - 1;
                end
            end else if (sample_cnt == 0 && sample_req) begin
                sample_cnt <= sample_num;
            end
        end
    end

    assign sample_progress = sample_cnt;
    always @(posedge clk) begin
        if (rst) begin
            sample_busy <= 1;
            sample_err  <= 0;
            sample_done <= 0;
        end else begin
            sample_busy <= (sample_cnt > 0);
            sample_err  <= (~sample_req) & (m_tvalid & ~m_tready);
            sample_done <= (~sample_req) & ((sample_cnt == 1) && (m_tvalid & m_tready));
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            m_tvalid <= 0;
            m_tlast  <= 0;
            m_tdata  <= 0;
            m_tkeep  <= 0;
        end else begin
            if (s_tvalid) begin
                m_tvalid <= s_tvalid & (sample_cnt > 0);
                m_tlast  <= (sample_cnt == 1);
                m_tdata  <= s_tdata;
                m_tkeep  <= {TDATA_NUM_BYTES{1'b1}};
            end else if (m_tready) begin
                m_tvalid <= s_tvalid & (sample_cnt > 1);
                m_tlast  <= (sample_cnt == 1);
                m_tdata  <= 0;
                m_tkeep  <= 0;
            end
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on
