/*
 * ad9959.h
 *
 *  Created on: 2019-05-09
 *      Author: CHI SHU (HARVARD-MIT-CUA)
 *
 * This is header file for functions related to AXI_AD9959_v1.0
 * Direct control can be user implemented but may not resulting any faster timing.
 * User should be cautious to change any functions below
 */

#ifndef SRC_AD9959_H_
#define SRC_AD9959_H_


#include "xil_types.h"
#include "xil_assert.h"
#include "xstatus.h"
#include "axi_AD9959.h"
#include "xparameters.h"
#include "xil_io.h"

#define AD9959_BASEADDR				XPAR_AXI_AD9959_0_S00_AXI_BASEADDR
#define	AD9959_RAMAddr_OFFSET		AXI_AD9959_S00_AXI_SLV_REG0_OFFSET
#define AD9959_TRAM_OFFSET			AXI_AD9959_S00_AXI_SLV_REG1_OFFSET
#define AD9959_DRAM_OFFSET			AXI_AD9959_S00_AXI_SLV_REG2_OFFSET
#define AD9959_CRAM_OFFSET			AXI_AD9959_S00_AXI_SLV_REG3_OFFSET
#define AD9959_RampDRAM_OFFSET		AXI_AD9959_S00_AXI_SLV_REG4_OFFSET
#define AD9959_UpdateC_OFFSET		AXI_AD9959_S00_AXI_SLV_REG5_OFFSET
//#define AD9959_ _OFFSET			AXI_AD9959_S00_AXI_SLV_REG6_OFFSET
#define AD9959_ERROR_OFFSET			AXI_AD9959_S00_AXI_SLV_REG7_OFFSET
#define AD9959_CONTROL_OFFSET		AXI_AD9959_S00_AXI_SLV_REG8_OFFSET
#define AD9959_CONTROLData_OFFSET	AXI_AD9959_S00_AXI_SLV_REG9_OFFSET


//Control Register Direct Loading Command
/**
*	CONTROL		NAME			Function
*	0x00000000	ERROR register Clear
*								it auto-stop clear after 16 clk cycles.
*								it takes at least 16 clk cycles.
*	0x00000001	FPGA_Control_Logic Reset
*								it resets fast ram port2 reading fifo;
*								it resets FPGRA_DDS_ARMED allowing data loading or RAM loading;
*								it resets fast control logic for triggering sequence mode and clear corresponding error.
*								it auto clear after 16 clk cycles.
*								it takes at least 16 clk cycles.
*
*	0x00000002	HighRAMaddr register Set
*								it loads CONTROLdata(+1) to the HighRAMAddr register for sequence mode. Only last 12 bit matters.
*								it only loads if FPGA_DDS_ARMED is clear.
*								it takes 1 clk cycles.
*	0x00000003	UpdateAll command
*								it updates all current registers to AD9959 DDS
*								it only take effect if FPGA_DDS_ARMED is clear and update_done is clear
*								In case of command issued,
*								it takes up to 2*(clk_divider+1)*[18*(32+8)+3*(16+8)+3*(24+8)+1*(8+8)+24]
*								= 952*(clk_divider+1) clk cycles.
*								For save operation, please have a long wait or checking command verifier register.
*	0x00000004	FPGA_EN Set
*								It allows FPGA to control DDS instead of conventional software from Analog Device
*								It is for debugging or other legacy purpose
*								User should take caution when invoke such command
*								default value is set.
*								it takes 1 clk cycles
*	0x00000005	FPGA_EN Clear
*								It allows Computer to control DDS and FPGA work as an buffer
*								FPGA board forbids read mode from computer by software from Analog Device
*								It is for debugging or other legacy purpose
*								User should take caution when invoke such command
*								default value is set.
*								it takes 1 clk cycles.
*	0x00000006	io_update send
*								It sends io_update to AD9959 DDS.
*								It only issue in case FPGA_DDS_ARMED is clear and UPDATE and UPDATE_ALL are clear
*								It auto clear after 2^16 = 65,536 cycles
*								it takes 2^16 = 65,536 cycles.
*	0x00000007	trigger mode Set
*								it sets trigger mode is software, onboard bottom or wire signal trigger
*								trigger is synchronize to main clk
*								11 = onboad bottom, 00 = external wire, 01/10 = software trigger
*								it takes 1 clk cyles.
*	0x00000008	software trigger or reset
*								it set software trigger by CONTROLdata[0], it is active high
*								it takes 1 clk cycles.
*	0x00000009	master_reset
*								it master reset AD9959 DDS
*								it also resets sequence module
*								it auto clear after 2^16 = 65,536 clk cycles
*								it takes at least 2^16 = 65,536 clk cycles.
*	0x0000000A	reference_config
*								it loads CONTROLdata to reference_config
*								0 or other value = in sequence mode it output 1 if not in timer waiting mode
*								1 = it outputs io_update delay 1 clk cycles
*								2 = it outputs trigger delay 1 clk cycles
*								it takes 1 clk cycles
*	0x0000000F clk_divider load
*								it loads CONTROLdata[4:0] to clk_divider
*								clk_divider takes effect in case AD9959 master reset command issued
*								it takes 1 clk cycles.
*	0x011111XX	register manual read out
*			00-18				it loads current value at addr (XX) in logic module into CONTROLdata read
*								subsequent reading read out value
*								addr is only up to 18
*			FF	direct done verifier
*								FF reads alternating 0xFFFFFFFF or 0x00000001.
*								if two read gives alternating values means previous command is done
*								it takes 1 clk cycles.
*	0x0FFFFFFF	FPGA_DDS_ARMED read out
*								it read out FPGA_DDS_ARMED as the highest bit into CONTROLdata read
*								subsequent reading read out value
*								it takes 1 clk cycles
*	0x111111XX	register manual input
*			00-18				In case of FPGA_DDS_ARMED is clear and update_done is clear
*								it loads CONTROLdata value to corresponding register at addr (XX)
*								subsequent update command or update_all command update value to AD9959 DDS
*								addr is only up to 18
*								it takes 1 clk cycles.
*			FE	set phase reset channel word
*			FF	update command
*								it send updates signal to FPGA control module of AD9959 update all different
*								register to last update value.
*								it takes ? clk cycles depending on number of register need to be update.
*	0xFFFFFFFF	FPGA_DDS_ARMED	Set
*								it set FPGA_DDS_ARMED to enable sequence mode
*								it enable FPGA as wll
*								it only issue above command in case update and update all are both clear.
*
*	Above are all implemented function for direct access mode, more functions will be implemented in future.
*/

