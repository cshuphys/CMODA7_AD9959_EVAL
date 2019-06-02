/*
 * userhelper.c
 *
 *  Created on: 2019-05-08
 *      Author: Chi Shu
 */

#include "userhelper.h"
#include <stdio.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "xuartlite.h"
#include "xstatus.h"
#include "xgpio.h"
#include "sleep.h"
#include "ad9959.h"

XUartLite UartLite;		//Instance of the UartLite Device
XGpio Gpio;				//Instance of the Gpio Device

XUartLite_Stats UartLite_Stats;

#define BOARD_DEVICE_ID			04		//board ID number
#define UARTLITE_DEVICE_ID		XPAR_UARTLITE_0_DEVICE_ID
#define UART_BUFFER_SIZE		16
#define GPIO_DEVICE_ID			XPAR_GPIO_0_DEVICE_ID

u8 SendBuffer[UART_BUFFER_SIZE];
u8 RecvBuffer[UART_BUFFER_SIZE];
unsigned int p_RecvBuffer = UART_BUFFER_SIZE - 1;
u8 GpioBuffer = 0x0;

/**
 * system initialization
 *
 * @param   none
 *
 * @return  Xstatus of initialization
 *
 * @note
 */
XStatus sys_init()
{	int Status;
	unsigned int SentCount;
	//unsigned int ReceivedCount = 0;
	//UART init
	Status = XUartLite_Initialize(&UartLite, UARTLITE_DEVICE_ID);
		if (Status != XST_SUCCESS) {
			return XST_FAILURE;
		}
	Status =XUartLite_SelfTest(&UartLite);
	if (Status != XST_SUCCESS){
		xil_printf("Uartlite polled Example Failed\r\n");
		return XST_FAILURE;
	}
	xil_printf("CMOD A7-35T AD9959 DDS\n", BOARD_DEVICE_ID);
	xil_printf("Aurthor: CHI SHU (HARVARD-MIT-CUA)\n");
	xil_printf("DeviceID: %02d\n", BOARD_DEVICE_ID);
	xil_printf("System Start up...\n");
	//GPIO init
	Status = XGpio_Initialize(&Gpio, GPIO_DEVICE_ID);
	if (Status != XST_SUCCESS){
		xil_printf("GPIO failed!\r\n");
		return XST_FAILURE;
	}
	//GPIO
	Status = XGpio_SelfTest(&Gpio);
	if (Status != XST_SUCCESS){
    	xil_printf("GPIO Self Test Fail\r\n");
    	return XST_FAILURE;
    }
	xil_printf("GPIO test pass!\n");

	//initializing uart buffer and send out test singal
	//UART
	xil_printf("Test data: ");

	for(int i = 0; i< UART_BUFFER_SIZE; i++){
		SendBuffer[i] = i+ 48;
		RecvBuffer[i] = 0;
	}
	while(XUartLite_IsSending(&UartLite)){	//make sure uart send out everything before uart test
			}
	SentCount = XUartLite_Send(&UartLite, SendBuffer, UART_BUFFER_SIZE);
	if (SentCount != UART_BUFFER_SIZE){
		xil_printf("\nUART buffer test failed!\n");
		return XST_FAILURE;
	}
	xil_printf("\nUART buffer test pass!\n");

	//GPIO
	XGpio_SetDataDirection(&Gpio, 1, 0x0);	//set gpio as output
	u8 gpiobuffer = 0;
	for(int i=0; i<=1000; i++){
			usleep(1000);
			if(i%50 == 0){
				gpiobuffer = (0x1C & gpiobuffer) |(((gpiobuffer & 0x03) + 1) & 0x03);
				XGpio_DiscreteWrite(&Gpio, 1, gpiobuffer);
			}
			else if(i%51 == 0){
				gpiobuffer = (0x03 & gpiobuffer) | (((gpiobuffer & 0x1C) + (1 <<2)) & 0x1C);
				XGpio_DiscreteWrite(&Gpio, 1, gpiobuffer);

			}
		}
	XGpio_DiscreteWrite(&Gpio, 1, 0x1C);

	//AD9959
	AD9959_init();


	xil_printf("Start up done!\n");
	while(XUartLite_IsSending(&UartLite)){	//make sure uart send out everything before init end
				}
	return XST_SUCCESS;
}

/**
 * Uart Polling function,
 * It is constantly monitoring uart and then appends RecvBuffer with new input
 *
 * @param   none
 *
 * @return  none
 *
 * @note
 */
