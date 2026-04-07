// tb_pag.v
// Testbench for the PAg (Per-branch Adaptive, global PHT) predictor.
//
// Test phases (in order):
//   1. Reset            — verify prediction defaults to not-taken
//   2. Loop simulation  — 8T + 1NT repeated 3 times, single PC
//   3. Correlated branch simulation — two PCs alternating, T,T,NT pattern
//   4. Random stress    — 16-cycle hardcoded pseudo-random sequence
//
// Waveform output: pag.vcd  (open with GTKWave)

`timescale 1ns / 1ps

module tb_pag;

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

    // Cycle counter for display
    integer cycle_count;

    // -----------------------------------------------------------------
    // Instantiate PAg predictor
    // -----------------------------------------------------------------
    pag_predictor #(
        .HISTORY_BITS(4),
        .PC_BITS(4),
        .BHT_ENTRIES(16),
        .PHT_SIZE(16)
    ) dut (
        .clk            (clk),
        .reset          (reset),
        .branch_detected(branch_detected),
        .branch_taken   (branch_taken),
        .pc             (pc),
        .prediction     (prediction),
        .bht_out        (bht_out)
    );

    // -----------------------------------------------------------------
    // Clock generation — 10 ns period
    // -----------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------
    // Periodic display: cycle, pc, branch_detected, branch_taken, prediction, BHT row
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        $display("CYC=%0d | pc=%b branch_det=%b taken=%b | prediction=%b | bht_out=%b",
                 cycle_count, pc, branch_detected, branch_taken, prediction, bht_out);
    end

    // -----------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("pag.vcd");
        $dumpvars(0, tb_pag);
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
        // ============================================================
        $display("\n===== PHASE 2: LOOP SIMULATION (8T + 1NT, 3 repetitions, PC=0001) =====");
        pc = 4'b0001;
        for (rep = 0; rep < 3; rep = rep + 1) begin
            $display("-- Repetition %0d --", rep + 1);
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
        // Phase 3 — Correlated branches: two PCs (0001, 0010), T,T,NT × 4
        // Each PC has its own BHT row but shares the PHT.
        // ============================================================
        $display("\n===== PHASE 3: CORRELATED BRANCH SIMULATION (T,T,NT x4, PC alternates) =====");
        for (k = 0; k < 12; k = k + 1) begin
            @(negedge clk);
            branch_detected = 1;
            // Alternate between two branch PCs
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
        // Pattern: 16'b1101_1010_1110_0101 (MSB first)
        // ============================================================
        $display("\n===== PHASE 4: RANDOM STRESS (16 cycles, PC=0011) =====");
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