/**************************** Type Definitions *****************************/



/**
 *
 * Write a value to a AXI_AD9959 register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written. The base addr of AXI_AD9959 is fixed as the
 * parameter defined in this header file.
 *
 * @param   RegOffset is the register offset from the base to write to.
 * @param   Data is the data written to the register.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void AD9959_mWriteReg(unsigned RegOffset, u32 Data)
 */
#define AD9959_mWriteReg(RegOffset, Data) \
	Xil_Out32((AD9959_BASEADDR)+(RegOffset), (u32)(Data))

/**
 *
 * Read a value from a AXI_AD9959 register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0. The base addr of AXI_AD9959 is fixed as the parameter
 * defined in this header file.
 *
 * @param   RegOffset is the register offset from the base to write to.
 *
 * @return  Data is the data from the register.
 *
 * @note
 * C-style signature:
 * 	u32 AD9959_mReadReg(unsigned RegOffset)
 */
#define AD9959_mReadReg(RegOffset) \
    Xil_In32((AD9959_BASEADDR) + (RegOffset))


/************************** Function Prototypes *****************************/

/*
 * ad9959 control functions in file ad9959.c
 */
void AD9959_ERROR_Clear();
int AD9959_ERROR_Check();
void AD9959_UPDATE();
void AD9959_UPDATE_ALL();
void AD9959_IO_UPDATE();
void AD9959_Trigger_Mode(u8 trigger_mode);
void AD9959_Soft_Trigger(u8 trigger);
int AD9959_Command_Check();
u32 AD9959_Read(u8 addr);
void AD9959_Write(u8 addr, u32 RegVal);
void AD9959_PrintRegMap();
void AD9959_FPGA_DDS_Reset();
void AD9959_Reset();
void AD9959_RefConfig(u8 config_mode);
void AD9959_ClkDivider(u8 clk_divider);
void AD9959_FPGA_DDS_ARMED();
void AD9959_phase_reset_init(u8 Ch);
u32 AD9959_UpdateComponents();
void AD9959_init();

/*
 * ad9959 memory functions in file ad9959_mem.c
 */
void AD9959_mem_HighAddr(u16 HighAddr);
u16 AD9959_mem_HighAddrRead();
void AD9959_mem_Addr(u16 addr, u16 command, u8 Ch, u16 RampRate);
void AD9959_mem_BurstInit(u16 addr, u8 command);
void AD9959_mem_BurstEnd();
void AD9959_mem_BurstWrite(u32 Tdata, u32 Ddata, u32 RampD);
void AD9959_mem_Write(u16 addr, u32 Tdata, u32 Ddata,
		u16 Cdata, u8 Ch, u16 RampRate, u32 RampD);
u32 AD9959_mem_Read(u16 addr, u8 RamLabel);
u32 AD9959_mem_ReadStatus(u8 addr);


#endif /* SRC_AD9959_H_ */