void Uart_Poll(){
	u8 local_recvbuffer[UART_BUFFER_SIZE];
	unsigned int local_recvcounts = 0;
	while(XUartLite_IsSending(&UartLite)){	//make sure uart send out everything before uart test
				}
	local_recvcounts = XUartLite_Recv(&UartLite, local_recvbuffer, UART_BUFFER_SIZE);
	//new data coming, loading to RecvBuffer
	for(unsigned int i = 0; i < local_recvcounts ; i++){
		p_RecvBuffer = (p_RecvBuffer == UART_BUFFER_SIZE - 1) ? 0 : (p_RecvBuffer + 1);
		RecvBuffer[p_RecvBuffer] = local_recvbuffer[i];
	}
}

/**
 * Uart statitics error check function,
 *
 *
 * @param   none
 *
 * @return  bool for either error or no error
 *
 * @note
 */
u8 Uart_ErrorCheck(){
	if(UartLite.Stats.ReceiveOverrunErrors == 0){
		if(UartLite.Stats.ReceiveFramingErrors == 0){
			if(UartLite.Stats.ReceiveParityErrors == 0){
				return 0;
			}
		}

	}
	return 1;
}


/**
 * This is a test program for debug only,
 * It tests direct loading and ad9959 basic functions
 * It supposedly control ad9959 four channels to output different values
 *
 *
 * @param   none
 *
 * @return  Xstatus of test
 *
 * @note
 */
XStatus test_program1(){
	AD9959_PrintRegMap();
	//u32 readbuffer = 0x0;

	AD9959_RefConfig(0x1);

//	//Write ch0:
	AD9959_Write(0x00, 0x10);
	AD9959_Write(0x04, 85899346);	//10MHz
	AD9959_Write(0x05, 0);			//phase 0
	AD9959_Write(0x06, 0x001200);	//50% amp
	AD9959_UPDATE();
////	AD9959_IO_UPDATE();
//
////
//	//Write ch1:
	AD9959_Write(0x00, 0x26);
	AD9959_Write(0x04, 85899346);	//10MHz
	AD9959_Write(0x05, 0x2000);		//phase 180
	AD9959_Write(0x06, 0x0013FF);	//100% amp
	AD9959_UPDATE();
	AD9959_IO_UPDATE();
//
//
//	//Write ch2:
//	AD9959_Write(0x00, 0x46);		//4 wire mode
//	//AD9959_Write(0x04, 687194767);	//80MHz
//	AD9959_Write(0x04, 85899346);	//10MHz
//	AD9959_Write(0x05, 0x0000);		//phase 0
//	AD9959_Write(0x06, 0x0013FF);	//50% amp
//	AD9959_UPDATE();
//	//AD9959_IO_UPDATE();
////
//	//Write ch3:
//	AD9959_Write(0x00, 0x86);		//4 wire mode
//	AD9959_Write(0x04, 85899346);	//10MHz
//	AD9959_Write(0x05, 0x1000);		//phase 90
//	AD9959_Write(0x06, 0x0013FF);	//100% amp
//	AD9959_UPDATE();
//	AD9959_IO_UPDATE();
//	//usleep(1000);
//	AD9959_Write(0x04, 85899346);	//10MHz
//	xil_printf("update_components:%08X\n",AD9959_UpdateComponents());
//	AD9959_UPDATE();
	return XST_SUCCESS;
}

/**
 * This is a test program for debug only,
 * It tests data loading to ad9959_mem functions
 * It supposedly control ad9959 four channels to output different values
 * It only runs sequence as set mode
 *
 *
 * @param   none
 *
 * @return  Xstatus of test
 *
 * @note
 */
