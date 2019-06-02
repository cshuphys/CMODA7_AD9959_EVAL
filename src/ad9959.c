/*
 * ad9959.c
 *
 *  Created on: 2019-05-09
 *      Author: CHI SHU (HARVARD-MIT-CUA)
 */

#include "ad9959.h"
#include "sleep.h"

/**
 *
 * Reset ERROR register of AD9959_control_module
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
void AD9959_ERROR_Clear(){
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x0000);
	usleep(100);
}

/**
 * check error register of AD9959_control_module
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
int AD9959_ERROR_Check(){
	u32 ERROR;
	ERROR = AD9959_mReadReg(AD9959_ERROR_OFFSET);
	if(ERROR!= 0x0000){
		for(int i = 0; i< 32; i++){
			if(ERROR & (0x0001 << i)){
			}
			else{
				xil_printf("ERROR at %d\n", i);
			}
		}
	}
	else{
		//xil_printf("No ERROR!\n");
	}
	return ERROR != 0x0000;
}

/**
 * update changed registers to AD9959_DDS
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
void AD9959_UPDATE(){
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x111111FF);
	usleep(100);
}

/**
 * update all registers of AD9959_DDS to set value
 *
 * @param   none
 *
 * @return  none
 *
 * @note	Write is only allowed in case AD9959_control_module is not armed
 */
void AD9959_UPDATE_ALL(){
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x00000003);
	usleep(10000);
}

void AD9959_All_Phase_Clear(){

}

/**
 * Send IO_UPDATE to AD9959_DDS
 *
 * @param   none
 *
 * @return  none
 *
 * @note	Write is only allowed in case AD9959_control_module is not armed
 */
void AD9959_IO_UPDATE(){
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x00000006);
	usleep(800);
}

/**
 * Set trigger mode of AD9959_control_module
 *
 * @param   trigger_mode sets how AD9959_control_module is
 * 		going to be triggered.
 * 		0x0 represents external trigger
 * 		0x1 represents btn trigger
 * 		default represents software trigger
 *
 * @return  none
 *
 * @note
 */
void AD9959_Trigger_Mode(u8 trigger_mode){
	u8 controldata = 0x0;
	switch(trigger_mode){
		case 0x0:
				controldata = 0x0;
				break;
		case 0x1:
				controldata = 0x3;
				break;
		default:
				controldata = 0x2;
				;
	}
	//set control data
	AD9959_mWriteReg(AD9959_CONTROLData_OFFSET, controldata);
	//trigger mode command
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x00000007);
	usleep(100);
}

/**
 * Software trigger of AD9959_control_module
 *
 * @param	trigger set low or high level of software trigger
 * 		0x0 represents low
 * 		default	represents high
 *
 * @return  none
 *
 * @note
 */
void AD9959_Soft_Trigger(u8 trigger){
	if(trigger == 0x00){
		AD9959_mWriteReg(AD9959_CONTROLData_OFFSET, 0x00000000);
	}
	else{
		AD9959_mWriteReg(AD9959_CONTROLData_OFFSET, 0x00000001);
	}
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x00000008);
	//usleep(100);
}

/**
 * check if AD9959_control_module completes last command
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
int AD9959_Command_Check(){
	u32 readbuffer[2];
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x011111FF);
	readbuffer[0] = AD9959_mReadReg(AD9959_CONTROLData_OFFSET);
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x011111FF);
	readbuffer[1] = AD9959_mReadReg(AD9959_CONTROLData_OFFSET);
	if(readbuffer[0] == 0x00000001)
		if(readbuffer[1] == 0xFFFFFFFF)
			return 1;
	if(readbuffer[0] == 0xFFFFFFFF)
			if(readbuffer[0] == 0x00000001)
				return 1;
	return 0;
}

/**
 * readback AD9959_control_module register value
 *
 * @param   addr is 8 bit address of ad9959 register
 * 		detail check AD9959 datasheet
 * 		value other than ad9959 datasheet:
 * 		0xFF	verifier register, it alternating return 0x00000001 or 0xFFFFFFFF
 *
 * @return  u32 value in the register
 *
 * @note	the read only happens on control level, no direct reading from AD9959 chip
 * 		Therefore register of AD9959 could be different depending on Update and io_update
 *
 */
u32 AD9959_Read(u8 addr){
	u32 control = 0x01111100;
	control |= addr;
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, control);
	return AD9959_mReadReg(AD9959_CONTROLData_OFFSET);
}

