// still drops first word after reset, but that's fine

module transceiver #(
    parameter WIDTH = 24,
    parameter COUNTER_BITS = 5    // 5 bits covers 0–24
)(
    input  wire        rst_n,
    input  wire        sck,
    input  wire        ws,
    input  wire        sd,
    output reg         valid,
    output reg  [WIDTH-1:0] data
);

reg r_ws, r_sd;
reg r_ws_last;

reg [COUNTER_BITS-1:0] word_counter;  // 0 = idle, 1..WIDTH = capturing

reg [WIDTH-1:0] channel_1;
reg [WIDTH-1:0] channel_2;

always @(posedge sck) begin

    if (!rst_n) begin
        valid        <= 1'b0;
        data         <= 24'b0;

        r_sd         <= 1'b0;
        r_ws         <= ws;
        r_ws_last    <= ws;            // ← FIX 1: match, don't force fake edge

        word_counter <= 5'b0;          // ← idle
        channel_1    <= 24'b0;
        channel_2    <= 24'b0;
    end

    else begin
        // latch inputs (1 cycle delayed)
        r_ws <= ws;
        r_sd <= sd;

        // ── NEW WORD DETECTED ──────────────────────────
        if (r_ws_last != r_ws) begin
            valid        <= 1'b0;
            word_counter <= 5'd1;                     // start capturing
            r_ws_last    <= r_ws;

            // write MSB (bit WIDTH-1)
            if (r_ws)
                channel_2[WIDTH-1] <= r_sd;
            else
                channel_1[WIDTH-1] <= r_sd;
        end

        // ── NO NEW WORD ───────────────────────────────
        else begin

            if (word_counter == 5'd0) begin
                // idle — waiting for first WS edge after reset
                // do nothing
            end

            else if (word_counter == (WIDTH - 1)) begin // end of word

                valid        <= 1'b1;
                word_counter <= 5'd0;                 // back to idle

                // concatenate data bcz it gets dropped otherwise

                if (r_ws)
                    data <= {channel_2[WIDTH-1:1], r_sd}; 
                else
                    data <= {channel_1[WIDTH-1:1], r_sd}; 
            end

            else begin                                // word_counter = 1..WIDTH-1
                // write to bit [WIDTH-1 - word_counter]
                // counter=1 → bit 22, counter=23 → bit 0
                if (r_ws)
                    channel_2[WIDTH-1 - word_counter] <= r_sd;
                else
                    channel_1[WIDTH-1 - word_counter] <= r_sd;

                word_counter <= word_counter + 5'd1;
            end
        end
    end
end

endmodule