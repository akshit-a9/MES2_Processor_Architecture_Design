// =============================================================
// RS/6000-Style Fetch Alignment Unit
// =============================================================
// Demonstrates what happens when a fetch address is misaligned.
// If the lower 4 bits (nibble) of the PC are non-zero, the
// address is misaligned — we round UP to the next cache-line
// boundary and signal a stall for one cycle.
// If aligned, fetch proceeds immediately with no stall.
// =============================================================

module fetch_align (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc_in,       // requested fetch address
    output reg  [31:0] fetch_addr,  // actual address sent to I-cache
    output reg         stall,       // 1 = misaligned, stall this cycle
    output reg         aligned      // 1 = fetch is aligned, no stall
);

    // Cache line size = 16 bytes (4-bit offset, nibble = bits [3:0])
    // Aligned  => pc_in[3:0] == 4'h0
    // Misaligned => anything else → round up to next 16-byte boundary

    wire misaligned = (pc_in[3:0] != 4'h0);

    // Next aligned address: clear lower nibble, add 16
    wire [31:0] rounded_up = {pc_in[31:4], 4'h0} + 32'h10;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fetch_addr <= 32'h0;
            stall      <= 1'b0;
            aligned    <= 1'b1;
        end else begin
            if (misaligned) begin
                // Misaligned: round up, stall for one cycle
                fetch_addr <= rounded_up;
                stall      <= 1'b1;
                aligned    <= 1'b0;
            end else begin
                // Aligned: fetch normally, no stall
                fetch_addr <= pc_in;
                stall      <= 1'b0;
                aligned    <= 1'b1;
            end
        end
    end

endmodule
