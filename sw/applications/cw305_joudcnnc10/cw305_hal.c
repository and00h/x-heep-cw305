// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "cw305_hal.h"
#include "gpio.h"
#include <stdio.h>
#include "uart.h"
#include "soc_ctrl.h"
#include "core_v_mini_mcu.h"
#include "error.h"
#include "x-heep.h"
#include <stdint.h>

uint8_t getcha() {
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);

    uart_t uart;
    uart.base_addr   = mmio_region_from_addr((uintptr_t)UART_START_ADDRESS);
    uart.baudrate    = 9600;
    uart.clk_freq_hz = 10000000; //soc_ctrl_get_frequency(&soc_ctrl);
    //#ifdef UART_NCO
    //uart.nco         = UART_NCO;
    //#else
    uart.nco         = ((uint64_t)uart.baudrate << (NCO_WIDTH + 4)) / uart.clk_freq_hz;
    //#endif

    if (uart_init(&uart) != kErrorOk) {
        return 0x55;
    }

    uint8_t data = 0xAA;
    uart_getchar(&uart, &data);
    return data;
}

void putcha(uint8_t data) {
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);

    uart_t uart;
    uart.base_addr   = mmio_region_from_addr((uintptr_t)UART_START_ADDRESS);
    uart.baudrate    = 9600;
    uart.clk_freq_hz = 10000000;//soc_ctrl_get_frequency(&soc_ctrl);
    //#ifdef UART_NCO
    //uart.nco         = UART_NCO;
    //#else
    uart.nco         = ((uint64_t)uart.baudrate << (NCO_WIDTH + 4)) / uart.clk_freq_hz;
    //#endif

    if (uart_init(&uart) != kErrorOk) {
        return;
    }

    uart_putchar(&uart, data);
}

void trigger_high (void) {
    gpio_write(TRIG_GPIO, true);
}

void trigger_low (void) {
    gpio_write(TRIG_GPIO, false);
}

void print (const char *ptr) {
    while (*ptr != 0) {
        putcha(*ptr);
        ptr++;
    }
}

void platform_init(void) {
    gpio_cfg_t trig_cfg = {
        .pin = TRIG_GPIO,
        .mode = GpioModeOutPushPull
    };

    gpio_result_t res = gpio_config(trig_cfg);
    if (res != GpioOk) {
        while (1);
    }
}

void init_uart(void) {
    //uart_enable_rx_int(); note: not needed as this is for when using interrupts
}

void trigger_setup(void) {
    gpio_write(TRIG_GPIO, false);
}