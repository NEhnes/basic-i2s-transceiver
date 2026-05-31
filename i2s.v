// LACKS AN ACK THAT MESSAGE WAS RECEIVED
// I'M AWARE THAT OUTPUT DATA IS HANDLED POORLY RIGHT NOW
// IF THE DESTINATION MISSED THE CLOCK CYCLE, DATA IS GONE
module transceiver(
    input  wire        rst_n,
    input  wire        sck,
    input  wire        ws,
    input  wire        sd,
    output reg         valid,
    output reg  [23:0] data     // ideally width shouldn't be hardcoded
); 

reg r_ws, r_sd; 
reg r_ws_last;

reg [4:0] word_counter;

reg [23:0] channel_1;
reg [23:0] channel_2;

always@(posedge sck) begin

    // reset logic
    if (!rst_n) begin
        // data is not valid, clear the garbage
        valid <= 1'b0;
        data <= 24'b0;

        // set them to opposite of current - this way we can't get part of a word
        r_ws <= !ws;
        r_ws_last <= !ws;

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

            // increment word counter (MUST be at zero, only logical way possible)
            word_counter <= word_counter + 1;

            // write MSB to correct channel, hardcode index for safety
            if (r_ws) channel_2[23] <= r_sd; 
            else      channel_1[23] <= r_sd;

            // update last WS variable to proceed in writing full word
            r_ws_last <= r_ws;
        
        // no new word
        end else begin

            word_counter <= word_counter + 1; // increment counter

            // write to correct slot
            if (r_ws) channel_2[23 - word_counter] <= r_sd;
            else      channel_1[23 - word_counter] <= r_sd;

            // READS FROM LAST CYCLE BCZ LATCHING
            // when last cycle is 23, it will be writing to slot zero
            // hence, completed word
            if (word_counter == 23) begin

                // valid will always be true unless immediately following reset
                // this is DIFFERENT than axi-stream valid
                // does NOT indicate new data, just that the data isn't garbage 
                valid <= 1;

                // reset word counter for next word
                word_counter <= 5'b0;

                // write data to appropriate channel
                if (r_ws) data <= channel_2;
                else      data <= channel_1;

            end
        end
    end
end

endmodule