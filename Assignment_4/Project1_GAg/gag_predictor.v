// gag_predictor.v
// GAg (Global Adaptive, global history) two-level branch predictor.
//
// One Global History Register (GHR) shared by all branches.
// One Pattern History Table (PHT) with PHT_SIZE entries of 2-bit saturating counters.
// GHR indexes the PHT to produce a prediction.

`timescale 1ns / 1ps

module gag_predictor #(
    parameter HISTORY_BITS = 4,            // width of the GHR
    parameter PHT_SIZE     = 16            // must equal 2^HISTORY_BITS
) (
    input  wire                   clk,
    input  wire                   reset,
    input  wire                   branch_detected, // 1 when a branch is at fetch
    input  wire                   branch_taken,    // actual outcome at resolution
    output wire                   prediction,      // 1 = predict taken
    output wire [HISTORY_BITS-1:0] ghr_out         // current GHR (for waveform)
);

    // -----------------------------------------------------------------
    // Internal signals
    // -----------------------------------------------------------------
    reg  [HISTORY_BITS-1:0] ghr;            // Global History Register
    reg  [HISTORY_BITS-1:0] ghr_at_fetch;  // GHR snapshot used at fetch time

    // PHT: array of 2-bit states.  We drive sat_counter inputs via wires.
    reg  [1:0] pht_state [0:PHT_SIZE-1];   // current states of all counters
    wire [1:0] pht_next  [0:PHT_SIZE-1];   // next states (computed below)

    // Expose GHR on the output port
    assign ghr_out = ghr;

    // -----------------------------------------------------------------
    // Prediction: index the PHT with the current GHR, MSB = prediction
    // -----------------------------------------------------------------
    assign prediction = pht_state[ghr][1];

    // -----------------------------------------------------------------
    // Latch the GHR value used at fetch so we update the correct entry
    // -----------------------------------------------------------------
    // Capture which PHT row was used for the current fetch
    always @(posedge clk) begin
        if (reset) begin
            ghr_at_fetch <= {HISTORY_BITS{1'b0}};
        end else if (branch_detected) begin
            ghr_at_fetch <= ghr;
        end
    end

    // -----------------------------------------------------------------
    // PHT update and GHR shift — both happen at resolution
    // Assumption: fetch and resolution happen in the same cycle.
    // -----------------------------------------------------------------
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // Initialise every PHT entry to weakly not-taken (2'b01)
            for (i = 0; i < PHT_SIZE; i = i + 1)
                pht_state[i] <= 2'b01;
            ghr <= {HISTORY_BITS{1'b0}};
        end else if (branch_detected) begin
            // Update the PHT entry that was indexed at fetch time
            if (branch_taken) begin
                if (pht_state[ghr_at_fetch] != 2'b11)
                    pht_state[ghr_at_fetch] <= pht_state[ghr_at_fetch] + 2'b01;
            end else begin
                if (pht_state[ghr_at_fetch] != 2'b00)
                    pht_state[ghr_at_fetch] <= pht_state[ghr_at_fetch] - 2'b01;
            end
            // Shift GHR left, insert actual outcome as LSB
            ghr <= {ghr[HISTORY_BITS-2:0], branch_taken};
        end
    end

endmodule
