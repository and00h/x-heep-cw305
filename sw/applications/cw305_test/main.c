// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "matfloat.h"
#include "csr.h"
#include "x-heep.h"
#include "cw305_hal.h"
#include "simpleserial.h"
#include "gpio.h"
#include "gpio_structs.h"
#include "bitfield.h"

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
} while (0);

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
        #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

// Bypass Boot ROM

uint8_t __attribute__((section ("porcodio"))) flag = 0;
uint8_t __attribute__((section ("porcodio"))) ended_ok = 0xAA;
uint8_t __attribute__((section ("porcodio"))) did_not_reset = 0;
volatile uint32_t __attribute__((section ("porcodio"))) mul_to_skip = 85;

float __attribute__((section ("porcodio"))) x[8][8] = {
    {  1.12,  0.14, -0.86, -0.62, -1.23, -1.05, -1.80, -1.87 },
    { -0.47,  0.83, -0.79, -1.40,  0.42, -0.88, -0.79, -0.04 },
    {  2.68, -0.13,  0.38,  0.78,  0.68,  0.78, -1.18, -0.59 },
    {  3.04,  3.30, -0.05, -0.11, -1.19,  0.96,  1.04,  2.12 },
    {  0.83,  1.34, -0.50,  0.86, -1.20,  0.46,  0.31, -0.63 },
    {  1.96,  1.16, -0.65,  0.01,  0.77,  0.25, -1.29, -0.84 },
    { -1.52,  0.22,  1.43,  0.40,  0.06,  0.85,  0.75,  0.77 },
    { -0.44,  0.40, -0.94,  0.93, -1.30,  2.37, -0.21,  1.22 }
};

float __attribute__((section ("porcodio"))) w[3][3] = {
    {  0.32, -0.06,  0.11 },
    { -1.57, -0.92, -0.16 },
    {  0.07,  0.48,  1.93 }
};

