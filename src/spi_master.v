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
// Module Name   : spi_master
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

module spi_master #(
    parameter integer DEFAULT_BAUD_DIV = 8,
    parameter integer DATA_WIDTH       = 8,
    parameter         CPOL             = 1'b0,
    parameter         CPHA             = 1'b0,
    parameter integer BIT_WIDTH        = 1,
    parameter         MSB              = 1'b0
) (
    input wire clk,
    input wire rst,

    input wire        load,
    input wire [31:0] baud_div,

    output reg                    spi_scsn = 1,
    output reg                    spi_sclk = CPOL,
    input  wire [(BIT_WIDTH-1):0] spi_miso,
    output reg  [(BIT_WIDTH-1):0] spi_mosi = 0,
    input  wire                   tx_valid,
    input  wire [ DATA_WIDTH-1:0] tx_data,
    output reg                    tx_ready = 0,
    output reg  [ DATA_WIDTH-1:0] rx_data = 0,
    output reg                    rx_valid = 0,
    output reg                    tx_busy = 1,
    output reg                    tx_done = 0
);

    localparam [3:0] FSM_IDLE = 4'b0000;
    localparam [3:0] FSM_PRE = FSM_IDLE + 1;
    localparam [3:0] FSM_FSB0 = FSM_PRE + 1;
    localparam [3:0] FSM_FSB1 = FSM_FSB0 + 1;
    localparam [3:0] FSM_DATA0 = FSM_FSB1 + 1;
    localparam [3:0] FSM_DATA1 = FSM_DATA0 + 1;
    localparam [3:0] FSM_LSB0 = FSM_DATA1 + 1;
    localparam [3:0] FSM_LSB1 = FSM_LSB0 + 1;

    reg  [             3:0] c_state;
    reg  [             3:0] n_state;

    reg                     shift_en_0;
    reg                     shift_en_1;
    reg  [DATA_WIDTH-1 : 0] spi_tx_buff;
    reg  [DATA_WIDTH-1 : 0] spi_rx_buff;

    reg  [             7:0] data_bit_cnt;

    wire                    new_valid;
    reg  [(DATA_WIDTH-1):0] tx_data_latch;

    reg  [            31:0] baud_div_reg  [0:1];
    reg  [            31:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            c_state <= FSM_IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    always @(*) begin
        if (rst) begin
            n_state = FSM_IDLE;
        end else begin
            case (c_state)
                FSM_IDLE: begin
                    if (tx_valid) begin
                        n_state = FSM_PRE;
                    end else begin
                        n_state = FSM_IDLE;
                    end
                end
                FSM_PRE: begin
                    if (shift_en_0) begin
                        n_state = FSM_FSB0;
                    end else begin
                        n_state = FSM_PRE;
                    end
                end
                FSM_FSB0: begin
                    if (shift_en_1) begin
                        n_state = FSM_FSB1;
                    end else begin
                        n_state = FSM_FSB0;
                    end
                end
                FSM_FSB1: begin
                    if (shift_en_0) begin
                        n_state = FSM_DATA0;
                    end else begin
                        n_state = FSM_FSB1;
                    end
                end
                FSM_DATA0: begin
                    if (shift_en_1) begin
                        n_state = FSM_DATA1;
                    end else begin
                        n_state = FSM_DATA0;
                    end
                end
                FSM_DATA1: begin
                    if (shift_en_0) begin
                        if (data_bit_cnt >= DATA_WIDTH - BIT_WIDTH) begin
                            n_state = FSM_LSB0;
                        end else begin
                            n_state = FSM_DATA0;
                        end
                    end else begin
                        n_state = FSM_DATA1;
                    end
                end
                FSM_LSB0: begin
                    if (shift_en_1) begin
                        n_state = FSM_LSB1;
                    end else begin
                        n_state = FSM_LSB0;
                    end
                end
                FSM_LSB1: begin
                    if (shift_en_0) begin
                        n_state = FSM_IDLE;
                    end else begin
                        n_state = FSM_LSB1;
                    end
                end
                default: n_state = FSM_IDLE;
            endcase
        end
    end

    // *******************************************************************************
    // tx data latch
    // *******************************************************************************
    // require new data at the time when all bits are shifted out
    // or when in idle state
    assign new_valid = tx_valid & tx_ready;

    always @(posedge clk) begin
        if (rst) begin
            tx_ready <= 1'b0;
        end else begin
            case (n_state)
                FSM_IDLE: tx_ready <= 1'b1;
                default:  tx_ready <= 1'b0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            tx_data_latch <= 0;
        end else begin
            if (new_valid) begin
                tx_data_latch <= tx_data;
            end else begin
                tx_data_latch <= tx_data_latch;
            end
        end
    end

    // data count
    always @(posedge clk) begin
        if (rst) begin
            data_bit_cnt <= 0;
        end else begin
            case (n_state)
                FSM_FSB0, FSM_FSB1, FSM_DATA0, FSM_DATA1, FSM_LSB0, FSM_LSB1: begin
                    if (shift_en_0) begin
                        if (data_bit_cnt >= DATA_WIDTH) begin
                            data_bit_cnt <= BIT_WIDTH;
                        end else begin
                            data_bit_cnt <= data_bit_cnt + BIT_WIDTH;
                        end
                    end else begin
                        data_bit_cnt <= data_bit_cnt;
                    end
                end
                default: begin
                    data_bit_cnt <= 0;
                end
            endcase
        end
    end

    // *******************************************************************************
    // spi timing generator
    // *******************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            spi_scsn <= 1'b1;
        end else begin
            case (n_state)
                FSM_FSB0, FSM_FSB1, FSM_DATA0, FSM_DATA1, FSM_LSB0, FSM_LSB1: begin
                    spi_scsn <= 1'b0;
                end
                default: begin
                    spi_scsn <= 1'b1;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            spi_sclk <= CPOL;
        end else begin
            case (n_state)
                FSM_FSB0, FSM_FSB1, FSM_DATA0, FSM_DATA1, FSM_LSB0, FSM_LSB1: begin
                    if (shift_en_0) spi_sclk <= (CPHA ^ CPOL);
                    else if (shift_en_1) spi_sclk <= ~(CPHA ^ CPOL);
                    else spi_sclk <= spi_sclk;
                end
                default: begin
                    spi_sclk <= CPOL;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            spi_mosi    <= 0;
            spi_tx_buff <= 0;
        end else begin
            case (n_state)
                FSM_PRE: begin
                    spi_mosi    <= 0;
                    spi_tx_buff <= tx_data_latch;
                end
                FSM_FSB0, FSM_LSB0, FSM_DATA0: begin
                    if (MSB) begin
                        if (shift_en_0) begin
                            spi_mosi    <= spi_tx_buff[(DATA_WIDTH-1)-:BIT_WIDTH];
                            spi_tx_buff <= spi_tx_buff << BIT_WIDTH;
                        end
                    end else begin
                        if (shift_en_0) begin
                            spi_mosi    <= spi_tx_buff[0+:BIT_WIDTH];
                            spi_tx_buff <= spi_tx_buff >> BIT_WIDTH;
                        end
                    end
                end
                FSM_FSB1, FSM_DATA1, FSM_LSB1: begin
                    spi_mosi    <= spi_mosi;
                    spi_tx_buff <= spi_tx_buff;
                end
                default: begin
                    spi_mosi    <= 0;
                    spi_tx_buff <= 0;
                end
            endcase
        end
    end

    // clear data when lsat bit shift in
    always @(posedge clk) begin
        if (rst) begin
            spi_rx_buff <= 0;
        end else begin
            case (n_state)
                FSM_PRE: begin
                    spi_rx_buff <= 0;
                end
                FSM_FSB0, FSM_DATA0, FSM_LSB0: begin
                    spi_rx_buff <= spi_rx_buff;
                end
                FSM_FSB1, FSM_DATA1, FSM_LSB1: begin
                    if (shift_en_1) begin
                        if (MSB) begin
                            spi_rx_buff <= (spi_rx_buff << BIT_WIDTH) | spi_miso;
                        end else begin
                            spi_rx_buff <= {spi_miso, spi_rx_buff[(DATA_WIDTH-1):BIT_WIDTH]};
                        end
                    end
                end
                default: begin
                    spi_rx_buff <= 0;
                end
            endcase
        end
    end

    // latch data and report when the last bit is shift in
    always @(posedge clk) begin
        if (rst) begin
            rx_data  <= 0;
            rx_valid <= 1'b0;
        end else begin
            case (n_state)
                FSM_LSB1: begin
                    if (shift_en_1) begin
                        if (MSB) begin
                            rx_data <= (spi_rx_buff << BIT_WIDTH) | spi_miso;
                        end else begin
                            rx_data <= {spi_miso, spi_rx_buff[(DATA_WIDTH-1):BIT_WIDTH]};
                        end
                    end
                    rx_valid <= shift_en_1;
                end
                default: begin
                    rx_data  <= 0;
                    rx_valid <= 1'b0;
                end
            endcase
        end
    end

    // *******************************************************************************
    // status generator
    // *******************************************************************************

    always @(posedge clk) begin
        if (rst) begin
            tx_busy <= 1'b1;
        end else begin
            case (n_state)
                FSM_IDLE: tx_busy <= 1'b0;
                default:  tx_busy <= 1'b1;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            tx_done <= 1'b0;
        end else begin
            case (n_state)
                FSM_LSB0: tx_done <= shift_en_0;
                default:  tx_done <= 1'b0;
            endcase
        end
    end

    // *******************************************************************************
    // clock generator
    // *******************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            baud_div_reg[0] <= DEFAULT_BAUD_DIV;
            baud_div_reg[1] <= DEFAULT_BAUD_DIV / 2;
        end else if (load) begin
            if (baud_div > 1) begin
                baud_div_reg[0] <= baud_div;
                baud_div_reg[1] <= baud_div[31:1];
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            counter    <= 16'b0;
            shift_en_0 <= 1'b0;
            shift_en_1 <= 1'b0;
        end else begin
            case (n_state)
                FSM_PRE, FSM_FSB0, FSM_FSB1, FSM_DATA0, FSM_DATA1, FSM_LSB0, FSM_LSB1: begin
                    if (counter >= baud_div_reg[0]) begin
                        counter <= 1;
                    end else begin
                        counter <= counter + 1;
                    end
                    shift_en_0 <= (counter == baud_div_reg[1]);
                    shift_en_1 <= (counter == baud_div_reg[0]);
                end
                default: begin
                    counter    <= 16'b0;
                    shift_en_0 <= 1'b0;
                    shift_en_1 <= 1'b0;
                end
            endcase
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on
