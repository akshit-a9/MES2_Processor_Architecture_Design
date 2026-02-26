`timescale 1ns / 1ps

module tb_pipeline;




    reg  fast_clk;
    reg  rst_n;

    wire       slow_clk;
    wire [7:0] s1_data_in;
    wire [7:0] s1_data_out;
    wire [7:0] pr_data_in;
    wire [7:0] pr_data_out;
    wire [7:0] s2_latch;
    wire [7:0] s2_result;

    pipeline_top dut (
        .fast_clk    (fast_clk),
        .rst_n       (rst_n),
        .slow_clk    (slow_clk),
        .s1_data_in  (s1_data_in),
        .s1_data_out (s1_data_out),
        .pr_data_in  (pr_data_in),
        .pr_data_out (pr_data_out),
        .s2_latch    (s2_latch),
        .s2_result   (s2_result)
    );


    initial fast_clk = 1'b0;
    always #5 fast_clk = ~fast_clk;

    initial begin
        rst_n = 1'b0;
        repeat (4) @(posedge fast_clk);  
        @(negedge fast_clk);          
        rst_n = 1'b1;
        $display("\n[%0t ns] *** Reset released ***\n", $time);
    end

    initial begin
        $monitor("[%0t ns] fast_clk=%b slow_clk=%b | S1_in=%0d S1_out=%0d | PR_in=%0d PR_out=%0d | S2_latch=%0d S2_result=%0d",
                 $time, fast_clk, slow_clk,
                 s1_data_in,
                 s1_data_out,
                 pr_data_in,
                 pr_data_out,
                 s2_latch,
                 s2_result);
    end


    always @(posedge slow_clk) begin
        if (rst_n)
            $display("[%0t ns] ---- slow_clk POSEDGE: PR=%0d -> S2_latch captures PR (no delay); S2_result=%0d (random-delay output) ----",
                     $time, pr_data_out, s2_result);
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
