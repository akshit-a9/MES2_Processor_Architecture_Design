module tee (
    input  wire [2:0] start_bank,
    input  wire [2:0] slot_offset,
    input  wire [2:0] start_row,
    output wire [2:0] row_out
);
    wire [3:0] sum = {1'b0, start_bank} + {1'b0, slot_offset};
    assign row_out = sum[3] ? (start_row + 3'd1) : start_row;
endmodule


module inst_cache_line #(
    parameter integer BANK_ID = 0
)(
    input  wire [2:0]  start_bank,
    input  wire [2:0]  slot_offset,
    input  wire [2:0]  start_row,
    output wire [31:0] instruction_out
);
    reg [31:0] mem [0:7];

    integer i;
    initial begin
        for (i = 0; i < 8; i = i + 1)
            mem[i] = 32'hA000_0000 | (i * 8 + BANK_ID);
    end

    wire [2:0] row_addr;
    tee t0 (
        .start_bank  (start_bank),
        .slot_offset (slot_offset),
        .start_row   (start_row),
        .row_out     (row_addr)
    );

    assign instruction_out = mem[row_addr];
endmodule


module fetch_unit_rs6000 (
    input  wire        clk,
    input  wire [31:0] start_address,
    output wire [2:0]  start_bank,
    output reg  [31:0] addr_reg,       // registered: aligns with inst_out in waveform
    output reg  [2:0]  bank_reg,       // registered: aligns with inst_out in waveform
    output reg  [31:0] inst_out_0,
    output reg  [31:0] inst_out_1,
    output reg  [31:0] inst_out_2,
    output reg  [31:0] inst_out_3,
    output reg  [31:0] inst_out_4,
    output reg  [31:0] inst_out_5,
    output reg  [31:0] inst_out_6,
    output reg  [31:0] inst_out_7
);
    assign start_bank      = start_address[4:2];
    wire [2:0] start_row   = start_address[7:5];

    wire [2:0] off0 = 3'd0 - start_bank;
    wire [2:0] off1 = 3'd1 - start_bank;
    wire [2:0] off2 = 3'd2 - start_bank;
    wire [2:0] off3 = 3'd3 - start_bank;
    wire [2:0] off4 = 3'd4 - start_bank;
    wire [2:0] off5 = 3'd5 - start_bank;
    wire [2:0] off6 = 3'd6 - start_bank;
    wire [2:0] off7 = 3'd7 - start_bank;

    wire [31:0] b0, b1, b2, b3, b4, b5, b6, b7;

    inst_cache_line #(.BANK_ID(0)) c0 (.start_bank(start_bank), .slot_offset(off0), .start_row(start_row), .instruction_out(b0));
    inst_cache_line #(.BANK_ID(1)) c1 (.start_bank(start_bank), .slot_offset(off1), .start_row(start_row), .instruction_out(b1));
    inst_cache_line #(.BANK_ID(2)) c2 (.start_bank(start_bank), .slot_offset(off2), .start_row(start_row), .instruction_out(b2));
    inst_cache_line #(.BANK_ID(3)) c3 (.start_bank(start_bank), .slot_offset(off3), .start_row(start_row), .instruction_out(b3));
    inst_cache_line #(.BANK_ID(4)) c4 (.start_bank(start_bank), .slot_offset(off4), .start_row(start_row), .instruction_out(b4));
    inst_cache_line #(.BANK_ID(5)) c5 (.start_bank(start_bank), .slot_offset(off5), .start_row(start_row), .instruction_out(b5));
    inst_cache_line #(.BANK_ID(6)) c6 (.start_bank(start_bank), .slot_offset(off6), .start_row(start_row), .instruction_out(b6));
    inst_cache_line #(.BANK_ID(7)) c7 (.start_bank(start_bank), .slot_offset(off7), .start_row(start_row), .instruction_out(b7));

    // MUX ROTATION: reorder bank outputs into fetch/program sequence.
    // inst_out_0 = instruction at start_address, inst_out_1 at +4, etc.
    function [31:0] mux8;
        input [2:0]  s;
        input [31:0] i0, i1, i2, i3, i4, i5, i6, i7;
        case (s)
            3'd0: mux8 = i0;
            3'd1: mux8 = i1;
            3'd2: mux8 = i2;
            3'd3: mux8 = i3;
            3'd4: mux8 = i4;
            3'd5: mux8 = i5;
            3'd6: mux8 = i6;
            3'd7: mux8 = i7;
            default: mux8 = 32'hx;
        endcase
    endfunction

    wire [2:0] s0 = start_bank + 3'd0;
    wire [2:0] s1 = start_bank + 3'd1;
    wire [2:0] s2 = start_bank + 3'd2;
    wire [2:0] s3 = start_bank + 3'd3;
    wire [2:0] s4 = start_bank + 3'd4;
    wire [2:0] s5 = start_bank + 3'd5;
    wire [2:0] s6 = start_bank + 3'd6;
    wire [2:0] s7 = start_bank + 3'd7;

    always @(posedge clk) begin
        addr_reg   <= start_address;
        bank_reg   <= start_bank;
        inst_out_0 <= mux8(s0, b0, b1, b2, b3, b4, b5, b6, b7);
        inst_out_1 <= mux8(s1, b0, b1, b2, b3, b4, b5, b6, b7);
        inst_out_2 <= mux8(s2, b0, b1, b2, b3, b4, b5, b6, b7);
        inst_out_3 <= mux8(s3, b0, b1, b2, b3, b4, b5, b6, b7);
        inst_out_4 <= mux8(s4, b0, b1, b2, b3, b4, b5, b6, b7);
        inst_out_5 <= mux8(s5, b0, b1, b2, b3, b4, b5, b6, b7);
        inst_out_6 <= mux8(s6, b0, b1, b2, b3, b4, b5, b6, b7);
        inst_out_7 <= mux8(s7, b0, b1, b2, b3, b4, b5, b6, b7);
    end

endmodule
