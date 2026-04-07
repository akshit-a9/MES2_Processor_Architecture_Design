// tb_pap.v
// Testbench for the PAp (Per-branch Adaptive, per-set PHT) predictor.
//
// Test phases (in order):
//   1. Reset            — verify prediction defaults to not-taken
//   2. Loop simulation  — 8T + 1NT repeated 3 times, single PC
//   3. Correlated branch simulation — two PCs alternating, T,T,NT pattern
//   4. Random stress    — 16-cycle hardcoded pseudo-random sequence
//
// Waveform output: pap.vcd  (open with GTKWave)

`timescale 1ns / 1ps

module tb_pap;

    // -----------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------
    reg        clk;
    reg        reset;
    reg        branch_detected;
    reg        branch_taken;
    reg  [3:0] pc;
    wire       prediction;
    wire [3:0] bht_out;
    wire [1:0] pht_select;

    // Cycle counter for display
    integer cycle_count;

    // -----------------------------------------------------------------
    // Instantiate PAp predictor
    // -----------------------------------------------------------------
    pap_predictor #(
        .HISTORY_BITS(4),
        .PC_BITS(4),
        .BHT_ENTRIES(16),
        .NUM_PHTS(4),
        .PHT_ENTRIES(16)
    ) dut (
        .clk            (clk),
        .reset          (reset),
        .branch_detected(branch_detected),
        .branch_taken   (branch_taken),
        .pc             (pc),
        .prediction     (prediction),
        .bht_out        (bht_out),
        .pht_select     (pht_select)
    );

    // -----------------------------------------------------------------
    // Clock generation — 10 ns period
    // -----------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------
    // Periodic display: cycle, pc, branch_detected, branch_taken,
    //                   prediction, BHT row, pht_select
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        $display("CYC=%0d | pc=%b branch_det=%b taken=%b | prediction=%b | bht_out=%b pht_sel=%b",
                 cycle_count, pc, branch_detected, branch_taken,
                 prediction, bht_out, pht_select);
    end

    // -----------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("pap.vcd");
        $dumpvars(0, tb_pap);
    end

    // -----------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------
    integer rep;
    integer k;
    reg [15:0] rand_seq;

    initial begin
        // Initialise
        cycle_count     = 0;
        branch_detected = 0;
        branch_taken    = 0;
        pc              = 4'b0000;
        reset           = 1;

        // ============================================================
        // Phase 1 — Reset (hold for 2 cycles)
        // ============================================================
        $display("\n===== PHASE 1: RESET =====");
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;
        $display("Reset released. Expect prediction = 0 (not-taken).");

        // ============================================================
        // Phase 2 — Loop simulation: 8T + 1NT × 3 reps, PC = 4'b0001
        // PC[1:0] = 01 → PHT bank 1 is used throughout this phase.
        // ============================================================
        $display("\n===== PHASE 2: LOOP SIMULATION (8T + 1NT, 3 repetitions, PC=0001) =====");
        pc = 4'b0001;
        for (rep = 0; rep < 3; rep = rep + 1) begin
            $display("-- Repetition %0d (pht_sel should be 01) --", rep + 1);
            for (k = 0; k < 8; k = k + 1) begin
                @(negedge clk);
                branch_detected = 1;
                branch_taken    = 1;
                @(posedge clk); #1;
            end
            @(negedge clk);
            branch_detected = 1;
            branch_taken    = 0;
            @(posedge clk); #1;
        end
        @(negedge clk);
        branch_detected = 0;
        branch_taken    = 0;

        // ============================================================
        // Phase 3 — Correlated branches:
        //   PC 4'b0001 (PC[1:0]=01, PHT bank 1)
        //   PC 4'b0010 (PC[1:0]=10, PHT bank 2)
        //   Pattern T, T, NT across 12 cycles, alternating PCs.
        // PAp separates these into different PHT banks → less aliasing.
        // ============================================================
        $display("\n===== PHASE 3: CORRELATED BRANCH SIMULATION (T,T,NT x4, PC alternates) =====");
        for (k = 0; k < 12; k = k + 1) begin
            @(negedge clk);
            branch_detected = 1;
            pc = (k % 2 == 0) ? 4'b0001 : 4'b0010;
            case (k % 3)
                0: branch_taken = 1;
                1: branch_taken = 1;
                2: branch_taken = 0;
                default: branch_taken = 0;
            endcase
            @(posedge clk); #1;
        end
        @(negedge clk);
        branch_detected = 0;
        branch_taken    = 0;

        // ============================================================
        // Phase 4 — Random stress: 16-bit pseudo-random, PC = 4'b0011
        // PC[1:0]=11 → PHT bank 3.
        // Pattern: 16'b1101_1010_1110_0101 (MSB first)
        // ============================================================
        $display("\n===== PHASE 4: RANDOM STRESS (16 cycles, PC=0011, pht_sel=11) =====");
        pc       = 4'b0011;
        rand_seq = 16'b1101_1010_1110_0101;
        for (k = 15; k >= 0; k = k - 1) begin
            @(negedge clk);
            branch_detected = 1;
            branch_taken    = rand_seq[k];
            @(posedge clk); #1;
        end
        @(negedge clk);
        branch_detected = 0;
        branch_taken    = 0;

        @(posedge clk); #1;
        $display("\n===== SIMULATION COMPLETE =====");
        $finish;
    end

endmodule