/**
 * DirectWrite AD9959_control_module register value
 *
 * @param   addr is 8 bit address of ad9959 register
 * 		detail check AD9959 datasheet
 * 		value other than ad9959 datasheet:
 * 		0xFE is not allowed since it is phase reset initialization
 * 		0xFF is not allowed since it is Update register to the AD9959 by sdio
 *
 * @param   RegVal is 32 bit register value of ad9959 register
 * 		detail check AD9959 datasheet
 * 		value other than ad9959 datasheet:
 *
 * @return  u32 value in the register
 *
 * @note	the read only happens on control level, no direct reading from AD9959 chip
 * 		Therefore register of AD9959 could be different depending on Update and io_update
 * 		Write is only allowed in case AD9959_control_module is not armed
 *
 */
void AD9959_Write(u8 addr, u32 RegVal){
	u32 control = 0x11111100;
	if(addr > 0x18)
		return;
	control |= addr;
	AD9959_mWriteReg(AD9959_CONTROLData_OFFSET, RegVal);
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, control);
}

/**
 * print AD9959_control_module Register Map
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
void AD9959_PrintRegMap(){
	u32 readbuffer;
	xil_printf("AD9959_Control_Logic_Register_Map:\n");
	xil_printf("Addr(8h)\t\tReg(32h)\n");
	for(u8 addr = 0x00; addr <= 0x18; addr++){
		xil_printf("%02X \t\t\t\t", addr);
		readbuffer = AD9959_Read(addr);
		xil_printf("%08X\n", readbuffer);
	}
}

/**
 * Reset FPGA DDS Logic module AD9959_control_module
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
void AD9959_FPGA_DDS_Reset(){
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x00000001);
	usleep(100);
}

/**
 * Reset AD9959_dds and AD9959 master reset
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
void AD9959_Reset(){
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x00000009);
	usleep(800);
}

/**
 * Set reference_config for reference signal
 *
 * @param   config_mode is 2 bits value to set what output shows from reference
 * 			0 or otherwise = low in waiting case
 * 			1 = io_update
 * 			2 = trigger
 *
 * @return  none
 *
 * @note
 */
void AD9959_RefConfig(u8 config_mode){
	config_mode &= 0x03;
	AD9959_mWriteReg(AD9959_CONTROLData_OFFSET, config_mode);
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x0000000A);
}

/**
 * Set set clock divider for dds sclk
 *
 * @param   clk_divider is 5 bits value to set what division between Mb clk to dds clk
 *
 *
 * @return  none
 *
 * @note	AD9959_Reset is needed to have clk_divider take into effect
 */
void AD9959_ClkDivider(u8 clk_divider){
	clk_divider &= 0x1F;
	AD9959_mWriteReg(AD9959_CONTROLData_OFFSET, clk_divider);
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x0000000F);
}

/**
 * Arm FPGA DDS Logic module AD9959_control_module
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
void AD9959_FPGA_DDS_ARMED(){
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0xFFFFFFFF);
	usleep(100);
}

/**
 * initialize AD9959_control_module
 *
 * @param   Ch the last four bits represents which channel is going to reset phase word
 *
 * @return  none
 *
 * @note
 */
void AD9959_phase_reset_init(u8 Ch){
	Ch &= 0x0F;
	AD9959_mWriteReg(AD9959_CONTROLData_OFFSET, Ch);
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x111111FE);
}

/**
 * initialize AD9959_control_module
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
u32 AD9959_UpdateComponents(){
	return AD9959_mReadReg(AD9959_UpdateC_OFFSET);
}

/**
 * initialize AD9959_control_module
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
void AD9959_init(){
	AD9959_ERROR_Clear();
	AD9959_FPGA_DDS_Reset();
	AD9959_mem_Addr(0x0, 0x0, 0x0F, 0x0);		//reset RAM addr
	AD9959_ClkDivider(0x01);		//Runing at 50MHz clk with 25MHz for spi limited by ad9959 eval capacitance
	AD9959_Reset();
	AD9959_UPDATE_ALL();
	AD9959_IO_UPDATE();
	usleep(1000);

	if(AD9959_Command_Check())
		xil_printf("Update All test pass!\n");
	else
		xil_printf("Update All test fail!\n");

	if(AD9959_ERROR_Check()){
	}
	else
		xil_printf("No ERROR!\n");
}

