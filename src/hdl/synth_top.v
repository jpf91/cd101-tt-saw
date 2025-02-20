
module synth_top(
    // 20480000 Hz
    input clk,
    input rstn,
    input trig,
    output data,
    // SPI
    input spi_clk,
    input spi_mosi,
    input spi_nss,
    //
    output dbg_rstn,
    output dbg_trig,
    output dbg_clk_sample,
    output dbg_clk_adsr,
    output dbg_osc0,
    output dbg_env0,
    output dbg_adsr0,
    output dbg_adsr_reg0,
    output dbg_adsr_filt0
);

    wire[7:0] adsr_ai, adsr_di, adsr_s, adsr_ri;
    wire[11:0] osc_count;
    wire[7:0] filter_a, filter_b;
    wire spi_progn, spi_trig;

    // Can come from pin or SPI
    wire merge_trig = trig | spi_trig;
    wire merge_rstn = rstn & spi_progn;

    assign dbg_rstn = merge_rstn;
    assign dbg_trig = merge_trig;

    synth syn (
        .clk(clk),
        .rstn(merge_rstn),
        .trig(merge_trig),
        .adsr_ai(adsr_ai),
        .adsr_di(adsr_di),
        .adsr_s(adsr_s),
        .adsr_ri(adsr_ri),
        .osc_count(osc_count),
        .filter_a(filter_a),
        .filter_b(filter_b),
        .data(data),
        .dbg_clk_sample(dbg_clk_sample),
        .dbg_clk_adsr(dbg_clk_adsr),
        .dbg_osc0(dbg_osc0),
        .dbg_env0(dbg_env0),
        .dbg_adsr0(dbg_adsr0),
        .dbg_adsr_reg0(dbg_adsr_reg0),
        .dbg_adsr_filt0(dbg_adsr_filt0)
    );

    spi ctrl (
        .clk(spi_clk),
        .arstn(rstn),
        .mosi(spi_mosi),
        .nss(spi_nss),

        .adsr_ai(adsr_ai), .adsr_di(adsr_di), .adsr_s(adsr_s), .adsr_ri(adsr_ri),
        .osc_count(osc_count),
        .filter_a(filter_a), .filter_b(filter_b),
        .progn(spi_progn),
        .trig(spi_trig)
    );

endmodule