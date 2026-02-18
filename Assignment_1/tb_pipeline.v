// =============================================================================
// tb_pipeline.v
// Testbench for the 2-Stage Dummy Pipeline with Clock Division
//
// Simulation flow:
//   1. Assert reset for a few fast_clk cycles.
//   2. Release reset and let the pipeline run for several slow_clk periods.
//   3. $monitor prints every signal change; $display marks slow_clk edges.
//   4. Simulation ends after SIM_CYCLES fast_clk cycles.
//
// Expected observations:
//   - Stage 1 asserts data_ready at a random fast_clk cycle within each
//     slow_clk period.
//   - PR captures Stage 1's output on the NEGEDGE of slow_clk.
//   - Stage 2 result = PR value * 2, updated on the POSEDGE of slow_clk.
// =============================================================================

`timescale 1ns / 1ps

module tb_pipeline;

    // -----------------------------------------------------------------------
    // Parameters (must match pipeline_top parameters)
    // -----------------------------------------------------------------------
    localparam DATA_WIDTH    = 8;
    localparam CLK_DIV_RATIO = 4;   // slow_clk = fast_clk / 4
    localparam MAX_DELAY     = 3;
    localparam FAST_CLK_HALF = 5;   // fast_clk period = 10 ns  (100 MHz)
    localparam SIM_CYCLES    = 120; // total fast_clk cycles to simulate

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    reg  fast_clk;
    reg  rst_n;

    wire                  slow_clk;
    wire [DATA_WIDTH-1:0] s1_data_out;
    wire                  s1_data_ready;
    wire [DATA_WIDTH-1:0] pr_data_out;
    wire [DATA_WIDTH-1:0] s2_result;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    pipeline_top #(
        .DATA_WIDTH   (DATA_WIDTH),
        .CLK_DIV_RATIO(CLK_DIV_RATIO),
        .MAX_DELAY    (MAX_DELAY)
    ) dut (
        .fast_clk     (fast_clk),
        .rst_n        (rst_n),
        .slow_clk     (slow_clk),
        .s1_data_out  (s1_data_out),
        .s1_data_ready(s1_data_ready),
        .pr_data_out  (pr_data_out),
        .s2_result    (s2_result)
    );

    // -----------------------------------------------------------------------
    // fast_clk generation
    // -----------------------------------------------------------------------
    initial fast_clk = 1'b0;
    always #(FAST_CLK_HALF) fast_clk = ~fast_clk;

    // -----------------------------------------------------------------------
    // Reset sequence
    // -----------------------------------------------------------------------
    initial begin
        rst_n = 1'b0;
        repeat (4) @(posedge fast_clk);   // hold reset for 4 fast_clk cycles
        @(negedge fast_clk);              // release on a negedge for clean timing
        rst_n = 1'b1;
        $display("\n[%0t ns] *** Reset released ***\n", $time);
    end

    // -----------------------------------------------------------------------
    // $monitor — fires on ANY signal change
    // -----------------------------------------------------------------------
    initial begin
        $monitor("[%0t ns] fast_clk=%b slow_clk=%b | S1: out=%0d ready=%b | PR: %0d | S2_result: %0d",
                 $time, fast_clk, slow_clk,
                 s1_data_out, s1_data_ready,
                 pr_data_out,
                 s2_result);
    end

    // -----------------------------------------------------------------------
    // Annotate slow_clk edges for readability
    // -----------------------------------------------------------------------
    always @(posedge slow_clk) begin
        if (rst_n)
            $display("[%0t ns] ---- slow_clk POSEDGE: Stage2 latches PR=%0d  =>  result=%0d ----",
                     $time, pr_data_out, s2_result);
    end

    always @(negedge slow_clk) begin
        if (rst_n)
            $display("[%0t ns] ==== slow_clk NEGEDGE: PR latches S1_out=%0d ====",
                     $time, s1_data_out);
    end

    // -----------------------------------------------------------------------
    // Annotate Stage 1 ready pulses
    // -----------------------------------------------------------------------
    always @(posedge fast_clk) begin
        if (rst_n && s1_data_ready)
            $display("[%0t ns]   >> Stage1 READY: data_out=%0d (will be captured by PR at next slow_clk negedge)",
                     $time, s1_data_out);
    end

    // -----------------------------------------------------------------------
    // End simulation
    // -----------------------------------------------------------------------
    integer cycle_count;
    initial begin
        cycle_count = 0;
        wait (rst_n == 1'b1);
        repeat (SIM_CYCLES) @(posedge fast_clk);
        $display("\n[%0t ns] *** Simulation complete after %0d fast_clk cycles ***", $time, SIM_CYCLES);
        $finish;
    end

    // -----------------------------------------------------------------------
    // Optional: VCD dump for waveform viewing (GTKWave / Vivado simulator)
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("pipeline_sim.vcd");
        $dumpvars(0, tb_pipeline);
    end

endmodule
