`timescale 1ns / 1ns
`include "i2s.v"

module i2s_tb;

reg i_sck, i_rst_n, i_ws, i_sd, o_valid;
reg [31:0] o_data;

reg [3:0] src_data [31:0];
reg [2:0] data_counter;
reg [4:0] word_counter;

transceiver uut (
    .rst_n(i_rst_n),
    .sck(i_sck),
    .ws(i_ws),
    .sd(i_sd),
    .valid(o_valid),
    .data(o_data)
);

initial begin
    $dumpfile("i2s.vcd");
    $dumpvars(0, i2s_tb);

    // initialize testbench counters
    data_counter = 1'b0;
    word_counter = 32'b0;

    // initialize uut port variables

    // reset

    // cycle through data & update WS as expected
end

always begin
    sck = ~sck;
    #10;
end



endmodule