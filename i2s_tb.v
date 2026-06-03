`timescale 1ns / 1ns
`include "i2s.v"

module i2s_tb;

  // -------------------------------------------------------------------------
  // DUT ports (driven by the testbench)
  // -------------------------------------------------------------------------
  reg        i_sck;
  reg        i_rst_n;
  reg        i_ws;
  reg        i_sd;
  wire       o_valid;
  wire [23:0] o_data;

  // -------------------------------------------------------------------------
  // Test vectors
  // -------------------------------------------------------------------------
  // 24‑bit words we want the DUT to reconstruct.
  // Each entry is one 24‑bit word that will be serialized LSB‑first.
  reg [32:0] src_data [0:3];   // a few words for the demo
  integer    data_counter;    // counts bits transmitted for the current word
  integer    word_counter;    // counts words transmitted

  // -------------------------------------------------------------------------
  // Instantiate the DUT
  // -------------------------------------------------------------------------
  transceiver uut (
      .rst_n (i_rst_n),
      .sck   (i_sck),
      .ws    (i_ws),
      .sd    (i_sd),
      .valid (o_valid),
      .data  (o_data)
  );

  // -------------------------------------------------------------------------
  // Clock generation (20 ns period → 50 MHz)
  // -------------------------------------------------------------------------
  initial i_sck = 0;
  always #10 i_sck = ~i_sck;   // toggle every 10 ns

  // -------------------------------------------------------------------------
  // Test stimulus
  // -------------------------------------------------------------------------
  initial begin
    // -------------------------------------------------
    // 1️⃣  Dump waveform for later inspection
    // -------------------------------------------------
    $dumpfile("i2s.vcd");
    $dumpvars(0, i2s_tb);

    // -------------------------------------------------
    // 2️⃣  Initialise registers
    // -------------------------------------------------
    i_rst_n = 0;          // keep DUT in reset initially
    i_ws    = 0;
    i_sd    = 0;
    data_counter = 0;
    word_counter = 0;

    // -------------------------------------------------
    // 3️⃣  Load a few test words (feel free to edit)
    // -------------------------------------------------
    src_data[0] = 24'hDEADDD;
    src_data[1] = 24'hBABEEE;
    src_data[2] = 24'hBADBAD;
    src_data[3] = 24'hF0000D;

    // -------------------------------------------------
    // 4️⃣  Release reset after a couple of clock edges
    // -------------------------------------------------
    #40 i_rst_n = 1;  // de‑assert reset

    // -------------------------------------------------
    // 5️⃣  Transmit all words, LSB‑first, one bit per clock
    // -------------------------------------------------
    for (word_counter = 0; word_counter < 4; word_counter = word_counter + 1) begin
      // WS is high for the left channel, low for the right channel.
      // For simplicity we toggle it every 32 bits.
      i_ws = word_counter[0];   // 0,1,0,1 … (alternates each word)

      // Send 32 bits of the current word, LSB first
      for (data_counter = 0; data_counter < 32; data_counter = data_counter + 1) begin
        i_sd = src_data[word_counter][data_counter];
        // Wait one rising edge of sck (the DUT samples on an edge)
        @(posedge i_sck);
      end
    end

    // -------------------------------------------------
    // 6️⃣  Wait for the DUT to raise `valid` and capture the last word
    // -------------------------------------------------
    @(posedge o_valid);
    $display("----- Received word -----");
    $display("  Expected : %h", src_data[word_counter-1]);
    $display("  DUT out  : %h", o_data);
    $display("--------------------------");

    // -------------------------------------------------
    // 7️⃣  Finish simulation
    // -------------------------------------------------
    #100 $finish;
  end

endmodule