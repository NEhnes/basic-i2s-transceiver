`timescale 1ns / 1ns
`include "i2s.v"

module i2s_tb;

  // -------------------------------------------------------------------------
  // UUT ports
  // -------------------------------------------------------------------------
  reg         i_rst_n;

  reg         i_sck = 0;
  reg         i_ws;
  reg         i_sd;

  wire        o_valid;
  wire [23:0] o_data;

  // -------------------------------------------------------------------------
  // Test vectors
  // -------------------------------------------------------------------------
  reg [23:0] src_data [0:3];   // a few words for the demo
  integer    data_counter;    // counts bits transmitted for the current word
  integer    word_counter;    // counts words transmitted

  // instantiate test module
  transceiver uut (
      .rst_n (i_rst_n),
      .sck   (i_sck),
      .ws    (i_ws),
      .sd    (i_sd),
      .valid (o_valid),
      .data  (o_data)
  );

  // toggle clock every 10ns (20ns cycle time)
  always begin
    i_sck = ~i_sck;
    #10;
  end

  



  // -------------------------------------------------------------------------
  // Test stimulus
  // -------------------------------------------------------------------------
  initial begin
    // -------------------------------------------------
    // Dump waveform for later inspection
    // -------------------------------------------------
    $dumpfile("i2s_tb.vcd");
    $dumpvars(0, i2s_tb);

    // -------------------------------------------------
    // Initialise registers
    // -------------------------------------------------
    i_rst_n = 0;          // keep DUT in reset initially
    i_ws    = 0;
    i_sd    = 0;
    data_counter = 0;
    word_counter = 0;

    // -------------------------------------------------
    // Test words (6 HEX CHARACTERS * 4bit per = 24 bit per word)
    // -------------------------------------------------

    src_data[0] = 24'hABCDEF;
    src_data[1] = 24'h123456;
    src_data[2] = 24'hBADBAD;
    src_data[3] = 24'hF0000D;

    // alternating high-low switching - easy to spot in waveform
    // to check that data is being transmitted properly
    // src_data[0] = 24'b111111111111111111111111;
    // src_data[1] = 24'b111111111111111111111111;
    // src_data[2] = 24'b111111111111111111111111;
    // src_data[3] = 24'b111111111111111111111111;
    // src_data[0] = 24'b010101010101010101010101; // 1-1-1-1
    // src_data[1] = 24'b001100110011001100110011; // 2-2-2-2
    // src_data[2] = 24'b000111000111000111000111; // 3-3-3-3
    // src_data[3] = 24'b000011110000111100001111; // 4-4-4-4

    // -------------------------------------------------
    // Release reset after a couple of clock edges
    // -------------------------------------------------
    #40 i_rst_n = 1;  // de‑assert reset

    // -------------------------------------------------
    // Transmit all words, LSB‑first, one bit per clock
    // -------------------------------------------------
    for (word_counter = 0; word_counter < 4; word_counter = word_counter + 1) begin
      // WS is high for the left channel, low for the right channel.
      // For simplicity we toggle it every 32 bits.
      i_ws <= word_counter[0];   // 0,1,0,1 … (alternates each word)

      // Send 24 bits of the current word, MSB first
      for (data_counter = 0; data_counter < 24; data_counter = data_counter + 1) begin
        // Subtract from 23 to grab the top bits first
        i_sd <= src_data[word_counter][23 - data_counter]; 
        @(posedge i_sck);
      end
    end

    // -------------------------------------------------
    // 6Wait for the DUT to raise `valid` and capture the last word
    // -------------------------------------------------
    // @(posedge o_valid);
    // $display("----- Received word -----");
    // $display("  Expected : %h", src_data[word_counter-1]);
    // $display("  DUT out  : %h", o_data);
    // $display("--------------------------");

    // -------------------------------------------------
    // Finish simulation
    // -------------------------------------------------
    #100 $finish;
  end

endmodule