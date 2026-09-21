## Clocks
#set_property -dict { PACKAGE_PIN N13   IOSTANDARD LVCMOS33 } [get_ports { I_pll_clk1 }];
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { clk_i }];
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_i_IBUF]

## Reset
set_property -dict { PACKAGE_PIN R1    IOSTANDARD LVCMOS33 } [get_ports { rst_i }]; #IO_L16P_T2_35 Sch=ck_rst
set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports { cw_pdic_i }]; #IO_L16P_T2_35 Sch=ck_rst

## Switches
set_property -dict { PACKAGE_PIN J16   IOSTANDARD LVCMOS33 } [get_ports { boot_select_i }]; #IO_L12N_T1_MRCC_16 Sch=sw[0]
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { execute_from_flash_i }]; #IO_L13P_T2_MRCC_16 Sch=sw[1]
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[2] }]; #IO_L13N_T2_MRCC_16 Sch=sw[2]
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[3] }]; #IO_L14P_T2_SRCC_16 Sch=sw[3]

## SPI
#set_property -dict {PACKAGE_PIN L12 IOSTANDARD LVCMOS33} [get_ports spi_flash_csb_o]
#set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_cw305_io[0]}]
#set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {spi_flash_sd_cw305_io[1]}]

## LEDs
set_property -dict { PACKAGE_PIN T2    IOSTANDARD LVCMOS33 } [get_ports { clk_led_o }]; #IO_L24N_T3_35 Sch=led[4]
set_property -dict { PACKAGE_PIN T3    IOSTANDARD LVCMOS33 } [get_ports { rst_led_o }]; #IO_25_35 Sch=led[5]
set_property -dict { PACKAGE_PIN T4    IOSTANDARD LVCMOS33 } [get_ports { exit_value_o }]; #IO_L24P_T3_A01_D17_14 Sch=led[6]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_led_o_OBUF]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_led_o_OBUF]

# set_property DRIVE 8 [get_ports LED*]

# JTAG
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS33} [get_ports jtag_tdi_i]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports jtag_tdo_o]
set_property -dict {PACKAGE_PIN B12 IOSTANDARD LVCMOS33} [get_ports jtag_tms_i]
set_property -dict {PACKAGE_PIN A12 IOSTANDARD LVCMOS33} [get_ports jtag_tck_i]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports jtag_trst_ni]


## UART
set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }]; #CW IO1
set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]; #CW IO2

# IO3-4:
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[8] }]; #IO4
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[9] }]; #IO3

# GPIO
set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[4] }]; # Sch=btnu
set_property -dict { PACKAGE_PIN D16   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[5] }]; # Sch=led[4]
set_property -dict { PACKAGE_PIN E13   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[6] }]; # Sch=led[5]
set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[7] }]; # Sch=led[6]
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[0] }]; # Sch=led[7]
set_property -dict { PACKAGE_PIN F12   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[1] }]; # Sch=sw[2]
set_property -dict { PACKAGE_PIN E11   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[10] }]; # Sch=sw[3]
set_property -dict { PACKAGE_PIN F13   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[11] }]; # Sch=sw[4]
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[12] }]; # Sch=sw[5]
set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { gpio_io[13] }]; # Sch=sw[6]

# USB
set_property -dict { PACKAGE_PIN F5   IOSTANDARD LVCMOS33 } [get_ports usb_clk_i]

set_property -dict { PACKAGE_PIN A7   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_data_io[0]}]
set_property -dict { PACKAGE_PIN B6   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_data_io[1]}]
set_property -dict { PACKAGE_PIN D3   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_data_io[2]}]
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_data_io[3]}]
set_property -dict { PACKAGE_PIN F3   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_data_io[4]}]
set_property -dict { PACKAGE_PIN B5   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_data_io[5]}]
set_property -dict { PACKAGE_PIN K1   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_data_io[6]}]
set_property -dict { PACKAGE_PIN K2   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_data_io[7]}]

set_property -dict { PACKAGE_PIN F4   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[0]}]
set_property -dict { PACKAGE_PIN G5   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[1]}]
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[2]}]
set_property -dict { PACKAGE_PIN H1   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[3]}]
set_property -dict { PACKAGE_PIN H2   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[4]}]
set_property -dict { PACKAGE_PIN G1   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[5]}]
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[6]}]
set_property -dict { PACKAGE_PIN F2   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[7]}]
set_property -dict { PACKAGE_PIN E1   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[8]}]
set_property -dict { PACKAGE_PIN E2   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[9]}]
set_property -dict { PACKAGE_PIN D1   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[10]}]
set_property -dict { PACKAGE_PIN C1   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[11]}]
set_property -dict { PACKAGE_PIN K3   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[12]}]
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[13]}]
set_property -dict { PACKAGE_PIN J3   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[14]}]
set_property -dict { PACKAGE_PIN B2   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[15]}]
set_property -dict { PACKAGE_PIN C7   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[16]}]
set_property -dict { PACKAGE_PIN C6   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[17]}]
set_property -dict { PACKAGE_PIN D6   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[18]}]
set_property -dict { PACKAGE_PIN C4   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[19]}]
set_property -dict { PACKAGE_PIN D5   IOSTANDARD LVCMOS33 } [get_ports {cw_usb_addr_i[20]}]

set_property -dict { PACKAGE_PIN A4   IOSTANDARD LVCMOS33 } [get_ports cw_usb_rd_ni]
set_property -dict { PACKAGE_PIN C2   IOSTANDARD LVCMOS33 } [get_ports cw_usb_we_ni]
set_property -dict { PACKAGE_PIN A3   IOSTANDARD LVCMOS33 } [get_ports cw_usb_cs_ni]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
