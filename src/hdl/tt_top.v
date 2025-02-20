/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_jp_cd101_saw (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    wire trig, data;
    wire spi_clk, spi_mosi, spi_nss;

    // BTN0 of https://digilent.com/reference/pmod/pmodbtn/start Connect to in Port
    assign trig = ui_in[0];

    // Bidir PMOD, TOP row: https://tinytapeout.com/specs/pinouts/
    // Note that we use this instead for SPI master: https://www.adafruit.com/product/2264
    // It's not PMOD compatible anyway
    assign spi_nss = uio_in[0];
    assign spi_mosi = uio_in[1];
    assign spi_clk = uio_in[3];

    // Compatible with this PMOD: https://github.com/MichaelBell/tt-audio-pmod, Out port
    assign uo_out[7] = data;

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, ui_in[7:1], uio_in[7:4], uio_in[2], 1'b0};

    // All output pins must be assigned. If not used, assign to 0.
    assign uio_out[7:2] = 0;
    assign uio_oe[7:2] = 0;
    assign uio_oe[1:0] = 2'b11;

    synth_top stop (
        .clk(clk),
        .rstn(rst_n),
        .trig(trig),
        .data(data),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_nss(spi_nss),
        .dbg_rstn(uo_out[6]),
        .dbg_trig(uo_out[5]),
        .dbg_clk_sample(uo_out[4]),
        .dbg_clk_adsr(uo_out[3]),
        .dbg_osc0(uo_out[2]),
        .dbg_env0(uo_out[1]),
        .dbg_adsr0(uo_out[0]),
        .dbg_adsr_reg0(uio_out[1]),
        .dbg_adsr_filt0(uio_out[0])
    );

endmodule
