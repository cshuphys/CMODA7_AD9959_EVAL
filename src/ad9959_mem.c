/*
 * ad9959_mem.c
 *
 *  Created on: 2019-05-12
 *      Author: Chi Shu (Harvard-MIT CUA)
 */



#include "ad9959.h"
#include "sleep.h"

/**
 *
 * Set AD9959_control_module memory highest address
 *
 * @param   HighAddr is the highest addr of the data in trigger mode
 * 		only last 12 bit used as addr
 *
 * @return  none
 *
 * @note 	Write is only allowed in case AD9959_control_module is not armed
 */
void AD9959_mem_HighAddr(u16 HighAddr){
	HighAddr &= 0x0FFF;	// only last 12 bit
	AD9959_mWriteReg(AD9959_CONTROLData_OFFSET, HighAddr);
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x00000002);
}

/**
 *
 * Read AD9959_control_module memory highest address
 *
 * @param
 *
 * @return  12 bit number as highest addr of the sequence memory
 *
 * @note
 */
u16 AD9959_mem_HighAddrRead(){
	u16 HighAddr = 0x0;	// only last 12 bit
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x10000002);
	HighAddr = 0x0FFF & AD9959_mReadReg(AD9959_CONTROLData_OFFSET);
	xil_printf("Mem Highest Addr: %03X\n", HighAddr);
	return HighAddr;
}

/**
 *
 * Set addr of AD9959_control_module memory and command Ram
 *
 * @param	addr is 12 bit RAM_addr
 *
 * @param	command is 2 bit value control if freq, phase or amp register change in update
 * 		0x0 or 0x3 represents freq;
 * 		0x1 represents phase;
 * 		0x2 represents amp;
 *
 * @param	Ch is 4 bits value control which channel is in sequence control
 *
 * @param	RampRate is 10 bit value max at 1000 for control ramp speed
 *
 * @return  none
 *
 * @note 	Write is only allowed in case AD9959_control_module is not armed
 */
void AD9959_mem_Addr(u16 addr, u16 command, u8 Ch, u16 RampRate){
	u32 addr32 = 0x00000000;
	addr &= 0x0FFF;		//only last 12 bits matter
	addr32 |= addr;
	command &= 0x0003;	//only last 2 bits matter
	Ch &= 0x0F;
	RampRate &= 0x03FF;
	RampRate = RampRate > 1000 ? 0 : RampRate;
	command |= ((command << 14) | (Ch << 10) | RampRate);
	addr32 |= command << 14;	//set RAM_addr[29:28] for command register
	AD9959_mWriteReg(AD9959_RAMAddr_OFFSET, addr32);
}

/**
 *
 * Initialize burst write mode of AD9959_control_module memory and set command value
 *
 * @param	addr is 12 bit RAM_addr
 *
 * @param	command is 2 bit value control if freq, phase or amp register change in update
 * 		0x0 or 0x3 represents freq;
 * 		0x1 represents phase;
 * 		0x2 represents amp;
 *
 * @return  none
 *
 * @note 	Write is only allowed in case AD9959_control_module is not armed
 */
void AD9959_mem_BurstInit(u16 addr, u8 command){
	u32 addr32 = 0x00000000;
	addr &= 0x0FFF;		//only last 12 bits matter
	addr32 |= addr;
	command &= 0x03;	//only last 2 bits matter
	addr32 |= command << 28;	//set RAM_addr[29:28] for command register
	//set initial addr for burst write mode
	AD9959_mWriteReg(AD9959_RAMAddr_OFFSET, addr32);
	addr32 |= 0x80000000;		//set burst mode of writing
	AD9959_mWriteReg(AD9959_RAMAddr_OFFSET, addr32);
}

/**
 *
 * End burst writing mode of AD9959_control_module memory
 * Addr will be set to 0x000 and command is 0x0
 *
 * @param	none
 *
 * @return  none
 *
 * @note 	Write is only allowed in case AD9959_control_module is not armed
 * 		This function only work correctly is BurstInit has used
 */
void AD9959_mem_BurstEnd(){
	AD9959_mWriteReg(AD9959_RAMAddr_OFFSET, 0x00000000);
}

