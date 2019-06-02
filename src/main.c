/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * 	main.c: main program
 *	Created on: 2019-05-08
 *	Author: Chi Shu
 *	vendor: HARVARD_MIT_CUA
 *	Description: This program should control associated HW design for fast logic
 *	control on AD9959 DDS and some other functions
 *	The program is designed to be primarily for internal usage. Any attempt to use it
 *	in other condition should be done with caution.
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartlite    Configurable only in HW design/115200 as HW
 */
#include <stdio.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "xuartlite.h"
#include "xstatus.h"
#include "xgpio.h"
#include "sleep.h"
#include "userhelper.h"
#include "ad9959.h"

int main(void){
	//setup
	//u32 databuffer;
	//unsigned int SentCount;
	//unsigned int ReceivedCount = 0;
	if(sys_init() != XST_SUCCESS){
		return XST_FAILURE;
	}

	test_program3();
	//loop
	//waiting for input
}


