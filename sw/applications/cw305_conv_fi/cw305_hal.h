#ifndef CW305_HAL_H
#define CW305_HAL_H

#define TRIG_GPIO 8
#include <stdint.h>

uint8_t getcha();

void putcha(uint8_t data);

void trigger_high (void);

void trigger_low (void);

void init_uart(void);

void trigger_setup(void);

void platform_init(void);

#endif