
`timescale 1 ns / 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MIT_HARVARD CUA
// Engineer: Chi Shu
// 
// Create Date: 2019/05/21
// Design Name: 
// Module Name: axi_AD9959_v2_0
// Project Name: FPGA controlled DDS AD9959
// Target Devices: CMOD A7-35T
// Tool Versions: VIVADO 2018.3
// Description: Custom IP for AD9959 control by FPGA
//              complete set of command for software control 
//              as well as fast sequence for direct set/ramp data up to 2^12 data points
//              This is just axi_lite packager, the main program is CommunicationPCFPGAAD9959_2_0.V
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

	module axi_AD9959_v2_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
		//Clock and trigger to fpga
        //input wire clk_dds,
        input wire trigger,
        input wire btn,     //button on CMOD A7 
        // Debug port
        output wire reference,  //reference port for debugging and other purpose
        output wire [3:0] sdio_check,    //this is for debugging purpose             
        output wire csb_check, sclk_check,   
        //AD9959 evaluation board header and switches
        output wire w7_o,   //PC or manual switches
        input wire w10_i,w1_i,w2_i,w3_i,    //PC control related connections
        inout wire w10_o,w1_o,w2_o,w3_o,    //PC control related connections
        inout wire [3:0] sdio,   //serial sdio pins
        inout wire [3:0] p,  //profile pin
        output wire sclk, csb, reset_dds, pwr_dwn, io_update,    //ad9959 chip level connections
        //output wire reset,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
// Instantiation of Axi Bus Interface S00_AXI
	axi_AD9959_v2_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) axi_AD9959_v2_0_S00_AXI_inst (
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),
		//user port
		//.clk_dds(clk_dds),
		.trigger(trigger),
		.btn(btn),
		.reference(reference),
		.sdio_check(sdio_check),
		.csb_check(csb_check), .sclk_check(sclk_check),
		.w7_o(w7_o),
		.w10_i(w10_i), .w1_i(w1_i), .w2_i(w2_i), .w3_i(w3_i),
		.w10_o(w10_o), .w1_o(w1_o), .w2_o(w2_o), .w3_o(w3_o),
		.sdio(sdio),
		.p(p),
		.sclk(sclk), .csb(csb), .reset_dds(reset_dds), .pwr_dwn(pwr_dwn), .io_update(io_update)
	);

	// Add user logic here

	// User logic ends

	endmodule
