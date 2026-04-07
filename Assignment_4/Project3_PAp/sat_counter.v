// sat_counter.v
// 2-bit saturating up/down counter used as a branch prediction counter.
// Increments on taken, decrements on not-taken, saturates at 11 and 00.
// Prediction is the MSB of the current state.
// NOTE: This file is identical across Project1_GAg, Project2_PAg, Project3_PAp.

module sat_counter (
    input  wire       clk,
    input  wire       reset,
    input  wire       taken,      // 1 = branch was taken, 0 = not taken
    output wire       prediction, // 1 = predict taken (MSB of state)
    output reg  [1:0] state       // current 2-bit counter value
);

    // Prediction is simply the most-significant bit of the counter state
    assign prediction = state[1];

    // On every clock edge: reset to weakly-not-taken (2'b01),
    // or increment/decrement while saturating at the extremes.
    always @(posedge clk) begin
        if (reset) begin
            state <= 2'b01; // weakly not-taken after reset
        end else if (taken) begin
            // Increment, saturate at 2'b11
            if (state != 2'b11)
                state <= state + 2'b01;
        end else begin
            // Decrement, saturate at 2'b00
            if (state != 2'b00)
                state <= state - 2'b01;
        end
    end

endmodule
