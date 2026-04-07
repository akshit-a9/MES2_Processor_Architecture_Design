// pap_predictor.v
// PAp (Per-branch Adaptive, per-set PHT) two-level branch predictor.
//
// Same BHT structure as PAg (per-branch history indexed by PC).
// Instead of one shared PHT, there are NUM_PHTS separate PHTs.
// PC[1:0] selects which PHT to use.
// The BHT row content selects the entry within the chosen PHT.

`timescale 1ns / 1ps

module pap_predictor #(
    parameter HISTORY_BITS = 4,    // width of each BHT row
    parameter PC_BITS      = 4,    // bits of PC used to index BHT
    parameter BHT_ENTRIES  = 16,   // must equal 2^PC_BITS
    parameter NUM_PHTS     = 4,    // number of separate PHTs (indexed by PC[1:0])
    parameter PHT_ENTRIES  = 16    // entries per PHT, must equal 2^HISTORY_BITS
) (
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    branch_detected, // 1 when a branch is at fetch
    input  wire                    branch_taken,    // actual outcome at resolution
    input  wire [PC_BITS-1:0]      pc,              // PC selects BHT row and PHT
    output wire                    prediction,       // 1 = predict taken
    output wire [HISTORY_BITS-1:0] bht_out,          // BHT row selected by pc (waveform)
    output wire [1:0]              pht_select         // which PHT is active (waveform)
);

    // Internal signals
    reg [HISTORY_BITS-1:0] bht     [0:BHT_ENTRIES-1];         // Branch History Table
    reg [1:0]              phts    [0:NUM_PHTS-1][0:PHT_ENTRIES-1]; // NUM_PHTS separate PHTs

    // PHT selection: use PC[1:0]
    wire [1:0]              pht_idx;       // which PHT bank to use
    wire [HISTORY_BITS-1:0] entry_idx;     // which entry within the selected PHT

    assign pht_idx   = pc[1:0];            // lower 2 bits of PC choose the PHT
    assign entry_idx = bht[pc];            // BHT row content chooses PHT entry
    assign pht_select = pht_idx;
    assign bht_out    = bht[pc];

    // Prediction = MSB of the selected PHT entry in the selected PHT bank
    assign prediction = phts[pht_idx][entry_idx][1];

    // Snapshots at fetch time — used to update the right PHT row later
    reg [1:0]              pht_idx_at_fetch;
    reg [HISTORY_BITS-1:0] entry_idx_at_fetch;
    reg [PC_BITS-1:0]      pc_at_fetch;

    // Latch the fetch-time indices for use during update
    always @(posedge clk) begin
        if (reset) begin
            pht_idx_at_fetch   <= 2'b00;
            entry_idx_at_fetch <= {HISTORY_BITS{1'b0}};
            pc_at_fetch        <= {PC_BITS{1'b0}};
        end else if (branch_detected) begin
            pht_idx_at_fetch   <= pht_idx;
            entry_idx_at_fetch <= entry_idx;
            pc_at_fetch        <= pc;
        end
    end

    // PHT update and BHT shift at resolution
    integer i, j;
    always @(posedge clk) begin
        if (reset) begin
            // Initialise all BHT rows
            for (i = 0; i < BHT_ENTRIES; i = i + 1)
                bht[i] <= {HISTORY_BITS{1'b0}};
            // Initialise all PHT banks to weakly not-taken (2'b01)
            for (i = 0; i < NUM_PHTS; i = i + 1)
                for (j = 0; j < PHT_ENTRIES; j = j + 1)
                    phts[i][j] <= 2'b01;
        end else if (branch_detected) begin
            // Update the correct entry in the correct PHT bank
            if (branch_taken) begin
                if (phts[pht_idx_at_fetch][entry_idx_at_fetch] != 2'b11)
                    phts[pht_idx_at_fetch][entry_idx_at_fetch] <=
                        phts[pht_idx_at_fetch][entry_idx_at_fetch] + 2'b01;
            end else begin
                if (phts[pht_idx_at_fetch][entry_idx_at_fetch] != 2'b00)
                    phts[pht_idx_at_fetch][entry_idx_at_fetch] <=
                        phts[pht_idx_at_fetch][entry_idx_at_fetch] - 2'b01;
            end
            // Shift the correct BHT row left, insert actual outcome as LSB
            bht[pc_at_fetch] <= {bht[pc_at_fetch][HISTORY_BITS-2:0], branch_taken};
        end
    end

endmodule
