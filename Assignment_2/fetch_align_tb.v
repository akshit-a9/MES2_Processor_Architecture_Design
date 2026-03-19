// =============================================================
// Testbench: fetch_align_tb
// =============================================================
// Drives several PC values through the fetch alignment unit:
//   1. Aligned address     → no stall, fetch_addr = pc_in
//   2. Misaligned address  → stall=1, fetch_addr rounded up
//   3. Another misaligned  → stall=1, rounded up
//   4. Aligned again       → back to normal
//
// In Vivado, look at the waveform signals:
//   pc_in, fetch_addr, stall, aligned
// You will clearly see stall pulse HIGH on misaligned cycles
// and fetch_addr jump to the next cache-line boundary.
// =============================================================

`timescale 1ns / 1ps

module fetch_align_tb;

    // ---- DUT signals ----
    reg         clk;
    reg         rst;
    reg  [31:0] pc_in;
    wire [31:0] fetch_addr;
    wire        stall;
    wire        aligned;

    // ---- Instantiate DUT ----
    fetch_align uut (
        .clk        (clk),
        .rst        (rst),
        .pc_in      (pc_in),
        .fetch_addr (fetch_addr),
        .stall      (stall),
        .aligned    (aligned)
    );

    // ---- Clock: 10 ns period ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Stimulus ----
    initial begin
        // -- Reset --
        rst   = 1;
        pc_in = 32'h0000_0000;
        @(posedge clk); #1;
        rst = 0;

        // -------------------------------------------------------
        // Cycle 1: ALIGNED address (0x0000_1000, nibble = 0x0)
        // Expect: stall=0, aligned=1, fetch_addr=0x0000_1000
        // -------------------------------------------------------
        pc_in = 32'h0000_1000;
        @(posedge clk); #1;
        $display("Cycle 1 | pc_in=%h | fetch_addr=%h | stall=%b | aligned=%b | %s",
                 pc_in, fetch_addr, stall, aligned,
                 (stall == 0) ? "OK - No stall" : "STALL");

        // -------------------------------------------------------
        // Cycle 2: MISALIGNED address (0x0000_1004, nibble = 0x4)
        // Expect: stall=1, aligned=0, fetch_addr=0x0000_1010 (rounded up)
        // -------------------------------------------------------
        pc_in = 32'h0000_1004;
        @(posedge clk); #1;
        $display("Cycle 2 | pc_in=%h | fetch_addr=%h | stall=%b | aligned=%b | %s",
                 pc_in, fetch_addr, stall, aligned,
                 (stall == 1) ? "STALL - Misaligned, rounded to next line" : "OK");

        // -------------------------------------------------------
        // Cycle 3: MISALIGNED address (0x0000_2008, nibble = 0x8)
        // Expect: stall=1, aligned=0, fetch_addr=0x0000_2010
        // -------------------------------------------------------
        pc_in = 32'h0000_2008;
        @(posedge clk); #1;
        $display("Cycle 3 | pc_in=%h | fetch_addr=%h | stall=%b | aligned=%b | %s",
                 pc_in, fetch_addr, stall, aligned,
                 (stall == 1) ? "STALL - Misaligned, rounded to next line" : "OK");

        // -------------------------------------------------------
        // Cycle 4: MISALIGNED address (0x0000_300C, nibble = 0xC)
        // Expect: stall=1, aligned=0, fetch_addr=0x0000_3010
        // -------------------------------------------------------
        pc_in = 32'h0000_300C;
        @(posedge clk); #1;
        $display("Cycle 4 | pc_in=%h | fetch_addr=%h | stall=%b | aligned=%b | %s",
                 pc_in, fetch_addr, stall, aligned,
                 (stall == 1) ? "STALL - Misaligned, rounded to next line" : "OK");

        // -------------------------------------------------------
        // Cycle 5: ALIGNED again (0x0000_4000, nibble = 0x0)
        // Expect: stall=0, aligned=1, fetch_addr=0x0000_4000
        // -------------------------------------------------------
        pc_in = 32'h0000_4000;
        @(posedge clk); #1;
        $display("Cycle 5 | pc_in=%h | fetch_addr=%h | stall=%b | aligned=%b | %s",
                 pc_in, fetch_addr, stall, aligned,
                 (stall == 0) ? "OK - No stall" : "STALL");

        // -------------------------------------------------------
        // Cycle 6: Branch target misalignment (0x0000_5006)
        // Simulates a branch landing mid-cache-line
        // Expect: stall=1, fetch_addr=0x0000_5010
        // -------------------------------------------------------
        pc_in = 32'h0000_5006;
        @(posedge clk); #1;
        $display("Cycle 6 | pc_in=%h | fetch_addr=%h | stall=%b | aligned=%b | %s (branch target)",
                 pc_in, fetch_addr, stall, aligned,
                 (stall == 1) ? "STALL - Branch target misaligned" : "OK");

        // -------------------------------------------------------
        // Cycle 7: ALIGNED (0x0000_5010 — the corrected address)
        // After hardware fixed the branch target address
        // -------------------------------------------------------
        pc_in = 32'h0000_5010;
        @(posedge clk); #1;
        $display("Cycle 7 | pc_in=%h | fetch_addr=%h | stall=%b | aligned=%b | %s",
                 pc_in, fetch_addr, stall, aligned,
                 (stall == 0) ? "OK - Fetch resumes normally" : "STALL");

        $display("");
        $display("Simulation complete.");
        $finish;
    end

endmodule
