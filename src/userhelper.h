/*
 * userhelper.h
 *	for user helper function
 *  Created on: 2019-05-08
 *      Author: Chi Shu
 */

#ifndef SRC_USERHELPER_H_
#define SRC_USERHELPER_H_

#include "xstatus.h"

XStatus sys_init();

XStatus test_program1();
XStatus test_program2();
XStatus test_program3();

void Uart_Poll();
u8 Uart_ErrorCheck();
#endif /* SRC_USERHELPER_H_ */

