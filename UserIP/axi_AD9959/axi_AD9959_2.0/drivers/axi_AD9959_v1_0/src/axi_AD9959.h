
#ifndef AXI_AD9959_H
#define AXI_AD9959_H


/****************** Include Files ********************/
#include "xil_types.h"
#include "xstatus.h"

#define AXI_AD9959_S00_AXI_SLV_REG0_OFFSET 0
#define AXI_AD9959_S00_AXI_SLV_REG1_OFFSET 4
#define AXI_AD9959_S00_AXI_SLV_REG2_OFFSET 8
#define AXI_AD9959_S00_AXI_SLV_REG3_OFFSET 12
#define AXI_AD9959_S00_AXI_SLV_REG4_OFFSET 16
#define AXI_AD9959_S00_AXI_SLV_REG5_OFFSET 20
#define AXI_AD9959_S00_AXI_SLV_REG6_OFFSET 24
#define AXI_AD9959_S00_AXI_SLV_REG7_OFFSET 28
#define AXI_AD9959_S00_AXI_SLV_REG8_OFFSET 32
#define AXI_AD9959_S00_AXI_SLV_REG9_OFFSET 36


/**************************** Type Definitions *****************************/
/**
 *
 * Write a value to a AXI_AD9959 register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written.
 *
 * @param   BaseAddress is the base address of the AXI_AD9959device.
 * @param   RegOffset is the register offset from the base to write to.
 * @param   Data is the data written to the register.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void AXI_AD9959_mWriteReg(u32 BaseAddress, unsigned RegOffset, u32 Data)
 *
 */
#define AXI_AD9959_mWriteReg(BaseAddress, RegOffset, Data) \
  	Xil_Out32((BaseAddress) + (RegOffset), (u32)(Data))

/**
 *
 * Read a value from a AXI_AD9959 register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0.
 *
 * @param   BaseAddress is the base address of the AXI_AD9959 device.
 * @param   RegOffset is the register offset from the base to write to.
 *
 * @return  Data is the data from the register.
 *
 * @note
 * C-style signature:
 * 	u32 AXI_AD9959_mReadReg(u32 BaseAddress, unsigned RegOffset)
 *
 */
#define AXI_AD9959_mReadReg(BaseAddress, RegOffset) \
    Xil_In32((BaseAddress) + (RegOffset))

/************************** Function Prototypes ****************************/


#endif // AXI_AD9959_H
