/*
 * Pulse waveform generator
 */

module oscillator(
    input clk,
    input rstn,
    input[11:0] count_max,
    output[7:0] data
);

    reg[11:0] counter;
    reg data_buf;

    always @(posedge clk) begin
        if (rstn == 0) begin
            counter <= 0;
        end else begin
            counter <= counter + count_max;
        end
    end

    assign data = counter[11:4];

endmodule