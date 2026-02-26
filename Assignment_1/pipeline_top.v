`timescale 1ns / 1ps

// slow_clk = fast_clk / 4

module clk_divider (
    input  wire fast_clk,
    input  wire rst_n,
    output reg  slow_clk
);
    integer count;

    always @(posedge fast_clk or negedge rst_n) begin
        if (!rst_n) begin
            count    <= 0;
            slow_clk <= 1'b0;
        end else begin
            if (count == 1) begin
                slow_clk <= ~slow_clk;
                count    <= 0;
            end else begin
                count <= count + 1;
            end
        end
    end
endmodule


module stage1 (
    input  wire       fast_clk,
    input  wire       rst_n,
    input  wire [7:0] input_val,
    output reg  [7:0] data_out
);
    integer delay_cnt;
    integer rand_delay;
    reg     computing;

    always @(posedge fast_clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= 8'd0;
            delay_cnt <= 0;
            rand_delay<= 0;
            computing <= 1'b0;
        end else begin
            if (!computing) begin
                rand_delay <= ($random % 3) + 1;
                delay_cnt  <= 0;
                computing  <= 1'b1;
            end else begin
                if (delay_cnt < rand_delay - 1) begin
                    delay_cnt <= delay_cnt + 1;
                end else begin
                    data_out  <= input_val + 1'b1;
                    computing <= 1'b0;
                    delay_cnt <= 0;
                end
            end
        end
    end
endmodule

// Pipeline Register - Captures Stage 1's output on the POSITIVE edge of slow_clk.
// Stage 2 also triggers on posedge; Verilog NBA semantics ensure Stage 2 reads
// the old PR value while PR updates to the new Stage 1 output simultaneously.
module pipeline_register (
    input  wire       slow_clk,
    input  wire       rst_n,
    input  wire [7:0] d_in,
    output reg  [7:0] d_out
);
    always @(posedge slow_clk or negedge rst_n) begin
        if (!rst_n)
            d_out <= 8'd0;
        else
            d_out <= d_in;
    end
endmodule

// Stage 2
// s2_latch : captures the PR value immediately on posedge slow_clk (no delay)
// s2_result: computes (pr_data << 1) after a random 1-3 fast_clk cycle delay
module stage2 (
    input  wire       fast_clk,
    input  wire       slow_clk,
    input  wire       rst_n,
    input  wire [7:0] pr_data,
    output reg  [7:0] s2_latch,   // exact PR input, latched immediately
    output reg  [7:0] s2_result   // result after random fast-cycle delay
);
    // --- s2_latch: capture PR on posedge slow_clk, no extra delay ---
    always @(posedge slow_clk or negedge rst_n) begin
        if (!rst_n)
            s2_latch <= 8'd0;
        else
            s2_latch <= pr_data;
    end

    // --- s2_result: random 1-3 fast_clk delay then compute ---
    integer delay_cnt;
    integer rand_delay;
    reg     computing;
    reg [7:0] captured_pr;  // holds the PR value when computation starts

    always @(posedge fast_clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_result   <= 8'd0;
            delay_cnt   <= 0;
            rand_delay  <= 0;
            computing   <= 1'b0;
            captured_pr <= 8'd0;
        end else begin
            if (!computing) begin
                captured_pr <= s2_latch;       // snapshot the latched input
                rand_delay  <= ($random % 3);
                delay_cnt   <= 0;
                computing   <= 1'b1;
            end else begin
                if (delay_cnt < rand_delay - 1) begin
                    delay_cnt <= delay_cnt + 1;
                end else begin
                    s2_result <= captured_pr << 1;
                    computing <= 1'b0;
                    delay_cnt <= 0;
                end
            end
        end
    end
endmodule


module pipeline_top (
    input  wire       fast_clk,
    input  wire       rst_n,
    // Observation ports
    output wire       slow_clk,
    output wire [7:0] s1_data_out,
    output wire [7:0] pr_data_out,
    output wire [7:0] s2_latch,
    output wire [7:0] s2_result
);
    // Stage 1 always increments the last value committed by the PR
    wire [7:0] input_to_s1 = pr_data_out;

    clk_divider u_clk_div (
        .fast_clk(fast_clk),
        .rst_n   (rst_n),
        .slow_clk(slow_clk)
    );

    stage1 u_stage1 (
        .fast_clk (fast_clk),
        .rst_n    (rst_n),
        .input_val(input_to_s1),
        .data_out (s1_data_out)
    );

    pipeline_register u_pr (
        .slow_clk(slow_clk),
        .rst_n   (rst_n),
        .d_in    (s1_data_out),
        .d_out   (pr_data_out)
    );

    stage2 u_stage2 (
        .fast_clk (fast_clk),
        .slow_clk (slow_clk),
        .rst_n    (rst_n),
        .pr_data  (pr_data_out),
        .s2_latch (s2_latch),
        .s2_result(s2_result)
    );

endmodule
