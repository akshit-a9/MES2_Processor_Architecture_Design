`timescale 1ns / 1ps

module tb_pipeline;




    reg  fast_clk;
    reg  rst_n;

    wire       slow_clk;
    wire [7:0] s1_data_out;
    wire [7:0] pr_data_out;
    wire [7:0] s2_result;

    pipeline_top dut (
        .fast_clk    (fast_clk),
        .rst_n       (rst_n),
        .slow_clk    (slow_clk),
        .s1_data_out (s1_data_out),
        .pr_data_out (pr_data_out),
        .s2_result   (s2_result)
    );


    initial fast_clk = 1'b0;
    always #5 fast_clk = ~fast_clk;

    initial begin
        rst_n = 1'b0;
        repeat (4) @(posedge fast_clk);   // hold reset for 4 fast_clk cycles
        @(negedge fast_clk);              // release on a negedge for clean timing
        rst_n = 1'b1;
        $display("\n[%0t ns] *** Reset released ***\n", $time);
    end

    initial begin
        $monitor("[%0t ns] fast_clk=%b slow_clk=%b | S1: out=%0d | PR: %0d | S2_result: %0d",
                 $time, fast_clk, slow_clk,
                 s1_data_out,
                 pr_data_out,
                 s2_result);
    end


    // Both PR and Stage2 update on posedge slow_clk (NBA semantics give clean 1-cycle separation)
    always @(posedge slow_clk) begin
        if (rst_n)
            $display("[%0t ns] ---- slow_clk POSEDGE: PR latches S1_out=%0d | Stage2 computes result=%0d (from old PR) ----",
                     $time, s1_data_out, s2_result);
    end

    initial begin
        wait (rst_n == 1'b1);
        repeat (120) @(posedge fast_clk);
        $display("\n[%0t ns] *** Simulation complete after 120 fast_clk cycles ***", $time);
        $finish;
    end

    initial begin
        $dumpfile("pipeline_sim.vcd");
        $dumpvars(0, tb_pipeline);
    end

endmodule
