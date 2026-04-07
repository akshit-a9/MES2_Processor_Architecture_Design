// pag_predictor.v
// PAg (Per-branch Adaptive, global PHT) two-level branch predictor.
//
// Each branch has its own history register stored in a Branch History Table (BHT).
// The BHT is indexed by the lower PC_BITS of the branch PC.
// All branches share one Pattern History Table (PHT) indexed by the BHT row content.

`timescale 1ns / 1ps

module pag_predictor #(
    parameter HISTORY_BITS = 4,     // width of each BHT row (per-branch history)
    parameter PC_BITS      = 4,     // bits of PC used to index the BHT
    parameter BHT_ENTRIES  = 16,    // must equal 2^PC_BITS
    parameter PHT_SIZE     = 16     // must equal 2^HISTORY_BITS
) (
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    branch_detected, // 1 when a branch is at fetch
    input  wire                    branch_taken,    // actual outcome at resolution
    input  wire [PC_BITS-1:0]      pc,             // PC used to select BHT row
    output wire                    prediction,      // 1 = predict taken
    output wire [HISTORY_BITS-1:0] bht_out          // BHT row selected by pc (waveform)
);

    // Internal signals
    reg  [HISTORY_BITS-1:0] bht      [0:BHT_ENTRIES-1]; // Branch History Table
    reg  [1:0]              pht      [0:PHT_SIZE-1];     // shared PHT (2-bit counters)

    // Snapshot of the BHT row (and PC) used at fetch — needed for update
    reg  [HISTORY_BITS-1:0] bht_row_at_fetch;
    reg  [PC_BITS-1:0]      pc_at_fetch;

    // PHT index at fetch = content of the selected BHT row
    wire [HISTORY_BITS-1:0] pht_index;
    assign pht_index = bht[pc];

    // Expose the selected BHT row on the output port
    assign bht_out = bht[pc];

    // Prediction = MSB of the PHT entry indexed by the selected BHT row
    assign prediction = pht[pht_index][1];

    // Latch the BHT row and PC used at fetch time for later update
    always @(posedge clk) begin
        if (reset) begin
            bht_row_at_fetch <= {HISTORY_BITS{1'b0}};
            pc_at_fetch      <= {PC_BITS{1'b0}};
        end else if (branch_detected) begin
            bht_row_at_fetch <= bht[pc];   // PHT index used this cycle
            pc_at_fetch      <= pc;         // which BHT row to shift later
        end
    end

    // PHT and BHT update at resolution (same cycle as fetch for simplicity)
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            // Initialise all BHT rows and PHT entries
            for (i = 0; i < BHT_ENTRIES; i = i + 1)
                bht[i] <= {HISTORY_BITS{1'b0}};
            for (i = 0; i < PHT_SIZE; i = i + 1)
                pht[i] <= 2'b01; // weakly not-taken
        end else if (branch_detected) begin
            // Update PHT entry that was indexed by the BHT row at fetch
            if (branch_taken) begin
                if (pht[bht_row_at_fetch] != 2'b11)
                    pht[bht_row_at_fetch] <= pht[bht_row_at_fetch] + 2'b01;
            end else begin
                if (pht[bht_row_at_fetch] != 2'b00)
                    pht[bht_row_at_fetch] <= pht[bht_row_at_fetch] - 2'b01;
            end
            // Shift the correct BHT row left, insert actual outcome as LSB
            bht[pc_at_fetch] <= {bht[pc_at_fetch][HISTORY_BITS-2:0], branch_taken};
        end
    end

endmodule
