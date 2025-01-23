/*
 * https://synthesizer-cookbook.com/SynCookbook.pdf
 */

module synth(
    // 20480000 Hz
    input clk,
    input rstn,
    input trig,
    // Configuration
    input[7:0] adsr_ai, adsr_di, adsr_s, adsr_ri,
    input[11:0] osc_count,
    input[7:0] filter_a, filter_b,
    output data
);

    wire clk_mod, clk_sample, clk_adsr, clk_mult;
    clkdiv clki (
        .clk(clk),
        .rstn(rstn),
        .clk_mod(clk_mod), // 20480000 Hz
        .clk_sample(clk_sample), // 20480000/512=40000Hz
        .clk_adsr(clk_adsr), // 40000/512=78.125Hz
        .clk_mult(clk_mult)
    );


    wire[7:0] envelope;
    adsr adsri (
        .clk(clk_adsr),
        .rstn(rstn),
        .trig(trig),
        .ai(adsr_ai),
        .di(adsr_di),
        .s(adsr_s),
        .ri(adsr_ri),
        .envelope(envelope)
    );


    wire[7:0] osc_data;
    oscillator osci (
        .clk(clk_sample),
        .rstn(rstn),
        .count_max(osc_count),
        .data(osc_data)
    );

    wire[15:0] adsr_data;
    shift_mult8 smul8 (
        .clk(clk),
        .clk_slow(clk_sample),
        .a(osc_data),
        .b(envelope),
        .y(adsr_data)
    );

    // Data needs to be constant for whole cycle when feeding into filter
    reg[15:0] adsr_data_reg;
    always @(posedge clk_sample) begin
        adsr_data_reg <= adsr_data;
    end

    wire[15:0] filt_data;
    filter filt (
        .clk(clk_mult),
        .clk_slow(clk_sample),
        .din(adsr_data_reg),
        .dout(filt_data),
        .a(filter_a),
        .b(filter_b)
    );

    dac daci (
        .clk(clk_mod),
        .rstn(rstn),
        .din(filt_data),
        .dout(data)
    );

endmodule