XStatus test_program2(){
	AD9959_FPGA_DDS_Reset();		//reset ad9959 control logic
	AD9959_init();

	//Write ch0:
	u32 Ddata = 8589934;		//1MHz
	u32 Dinc = 8589934;
	AD9959_Write(0x00, 0x16);	//Ch0 4 wire
	AD9959_Write(0x04, Ddata);		//1MHz
	AD9959_Write(0x05, 0);			//phase 0
	AD9959_Write(0x06, 0x0013FF);	//100% amp
	AD9959_UPDATE();
	//AD9959_IO_UPDATE();

	//Write ch1:
	AD9959_Write(0x00, 0x26);		//
	AD9959_Write(0x04, Ddata+Dinc);		//1MHz
	AD9959_Write(0x05, 0x0);		//phase 0
	AD9959_Write(0x06, 0x0013FF);	//100% amp
	AD9959_UPDATE();
	AD9959_IO_UPDATE();				//SET THE SAME PHASE
	AD9959_phase_reset_init(0x03);	//Reset phase of Ch 0 and 1
	AD9959_Write(0x04, Ddata);		//1MHz

	u32 timer = 0x0;
	u16 TotalNumData = 10;
	//Set mode sequence
	for(u16 addr = 0x000; addr < TotalNumData; addr ++){
		timer = addr*1000+100;		//every 10 us
		Ddata = Ddata + Dinc;
		//addr Tdata, Ddata, freq, Ch0, No Ramp
		AD9959_mem_Write(addr, timer, Ddata, 0x0, 0x01, 0x0, 0x0);
	}
	AD9959_mem_HighAddr(TotalNumData-1);

	//reading check
	u32 readbuffer[4];
	TotalNumData = AD9959_mem_HighAddrRead() + 1;
	xil_printf("Mem Highest Addr: %03X\n", TotalNumData);

	for(u16 addr = 0x000; addr < TotalNumData; addr ++){
		readbuffer[0] = AD9959_mem_Read(addr, 0x00);
		readbuffer[1] = AD9959_mem_Read(addr, 0x01);
		readbuffer[2] = AD9959_mem_Read(addr, 0x02);
		readbuffer[3] = AD9959_mem_Read(addr, 0x03);
		u8 Chr = (readbuffer[2] >> 10) & 0xF;
		u16 RampRater = readbuffer[2] & 0x03FF;
		u8 Cfuncr = (readbuffer[2] >> 14) & 0x03;
		xil_printf("Addr %03X:\t\tTRAM:%08X  \t\t DRAM:%08X \t\t CRAM:%08X \t\t Ch:%01X \t Func:%01X \t RampRate:%03x \t RampD:%08X\n",
				addr, readbuffer[0], readbuffer[1], readbuffer[2], Chr, Cfuncr, RampRater, readbuffer[3]);
	}
	AD9959_RefConfig(0x01);
	AD9959_FPGA_DDS_Reset();

	AD9959_Trigger_Mode(0x00);
//	AD9959_Trigger_Mode(0x10);
	AD9959_mWriteReg(AD9959_CONTROL_OFFSET, 0x011111FE);
	xil_printf("Phase init:%08X\n", AD9959_mReadReg(AD9959_CONTROLData_OFFSET));

	xil_printf("RAM_addr2:%08X\n",AD9959_mem_ReadStatus(0x00));
	xil_printf("T_0 :%08X\n",AD9959_mem_ReadStatus(0x10));
	xil_printf("T_1 :%08X\n",AD9959_mem_ReadStatus(0x11));
	AD9959_FPGA_DDS_ARMED();
	xil_printf("FPGA_ARMED!\n");
	xil_printf("RAM_addr2:%08X\n",AD9959_mem_ReadStatus(0x00));
	xil_printf("C_init :%08X\n",AD9959_mem_ReadStatus(0x02));
	xil_printf("D_init :%08X\n",AD9959_mem_ReadStatus(0x01));
	xil_printf("T_2 :%08X\n",AD9959_mem_ReadStatus(0x12));

//	AD9959_Soft_Trigger(0x01);
//	usleep(1000);
//	xil_printf("1RAM_addr2:%08X\n",AD9959_mem_ReadStatus(0x00));
//	xil_printf("T_0 :%08X\n",AD9959_mem_ReadStatus(0x10));
//	xil_printf("T_1 :%08X\n",AD9959_mem_ReadStatus(0x11));
//	xil_printf("T_2 :%08X\n",AD9959_mem_ReadStatus(0x12));
//
//	AD9959_Soft_Trigger(0x00);
//	usleep(1000);
//	xil_printf("1RAM_addr2:%08X\n",AD9959_mem_ReadStatus(0x00));
//
//	AD9959_Soft_Trigger(0x01);
//	usleep(1000);
//	xil_printf("2RAM_addr2:%08X\n",AD9959_mem_ReadStatus(0x00));
//
//	AD9959_Soft_Trigger(0x00);
//	usleep(1000);
//	xil_printf("2RAM_addr2:%08X\n",AD9959_mem_ReadStatus(0x00));
//
//
//	AD9959_Soft_Trigger(0x01);
//	usleep(1000);
//	xil_printf("3RAM_addr2:%08X\n",AD9959_mem_ReadStatus(0x00));
//
//	AD9959_Soft_Trigger(0x00);
//	usleep(1000);
//	xil_printf("3RAM_addr2:%08X\n",AD9959_mem_ReadStatus(0x00));
	return XST_SUCCESS;
}

