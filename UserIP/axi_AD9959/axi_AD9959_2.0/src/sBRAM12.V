`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MIT_HARVARD CUA
// Engineer: Chi Shu
// 
// Create Date: 11/03/2017 10:33:57 AM
// Design Name: 
// Module Name: sBRAM12
// Project Name: FPGA controlled DDS AD9959
// Target Devices: CMOD A7-35T
// Tool Versions: VIVADO 2017.2.1
// Description: 
// Dual_Port Block Ram with two port.
// port 1 wirte first
// port 2 read only
// parameter Bram depth
// Reference to ug901-vivado-synthesis.pdf P116
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sBRAM12(
    clk1,clk2,
    en1, en2,
    we1,
    addr1,addr2,
    di1,
    do1,do2
    );
    parameter addrdepth = 12;
    parameter width = 4;
    input clk1,clk2,en1,en2,we1;
    input [addrdepth-1:0] addr1, addr2;
    input [width-1:0] di1;
    output reg [width-1:0] do1,do2;
    reg [width-1:0] bram [2**addrdepth-1:0];
    always @(posedge clk1)
    begin
        if(en1)
            begin
            if(we1)
                begin
                bram[addr1]<=di1;
                do1<=di1;
                end
            else
                do1<=bram[addr1];
            end
    end 
    always @(posedge clk2)
    begin
        if(en2)
            begin
                do2<=bram[addr2];
            end
    end 
      
endmodule
