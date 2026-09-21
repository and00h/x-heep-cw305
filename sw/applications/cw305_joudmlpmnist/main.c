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
#include "layer_input.h"
#include "fi_conf.h"

#define FS_INITIAL 0x01

// Flags and stuff that needs to be read/written by the ChipWhisperer-Lite
uint8_t __attribute__((section ("important_stuff"))) ended_ok = 0xAA;
uint8_t __attribute__((section ("important_stuff"))) did_not_reset = 0;
volatile uint32_t __attribute__((section ("important_stuff"))) mul_to_skip = 891;
volatile uint32_t __attribute__((section ("important_stuff"))) target_layer = 0;

typedef struct {
    volatile float *data;
    volatile ssize_t dims[4];
} tensor_t;

#ifdef TARGET_CONV
extern void entry(const float tensor_input[N_INPUTS][IN_CHANNELS][SPATIAL_SIZE_H][SPATIAL_SIZE_W], float tensor_output[N_INPUTS][OUT_CHANNELS][OUT_SPATIAL_SIZE_H][OUT_SPATIAL_SIZE_W]);
#else
extern void entry(const float tensor_input[N_INPUTS][IN_FEATURES], float tensor_output[N_INPUTS][OUT_FEATURES]);
#endif

#ifdef TARGET_CONV
float __attribute__((section("important_stuff"))) oooo[N_INPUTS][OUT_CHANNELS][OUT_SPATIAL_SIZE_H][OUT_SPATIAL_SIZE_W];
#else
float __attribute__((section("important_stuff"))) oooo[N_INPUTS][OUT_FEATURES];
#endif 

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

    entry(x, oooo);
    // Memory barrier to avoid GCC reordering important instructions
    __asm__ volatile("" : : "g"(oooo) : "memory");

    ended_ok = 0x55;

    return did_not_reset == 0xCC;
}