/**
 * This is a test program for debug only,
 * It tests data loading to ad9959_mem functions
 * It supposedly control ad9959 four channels to output different values
 * It runs sequence as ramp mode both in ramp up and ramp down
 *
 *
 * @param   none
 *
 * @return  Xstatus of test
 *
 * @note
 */
XStatus test_program3(){
	AD9959_FPGA_DDS_Reset();		//reset ad9959 control logic
	AD9959_init();

	//Write ch0:
	u32 Ddata = 858993*12;		//1MHz
	u32 Dinc = 858993;
	AD9959_Write(0x00, 0x16);	//Ch0 4 wire
	AD9959_Write(0x04, Ddata);		//1MHz
	AD9959_Write(0x05, 0);			//phase 0
	AD9959_Write(0x06, 0x0013FF);	//100% amp
	AD9959_UPDATE();
	//AD9959_IO_UPDATE();

	//Write ch1:
	AD9959_Write(0x00, 0x26);		//
	AD9959_Write(0x04, Ddata);		//1MHz
	AD9959_Write(0x05, 0x0);		//phase 0
	AD9959_Write(0x06, 0x0013FF);	//100% amp
	AD9959_UPDATE();
	AD9959_IO_UPDATE();				//SET THE SAME PHASE
	AD9959_Write(0x04, Ddata+Dinc);		//1MHz
	AD9959_phase_reset_init(0X03);	//Reset phase of Ch 0 and 1

	//control burst write for ch1
	u32 timer[3]; u32 timeroffset = 100;
	u32 Ddata_list[2]; u32 dD= 0x0;
	u32 dt = 0;
	u16 TotalNumData = 10;
	//Ramp mode sequence
	//First Element loading
	timer[0] = 0*1000+timeroffset;
	Ddata_list[0] = Ddata;
	for(u16 addr = 0x001; addr < TotalNumData; addr ++){
		timer[1] = addr*1000+timeroffset;
		dt = timer[1] - timer[0];
		Ddata_list[1] = Ddata_list[0] - Dinc;
		dD = Ddata_list[1] - Ddata_list[0];
		u32 rampsteps = dt/100;
		u16 RampRate = 1;
		u32 RampD = 0;
		if(Ddata_list[1] > Ddata_list[0]){
			dD = Ddata_list[1] - Ddata_list[0];
			RampD = dD/rampsteps;
		}
		else if(Ddata_list[1] < Ddata_list[0]){
			dD = Ddata_list[0] - Ddata_list[1];
			RampD = - (dD/rampsteps);			//parentheses is necessary to make sure negative
			//RampD = - RampD;
		}
		else{		//dD =0  no ramp
			RampRate = 0;
			RampD = 0;
		}

		//addr Tdata, Ddata, freq, Ch0, RampRate, RampD
		AD9959_mem_Write(addr-1, timer[0], Ddata_list[0], 0x0, 0x01, RampRate, RampD);
		timer[0] = timer[1];
		Ddata_list[0] = Ddata_list[1];
	}
	AD9959_mem_Write(TotalNumData-1, timer[0], Ddata_list[0], 0x0, 0x01, 0x0, 0x0);
	AD9959_mem_HighAddr(TotalNumData-1);

	u32 readbuffer[4];
	//reading check

	for(u16 addr = 0x000; addr < TotalNumData; addr ++){
			readbuffer[0] = AD9959_mem_Read(addr, 0x00);
			readbuffer[1] = AD9959_mem_Read(addr, 0x01);
			readbuffer[2] = AD9959_mem_Read(addr, 0x02);
			readbuffer[3] = AD9959_mem_Read(addr, 0x03);
			u8 Chr = (readbuffer[2] >> 10) & 0xF;
			u16 RampRater = readbuffer[2] & 0x03FF;
			u8 Cfuncr = (readbuffer[2] >> 14) & 0x03;
			xil_printf("Addr %03X:\t\tTRAM:%08X  \t\t DRAM:%08X \t\t CRAM:%08X \t\t Ch:%01X \t Func:%01X \t RampRate:%03x \t RampD:%08X\n",
					addr, readbuffer[0], readbuffer[1], readbuffer[2], Chr, Cfuncr, RampRater, readbuffer[3]);
		}

	AD9959_FPGA_DDS_Reset();
	AD9959_RefConfig(0x00);
	AD9959_Trigger_Mode(0x00);
	AD9959_FPGA_DDS_ARMED();

	return XST_SUCCESS;
}




