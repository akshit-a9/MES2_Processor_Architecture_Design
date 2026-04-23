`timescale 1ns / 1ps

module fetch_rs6000_tb;

    reg         clk;
    reg  [31:0] start_address;
    wire [2:0]  start_bank;
    wire [31:0] addr_reg;
    wire [2:0]  bank_reg;
    wire [31:0] inst_out_0, inst_out_1, inst_out_2, inst_out_3;
    wire [31:0] inst_out_4, inst_out_5, inst_out_6, inst_out_7;

    fetch_unit_rs6000 uut (
        .clk          (clk),
        .start_address(start_address),
        .start_bank   (start_bank),
        .addr_reg     (addr_reg),
        .bank_reg     (bank_reg),
        .inst_out_0   (inst_out_0), .inst_out_1(inst_out_1),
        .inst_out_2   (inst_out_2), .inst_out_3(inst_out_3),
        .inst_out_4   (inst_out_4), .inst_out_5(inst_out_5),
        .inst_out_6   (inst_out_6), .inst_out_7(inst_out_7)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task check;
        input [31:0] addr;
        input [31:0] e0, e1, e2, e3, e4, e5, e6, e7;
        reg pass;
        begin
            @(posedge clk);
            start_address = addr;
            @(posedge clk); #1;
            pass = (inst_out_0 == e0) && (inst_out_1 == e1) &&
                   (inst_out_2 == e2) && (inst_out_3 == e3) &&
                   (inst_out_4 == e4) && (inst_out_5 == e5) &&
                   (inst_out_6 == e6) && (inst_out_7 == e7);
            $display("addr=%h  bank=%0d  row=%0d  |  %h %h %h %h  %h %h %h %h  |  %s",
                     addr_reg, bank_reg, addr_reg[7:5],
                     inst_out_0, inst_out_1, inst_out_2, inst_out_3,
                     inst_out_4, inst_out_5, inst_out_6, inst_out_7,
                     pass ? "PASS" : "*** FAIL ***");
        end
    endtask

    initial begin
        start_address = 32'h0;
        @(posedge clk); #1;

        $display("");
        $display("============================================================");
        $display(" RS/6000 T-Circuit Fetch  -  A[N] = 0xA000_00NN");
        $display(" Outputs in fetch/program order:");
        $display(" inst_out_0 = instruction at start_address, inst_out_K at +4*K");
        $display(" addr        bank row  inst_out_0..7                  result");
        $display("============================================================");

        // addr=0x2000  bank=0  row=0
        // fetch seq starts at bank0/row0 -> A0,A1,A2,A3,A4,A5,A6,A7
        check(32'h2000,
              32'hA0000000, 32'hA0000001, 32'hA0000002, 32'hA0000003,
              32'hA0000004, 32'hA0000005, 32'hA0000006, 32'hA0000007);

        // addr=0x200C  bank=3  row=0
        // fetch seq starts at bank3/row0=A3, wraps past bank7 into row1
        // -> A3,A4,A5,A6,A7,A8,A9,A10
        check(32'h200C,
              32'hA0000003, 32'hA0000004, 32'hA0000005, 32'hA0000006,
              32'hA0000007, 32'hA0000008, 32'hA0000009, 32'hA000000A);

        // addr=0x2018  bank=6  row=0
        // fetch seq: A6,A7,A8,A9,A10,A11,A12,A13
        check(32'h2018,
              32'hA0000006, 32'hA0000007, 32'hA0000008, 32'hA0000009,
              32'hA000000A, 32'hA000000B, 32'hA000000C, 32'hA000000D);

        // addr=0x201C  bank=7  row=0
        // fetch seq: A7,A8,A9,A10,A11,A12,A13,A14
        check(32'h201C,
              32'hA0000007, 32'hA0000008, 32'hA0000009, 32'hA000000A,
              32'hA000000B, 32'hA000000C, 32'hA000000D, 32'hA000000E);

        // addr=0x2020  bank=0  row=1
        // fetch seq: A8,A9,A10,A11,A12,A13,A14,A15
        check(32'h2020,
              32'hA0000008, 32'hA0000009, 32'hA000000A, 32'hA000000B,
              32'hA000000C, 32'hA000000D, 32'hA000000E, 32'hA000000F);

        // addr=0x2034  bank=5  row=1
        // fetch seq: A13,A14,A15,A16,A17,A18,A19,A20
        check(32'h2034,
              32'hA000000D, 32'hA000000E, 32'hA000000F, 32'hA0000010,
              32'hA0000011, 32'hA0000012, 32'hA0000013, 32'hA0000014);

        $display("============================================================");
        $display(" All fetches: 1 cycle, 8 instructions, no stall.");
        $display("============================================================");
        $display("");
        $finish;
    end

endmodule
