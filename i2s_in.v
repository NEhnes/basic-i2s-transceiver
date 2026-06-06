// still drops first word after reset, but that's fine

// i do not need to worry about buffering. my next module is a dedicated fifo buffer that can run
// well above the speed of this one. it will get its ready from downstream transceiver out

module transceiver_in #(
    parameter WIDTH = 24,
    parameter COUNTER_BITS = 5    // 5 bits covers 0–24
)(
    // general state
    input  wire             rst_n,
    input  wire             clk, // doubles as sck

    // incoming
    input  wire             ws,
    input  wire             sd,

    // outgoing
    input wire              o_tready,
    output reg              o_tvalid,
    output reg  [WIDTH-1:0] tdata
);

reg r_ws, r_sd;
reg r_ws_last;

reg state; // 0 is idle, 1 is processing word

reg [COUNTER_BITS-1:0] word_counter;

reg [WIDTH-1:0] channel_1;
reg [WIDTH-1:0] channel_2;

always @(posedge clk) begin

    if (!rst_n) begin // reset logic
        o_tvalid     <= 1'b0;
        tdata        <= {WIDTH{1'b0}}; 

        r_sd         <= 1'b0;
        r_ws         <= ws;
        r_ws_last    <= ws;

        word_counter <= 5'b0;
        channel_1    <= 24'b0;
        channel_2    <= 24'b0;
    end

    else begin
        // latch inputs (1 cycle delayed) for stability
        r_ws <= ws;
        r_sd <= sd;

        // ── NEW WORD DETECTED ──────────────────────────
        if (r_ws_last != r_ws) begin
            word_counter <= 5'd1;
            r_ws_last    <= r_ws;
            state <= 1;

            // write MSB (bit WIDTH-1)
            if (r_ws)
                channel_2[WIDTH-1] <= r_sd;
            else
                channel_1[WIDTH-1] <= r_sd;
        end

        // ── NO NEW WORD ────── NOT IN IDLE ────────
        else if (state != 0) begin

            if (word_counter == (WIDTH - 1)) begin // end of word

                o_tvalid <= 1'b1;
                state <= 0;          // back to idle

                // concatenate data bcz it gets dropped otherwise
                if (r_ws)
                    tdata <= {channel_2[WIDTH-1:1], r_sd}; 
                else
                    tdata <= {channel_1[WIDTH-1:1], r_sd}; 
            end

            else begin
                // write to bit [WIDTH-1 - word_counter]
                // counter=1 → bit 22, counter=23 → bit 0
                if (r_ws)
                    channel_2[WIDTH-1 - word_counter] <= r_sd;
                else
                    channel_1[WIDTH-1 - word_counter] <= r_sd;

                word_counter <= word_counter + 5'd1;
            end
        end

        // AI IS FUCKING WRONG THIS SHIT IS VALID
        // READS OLD VALUE SIGNAL AND DOES NOT CREATE A RACE CONDITION WITH THE WORD END LOGIC
        if (o_tready && o_tvalid) begin // data transfer out happens
            o_tvalid <= 1'b0; // set low until next complete word
        end
    end
end

endmodule