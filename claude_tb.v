`timescale 1ns / 1ps
`include "i2s_in.v"

module transceiver_in_tb;

    // Clock and reset
    reg clk;
    reg rst_n;

    // DUT ports
    reg        ws;
    reg        sd;
    reg        o_tready;
    wire       o_tvalid;
    wire [23:0] tdata;

    // Test tracking
    integer num_pass = 0;
    integer num_fail = 0;

    // ── DUT ────────────────────────────────────────────
    transceiver_in #(
        .WIDTH(24),
        .COUNTER_BITS(5)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .ws       (ws),
        .sd       (sd),
        .o_tready (o_tready),
        .o_tvalid (o_tvalid),
        .tdata    (tdata)
    );

    // ── Clock: 10 ns period ────────────────────────────
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ── Waveform dump ──────────────────────────────────
    initial begin
        $dumpfile("claude_tb.vcd");
        $dumpvars(0, transceiver_in_tb);
    end

    // ── Reset ──────────────────────────────────────────
    initial begin
        rst_n    = 1'b0;
        ws       = 1'b0;
        sd       = 1'b0;
        o_tready = 1'b1;
        #50;
        @(posedge clk); #1;
        rst_n = 1'b1;
    end

    // ── Task: send one 24-bit word via I2S ─────────────
    // ws_val: WS level during this word
    // data:   24-bit payload, MSB first
    // I2S: WS edge → 1-cycle delay → MSB on next cycle
    task send_word;
        input        ws_val;
        input [23:0] data;
        integer i;
        begin
            // WS edge (previous word's last bit / idle → new WS)
            @(posedge clk); #1;
            ws = ws_val;

            // Clock out bits [23..0], MSB first
            for (i = 23; i >= 0; i = i - 1) begin
                @(posedge clk); #1;
                sd = data[i];
            end
        end
    endtask

    // ── Task: check tdata after handshake ──────────────
    task check_output;
        input [23:0] expected;
        input [127:0] label; // unused in display but kept for clarity
        begin
            // Wait for valid
            wait(o_tvalid == 1'b1);
            @(posedge clk); #1; // sample after one clock with valid high
            if (tdata === expected) begin
                $display("[PASS] %s: got %h", label, tdata);
                num_pass = num_pass + 1;
            end else begin
                $display("[FAIL] %s: expected %h, got %h", label, expected, tdata);
                num_fail = num_fail + 1;
            end
        end
    endtask

    // ── Test 1: Left channel (WS=0), known pattern ─────
    // I2S left channel = WS low
    // We send on WS=0, expect tdata = 24'hA5C3F0
    initial begin
        wait(rst_n == 1'b1);
        #20; // let DUT settle past first edge

        o_tready = 1'b1;

        // First word after reset is dropped (by design), so send a dummy
        send_word(1'b0, 24'hFFFFFF); // dummy — dropped

        // Now send real left-channel word
        send_word(1'b0, 24'hA5C3F0);

        // Wait and check
        wait(o_tvalid == 1'b1);
        @(posedge clk);
        if (tdata === 24'hA5C3F0) begin
            $display("[PASS] Test1 left-channel: got %h", tdata);
            num_pass = num_pass + 1;
        end else begin
            $display("[FAIL] Test1 left-channel: expected A5C3F0, got %h", tdata);
            num_fail = num_fail + 1;
        end
    end

    // ── Test 2: Right channel (WS=1), all zeros ────────
    initial begin
        wait(rst_n == 1'b1);
        #20;

        // Let test 1 finish its dummy + real word first (~50 cycles each)
        #1200;

        send_word(1'b1, 24'h000000); // right channel, all zeros

        wait(o_tvalid == 1'b1);
        @(posedge clk);
        if (tdata === 24'h000000) begin
            $display("[PASS] Test2 right-channel zeros: got %h", tdata);
            num_pass = num_pass + 1;
        end else begin
            $display("[FAIL] Test2 right-channel zeros: expected 000000, got %h", tdata);
            num_fail = num_fail + 1;
        end
    end

    // ── Test 3: Right channel, all ones ────────────────
    initial begin
        wait(rst_n == 1'b1);
        #20;

        #1800; // wait for test 2 to finish

        send_word(1'b1, 24'hFFFFFF);

        wait(o_tvalid == 1'b1);
        @(posedge clk);
        if (tdata === 24'hFFFFFF) begin
            $display("[PASS] Test3 right-channel all-ones: got %h", tdata);
            num_pass = num_pass + 1;
        end else begin
            $display("[FAIL] Test3 right-channel all-ones: expected FFFFFF, got %h", tdata);
            num_fail = num_fail + 1;
        end
    end

    // ── Test 4: AXI-S backpressure — hold TREADY low ──
    // TVALID must stay high until TREADY asserted
    initial begin
        wait(rst_n == 1'b1);
        #20;

        #2400; // wait for tests 1-3

        o_tready = 1'b0; // apply backpressure

        send_word(1'b0, 24'h123456);

        // Wait for valid to assert
        wait(o_tvalid == 1'b1);

        // Check: valid stays high for 5 cycles while ready is low
        begin : bp_check
            integer k;
            integer valid_held;
            valid_held = 1;
            for (k = 0; k < 5; k = k + 1) begin
                @(posedge clk);
                if (o_tvalid !== 1'b1)
                    valid_held = 0;
            end
            if (valid_held) begin
                $display("[PASS] Test4 backpressure: TVALID held high");
                num_pass = num_pass + 1;
            end else begin
                $display("[FAIL] Test4 backpressure: TVALID dropped before TREADY");
                num_fail = num_fail + 1;
            end
        end

        // Release ready; check data
        @(posedge clk); #1;
        o_tready = 1'b1;
        @(posedge clk);
        if (tdata === 24'h123456) begin
            $display("[PASS] Test4 backpressure data: got %h", tdata);
            num_pass = num_pass + 1;
        end else begin
            $display("[FAIL] Test4 backpressure data: expected 123456, got %h", tdata);
            num_fail = num_fail + 1;
        end

        // TVALID must deassert after handshake
        @(posedge clk);
        if (o_tvalid === 1'b0) begin
            $display("[PASS] Test4 TVALID deasserted after handshake");
            num_pass = num_pass + 1;
        end else begin
            $display("[FAIL] Test4 TVALID still high after handshake");
            num_fail = num_fail + 1;
        end
    end

    // ── Timeout + summary ──────────────────────────────
    initial begin
        #50000;
        $display("\n=== Summary ===");
        $display("Passed: %0d", num_pass);
        $display("Failed: %0d", num_fail);
        $finish;
    end

endmodule