float __attribute__((section ("porcodio"))) o[8][8] = {
    { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
    { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
    { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
    { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
    { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
    { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
    { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
    { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 }
};

uint8_t __attribute__((section ("porcodio"))) o_clean[] = {
    0xC6, 0xA1, 0xA5, 0x3E, 0xC8, 0x29, 0x3A, 0xC0, 0x5C, 0x8F, 0x16, 0xC0, 0x46, 0xD8, 0x0C, 0x40, 0x85, 0x9E, 0x2D, 0x3F, 0x2B, 0x3A, 0xA2, 0x3F, 0x1C, 0x7C, 0x45, 0x40, 0xCE, 0x19, 0x8F, 0x40, 
    0x2C, 0x43, 0xA4, 0x3F, 0x4A, 0x7B, 0x9B, 0x3F, 0x88, 0x63, 0xAD, 0x3F, 0xDB, 0x46, 0x73, 0x40, 0x1A, 0x51, 0x66, 0x40, 0xA4, 0xDF, 0x06, 0xC0, 0x70, 0xAD, 0xFA, 0x3C, 0xBD, 0x1E, 0xE5, 0x3E, 
    0xC1, 0x17, 0xB0, 0x40, 0x15, 0x14, 0x2F, 0xC0, 0xFA, 0xCB, 0xEE, 0xBD, 0xAA, 0x82, 0x79, 0xC0, 0x6A, 0xB3, 0xA2, 0xBF, 0x46, 0x7B, 0x63, 0x3F, 0x5C, 0xFE, 0x8B, 0x40, 0xCA, 0x10, 0x4F, 0x40, 
    0xB0, 0xEA, 0x03, 0xBF, 0x9A, 0x08, 0xE5, 0xC0, 0x0A, 0x46, 0x65, 0xC0, 0x68, 0x91, 0xB5, 0xBF, 0x6D, 0xE7, 0xE3, 0x3F, 0x69, 0x22, 0xCC, 0x3F, 0x51, 0x49, 0x65, 0xC0, 0x5F, 0x98, 0x86, 0xC0, 
    0xF6, 0x75, 0x18, 0x40, 0x7D, 0xD0, 0x0F, 0xC0, 0x10, 0x2D, 0x72, 0xBF, 0xCF, 0xD5, 0xBE, 0x3F, 0xB2, 0xBF, 0x2C, 0x3F, 0xC1, 0x42, 0x9D, 0xBF, 0x2D, 0xB2, 0x29, 0xC0, 0x15, 0xAE, 0x47, 0xBE, 
    0x8B, 0x8E, 0x0C, 0xC0, 0x42, 0x57, 0x93, 0xBF, 0x15, 0x6A, 0x4D, 0x3F, 0x7C, 0xD0, 0x73, 0x3F, 0x35, 0x5E, 0xAA, 0x3F, 0x56, 0xB1, 0x7F, 0x3E, 0xBE, 0x30, 0x39, 0x40, 0x5E, 0xDC, 0x56, 0x40, 
    0x50, 0x8D, 0xF7, 0x3F, 0x08, 0xCE, 0x49, 0x3F, 0x67, 0x91, 0x6D, 0x3D, 0x00, 0x00, 0x9C, 0xC0, 0x4E, 0x8D, 0x4B, 0x40, 0x87, 0xE2, 0x87, 0xBE, 0x39, 0x8B, 0xAC, 0x3E, 0x0B, 0xB5, 0xD6, 0xBF, 
    0x0C, 0x93, 0xE9, 0x3E, 0xA8, 0x0A, 0x06, 0x3E, 0xF6, 0xCB, 0xEE, 0x3D, 0xEE, 0x5A, 0xA2, 0x3F, 0x08, 0xCE, 0xD9, 0xBE, 0x63, 0xB0, 0x61, 0xBD, 0x19, 0x51, 0x5A, 0xC0, 0x83, 0x51, 0x19, 0xBF
};

uint8_t conv2d(float output[8][8]) {
    // Iterate over every pixel in the output image
    uint32_t fmadd_count = 0;

    for (int i = 0; i < 8; i++) {         // Height
        for (int j = 0; j < 8; j++) {     // Width
                
                float sum = 0;

                // Iterate over the 3x3 kernel
                for (int m = -1; m <= 1; m++) {     // Kernel Height
                    for (int n = -1; n <= 1; n++) { // Kernel Width
                        
                        int row = i + m;
                        int col = j + n;
                        // Zero-padding boundary check
                        if (fmadd_count == mul_to_skip) TRIG_HIGH;
                        if (row >= 0 && row < 8 && col >= 0 && col < 8) {
                            // w is indexed [m+1][n+1] to shift range [-1,1] to [0,2]
                            sum += x[row][col] * w[m + 1][n + 1];
                        }
                        TRIG_LOW;
                        fmadd_count += 1;
                    }
                }
                output[i][j] = sum;
        }
    }
    // static const char *aaaa = "AAAAAAAAAAAAAAAA";
    // simpleserial_put('r', 16, (uint8_t *) aaaa);
    
    return 0;
}

uint8_t conv2d_clean(float output[8][8]) {
    // Iterate over every pixel in the output image
    for (int i = 0; i < 8; i++) {         // Height
        for (int j = 0; j < 8; j++) {     // Width
                
                float sum = 0;

                // Iterate over the 3x3 kernel
                for (int m = -1; m <= 1; m++) {     // Kernel Height
                    for (int n = -1; n <= 1; n++) { // Kernel Width
                        
                        int row = i + m;
                        int col = j + n;

                        // Zero-padding boundary check
                        if (row >= 0 && row < 8 && col >= 0 && col < 8) {
                            // w is indexed [m+1][n+1] to shift range [-1,1] to [0,2]
                            sum += x[row][col] * w[m + 1][n + 1];
                        }
                    }
                }
                output[i][j] = sum;
        }
    }
    // static const char *aaaa = "AAAAAAAAAAAAAAAA";
    // simpleserial_put('r', 16, (uint8_t *) aaaa);
    
    return 0;
}

int check() {
    float *porcata = (float *) &o_clean[0];
    for (int i = 0; i < 8; i++ ) {
        for (int j = 0; j < 8; j++) {
            if (o[i][j] != porcata[i * 8 + j]) return 1;
        }
    }

    return 0;
}

int main(void)
{
    CSR_SET_BITS(CSR_REG_MSTATUS, (FS_INITIAL << 13));
    platform_init();
    init_uart();
    trigger_setup();
    did_not_reset = 0xFF;
    ended_ok = 0xFF;

    conv2d(o);

    // ended_ok = check() ? 0xAA : 0x55;

    did_not_reset = 0xCC;
	//simpleserial_init();
    //simpleserial_addcmd('f', 0, conv2d);
    //simpleserial_get();
    return did_not_reset == 0xCC;
}