`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MIT_HARVARD CUA
// Engineer: Chi Shu
// 
// Create Date: 2017/09/10 22:27:06
// Design Name: 
// Module Name: CommunicationPCFPGAAD9959
// Project Name: FPGA controlled DDS AD9959
// Target Devices: CMOD A7-35T
// Tool Versions: VIVADO 2017.2.1
// Tool Versions: VIVADO 2017.2.1
// Description: CommunicationPCFPGAAD9959_BlockRam
//              
//              4 channel implemented
//              fast Ramp mode fixed at rate of 1MHz, value set by every 1us
//              slow ramp mode fixed at rate of 10kHz, value set by every 100us.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module CommunicationPCFPGAAD9959_2_0(
input resetn,
input clk_axi,
//input clk_dds,
input btn,
//register space
input [31:0] RAM_addr,   //RAM_addr or Condition    addr is [11:0]; burst mode [31]; freq/phase/amp [29:28]
                        //                                                                  register addr 6'h0;
input [31:0] TRAMw,  // Time data RAM                                                       register addr 6'h04
input [31:0] DRAMw,  // Data RAM                                                            register addr 6'h08
input [31:0] CRAMw,  // Command RAM write, represent set in frequency, phase, amplitude     register addr 6'h0C 
input [31:0] RampDRAMw, //Ramp Data write                                                   register addr 6'h10
output [31:0] TRAMr,    //Time data RAM read                                                register addr 6'h04
output [31:0] DRAMr,    //DATA RAM read                                                     register addr 6'h08
output [31:0] CRAMr,    //Command RAM read                                                  register addr 6'h0C
output [31:0] RampDRAMr,//Ramp Data read                                                    regiseter addr 6'h10                                                                                            
output [0:24] update_components_r,                                                          //register addr 6'h14
                                                                                            //register addr 6'h18
output reg [31:0] ERROR,    //ERROR register                                                register addr 6'h1C
//Direct
input [31:0] CONTROL,   //DIRECT CONTROL register       register addr 6'h20
input [31:0] CONTROLdata,   //DIRECT CONTROL data register      register addr 6'h24
output reg [31:0] CONTROLrdata,       //DIRECT CONTROL read back data
//RAM we port
input wire TRAM_we, DRAM_we, CRAM_we, RampDRAM_we,
//DIRECT CONTROL port
input wire CONTROL_we,
//AD9959 connection
output w7_o,
input w10_i,w1_i,w2_i,w3_i,
inout w10_o,w1_o,w2_o,w3_o,
inout [3:0] sdio,
output [3:0] p,
output sclk,csb,reset_dds,pwr_dwn,io_update,
output [3:0] sdio_check,
output csb_check,sclk_check,
//experiment inout
input trigger_ext,
output reg reference
    );
    //parameter
    parameter command_width = 16;
    parameter ramp_rate_min = 100; //1us
    parameter ramp_rate_max = 100000;    //1ms
    //register
    //AD9959MASTER wire and register
    wire [31:0] rad9959data;
    wire [4:0] rad9959addr;
    wire update_done;
    // initial value for dds
    reg [7:0] csr=8'hF0, csr_axi = 5'hF0;
    reg [23:0] fr1=24'hD00000,cfr=24'h000300, cfr_axi = 24'h000300;
    
    reg [15:0] fr2=16'b0,lsrr=16'b0, phase_current = 16'b0;
    reg [9:0] amp_current = 10'b0;

    reg [31:0]  rdw=32'b0,fdw=32'b0,
                cw1=32'b0,cw2=32'b0,cw3=32'b0,cw4=32'b0,cw5=32'b0,cw6=32'b0,cw7=32'b0,
                cw8=32'b0,cw9=32'b0,cw10=32'b0,cw11=32'b0,cw12=32'b0,cw13=32'b0,cw14=32'b0,cw15=32'b0,
                f_current = 32'h0;  
    reg [23:0] acr = 24'h0013FF; 
    reg [31:0] cftw0 = 32'h28F5C28F;
    reg [15:0] cpow0 = 0;
    wire [3:0] Ch_En;
    reg [3:0] P=4'b0;
    reg [4:0] RAD9959ADDR=5'h1F;
    //reg FPGA_EN=1'b1;
    reg [0:24] update_components_axi = 0, update_components= 0;
    assign update_components_r = update_components;
    reg UPDATE,IO_UPDATE;
    reg UPDATE_axi = 0,
        IO_UPDATE_axi = 0;
    reg [3:0] IO_UPDATE_counter=4'b0,UPDATE_counter=4'b0;
    reg ERRORRESET = 0;
    assign p=P;
    assign rad9959addr=RAD9959ADDR;
    //Block RAM
    reg TWE1 = 0, DWE1 = 0, RampDWE1 = 0, CWE1 = 0, CWE1LAST = 0;
    wire Twe1, Dwe1, Cwe1, RampDwe1;
    
    assign Twe1 = TWE1;
    assign Dwe1 = DWE1;
    assign RampDwe1 = RampDWE1;
    assign Cwe1 = CWE1;
    
    parameter integer depth = 12;
    reg [depth-1:0] RAM_addr1= 0,RAM_addr2= 0;
    reg [23:0] acr_axi=24'h0013FF;
    reg [15:0] cpow0_axi = 16'b0;
    reg [31:0] cftw0_axi = 32'h28F5C28F;
    reg [depth : 0] IO_UPDATE_counts = 0, HighRAMaddr = 1;
    reg [31:0] TRAM_di1=32'b0, DRAM_di1=32'b0, RampDRAM_di1 = 32'h0;
    reg [command_width-1 :0] CRAM_di1 = 32'b0;
    wire [31:0] TRAM_do2,DRAM_do2, RampDRAM_do2;
    wire [command_width-1 :0] CRAM_do2;
    
    //control 
    reg [31: 0] CONTROL_1 = 0;
    reg CONTROL_weLAST = 0;     //CONTROL register write enable
    reg CONTROL_DDS_RESET = 0;  //FPGA DDS logic reset
    reg FPGA_DDS_ARMED = 0;     //FPGA fast tunning DDS armed
    reg DirectOn = 0;
    reg [3:0] DirectState = 0;
    reg [3:0] ERRORRESETcounter = 4'h0;
    reg [15:0] IO_UPDATE_manual_counter=16'h0000;       //counter for update all or manual update in case of slow sys_clock at AD9959
    reg verifier_counter = 0;

    reg trigger = 0, trigger_soft = 0;
    reg [1:0] btnon = 0;    // 11 btn control, 10 or 01 software control, 00 trigger_ext    
    reg AD9959_Reset = 0; 
    reg [15:0] AD9959_Reset_Counter = 0;
    reg [3:0] CONTROL_DDS_RESET_COUNTER = 0;
    reg [4:0] clk_divider = 5'h1F;
    wire [4:0] clk_speed;
    reg [3:0] IO_UPDATEwait = 0;
    reg init_set = 0;
    reg [31:0] T_last = 0;
    reg [3:0] reference_config = 0;
    reg [3:0] phase_init_reset = 0;
    initial begin
    reference <= 0;
    //set up dds
    end
    reg [11:0] trigger_counter = 12'h3E7;     //minimum trigger 1ms rising slope  dec 999 for 10us
    reg trigger_last_in = 0;
    wire trigger_in;
    assign trigger_in = (btnon == 2'b11) ? btn : (btnon == 2'b00 ? trigger_ext : trigger_soft);
    
    
    reg TRIGGERLAST = 0, trigger_last = 0;
    reg [31:0] TIMER = 32'h0;
    reg [31:0] D_init = 32'h0;
    reg [command_width-1 : 0] C_init = 0;
    reg [31:0] T_0 = 32'h0, T_1 =32'h0, T_2 = 32'h0; //0 represents current value, 1 represents next value
    reg [31:0] D_0 = 32'h0, D_1 =32'h0, D_2 = 32'h0;
    reg [31:0] RampD_0 = 32'h0, RampD_1 =32'h0, RampD_2 = 32'h0;
    reg [31:0] RampD =32'h0;
    reg [9:0] RampRate = 0;
    reg [3:0] RampCh_En = 0;
    reg [command_width-1 : 0] C_0 = 0, C_1 = 0, C_2 = 0;
    reg [3:0] MainState = 4'h0;
    reg [2:0] NumFifo= 0;
    reg FifoRE = 0; 
    
    always @(posedge clk_axi)
    begin
    trigger_last_in <= trigger;
    if(trigger_counter == 0)
        begin
        if(trigger_last_in != trigger_in)
            begin
            trigger_counter <= 12'h3E7;
            trigger <= trigger_in;
            end
        end
    else
        begin
        trigger_counter <= trigger_counter -1;
        end
    end  
    
    
    always @(posedge clk_axi)//com has to have the same clk as ram
    begin
    if(~resetn)
        begin
        FPGA_DDS_ARMED <= 0; 
        CWE1LAST <= 0;
        CONTROL_weLAST <= 0;
        DirectOn <= 0;
        DirectState <= 0;
        ERRORRESET <= 0;
        CONTROL_1 <= 0;
        TWE1 <= 0;
        DWE1 <= 0;
        RampDWE1 <= 0;
        CWE1 <= 0;
        AD9959_Reset <= 0;
        AD9959_Reset_Counter <= 0;
        IO_UPDATE_manual_counter <= 0;
        ERROR[0] <= 0;
        clk_divider <= 5'h1F;
        reference_config <= 0;
        csr_axi <= 8'hF0;
        fr1 <= 24'hD00000; cfr_axi <= 24'h000300;
        fr2 <=16'h0; lsrr <= 16'h0;
        rdw <= 32'h0; fdw <= 32'h0;
        cw1 <= 32'h0; cw2 <= 32'h0; cw3 <= 32'h0; cw4 <= 32'h0; cw5 <= 32'h0; cw6 <= 32'h0; cw7 <= 32'h0;
        cw8 <= 32'h0; cw9 <= 32'h0; cw10 <= 32'h0; cw11 <= 32'h0; cw12 <= 32'h0; cw13 <= 32'h0; cw14 <= 32'h0; cw15 <= 32'h0; 
        cpow0_axi <= 0;  acr_axi <= 24'h0013FF; cftw0_axi <= 32'h28F5C28F;
        update_components_axi <= 0;
        end
    else
        begin
        //Direct Control begin
        CONTROL_weLAST <= CONTROL_we;   //control we fifo to find rising edge
        if(CONTROL_we & (~CONTROL_weLAST) & ~DirectOn)
            begin
            CONTROL_1 <= CONTROL;
            casez(CONTROL)
                32'h00000000:   //ERROR clear
                    begin
                    ERRORRESET <= 1;
                    ERRORRESETcounter <= 0;
                    DirectState <= 4'h0;
                    DirectOn <= 1;
                    end
                32'h00000001:   //reset dds fast control logic
                    begin
                    CONTROL_DDS_RESET <= 1;
                    CONTROL_DDS_RESET_COUNTER <= 4'hF;
                    FPGA_DDS_ARMED <= 0;
                    DirectState <= 4'h0;
                    DirectOn <= 1;
                    end
                32'h00000002:   //set total number of data points
                    begin
                    if(~FPGA_DDS_ARMED)
                        begin
                        HighRAMaddr <= CONTROLdata[depth-1 : 0] + 1;
                        end
                    end
                32'h10000002:   //read total number of data points
                        CONTROLrdata <= HighRAMaddr - 1;
                32'h00000003:   //AD9959 reset update all
                    begin
                    if(~FPGA_DDS_ARMED & ~update_done)
                        begin
                        update_components_axi <= 25'h1FFFFFF;
                        UPDATE_axi <= 1;
                        DirectState <= 4'h0;
                        DirectOn <= 1;
                        end
                    else
                        begin
                        end
                    end
                32'h00000004:   //PC to FPGA
                    begin
                    //FPGA_EN <= 1;
                    end
                32'h00000005:   //FPGA to PC
                    begin
                    //FPGA_EN <= 0;
                    end
                32'h00000006:   //manual send io_update
                    begin
                    if(~FPGA_DDS_ARMED & ~UPDATE)
                        begin
                        IO_UPDATE_axi <= 1;
                        DirectState <= 4'h0;
                        IO_UPDATE_manual_counter <= 16'hFFFF;
                        DirectOn <= 1;
                        end
                    end
                32'h00000007:   //change trigger mode
                    btnon <=~FPGA_DDS_ARMED ? CONTROLdata[1:0] : btnon;
                32'h10000007:   //read back trigger mode
                    CONTROLrdata <= btnon;
                32'h00000008:   //send software trigger or disable software trigger
                    begin
                    trigger_soft <= CONTROLdata[0];
                    end
                32'h00000009:   //master reset of ad9959
                    begin
                    AD9959_Reset <= 1;
                    DirectOn <= 1;
                    DirectState <= 4'h0;
                    AD9959_Reset_Counter <= 16'hFFFF;
                    end
                32'h0000000A:
                        reference_config <= CONTROLdata;
                32'h1000000A:
                        CONTROLrdata <= reference_config;
                32'h0000000F:       //set clock divider
                        clk_divider <= CONTROLdata[4:0];
                32'h1000000F:
                        CONTROLrdata <= clk_speed;
                {24'h011111, 8'h?}:     //manual read back
                    begin
                    case(CONTROL[7:0])
                        8'h00:  CONTROLrdata <= csr;
                        8'h01:  CONTROLrdata <= fr1;  
                        8'h02:  CONTROLrdata <= fr2;  
                        8'h03:  CONTROLrdata <= cfr;
                        8'h04:  CONTROLrdata <= cftw0;
                        8'h05:  CONTROLrdata <= cpow0;
                        8'h06:  CONTROLrdata <= acr;
                        8'h07:  CONTROLrdata <= lsrr;
                        8'h08:  CONTROLrdata <= rdw;
                        8'h09:  CONTROLrdata <= fdw;  
                        8'h0A:  CONTROLrdata <= cw1;   
                        8'h0B:  CONTROLrdata <= cw2;
                        8'h0C:  CONTROLrdata <= cw3;
                        8'h0D:  CONTROLrdata <= cw4;
                        8'h0E:  CONTROLrdata <= cw5;
                        8'h0F:  CONTROLrdata <= cw6;
                        8'h10:  CONTROLrdata <= cw7;
                        8'h11:  CONTROLrdata <= cw8;
                        8'h12:  CONTROLrdata <= cw9;
                        8'h13:  CONTROLrdata <= cw10;
                        8'h14:  CONTROLrdata <= cw11;
                        8'h15:  CONTROLrdata <= cw12;
                        8'h16:  CONTROLrdata <= cw13;
                        8'h17:  CONTROLrdata <= cw14;
                        8'h18:  CONTROLrdata <= cw15;
                        8'hFE:  CONTROLrdata <= phase_init_reset;     
                        8'hFF:  
                            begin
                            CONTROLrdata <=verifier_counter ? 32'hFFFFFFFF : 32'h00000001;
                            verifier_counter <= verifier_counter + 1;
                            end
                        default:    CONTROLrdata <= 0;
                    endcase
                    end
                32'h0FFFFFFF:
                    CONTROLrdata <= {FPGA_DDS_ARMED,31'b0};
                {24'h111111,8'h?}:   //manual input
                    begin
                    if(~FPGA_DDS_ARMED & ~update_done)
                        begin
                        if(CONTROL[7:0] <=8'h18)
                            begin
                            update_components_axi[CONTROL[7:0]] <= 1;
                            end
                        case(CONTROL[7:0])
                        8'h00:  csr_axi <= CONTROLdata[7:0];
                        8'h01:  fr1 <= CONTROLdata[24:0];
                        8'h02:  fr2 <= CONTROLdata[15:0];
                        8'h03:  cfr_axi <= CONTROLdata[23:0];
                        8'h04:  cftw0_axi <= CONTROLdata[31:0];  
                        8'h05:  cpow0_axi <= {2'b00, CONTROLdata[13:0]};
                        8'h06:  acr_axi <= CONTROLdata[23:0];
                        8'h07:  lsrr <= CONTROLdata[15:0];
                        8'h08:  rdw <= CONTROLdata[31:0];
                        8'h09:  fdw <= CONTROLdata[31:0]; 
                        8'h0A:  cw1 <= CONTROLdata[31:0];
                        8'h0B:  cw2 <= CONTROLdata[31:0]; 
                        8'h0C:  cw3 <= CONTROLdata[31:0];
                        8'h0D:  cw4 <= CONTROLdata[31:0];
                        8'h0E:  cw5 <= CONTROLdata[31:0];
                        8'h0F:  cw6 <= CONTROLdata[31:0];
                        8'h10:  cw7 <= CONTROLdata[31:0];
                        8'h11:  cw8 <= CONTROLdata[31:0];
                        8'h12:  cw9 <= CONTROLdata[31:0];
                        8'h13:  cw10 <= CONTROLdata[31:0];
                        8'h14:  cw11 <= CONTROLdata[31:0];
                        8'h15:  cw12 <= CONTROLdata[31:0];
                        8'h16:  cw13 <= CONTROLdata[31:0];
                        8'h17:  cw14 <= CONTROLdata[31:0];
                        8'h18:  cw15 <= CONTROLdata[31:0]; 
                        8'hFE:  phase_init_reset <= CONTROLdata[3:0];      
                        8'hFF:
                            begin
                            UPDATE_axi <= 1;
                            DirectState <= 4'h0;
                            DirectOn <= 1;
                            end
                        default:
                            begin
                            end
                        endcase
                        end
                    else
                        begin
                        end
                    end
                {32'h00FFFF, 8'h?}:     //sequence related reading
                    begin
                    case(CONTROL[7:0])
                        8'h00:
                            CONTROLrdata <= RAM_addr2;
                        8'h01:
                            CONTROLrdata <= D_init;
                        8'h02:
                            CONTROLrdata <= C_init;
                        8'h10:
                            CONTROLrdata <= T_0;
                        8'h11:
                            CONTROLrdata <= T_1;
                        8'h12:
                            CONTROLrdata <= T_2;
                        8'h20:
                            CONTROLrdata <= D_0;
                        8'h21:
                            CONTROLrdata <= D_1;
                        8'h22:
                            CONTROLrdata <= D_2;
                        8'h30:
                            CONTROLrdata <= C_0;
                        8'h31:
                            CONTROLrdata <= C_1;
                        8'h32:
                            CONTROLrdata <= C_2;
                        8'h40:
                            CONTROLrdata <= RampD_0;
                        8'h41:
                            CONTROLrdata <= RampD_1;
                        8'h42:
                            CONTROLrdata <= RampD_2;
                        default:
                            CONTROLrdata <= 0;
                    endcase
                    end
                32'hFFFFFFFF:   //dds output control FPGA armed
                    begin
                    IO_UPDATE_axi <= 0;
                    if(UPDATE)
                        begin
                        DirectOn <= 1;
                        end 
                    else
                        begin
                        FPGA_DDS_ARMED <= 1;
                        end
                    end
                default:
                    begin
                    CONTROL_DDS_RESET <= 0;
                    ERRORRESET <= 0;
                    end
            endcase
            end
        else
            begin
            if(DirectOn)
                begin
                case(DirectState)
                    4'h0:
                        begin
                        case(CONTROL_1)
                            32'h00000000:
                                begin
                                ERRORRESETcounter <= (ERRORRESETcounter == 4'hF) ? 4'hF : ERRORRESETcounter +1;
                                if(ERRORRESETcounter == 4'hF)
                                    begin
                                    ERRORRESET <= 0;
                                    DirectOn <= 0;
                                    end
                                end
                            32'h00000001:
                                begin
                                if(CONTROL_DDS_RESET_COUNTER == 0)
                                    begin
                                    CONTROL_DDS_RESET <= 0;
                                    DirectOn <= 0;
                                    end
                                else
                                    begin
                                    CONTROL_DDS_RESET_COUNTER <= CONTROL_DDS_RESET_COUNTER -1;
                                    end
                                end
                            32'h00000003:   //update all
                                begin
                                if(update_done)
                                    begin
                                    UPDATE_axi <= 0;
                                    update_components_axi <= 0;
                                    DirectOn <= 0;
                                    end
                                end
                            32'h00000006:
                                begin
                                IO_UPDATE_manual_counter <= (IO_UPDATE_manual_counter == 16'h0) ? 16'h0 : IO_UPDATE_manual_counter-1;
                                IO_UPDATE_axi <= (IO_UPDATE_manual_counter == 16'h0) ? 0 : 1;
                                DirectOn <= (IO_UPDATE_manual_counter == 16'h0) ? 0 : 1;
                                end
                            32'h00000009:
                                begin
                                AD9959_Reset_Counter <= (AD9959_Reset_Counter == 16'h0) ? 16'h0 : AD9959_Reset_Counter-1;
                                AD9959_Reset <= (AD9959_Reset_Counter == 16'h0) ? 0 : 1;
                                DirectOn <= (AD9959_Reset_Counter == 16'h0) ? 0 : 1;
                                end
                            32'h111111FF:
                                begin
                                if(update_done)
                                    begin
                                    update_components_axi <= 0;
                                    UPDATE_axi <= 0;
                                    DirectOn <= 0;
                                    end
                                end
                            32'hFFFFFFFF:
                                begin
                                if(update_done)
                                    begin
                                    UPDATE_axi <= 0;
                                    update_components_axi <= 0;
                                    DirectOn <= 0;
                                    FPGA_DDS_ARMED <= 1;
                                    end
                                end
                            default:
                                begin   //NOP
                                end
                        endcase
                        end
                    default:
                        begin   //NOP
                        end
                endcase
                end
            end
        //Direct Control end
        
        //RAM part begin
        CWE1LAST <= CWE1;   //CWE fifo to find rising edge
        case(RAM_addr[31])    //burst mode addr increment on its own
            1'h0:
                begin
                RAM_addr1 <= RAM_addr[depth-1 : 0];
                end
            1'h1:
                begin
                if(~Cwe1 && CWE1LAST && RAM_addr != 12'hFFF)       //last data has been loaded
                    begin
                    RAM_addr1 <= RAM_addr1 + 1;
                    end
                end
            default:
                begin
                RAM_addr1 <= RAM_addr[depth-1 : 0];
                end
        endcase
        if(FPGA_DDS_ARMED)
            begin
            TWE1 <= 0;
            DWE1 <= 0;
            CWE1 <= 0;
            ERROR[0] <= (Twe1||Dwe1||Cwe1)? 1 : (ERRORRESET ? 0 : ERROR[0]);
            end
        else
            begin
            ERROR[0] <= (ERRORRESET) ? 0: ERROR[0];
            if(TRAM_we)
                begin
                TWE1 <= 1;
                TRAM_di1 <= TRAMw;
                end
            else
                begin
                TWE1 <= 0;            
                end
            if(DRAM_we)
                begin
                DWE1 <=1;
                DRAM_di1 <= DRAMw;
                if(RAM_addr[23:14] > 0 & RAM_addr[23:14] <=1000)        //ramp
                    begin
                    RampDRAM_di1 <= RampDRAMw;
                    CRAM_di1 <= RAM_addr[29:29-command_width+1];
                    //29:28 is control whether freq, phase or amp to change
                    //27:24 control channels to be set or ramp
                    //23:14 ramp rate (10 bit value)
                    end
                else                    //set
                    begin
                    RampDRAM_di1 <= 0;  //no ramp
                    CRAM_di1[command_width-1: command_width-6] <= RAM_addr[29:24];
                    CRAM_di1[command_width-7: 0] <= 0;  //force to 0 if invalid
                    end
                CWE1 <= 1;
                RampDWE1 <= 1;                                                                           
                end
            else
                begin
                DWE1 <= 0;
                CWE1 <= 0;
                RampDWE1 <= 0;
                end
            //RAM Part end               
            end
        end
        
    end

    //data fifo
    reg [1:0] RAM_state = 0;
    always @(posedge clk_axi)
    begin
    if(CONTROL_DDS_RESET)
        begin
        RAM_addr2 <= 0;
        NumFifo <= 0;
        D_init <= (RAM_addr2 == 0) ? DRAM_do2 : D_init;
        C_init <= (RAM_addr2 == 0) ? CRAM_do2 : C_init; 
        ERROR[2] <= 0;
        RAM_state <= 0;
        end
    else
        begin
        if(FifoRE)
            begin
            if(NumFifo == 0)
                begin
                ERROR[2] <= 1;
                end
            else
                begin
                NumFifo <= NumFifo -1;
                end
            end
        else
            begin
            case(RAM_state)
                2'h3:
                    begin
                    RAM_state <= RAM_state - 1;
                    
                    end
                2'h2:
                    begin
                    //wait data ready
                    RAM_state <= RAM_state - 1;
                    end
                2'h1:
                    begin
                    RAM_state <= RAM_state - 1;
                    end
                2'h0:
                    begin
                    if(NumFifo < 3)
                        begin
                        RAM_state <= 2'h2;
                        RAM_state <= RAM_state - 1;
                        T_0 <= T_1;
                        D_0 <= D_1;
                        RampD_0 <= RampD_1;
                        C_0 <= C_1;
                        T_1 <= T_2;
                        D_1 <= D_2;
                        RampD_1 <= RampD_2;
                        C_1 <= C_2;
                        T_2 <= TRAM_do2;
                        D_2 <= DRAM_do2;
                        RampD_2 <= RampDRAM_do2;
                        C_2 <= CRAM_do2;
                        NumFifo <= NumFifo +1;
                        if(HighRAMaddr - 1 == RAM_addr2)
                            begin
                            RAM_addr2 <= 0;
                            end
                        else    
                            begin
                            RAM_addr2 <= RAM_addr2 +1;
                            end
                        end
                    end
            endcase
            end
        end  
    end
    
    
    reg phase_reset = 0;
    reg [3:0] init_check_list = 0;
    always @(posedge clk_axi)
    begin
    if(AD9959_Reset)
        begin
        acr <= 24'h0013FF; cpow0 <= 16'h0; cftw0 <= 32'h28F5C28F; 
        TRIGGERLAST <= 0; TIMER <= 32'h0; MainState <= 4'h0;
        IO_UPDATE_counts <= 0; IO_UPDATE <= 0; FifoRE <= 0; 
        UPDATE <= 0; ERROR[31:3] <= 0; ERROR[1] <= 0;
        T_last <= 0; reference <= 0;
        phase_reset <= 0; init_check_list <= 0;
        RampCh_En <= 0;
        end
    else
        begin
        if(CONTROL_DDS_RESET)
            begin
            TRIGGERLAST <= 0; TIMER <= 32'h0; MainState <= 4'h0;
            IO_UPDATE_counts <= 0; IO_UPDATE <= 0; FifoRE <= 0; 
            UPDATE <= 0; ERROR[31:3] <= 0; ERROR[1] <= 0;
            T_last <= 0; reference <= 0;
            phase_reset <= 0; init_check_list <= 0; RampCh_En <= 0;
            trigger_last <= 0;
            end
        else
            begin
            case(reference_config)
                4'h0:
                    reference <= (MainState == 4'h0) ? 0 : 1;
                4'h1:
                    reference <= io_update;
                4'h2:
                    reference <= trigger;
                default:
                    reference <= (MainState == 4'h0) ? 0 : 1;
            endcase            
            trigger_last <= trigger;
            TIMER <= (FPGA_DDS_ARMED & ~trigger_last & trigger) ? 0 : ((TIMER == 32'hFFFFFFFF) ? 32'hFFFFFFFF : TIMER +1);     // make sure timer never overflow
            if(~FPGA_DDS_ARMED)
                begin
                csr <= csr_axi;
                cfr <= cfr_axi;
                acr <= acr_axi;
                cpow0[13:0] <= cpow0_axi[13:0];
                cftw0 <= cftw0_axi;
                update_components <= update_components_axi;
                UPDATE <= UPDATE_axi;
                IO_UPDATE <= IO_UPDATE_axi;
                TRIGGERLAST <= 0; 
                MainState <= 4'h0;
                IO_UPDATE_counts <= 0;
                FifoRE <= 0; 
                T_last <= 0;
                init_set <= 0;
                end
            else
                begin
                case(MainState)  //state machine
                    4'h0:   //idle
                        begin
                        TRIGGERLAST <= init_set ? 1'b0 : trigger; //trigger fifo to find rising edge
                        case({TRIGGERLAST, (init_set ? 1'b0 : trigger)})
                            2'b01:  //new trigger coming in
                                begin
                                IO_UPDATE <= 0;
                                ERROR[1] <= ERRORRESET ? 0 : (init_check_list!= 4'h4 ? 1 : ERROR[1]);      // reset sequence not yet done
                                UPDATE <= 0;
                                IO_UPDATE_counts <= 0;
                                MainState <= 4'h0;
                                init_check_list <= 0;
                                phase_reset <= 0;
                                init_set <= 0;
                                end
                            2'b11:  //reach if the end of sequence
                                begin
                                if(IO_UPDATE_counts == HighRAMaddr) //reach the end of sequence
                                    begin
                                    end
                                else
                                    begin
                                    if(TIMER >= T_0 && T_last < T_0 )
                                        begin
                                        T_last <= T_0;
                                        RampRate <= (clk_speed <= 8) ? C_0[command_width-7: command_width-16] : 0;  // ramp is only allowed in fast clk case
                                        RampD <= RampD_0;
                                        RampCh_En <= C_0[command_width-3: command_width-6];
                                        IO_UPDATE <= 1;
                                        IO_UPDATE_counts <= IO_UPDATE_counts +1;
                                        IO_UPDATEwait <= 1;
                                        MainState <= 4'h1;
                                        FifoRE <= 1;
                                        if(TIMER != T_0)        //timing failure
                                            begin
                                            ERROR[4] <= 1;
                                            end
                                        end
                                    else
                                        begin
                                        ERROR[3] <= (T_last < T_0) ? ERROR[3] : 1;
                                        if(RampRate == 0)   
                                            begin
                                            end
                                        else
                                            begin
                                            if(TIMER >= T_last + ({22'h0,RampRate}<< 6) + ({22'h0,RampRate}<< 5) + ({22'h0,RampRate}<< 2))        //*100)
                                                begin
                                                IO_UPDATE <= 1;
                                                IO_UPDATEwait <= 1;
                                                MainState <= 4'h1;
                                                T_last <= TIMER;
                                                if(TIMER > T_0-{22'h0, RampRate} <<1)       //the last value before next data point must be direct set to next data value
                                                    begin
                                                    RampRate <= 0;
                                                    end
                                                if(TIMER !=  T_last + ({22'h0,RampRate}<< 6) + ({22'h0,RampRate}<< 5) + ({22'h0,RampRate}<< 2))
                                                    begin
                                                    ERROR[5] <= 1;
                                                    end
                                                end
                                            end
                                                        
                                        
                                        end
                                    end
                                end
                            2'b10:  //sequence ended
                                begin
                                ERROR[3] <= (IO_UPDATE_counts - 1 == {1'b0, HighRAMaddr}) ? ERROR[3] : 1;        // check if there is too many io update
                                init_set <= 1;
                                IO_UPDATE <= 1;
                                IO_UPDATEwait <= 1;
                                MainState <= 4'h1;
                                FifoRE <= 0;
                                RampRate <= 0;
                                RampD <= 0;
                                end
                            2'b00:  //sequence reset to startup
                                begin
                                ERROR[3] <= ERRORRESET ? 0 : ERROR[3];
                                RampRate <= 0;
                                RampD <= 0;
                                //check if value set is equal to the init value
                                case(init_check_list)
                                    4'h0:   //check tuning word
                                        begin
                                        case(C_init[command_width-1 : command_width-2])
                                            2'b00, 2'b11:   //frequency
                                                begin
                                                if(D_init != f_current || D_init != cftw0)
                                                    begin
                                                    init_set <= 1;
                                                    MainState <= 4'h2;
                                                    end
                                                else
                                                    begin
                                                    init_set <= 0;
                                                    init_check_list <= init_check_list+1;   
                                                    end                                     
                                                end
                                            2'b01:          //phase
                                                begin
                                                if(D_init[13:0] != phase_current[13:0] || D_init[13:0] != cpow0[13:0])
                                                    begin
                                                    init_set <= 1;
                                                    MainState <= 4'h2;
                                                    end
                                                else
                                                    begin
                                                    init_set <= 0;
                                                    init_check_list <= init_check_list+1;
                                                    end
                                                end
                                            2'b10:          //amp
                                                begin
                                                if(D_init[9:0] != amp_current || D_init[9:0] != acr[9:0])
                                                    begin
                                                    init_set <= 1;
                                                    MainState <= 4'h2;
                                                    end
                                                else
                                                    begin
                                                    init_set <= 0;
                                                    init_check_list <= init_check_list+1;
                                                    end
                                                end
                                        endcase
                                        end
                                    4'h1:  //phase auto clear set
                                        begin
                                        if(~phase_reset & (phase_init_reset != 4'h0))
                                            begin
                                            csr[7:4] <= phase_init_reset;
                                            cfr[2] <= 1;    //auto phase clear
                                            update_components[0] <= 1;
                                            update_components[3] <= 1;
                                            phase_reset <= 1;
                                            MainState <= 4'h2;
                                            init_set <= 1;
                                            end
                                        else
                                            begin
                                            init_check_list <= init_check_list +1;
                                            end
                                        end
                                    4'h2:   //phase auto clear reset
                                        begin
                                        cfr[2] <= 0;    //auto phase clear
                                        update_components[3] <= 1;
                                        MainState <= 4'h2;
                                        init_set <= 1;
                                        init_check_list <= init_check_list+1;
                                        end
                                    4'h3:   //channel word reset
                                        begin
                                        csr[7:4] <= C_init[command_width-3 : command_width-6];
                                        update_components[0] <= 1;
                                        MainState <= 4'h2;
                                        init_set <= 0;
                                        init_check_list <= init_check_list+1;
                                        end
                                    4'h4:   //wait
                                        begin
                                        end
                                    default:
                                        ;
                                endcase
                                FifoRE <= 0;
                                T_last <= 0;
                                IO_UPDATE <= 0;
                                UPDATE <= 0;
                                IO_UPDATE_counts <= 0;
                                end
                            default:
                                ;
                        endcase                    
                        end
                    4'h1:       //IO_UPDATE wait
                        begin
                        FifoRE <= 0;
                        IO_UPDATEwait <= IO_UPDATEwait -1;
                        MainState <= (IO_UPDATEwait == 0) ? (init_set ? 4'h0 : 4'h2) : 4'h1;
                        init_set <= 0;
                        f_current <= cftw0;
                        phase_current <= cpow0;
                        amp_current <= acr[9:0] ;              
                        end
                    4'h2:       //UPdate value set
                        begin
                        IO_UPDATE <= 0;
                        UPDATE <=(UPDATE | update_done)? 0 : 1;
                        MainState <= (UPDATE | update_done) ? 4'h2 : 4'h3; 
                        if(~UPDATE & ~update_done)
                            begin
                            if(init_check_list == 0)
                                begin
                                if((init_set ? C_init[command_width-3 : command_width-6] : (RampRate == 0 ? C_0[command_width-3 : command_width-6] : RampCh_En) )!= Ch_En )
                                    begin
                                    csr[7:4] <= C_0[command_width-3 : command_width-6];
                                    update_components[0] <= 1;
                                    end
                                case((init_set ? C_init[command_width-1:command_width-2] : C_0[command_width-1:command_width-2]))
                                    2'b00, 2'b11:   //frequency word
                                        begin
                                        cftw0 <= (init_set) ? D_init : (RampRate == 0 ? D_0 : cftw0 + RampD);   //negative value by overflow
                                        update_components[4:6] <= 3'b100;
                                        end
                                    2'b01:          //phase
                                        begin
                                        cpow0[13:0] <= (init_set) ? D_init[13:0] : (RampRate == 0 ? D_0[13:0] : cpow0[13:0] + RampD[13:0]);
                                        update_components[4:6] <= 3'b010;
                                        end
                                    2'b10:          //amp
                                        begin
                                        acr[9:0] <= init_set ? D_init[9:0] : (RampRate == 0 ? D_0[9:0] : acr[9:0] + RampD[9:0]);  //ramp rate to 0 only direct control
                                        update_components[4:6] <= 3'b001;
                                        end
                                    default:
                                        begin
                                        //NOP
                                        end
                                endcase
                                end
                            else
                                begin
                                
                                end
                            end
                            
                        end
                    4'h3:
                        begin
                        UPDATE <= update_done ? 0 : 1;
                        update_components <= update_done ? 0 : update_components;
                        MainState <= update_done ? (init_set ? 4'h1 : 4'h0): 4'h3;
                        IO_UPDATE <= (update_done & init_set) ? 1 : 0; 
                        IO_UPDATEwait <= 1;
                        end
                    default:    //default case should never invoke
                        begin
                        end
                endcase
                end
            end
        end
    end
    
        sBRAM12 #(.addrdepth(12), .width(32)) TRAM(.clk1(clk_axi),.clk2(clk_axi),
                .en1(1'b1), .en2(1'b1),
                .we1(Twe1),
                .addr1(RAM_addr1),.addr2(RAM_addr2),
                .di1(TRAM_di1),
                .do1(TRAMr),.do2(TRAM_do2));
        sBRAM12 #(.addrdepth(12), .width(32))  DRAM(.clk1(clk_axi),.clk2(clk_axi),
                .en1(1'b1), .en2(1'b1),
                .we1(Dwe1),
                .addr1(RAM_addr1),.addr2(RAM_addr2),
                .di1(DRAM_di1),
                .do1(DRAMr),.do2(DRAM_do2));
        sBRAM12 #(.addrdepth(12), .width(32))  RampDRAM(.clk1(clk_axi),.clk2(clk_axi),
                .en1(1'b1), .en2(1'b1),
                .we1(RampDwe1),
                .addr1(RAM_addr1),.addr2(RAM_addr2),
                .di1(RampDRAM_di1),
                .do1(RampDRAMr),.do2(RampDRAM_do2));
                
        sBRAM12 #(.addrdepth(12), .width(command_width)) CRAM(.clk1(clk_axi),.clk2(clk_axi),
                .en1(1'b1), .en2(1'b1),
                .we1(Cwe1),
                .addr1(RAM_addr1),.addr2(RAM_addr2),
                .di1(CRAM_di1),
                .do1(CRAMr),.do2(CRAM_do2));        
        
               
        AD9959Master_2_0 AD9959DDS(
        .reset(AD9959_Reset),
        .clk_divider_in(clk_divider),
        .clk(clk_axi),//200MHZ for the max, running on both positive and negative edge
        //internal register space
        .CSR(csr),.FR1(fr1),.CFR(cfr),.ACR(acr),.FR2(fr2),.CPOW0(cpow0),.LSRR(lsrr),.CFTW0(cftw0),.RDW(rdw),.FDW(fdw),
        .CW1(cw1),.CW2(cw2),.CW3(cw3),.CW4(cw4),.CW5(cw5),.CW6(cw6),.CW7(cw7),.CW8(cw8),
        .CW9(cw9),.CW10(cw10),.CW11(cw11),.CW12(cw12),.CW13(cw13),.CW14(cw14),.CW15(cw15),
        .UPDATE_COMPONENTS(update_components),
        //control space
        .UPDATE(UPDATE),
        .UPDATE_DONE(update_done),
        .reg_addr(0), .reg_r(),
        .clk_divider_out(clk_speed),
        .Ch_Enable(Ch_En),
        //communicatoion ports to ad9959
        .W10_I(w10_i),.W1_I(w1_i),.W2_I(w2_i),.W3_I(w3_i),
        .W7_O(w7_o),.W10_O(w10_o),.W1_O(w1_o),.W2_O(w2_o),.W3_O(w3_o),
        .CS_bar(csb),
        .SCLK(sclk),
        .SDIO(sdio),
        .io_update(IO_UPDATE),.IO_UPDATE(io_update),
        .master_reset(1'b0),.MASTER_RESET(reset_dds),
        .pwr_dwn(1'b0),.PWR_DWN(pwr_dwn),
        .re(0),
        .RADDR(rad9959addr),
        .RDATA(rad9959data),
        .sdio_check(sdio_check),
        .csb_check(csb_check),.sclk_check(sclk_check)
                );   
endmodule