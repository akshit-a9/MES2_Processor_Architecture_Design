// tb_gag.v
// Testbench for the GAg (Global Adaptive, global history) predictor.
//
// Test phases (in order):
//   1. Reset            — verify prediction defaults to not-taken
//   2. Loop simulation  — 8T + 1NT repeated 3 times (predictor should settle)
//   3. Correlated branch simulation — fixed PC, alternating T/T/NT pattern
//   4. Random stress    — 16-cycle hardcoded pseudo-random sequence
//
// Waveform output: gag.vcd  (open with GTKWave)

`timescale 1ns / 1ps

module tb_gag;

    reg        clk;
    reg        reset;
    reg        branch_detected;
    reg        branch_taken;
    wire       prediction;
    wire [3:0] ghr_out;

    // Cycle counter for display
    integer cycle_count;

    gag_predictor #(
        .HISTORY_BITS(4),
        .PHT_SIZE(16)
    ) dut (
        .clk            (clk),
        .reset          (reset),
        .branch_detected(branch_detected),
        .branch_taken   (branch_taken),
        .prediction     (prediction),
        .ghr_out        (ghr_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;


    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        $display("CYC=%0d | branch_det=%b taken=%b | prediction=%b | ghr=%b",
                 cycle_count, branch_detected, branch_taken, prediction, ghr_out);
    end


    initial begin
        $dumpfile("gag.vcd");
        $dumpvars(0, tb_gag);
    end

    integer rep;   // repetition loop variable
    integer k;     // general loop variable
    reg [15:0] rand_seq; // pseudo-random sequence (hardcoded)

    initial begin
        // Initialise
        cycle_count   = 0;
        branch_detected = 0;
        branch_taken    = 0;
        reset           = 1;

        $display("\n===== PHASE 1: RESET =====");
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;
        $display("Reset released. Expect prediction = 0 (not-taken).");

        $display("\n===== PHASE 2: LOOP SIMULATION (8T + 1NT, 3 repetitions) =====");
        for (rep = 0; rep < 3; rep = rep + 1) begin
            $display("-- Repetition %0d --", rep + 1);
            // 8 taken branches
            for (k = 0; k < 8; k = k + 1) begin
                @(negedge clk);
                branch_detected = 1;
                branch_taken    = 1;
                @(posedge clk); #1;
            end
            // 1 not-taken branch (loop exit)
            @(negedge clk);
            branch_detected = 1;
            branch_taken    = 0;
            @(posedge clk); #1;
        end
        @(negedge clk);
        branch_detected = 0;
        branch_taken    = 0;

        $display("\n===== PHASE 3: CORRELATED BRANCH SIMULATION (T,T,NT × 4) =====");
        for (k = 0; k < 12; k = k + 1) begin
            @(negedge clk);
            branch_detected = 1;
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

        $display("\n===== PHASE 4: RANDOM STRESS (16 cycles) =====");
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

        // One idle cycle then finish
        @(posedge clk); #1;
        $display("\n===== SIMULATION COMPLETE =====");
        $finish;
    end

endmodule
