`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.03.2026 23:53:21
// Design Name: 
// Module Name: tb_branch_predictor
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


module tb_branch_predictor;

    reg clk;
    reg rst;
    reg taken;
    wire [1:0] state;
    integer i;
    integer seed;
    
    branch_predictor uut (
    .clk (clk),
    .rst (rst),
    .taken (taken),
    .state (state)
   ); 
   
   initial clk = 0;
   always #5 clk = ~clk;
   
   initial begin
   
   rst = 1;
   @(posedge clk); #1;
   $display("state = %b (expected 11)", state);
   rst = 0;
   
   taken = 1; 
   @(posedge clk); #1;
   $display("Taken = %b, state = %b", taken, state);
   
   taken = 1; 
   @(posedge clk); #1;
   $display("Taken = %b, state = %b", taken, state);
   
   taken = 0; 
   @(posedge clk); #1;
   $display("Taken = %b, state = %b", taken, state);
   
   taken = 0; 
   @(posedge clk); #1;
   $display("Taken = %b, state = %b", taken, state);
   
   taken = 0; 
   @(posedge clk); #1;
   $display("Taken = %b, state = %b", taken, state);
   
   taken = 0; 
   @(posedge clk); #1;
   $display("Taken = %b, state = %b", taken, state);
   
   taken = 0; 
   @(posedge clk); #1;
   $display("Taken = %b, state = %b", taken, state);
   
   seed = 37;
   for (i = 0; i < 15; i = i+1) begin
        taken = $random(seed) & 1;
        @(posedge clk); #1;
        $display("taken = %b, state = %b", taken, state);
    end
   
   $finish;
   
   end
    
        
endmodule
