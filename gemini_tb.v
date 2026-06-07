`timescale 1ns / 1ps
`include "i2s_in.v"

module transceiver_in_tb;

    // ---------------------------------------------------------
    // 1. Signal Declarations
    // ---------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         ws;
    reg         sd;
    reg         o_tready;
    wire        o_tvalid;
    wire [23:0] tdata;

    // Test tracking
    integer num_pass = 0;
    integer num_fail = 0;

    // ---------------------------------------------------------
    // 2. DUT Instantiation
    // ---------------------------------------------------------
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

    // ---------------------------------------------------------
    // 3. Clock Generation (10ns period)
    // ---------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---------------------------------------------------------
    // 4. Waveform Dump
    // ---------------------------------------------------------
    initial begin
        $dumpfile("gemini_tb.vcd");
        $dumpvars(0, transceiver_in_tb);
    end

    // ---------------------------------------------------------
    // 5. Tasks for Reusability
    // ---------------------------------------------------------
    
    // Task: send one 24-bit word via I2S
    // I2S spec: WS edge -> 1-cycle delay -> MSB on next cycle
    task send_word;
        input        ws_val;
        input [23:0] data;
        integer i;
        begin
            // WS edge
            @(posedge clk); #1;
            ws = ws_val;

            // Clock out bits [23..0], MSB first
            for (i = 23; i >= 0; i = i - 1) begin
                @(posedge clk); #1;
                sd = data[i];
            end
        end
    endtask

    // Task: Wait for valid and check output
    task check_output;
        input [23:0]  expected;
        input [255:0] test_name; // String to identify the test
        begin
            // Wait synchronously for valid to assert
            wait(o_tvalid == 1'b1);
            @(posedge clk); // Sample right at the clock edge where valid is high
            
            if (tdata === expected) begin
                $display("[PASS] %s: got %h", test_name, tdata);
                num_pass = num_pass + 1;
            end else begin
                $display("[FAIL] %s: expected %h, got %h", test_name, expected, tdata);
                num_fail = num_fail + 1;
            end
        end
    endtask

    // ---------------------------------------------------------
    // 6. MAIN TEST SEQUENCER
    // Run everything sequentially in ONE initial block
    // ---------------------------------------------------------
    initial begin
        // --- Initialization & Reset ---
        rst_n    = 1'b0;
        ws       = 1'b0;
        sd       = 1'b0;
        o_tready = 1'b1;
        
        #50;
        @(posedge clk); #1;
        rst_n = 1'b1;
        #20; // Let DUT settle past reset
        
        $display("\n=== Starting I2S Transceiver Tests ===\n");

        // -----------------------------------------------------
        // Test 1: Left channel (WS=0), known pattern
        // -----------------------------------------------------
        // First word after reset is dropped (by design), so send a dummy
        send_word(1'b0, 24'hFFFFFF); 

        // Now send real left-channel word
        send_word(1'b0, 24'hA5C3F0);
        check_output(24'hA5C3F0, "Test 1 (Left Channel Pattern)");

        // -----------------------------------------------------
        // Test 2: Right channel (WS=1), all zeros
        // -----------------------------------------------------
        send_word(1'b1, 24'h000000); 
        check_output(24'h000000, "Test 2 (Right Channel All Zeros)");

        // -----------------------------------------------------
        // Test 3: Right channel (WS=1), all ones
        // -----------------------------------------------------
        send_word(1'b1, 24'hFFFFFF);
        check_output(24'hFFFFFF, "Test 3 (Right Channel All Ones)");

        // -----------------------------------------------------
        // Test 4: AXI-S Backpressure
        // -----------------------------------------------------
        // Apply backpressure before sending data
        @(posedge clk); #1;
        o_tready = 1'b0; 

        send_word(1'b0, 24'h123456);

        // Wait for valid to assert
        wait(o_tvalid == 1'b1);

        // Check: valid must stay high for 5 cycles while ready is low
        begin : bp_check
            integer k;
            reg valid_held;
            valid_held = 1;
            
            for (k = 0; k < 5; k = k + 1) begin
                @(posedge clk);
                if (o_tvalid !== 1'b1) begin
                    valid_held = 0;
                end
            end
            
            if (valid_held) begin
                $display("[PASS] Test 4 (Backpressure): TVALID held high while TREADY low");
                num_pass = num_pass + 1;
            end else begin
                $display("[FAIL] Test 4 (Backpressure): TVALID dropped before TREADY");
                num_fail = num_fail + 1;
            end
        end

        // Release ready
        @(posedge clk); #1;
        o_tready = 1'b1;
        
        // Wait one cycle for handshake to complete, check data
        @(posedge clk);
        if (tdata === 24'h123456) begin
            $display("[PASS] Test 4 (Backpressure Data): got %h", tdata);
            num_pass = num_pass + 1;
        end else begin
            $display("[FAIL] Test 4 (Backpressure Data): expected 123456, got %h", tdata);
            num_fail = num_fail + 1;
        end

        // TVALID must deassert after handshake completes
        @(posedge clk); #1;
        if (o_tvalid === 1'b0) begin
            $display("[PASS] Test 4 (Handshake): TVALID deasserted successfully");
            num_pass = num_pass + 1;
        end else begin
            $display("[FAIL] Test 4 (Handshake): TVALID still high after TREADY handshake");
            num_fail = num_fail + 1;
        end

        // -----------------------------------------------------
        // Finish Simulation
        // -----------------------------------------------------
        #100;
        $display("\n=== Summary ===");
        $display("Passed: %0d", num_pass);
        $display("Failed: %0d", num_fail);
        if (num_fail == 0)
            $display("STATUS: SUCCESS\n");
        else
            $display("STATUS: FAILED\n");
            
        $finish;
    end

    // ---------------------------------------------------------
    // 7. Timeout Watchdog (Just in case DUT hangs)
    // ---------------------------------------------------------
    initial begin
        #500000;
        $display("\n[FATAL] Simulation timeout reached! DUT might be hung.");
        $display("Passed: %0d, Failed: %0d", num_pass, num_fail);
        $finish;
    end

endmodule