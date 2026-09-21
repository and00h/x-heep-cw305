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
#include "conv_data.h"
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

typedef struct {
    volatile float *data;
    volatile ssize_t dims[4];
} tensor_t;

void conv2d(volatile tensor_t *x, volatile tensor_t *weight, volatile tensor_t *o) {
    // Flag to tell the convolution loop where to raise the trigger
    volatile uint32_t fmadd_count = 0;
    volatile int window = weight->dims[3] / 2;

    for (int n = 0; n < o->dims[0]; n++ ) {
        for (int h = 0; h < o->dims[2]; h++) {
            for (int w = 0; w < o->dims[3]; w++) {
                for (int c = 0; c < o->dims[1]; c++) {
                    int filter_base_index = c * (weight->dims[1] * weight->dims[2] * weight->dims[3]);
                    int input_base_index = n * (x->dims[1] * x->dims[2] * x->dims[3]);
                    int out_channel = c;
                    int output_index = n * (o->dims[1] * o->dims[2] * o->dims[3]) +
                                       c * (o->dims[2] * o->dims[3]) +
                                       h * (o->dims[3]) + 
                                       w;
                    volatile float sum = 0.0f;
                    for (int in_channel = 0; in_channel < weight->dims[1]; in_channel++) {
                        int filter_channel_idx = in_channel * (weight->dims[2] * weight->dims[3]);
                        int input_channel_offset = in_channel * (x->dims[2] * x->dims[3]);
                        for (int i = -window; i <= window; i++) {
                            for (int j = -window; j <= window; j++) {
                                int row = (h + i);
                                int col = (w + j);
                                int n_rows = x->dims[2];
                                int n_cols = x->dims[3];
                                int input_index = input_base_index + input_channel_offset + 
                                                  row * n_cols + 
                                                  col;
                                int filter_index = filter_base_index + filter_channel_idx + 
                                                   (i + window) * (weight->dims[2]) + 
                                                   (j + window);

                                if (fmadd_count == mul_to_skip) TRIG_HIGH;
                                if (row >= 0 && row < n_rows && col >= 0 && col < n_cols) {
                                    sum += x->data[input_index] * weight->data[filter_index];
                                }
                                TRIG_LOW;
                                fmadd_count += 1;
                            }
                        }
                    }
                    o->data[output_index] = sum;
                }
            }
        }
    }
}

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
        .dims = {1, 3, 32, 32}
    };
    volatile tensor_t w_tensor = {
        .data = &w[0][0][0][0],
        .dims = {32, 3, 3, 3}
    };
    volatile tensor_t o_tensor = {
        .data = &o[0][0][0],
        .dims = {1, 32, 32, 32}
    };

    conv2d(&x_tensor, &w_tensor, &o_tensor);
    // Memory barrier to avoid GCC reordering important instructions
    __asm__ volatile("" : : "g"(o) : "memory");

    ended_ok = 0x55;

    return did_not_reset == 0xCC;
}