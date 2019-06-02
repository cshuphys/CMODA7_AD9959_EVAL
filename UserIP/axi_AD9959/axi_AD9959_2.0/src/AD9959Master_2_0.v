`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MIT_HARVARD CUA
// Engineer: Chi Shu
// Create Date: 2017/10/07 15:10:49
// Design Name: 
// Module Name: AD9959Master
// Project Name: FPGA controlled DDS AD9959
// Target Devices: CMOD A7-35T
// Tool Versions: VIVADO 2017.2.1
// Description: 
// parallel to serial converter for ad9959
// It updates corresponding register to AD9959 by spi mode depending UPDATE_COMPONENTS
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

parameter  CSR_addr=5'h00, FR1_addr=5'h01,FR2_addr=5'h02,CFR_addr=5'h03,
                CFTW0_addr=5'h04,CPOW0_addr=5'h05,ACR_addr=5'h06,      
                LSRR_addr=5'h07,RDW_addr=5'h08,FDW_addr=5'h09,
                CW1_addr=5'h0A,CW2_addr=5'h0B,CW3_addr=5'h0C,CW4_addr=5'h0D,
                CW5_addr=5'h0E,CW6_addr=5'h0F,CW7_addr=5'h10,CW8_addr=5'h11,
                CW9_addr=5'h12,CW10_addr=5'h13,CW11_addr=5'h14,CW12_addr=5'h15,
                CW13_addr=5'h16,CW14_addr=5'h17,CW15_addr=5'h18;

module AD9959Master_2_0(
    input reset,
    input [4:0] clk_divider_in,
    output [4:0] clk_divider_out,
    input clk,
    input [7:0] CSR,
    input [23:0] FR1,CFR,ACR,
    input [15:0] FR2,CPOW0,LSRR,
    input [31:0] CFTW0,RDW,FDW,CW1,CW2,CW3,CW4,CW5,CW6,CW7,CW8,CW9,CW10,CW11,CW12,CW13,CW14,CW15,
    input [0:24] UPDATE_COMPONENTS, //csr highest bit
    input UPDATE,
    output UPDATE_DONE,
    //
    input [3:0] reg_addr,
    output reg [31:0] reg_r,
    output reg [3:0] Ch_Enable,
    //board pin
    input W10_I,W1_I,W2_I,W3_I,
    inout W10_O,W1_O,W2_O,W3_O,
    output W7_O,
    output CS_bar,
    output SCLK,
    inout [3:0] SDIO,
    input re,
    input [4:0] RADDR,
    output [31:0] RDATA,
    input io_update,master_reset,pwr_dwn,
    output IO_UPDATE,//not be controlled inside current version
    output MASTER_RESET,//not be controlled inside current version
    output PWR_DWN,//not be controlled inside current version
    output [3:0] sdio_check,
    output csb_check,sclk_check
    );
    reg [7:0] csr=8'hF0;
    reg [23:0] fr1=24'hD00000,cfr=24'h000300,acr=24'h0013FF;
    reg [15:0] fr2=16'h0, cpow0=16'h0, lsrr=16'h0;
    reg [31:0] cftw0=32'h28F5C28F, rdw=32'h0,fdw=32'h0,
               cw1=32'h0,cw2=32'h0,cw3=32'h0,cw4=32'h0,cw5=32'h0,cw6=32'h0,cw7=32'h0,
               cw8=32'h0,cw9=32'h0,cw10=32'h0,cw11=32'h0,cw12=32'h0,cw13=32'h0,cw14=32'h0,cw15=32'h0;
    reg [0:24] update_components=25'b0;//[0] means the csr which is the highest prioriy in update;
    reg update_done=1'b0,update=1'b0;
    reg cs=1'b0,sclk=1'b1;
    reg [3:0] sdio=4'b0;
    reg [1:0] state=2'b00;
    reg io_update_en = 0;
    reg readwrite_bar=1'b0; //0 means write, 1 means read;
    reg [39:0] wdata;
    reg [6:0] p_wdata=6'd39;
    reg tpre_counter=1'b1;
    reg [4:0] p_rdata=5'd31;
    reg [31:0] rdata;
    reg sdio_en=1'b1;
    reg wire_mode = 0;  //0 means 2 wire, 1 means 4 wire;
    reg software_reset = 0;
    //tristate buffer
    assign CS_bar =~cs;
    assign SCLK = sclk;
    assign SDIO = sdio_en ? sdio : 4'bZZZZ;
    assign IO_UPDATE = io_update & io_update_en;
    assign MASTER_RESET = master_reset|software_reset;
    assign PWR_DWN = pwr_dwn;
    //evaluation board jumper
    assign W7_O = 1'b1;
    assign W10_O=1'bZ;
    assign W1_O = 1'bZ;
    assign W2_O = 1'bZ;
    assign W3_O = 1'bZ;
    //debug check
    assign sdio_check = sdio;
    assign sclk_check = sclk;
    assign csb_check = ~cs;
    assign UPDATE_DONE = update_done;
    assign RDATA = rdata;
    reg [4:0] clk_counter = 5'h1F, clk_divider = 5'h1F;
    assign clk_divider_out = clk_divider;

    initial begin
    if(csr[2:1] != 0)
        begin
        csr[2:1] = 0;
        wire_mode = 0;
        end
    Ch_Enable = 4'hF;
    end
    always @(posedge clk)
    begin
    if(reset)
        begin
        Ch_Enable <=4'hF;
        software_reset <= 1;        //master reset for ad9959
        state <= 2'b00;
        wire_mode <= 0;
        readwrite_bar <=1'b0;
        update_done <= 1'b0;
        update <= 1'b0;
        //initial value for sdio and other port
        cs <= 1'b0;
        sclk <= 1'b1;
        sdio <= 4'b0;
        io_update_en <= 0;
        sdio_en <= 1'b1;
        clk_counter <= clk_divider_in;
        clk_divider <= clk_divider_in;
        update_components <= 0;
        //master reset for all value
        csr <= 8'hF0;
        fr1 <= 24'hD00000; cfr <= 24'h000300; acr <= 24'h0013FF;
        fr2 <=16'h0; cpow0 <= 16'h0; lsrr <= 16'h0;
        cftw0 <= 32'h28F5C28F; rdw <= 32'h0; fdw <= 32'h0;
        cw1 <= 32'h0; cw2 <= 32'h0; cw3 <= 32'h0; cw4 <= 32'h0; cw5 <= 32'h0; cw6 <= 32'h0; cw7 <= 32'h0;
        cw8 <= 32'h0; cw9 <= 32'h0; cw10 <= 32'h0; cw11 <= 32'h0; cw12 <= 32'h0; cw13 <= 32'h0; cw14 <= 32'h0; cw15 <= 32'h0;
        end
    else
        begin
        software_reset <= 0;
        io_update_en <= 1;
        clk_counter <= (clk_counter == 4'h0) ? clk_divider : clk_counter-1;
        if(clk_counter == 4'h0)
            begin     
            case(state)//
            2'b00://idle;
                begin
                if(readwrite_bar==1'b1)
                    begin
                    state<=2'b00;
                    readwrite_bar<=1'b0;
                    end
                else
                    begin
                    casez(update_components)//0 to 24;
                    25'b0:      // check if there is update or update_all
                        begin
                        cs<=1'b0;
                        sclk<=1'b1;
                        update_done <= update & UPDATE;   //check if update is done
                        Ch_Enable <= csr[7:4];
                        update_components <= (~update & UPDATE) ? UPDATE_COMPONENTS : 0; //initial update
                        update <= UPDATE;   //keep track of update
                        wire_mode <=IO_UPDATE ? (csr[2:1] == 2'b11 ? 1 : 0) : wire_mode;    //io_update issue change spi wire_mode
                        end
                    {1'h1,24'b?}:   //CSR to write
                        begin
                        readwrite_bar<=1'b0;
                        wdata[15:0]<={3'b000,CSR_addr, CSR[7:4], 1'b0, (CSR[2:1] == 2'b11 ? 2'b11 : 2'b00 ), 1'b0};     //force csr to be either two wire mode or four wire mode
                        csr <= {CSR[7:4], 1'b0, (CSR[2:1] == 2'b11 ? 2'b11 : 2'b00 ), 1'b0};
                        p_wdata<=6'd15;
                        state<=2'b01;
                        update_components[0]<=1'b0;
                        end
                    {2'h1,23'b?}://FR1 to write
                        begin
                        readwrite_bar<=1'b0;
                        wdata[31:0]<={3'b000,FR1_addr,FR1};
                        fr1 <= FR1;
                        p_wdata<=6'd31;
                        state<=2'b01;
                        update_components[1]<=1'b0;
                        end
                    {3'h1,22'b?}://FR2 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[23:0]<={3'b000,FR2_addr,FR2};
                        fr2 <= FR2;
                        p_wdata<=6'd23;
                        state<=2'b01;
                        update_components[2]<=1'b0;
                        end 
                    {4'h1,21'b?}://CFR to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[31:0]<={3'b000,CFR_addr, CFR};
                        cfr <= CFR;
                        p_wdata<=6'd31;
                        state<=2'b01;
                        update_components[3]<=1'b0;
                        end   
                    {5'h01,20'b?}://CFTW0 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CFTW0_addr,CFTW0};
                        cftw0 <= CFTW0;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[4]<=1'b0;
                        end   
                    {6'h01,19'b?}://CPOW0 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[23:0]<={3'b000,CPOW0_addr,CPOW0};
                        cpow0 <= CPOW0;
                        p_wdata<=6'd23;
                        state<=2'b01;
                        update_components[5]<=1'b0;
                        end 
                    {7'h01,18'b?}://ACR to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[31:0]<={3'b000,ACR_addr,ACR};
                        acr <= ACR;
                        p_wdata<=6'd31;
                        state<=2'b01;
                        update_components[6]<=1'b0;
                        end 
                    {8'h01,17'b?}://LSRR to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[23:0]<={3'b000,LSRR_addr,LSRR};
                        lsrr <= LSRR;
                        p_wdata<=6'd23;
                        state<=2'b01;
                        update_components[7]<=1'b0;
                        end 
                    {9'h001,16'b?}://RDW to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,RDW_addr,RDW};
                        rdw <= RDW;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[8]<=1'b0;
                        end 
                    {10'h001,15'b?}://FDW to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,FDW_addr,FDW};
                        fdw <= FDW;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[9]<=1'b0;
                        end 
                    {11'h001,14'b?}://CW1 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW1_addr,CW1};
                        cw1 <= CW1;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[10]<=1'b0;
                        end 
                    {12'h001,13'b?}://CW2 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW2_addr,CW2};
                        cw2 <= CW2;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[11]<=1'b0;
                        end 
                    {13'h0001,12'b?}://CW3 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW3_addr,CW3};
                        cw3 <= CW3;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[12]<=1'b0;
                        end 
                    {14'h0001,11'b?}://CW4 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW4_addr,CW4};
                        cw4 <= CW4;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[13]<=1'b0;
                        end 
                    {15'h0001,10'b?}://CW5 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW5_addr,CW5};
                        cw5 <= CW5;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[14]<=1'b0;
                        end 
                    {16'h0001,9'b?}://CW6 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW6_addr,CW6};
                        cw6 <= CW6;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[15]<=1'b0;
                        end 
                    {17'h00001,8'b?}://CW7 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW7_addr,CW7};
                        cw7 <= CW7;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[16]<=1'b0;
                        end 
                    {18'h00001,7'b?}://CW8 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW8_addr,CW8};
                        cw8 <= CW8;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[17]<=1'b0;
                        end 
                    {19'h00001,6'b?}://CW9 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW9_addr,CW9};
                        cw9 <= CW9;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[18]<=1'b0;
                        end 
                    {20'h0001,5'b?}://CW10 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW10_addr,CW10};
                        cw10 <= CW10;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[19]<=1'b0;
                        end 
                    {21'h000001,4'b?}://CW11 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW11_addr,CW11};
                        cw11 <= CW11;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[20]<=1'b0;
                        end 
                    {22'h000001,3'b?}://CW12 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW12_addr,CW12};
                        cw12 <= CW12;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[21]<=1'b0;
                        end 
                    {23'h000001,2'b?}://CW13 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW13_addr,CW13};
                        cw13 <= CW13;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[22]<=1'b0;
                        end 
                    {24'h000001,1'b?}://CW14 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW14_addr,CW14};
                        cw14 <= CW14;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[23]<=1'b0;
                        end 
                    {25'h0000001}://CW15 to write;
                        begin
                        readwrite_bar<=1'b0;
                        wdata[39:0]<={3'b000,CW15_addr,CW15};
                        cw15 <= CW15;
                        p_wdata<=6'd39;
                        state<=2'b01;
                        update_components[24]<=1'b0;
                        end 
                    default:
                        begin
                        cs<=1'b0;
                        sclk<=1'b1;
                        update_done <= 0;
                        end
                    endcase
                end
                end
            2'b01://write;
                begin
                if(cs==0)   //set chip select
                    begin
                    cs<=1'b1; //select chip
                    tpre_counter<=1'b0; //tpre counter in this case is 5ns;
                    sclk<=1'b1; //reset sclk
                    end
                else
                    begin
                    if(tpre_counter!=0)
                        begin
                        tpre_counter<=tpre_counter-1'b1;
                        end
                    else
                        begin   //chip select ready
                        case(wire_mode) //0 is two wire mode, 1 is four wire mode;
                        1'b0://two wire mode
                            begin
                            case(sclk)
                            1'b1://negative edge
                                begin
                                sclk<=~sclk;
                                sdio[0]<=wdata[p_wdata];
                                end
                            1'b0://positive edge
                                begin
                                sclk<=~sclk;
                                if(p_wdata==0)
                                    begin
                                    p_wdata<=6'd39;
                                    state <= (readwrite_bar==0)?2'b00:2'b10;
                                    sdio_en<=(readwrite_bar==0)?1'b1:1'b0;
                                    end
                                else
                                    begin
                                    p_wdata<=p_wdata-1;
                                    end
                                end
                            endcase
                            end 
                        1'b1://four wire mode
                            begin
                            case(sclk)
                            1'b1://negative edge
                                begin
                                sclk<=~sclk;
                                sdio<=wdata[p_wdata-:4];
                                end
                            1'b0:
                                begin
                                sclk<=~sclk;
                                if(p_wdata<=3)
                                    begin
                                    p_wdata<=6'd39;
                                    state<=(readwrite_bar==0)?2'b00:2'b10;
                                    sdio_en<=(readwrite_bar==0)?1'b1:1'b0;
                                    end
                                else
                                    begin
                                    p_wdata<=p_wdata-4;
                                    end
                                end
                            endcase
                            end
                        default:
                            begin
                            end
                        endcase
                        end
                    end
                end
        //    2'b10://read don't care for the moment
        //        begin
        //        case(WIRE_MODE)
        //        1'b0://two wire mode
        //            begin
        //            case(sclk)
        //            1'b0://positive edge
        //                begin
        //                sclk<=~sclk;
        //                rdata[p_rdata]<=SDIO[0];
        //                if(p_rdata==0)
        //                    begin
        //                    state<=2'b00;
        //                    p_rdata<=5'd31;
        //                    readwrite_bar<=1'b0;
        //                    sdio_en<=1'b1;
        //                    end
        //                else
        //                    begin
        //                    p_rdata<=p_rdata-1;
        //                    end
        //                end
        //            1'b1://negative edge
        //                begin
        //                sclk<=~sclk;
        //                end
        //            endcase
        //            end
        //        1'b1://four wire mode
        //            begin
        //            case(sclk)
        //            1'b0://positive edge
        //                begin
        //                sclk<=~sclk;
        //                rdata[p_rdata-:4]<=SDIO;
        //                if(p_rdata<=3)
        //                    begin
        //                    state<=2'b00;
        //                    p_rdata<=5'd31;
        //                    readwrite_bar<=1'b0;
        //                    sdio_en<=1'b1;
        //                    end
        //                else
        //                    begin
        //                    p_rdata<=p_rdata-4;
        //                    end
        //                end
        //            1'b1://negative edge
        //                begin
        //                sclk<=~sclk;
        //                end
        //            endcase
        //            end
        //        endcase
        //        end
            default:
                begin
                end 
            endcase
            end
        end
    end
    //register software check
    always @(posedge clk)
    begin
    if(reset)
        begin
        reg_r <= 0;
        end
    else
        begin
        case(reg_addr)
        4'h0:   //clock divider value check
            reg_r <= { 27'h0, clk_divider};
        default:
            begin
            reg_r <= 0;
            end
        endcase
        end
    end
endmodule
