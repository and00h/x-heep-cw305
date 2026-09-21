// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#include "x-heep.h"
#include "cw305_hal.h"
#include "gpio.h"
#include "gpio_structs.h"
#include "bitfield.h"
#include "input_conv.h"

#define FS_INITIAL 0x01

#define TRIG_HIGH do { \
asm volatile ("" : : : "memory"); \
volatile gpio * gpio_per = ((volatile gpio *) GPIO_START_ADDRESS); \
gpio_per->GPIO_OUT0 = bitfield_write(gpio_per->GPIO_OUT0, BIT_MASK_1, TRIG_GPIO, true); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
} while (0);

#define TRIG_LOW do { \
asm volatile ("" : : : "memory"); \
volatile gpio * gpio_per = ((volatile gpio *) GPIO_START_ADDRESS); \
gpio_per->GPIO_OUT0 = bitfield_write(gpio_per->GPIO_OUT0, BIT_MASK_1, TRIG_GPIO, false); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
asm("nop"); asm("nop"); asm("nop"); asm("nop"); \
did_not_reset = 0xCC; \
} while (0);

// Flags and stuff that needs to be read/written by the ChipWhisperer-Lite
uint8_t __attribute__((section ("important_stuff"))) ended_ok = 0xAA;
uint8_t __attribute__((section ("important_stuff"))) did_not_reset = 0;
volatile uint32_t __attribute__((section ("important_stuff"))) mul_to_skip = 891;
volatile uint32_t __attribute__((section ("important_stuff"))) target_layer = 0;

typedef struct {
    volatile float *data;
    volatile ssize_t dims[4];
} tensor_t;

extern void entry(const float tensor_input[1][IN_CHANNELS][SPATIAL_SIZE_H][SPATIAL_SIZE_W], float tensor_output[1][OUT_CHANNELS][OUT_SPATIAL_SIZE_H][OUT_SPATIAL_SIZE_W]);
extern void entry_full(const float tensor_input[1][1][28][28], float tensor_output[1][10]);

float __attribute__((section("important_stuff"))) oooo[1][OUT_CHANNELS][OUT_SPATIAL_SIZE_H][OUT_SPATIAL_SIZE_W];
float __attribute__((section("important_stuff"))) l_oooo[1][10];

#define COMMAND_GET_OUTPUT  0
#define COMMAND_GLITCH      1

int main(void)
{
    CSR_SET_BITS(CSR_REG_MSTATUS, (FS_INITIAL << 13));
    platform_init();
    init_uart();
    trigger_setup();
    did_not_reset = 0xFF;
    ended_ok = 0xFF;

    volatile tensor_t x_tensor = {
        .data = &x[0][0][0][0],
        .dims = {1, IN_CHANNELS, SPATIAL_SIZE_H, SPATIAL_SIZE_W}
    };
#ifdef GLITCH_FULL
    entry_full(x, l_oooo);
#else
    entry(x, oooo);
#endif
    // Memory barrier to avoid GCC reordering important instructions
    __asm__ volatile("" : : "g"(oooo) : "memory");

    ended_ok = 0x55;

    return did_not_reset == 0xCC;
}