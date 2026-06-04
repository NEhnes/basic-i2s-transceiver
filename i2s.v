// LACKS AN ACK THAT MESSAGE WAS RECEIVED
// I'M AWARE THAT OUTPUT DATA IS HANDLED POORLY RIGHT NOW
// IF THE DESTINATION MISSED THE CLOCK CYCLE, DATA IS GONE
// KEEP IN MIND THAT THIS IS 1 CYCLE BEHIND
module transceiver #(
    parameter WIDTH = 24,
    parameter COUNTER_BITS = 5
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

reg [COUNTER_BITS-1:0] word_counter;

reg [WIDTH-1:0] channel_1;
reg [WIDTH-1:0] channel_2;

always@(posedge sck) begin

    // reset logic
    if (!rst_n) begin
        // data is not valid, clear the garbage
        valid <= 1'b0;
        data <= 24'b0;

        r_sd <= 1'b0;

        r_ws <= ws;
        r_ws_last <= ws;

        // reset counter of bits within word
        word_counter <= 5'b0;

        // clear channels for safety (not strictly necessary)
        channel_1 <= 24'b0;
        channel_2 <= 24'b0;
    end

    else begin
        // latch my inputs
        r_ws <= ws;
        r_sd <= sd;

        // new word
        if (r_ws_last != r_ws) begin
            // *****CURRENT BUG*****
            // IS TAKING LAST WORD'S LSB BECAUSE CYCLE IS 1 BEHIND
            // IMPLEMENT PIPELINE OR HANDLE OTHERWISE

            // de-assert valid to indicate stale data
            valid <= 1'b0;

            // hardcode for safety
            word_counter <= 5'b1;

            // write MSB to correct channel, hardcode to MSB index for safety
            if (r_ws) channel_2[WIDTH-1] <= r_sd; 
            else      channel_1[WIDTH-1] <= r_sd;

            // update last WS variable to proceed in writing full word
            r_ws_last <= r_ws;
        
        // no new word
        end else begin

            if (word_counter == (WIDTH - 1)) begin
                // LAST CHARACTER WRITE

                // READS FROM LAST CYCLE BCZ LATCHING
                // when word_counter is 23, it will be writing to slot 0
                // hence, completed word
                valid <= 1;

                // reset word counter for next word
                word_counter <= 5'b0;

                // write data to appropriate channel
                if (r_ws) data <= channel_2;
                else      data <= channel_1;

            end else begin
                // STANDARD WRITE
                // will take effect next cycle
                word_counter <= word_counter + 1; // increment counter

                // write to correct bit
                if (r_ws) channel_2[23 - word_counter] <= r_sd;
                else      channel_1[23 - word_counter] <= r_sd;
            end
            
        end
    end
end

endmodule