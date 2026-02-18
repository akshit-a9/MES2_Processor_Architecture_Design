// =============================================================================
// pipeline_top.v
// 2-Stage Dummy Pipeline with Clock Division and Pipeline Register (PR)
//
// Architecture:
//   fast_clk  --> Stage 1 (increment + random delay) --> PR (latched on negedge slow_clk) --> Stage 2
//   slow_clk  = fast_clk / CLK_DIV_RATIO
//
// Stage 1: Increments an 8-bit counter. The result becomes "ready" at a
//          random cycle within the fast_clk domain (simulated via $random).
//          NOTE: $random is NOT synthesizable; this is for simulation only.
//
// PR      : Pipeline Register. Captures Stage 1's output on the NEGATIVE edge
//           of slow_clk, regardless of when Stage 1 finished.
//
// Stage 2: Receives the PR value and doubles it (simple computation).
// =============================================================================

`timescale 1ns / 1ps

// ---------------------------------------------------------------------------
// Clock Divider
// Generates slow_clk with period = CLK_DIV_RATIO * fast_clk period.
// slow_clk goes HIGH for the first half and LOW for the second half.
// ---------------------------------------------------------------------------
module clk_divider #(
    parameter CLK_DIV_RATIO = 4   // slow_clk period = 4 x fast_clk period
)(
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
            if (count == (CLK_DIV_RATIO/2 - 1)) begin
                slow_clk <= ~slow_clk;
                count    <= 0;
            end else begin
                count <= count + 1;
            end
        end
    end
endmodule


// ---------------------------------------------------------------------------
// Stage 1: Incrementer with simulated random-latency "ready" signal
//
// On each fast_clk posedge, if not already ready, a random number of cycles
// (1 to MAX_DELAY) is counted down. When the counter hits zero, data_out
// is set to (input_val + 1) and data_ready is asserted for one cycle.
//
// The "random delay" models a computation that can finish at any point in
// the fast_clk domain.
// ---------------------------------------------------------------------------
module stage1 #(
    parameter DATA_WIDTH = 8,
    parameter MAX_DELAY  = 3    // max random delay in fast_clk cycles
)(
    input  wire                  fast_clk,
    input  wire                  rst_n,
    input  wire [DATA_WIDTH-1:0] input_val,   // value to increment
    output reg  [DATA_WIDTH-1:0] data_out,    // incremented result
    output reg                   data_ready   // pulses HIGH when data_out is valid
);
    integer delay_cnt;
    integer rand_delay;
    reg     computing;

    always @(posedge fast_clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out   <= {DATA_WIDTH{1'b0}};
            data_ready <= 1'b0;
            computing  <= 1'b0;
            delay_cnt  <= 0;
            rand_delay <= 0;
        end else begin
            data_ready <= 1'b0;   // default: de-assert each cycle

            if (!computing) begin
                // Start a new computation: pick a random delay (1..MAX_DELAY)
                rand_delay <= ($random % MAX_DELAY) + 1;
                delay_cnt  <= 0;
                computing  <= 1'b1;
            end else begin
                if (delay_cnt < rand_delay - 1) begin
                    delay_cnt <= delay_cnt + 1;
                end else begin
                    // Computation done
                    data_out   <= input_val + 1'b1;
                    data_ready <= 1'b1;
                    computing  <= 1'b0;
                    delay_cnt  <= 0;
                end
            end
        end
    end
endmodule


// ---------------------------------------------------------------------------
// Pipeline Register (PR)
// Captures Stage 1 output on the NEGATIVE edge of slow_clk.
// The data is held stable until the next negedge of slow_clk.
// ---------------------------------------------------------------------------
module pipeline_register #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  slow_clk,
    input  wire                  rst_n,
    input  wire [DATA_WIDTH-1:0] d_in,
    output reg  [DATA_WIDTH-1:0] d_out
);
    always @(negedge slow_clk or negedge rst_n) begin
        if (!rst_n)
            d_out <= {DATA_WIDTH{1'b0}};
        else
            d_out <= d_in;   // latch whatever Stage 1 has at this moment
    end
endmodule


// ---------------------------------------------------------------------------
// Stage 2: Simple computation on PR output
// Doubles the received value (left-shift by 1).
// Registered on the positive edge of slow_clk.
// ---------------------------------------------------------------------------
module stage2 #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  slow_clk,
    input  wire                  rst_n,
    input  wire [DATA_WIDTH-1:0] pr_data,
    output reg  [DATA_WIDTH-1:0] result
);
    always @(posedge slow_clk or negedge rst_n) begin
        if (!rst_n)
            result <= {DATA_WIDTH{1'b0}};
        else
            result <= pr_data << 1;   // double the value
    end
endmodule


// ---------------------------------------------------------------------------
// Top-Level: Wires everything together
// ---------------------------------------------------------------------------
module pipeline_top #(
    parameter DATA_WIDTH    = 8,
    parameter CLK_DIV_RATIO = 4,
    parameter MAX_DELAY     = 3
)(
    input  wire                  fast_clk,
    input  wire                  rst_n,
    // Observation ports (for testbench / ILA)
    output wire                  slow_clk,
    output wire [DATA_WIDTH-1:0] s1_data_out,
    output wire                  s1_data_ready,
    output wire [DATA_WIDTH-1:0] pr_data_out,
    output wire [DATA_WIDTH-1:0] s2_result
);
    // -----------------------------------------------------------------------
    // Internal: input_val fed back from PR output so Stage 1 always increments
    // the last committed value (creates a running chain of increments).
    // -----------------------------------------------------------------------
    wire [DATA_WIDTH-1:0] input_to_s1 = pr_data_out;

    // Clock Divider
    clk_divider #(
        .CLK_DIV_RATIO(CLK_DIV_RATIO)
    ) u_clk_div (
        .fast_clk(fast_clk),
        .rst_n   (rst_n),
        .slow_clk(slow_clk)
    );

    // Stage 1
    stage1 #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_DELAY (MAX_DELAY)
    ) u_stage1 (
        .fast_clk  (fast_clk),
        .rst_n     (rst_n),
        .input_val (input_to_s1),
        .data_out  (s1_data_out),
        .data_ready(s1_data_ready)
    );

    // Pipeline Register (PR) — latches on negedge of slow_clk
    pipeline_register #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_pr (
        .slow_clk(slow_clk),
        .rst_n   (rst_n),
        .d_in    (s1_data_out),
        .d_out   (pr_data_out)
    );

    // Stage 2
    stage2 #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_stage2 (
        .slow_clk(slow_clk),
        .rst_n   (rst_n),
        .pr_data (pr_data_out),
        .result  (s2_result)
    );

endmodule