/**
 *
 * Write single burst data into AD9959_control_module memory
 * Addr follows last write addr and addr add 1 after Ddata write
 *
 * @param	Tdata is 32 bit Time value save in TRAM at RAM_addr
 *
 * @param	Ddata is 32 bit data value save in DRAM at RAM_addr
 *
 * @param	RampD is 32 bit data value save in RampDRAM at RAM_addr
 *
 * @return  none
 *
 * @note 	Write is only allowed in case AD9959_control_module is not armed
 * 		This function only work correctly is BurstInit has used
 */
void AD9959_mem_BurstWrite(u32 Tdata, u32 Ddata, u32 RampD){
	AD9959_mWriteReg(AD9959_TRAM_OFFSET, Tdata);
	AD9959_mWriteReg(AD9959_RampDRAM_OFFSET, RampD);
	AD9959_mWriteReg(AD9959_DRAM_OFFSET, Ddata);
}


/**
 *
 * Write single data into AD9959_control_module memory
 *
 * @param	addr is 12 bit RAM_addr
 *
 * @param	Tdata is 32 bit Time value save in TRAM at RAM_addr
 *
 * @param	Ddata is 32 bit data value save in DRAM at RAM_addr
 *
 * @param	Cdata is 32 bit Command value save in CRAM at RAM_addr
 *
 * @return  none
 *
 * @note 	Write is only allowed in case AD9959_control_module is not armed
 */
void AD9959_mem_Write(u16 addr, u32 Tdata, u32 Ddata, u16 Cdata, u8 Ch, u16 RampRate, u32 RampD){
	AD9959_mem_Addr(addr, Cdata, Ch, RampRate);
	AD9959_mWriteReg(AD9959_TRAM_OFFSET, Tdata);
	AD9959_mWriteReg(AD9959_RampDRAM_OFFSET, RampD);
	AD9959_mWriteReg(AD9959_DRAM_OFFSET, Ddata);
}

/**
 *
 * Read single data from AD9959_control_module memory
 *
 * @param	addr is 12 bit RAM_addr
 *
 * @param	RamLabel is 2 bit Label value define which Ram to be read from
 *		0x0 represents TRAM;
 * 		0x1 represents DRAM;
 * 		0x2 represents CRAM;
 * 		0x3 represents RampDRAM;
 * 		default represents TRAM;
 *
 * @return  none
 *
 * @note 	Read can be performed at any time.
 */
u32 AD9959_mem_Read(u16 addr,u8 RamLabel){
	AD9959_mem_Addr(addr, 0x0, 0x0, 0x0);
	RamLabel &= 0x03;	//only last 2 bits matter
	switch(RamLabel){
		case(0x00):
			return AD9959_mReadReg(AD9959_TRAM_OFFSET);
			break;
		case(0x01):
			return AD9959_mReadReg(AD9959_DRAM_OFFSET);
			break;
		case(0x02):
			return AD9959_mReadReg(AD9959_CRAM_OFFSET);
			break;
		case(0x03):
			return AD9959_mReadReg(AD9959_RampDRAM_OFFSET);
			break;
		default:
			return AD9959_mReadReg(AD9959_TRAM_OFFSET);
	}
}

/**
 *
 * Read single status data from AD9959_control_module memory
 *
 * @param	addr is 8 bit addr for status read
 *		0x00: RAM_addr2;
 * 		0x01: D_init;
 * 		0x02: C_init;
 * 		0x10: T_0;
 * 		0x11: T_1;
 * 		0x12: T_2;
 * 		0x20: D_0;
 * 		0x21: D_1;
 * 		0x22: D_2;
 * 		0x30: C_0;
 * 		0x31: C_1;
 * 		0x32: C_2;
 * 		0x40: RampD_0;
 * 		0x41: RampD_1;
 * 		0x42: RampD_2;
 * 		default: 0;
 *
 * @return  u32 data
 *
 * @note 	Read can be performed at any time.
 */
u32 AD9959_mem_ReadStatus(u8 addr){
	u32 command = 0x00FFFF00;
	command |= addr;
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, command);
	return AD9959_mReadReg(AD9959_CONTROLData_OFFSET);
}







