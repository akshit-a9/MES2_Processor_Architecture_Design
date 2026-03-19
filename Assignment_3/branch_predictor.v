`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.03.2026 23:42:38
// Design Name: 
// Module Name: branch_predictor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module branch_predictor(
    input wire clk,
    input wire rst,
    input wire taken,
    output reg [1:0] state
    );
    
    reg [1:0] next_state;
    
    always @ (posedge clk) begin
        if (rst)
            state <= 2'b11;
        else
            state <= next_state;
     end
     
     always @(*) begin
        case(state)
            2'b00: next_state = taken? 2'b01 : 2'b00;
            2'b01: next_state = taken? 2'b10 : 2'b00;
            2'b10: next_state = taken? 2'b11 : 2'b01;
            2'b11: next_state = taken? 2'b11 : 2'b10;
            default: next_state = 2'b11;
            endcase
     end
            
endmodule
