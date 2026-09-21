// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module clkgen_xil7series (
    input  IO_CLK,
    input  IO_RST_N,
    output clk_sys,
    output rst_sys_n
);
  logic locked_pll;
  logic io_clk_buf;
  logic clk_50_buf;
  logic clk_50_unbuf;
  logic clk_fb_buf;
  logic clk_fb_unbuf;

  // input buffer
  IBUF io_clk_ibuf (
      .I(IO_CLK),
      .O(io_clk_buf)
  );

  PLLE2_ADV #(
      .BANDWIDTH         ("OPTIMIZED"),
      .COMPENSATION      ("ZHOLD"),
      .STARTUP_WAIT      ("FALSE"),
      .DIVCLK_DIVIDE     (1),
      .CLKFBOUT_MULT     (12),
      .CLKFBOUT_PHASE    (0.000),
      .CLKOUT0_DIVIDE    (120),
      .CLKOUT0_PHASE     (0.000),
      .CLKOUT0_DUTY_CYCLE(0.500),
      .CLKIN1_PERIOD     (10)
  ) pll (
      .CLKFBOUT(clk_fb_unbuf),
      .CLKOUT0 (clk_50_unbuf),
      .CLKOUT1 (),
      .CLKOUT2 (),
      .CLKOUT3 (),
      .CLKOUT4 (),
      .CLKOUT5 (),
      // Input clock control
      .CLKFBIN (clk_fb_buf),
      .CLKIN1  (io_clk_buf),
      .CLKIN2  (1'b0),
      // Tied to always select the primary input clock
      .CLKINSEL(1'b1),
      // Ports for dynamic reconfiguration
      .DADDR   (7'h0),
      .DCLK    (1'b0),
      .DEN     (1'b0),
      .DI      (16'h0),
      .DO      (),
      .DRDY    (),
      .DWE     (1'b0),
      // Other control and status signals
      .LOCKED  (locked_pll),
      .PWRDWN  (1'b0),
      // Do not reset PLL on external reset, otherwise ILA disconnects at a reset
      .RST     (1'b0)
  );

  // output buffering
  BUFG clk_fb_bufg (
      .I(clk_fb_unbuf),
      .O(clk_fb_buf)
  );

  BUFG clk_50_bufg (
      .I(clk_50_unbuf),
      .O(clk_50_buf)
  );

  // outputs
  // clock
  assign clk_sys   = clk_50_buf;

  // reset
  assign rst_sys_n = locked_pll & IO_RST_N;
endmodule

module cw305_core_v_mini_mcu_wrapper
  import obi_pkg::*;
  import reg_pkg::*;
#(
    parameter CLK_LED_COUNT_LENGTH = 25
) (
    inout  logic clk_i,
    input  logic rst_i,
    input  logic cw_pdic_i,
    output logic rst_led_o,
    output logic clk_led_o,

    inout logic boot_select_i,
    inout logic execute_from_flash_i,

    // JTAG interface
    inout logic jtag_tck_i,
    inout logic jtag_tms_i,
    inout logic jtag_trst_ni,
    inout logic jtag_tdi_i,
    inout logic jtag_tdo_o,

    // UART interface
    inout logic uart_rx_i,
    inout logic uart_tx_o,

    // GPIO
    inout logic [13:0] gpio_io,

    // ChipWhisperer USB interface
    inout logic        usb_clk_i,
    inout logic [ 7:0] cw_usb_data_io,
    input logic [20:0] cw_usb_addr_i,
    input logic        cw_usb_rd_ni,
    input logic        cw_usb_we_ni,
    input logic        cw_usb_cs_ni,
    input logic        cw_nrst_ni,

    output logic exit_value_o
);

  wire                               clk_gen;
  logic [                      31:0] exit_value;
  wire                               rst_n;
  logic [CLK_LED_COUNT_LENGTH - 1:0] clk_count;
  logic [                      26:0] usb_clk_count;
  logic                              heep_rst_n;
  // low active reset
  assign rst_n = rst_i & cw_pdic_i;

  // reset LED for debugging
  assign rst_led_o = rst_n;

  // counter to blink an LED
  assign clk_led_o = clk_count[CLK_LED_COUNT_LENGTH-1];
  //assign exit_value_o = usb_clk_count[25];

  always_ff @(posedge clk_gen or negedge rst_n) begin : clk_count_process
    if (!rst_n) begin
      clk_count <= '0;
    end else begin
      clk_count <= clk_count + 1;
    end
  end

  always_ff @(posedge usb_clk_i or negedge rst_n) begin : usb_clk_count_process
    if (!rst_n) begin
      usb_clk_count <= 0;
    end else begin
      usb_clk_count <= usb_clk_count + 1;
    end
  end

  // eXtension Interface
  if_xif #() ext_if ();

  wire jtag_tck_buf_i;
  BUFG jtag_tck_buf_i_bufg (
      .I(jtag_tck_i),
      .O(jtag_tck_buf_i)
  );

  BUFG clk_gen_buf (
      .I(clk_i),
      .O(clk_gen)
  );

  x_heep_system x_heep_system_i (
      .hart_id_i('0),
      .xheep_instance_id_i('0),
      .intr_vector_ext_i('0),
      .xif_compressed_if(ext_if),
      .xif_issue_if(ext_if),
      .xif_commit_if(ext_if),
      .xif_mem_if(ext_if),
      .xif_mem_result_if(ext_if),
      .xif_result_if(ext_if),
      .ext_xbar_master_req_i('0),
      .ext_xbar_master_resp_o(),
      .ext_core_instr_req_o(),
      .ext_core_instr_resp_i('0),
      .ext_core_data_req_o(),
      .ext_core_data_resp_i('0),
      .ext_debug_master_req_o(),
      .ext_debug_master_resp_i('0),
      .ext_dma_read_req_o(),
      .ext_dma_read_resp_i('0),
      .ext_dma_write_req_o(),
      .ext_dma_write_resp_i('0),
      .ext_dma_addr_req_o(),
      .ext_dma_addr_resp_i('0),
      .ext_peripheral_slave_req_o(),
      .ext_peripheral_slave_resp_i('0),
      .ext_ao_peripheral_req_i('0),
      .ext_ao_peripheral_resp_o(),
      .cpu_subsystem_powergate_switch_no(),
      .cpu_subsystem_powergate_switch_ack_ni('0),
      .peripheral_subsystem_powergate_switch_no(),
      .peripheral_subsystem_powergate_switch_ack_ni('0),
      .external_subsystem_powergate_switch_no(),
      .external_subsystem_powergate_switch_ack_ni('0),
      .external_subsystem_powergate_iso_no(),
      .external_subsystem_rst_no(),
      .external_ram_banks_set_retentive_no(),
      .external_subsystem_clkgate_en_no(),
      .exit_value_o(exit_value),
      .clk_i(clk_gen),
      .rst_ni(rst_n & heep_rst_n),
      .boot_select_i(boot_select_i),
      .execute_from_flash_i('0),
      .jtag_tck_i(jtag_tck_buf_i),
      .jtag_tms_i(jtag_tms_i),
      .jtag_trst_ni(jtag_trst_ni),
      .jtag_tdi_i(jtag_tdi_i),
      .jtag_tdo_o(jtag_tdo_o),
      .uart_rx_i(uart_rx_i),
      .uart_tx_o(uart_tx_o),
      .exit_valid_o(),
      .gpio_0_io(gpio_io[0]),
      .gpio_1_io(gpio_io[1]),
      .gpio_2_io(gpio_io[2]),
      .gpio_3_io(gpio_io[3]),
      .gpio_4_io(gpio_io[4]),
      .gpio_5_io(gpio_io[5]),
      .gpio_6_io(gpio_io[6]),
      .gpio_7_io(gpio_io[7]),
      .gpio_8_io(gpio_io[8]),
      .gpio_9_io(gpio_io[9]),
      .gpio_10_io(gpio_io[10]),
      .gpio_11_io(gpio_io[11]),
      .gpio_12_io(gpio_io[12]),
      .gpio_13_io(gpio_io[13]),
      .spi_slave_sck_io(),
      .spi_slave_cs_io(),
      .spi_slave_miso_io(),
      .spi_slave_mosi_io(),
      .spi_flash_sd_0_io(),
      .spi_flash_sd_1_io(),
      .spi_flash_sd_2_io(),
      .spi_flash_sd_3_io(),
      .spi_flash_cs_0_io(),
      .spi_flash_cs_1_io(),
      .spi_flash_sck_io(),
      .spi_sd_0_io(),
      .spi_sd_1_io(),
      .spi_sd_2_io(),
      .spi_sd_3_io(),
      .spi_cs_0_io(),
      .spi_cs_1_io(),
      .spi_sck_io(),
      .i2c_scl_io(),
      .i2c_sda_io(),
      .spi2_sd_0_io(),
      .spi2_sd_1_io(),
      .spi2_sd_2_io(),
      .spi2_sd_3_io(),
      .spi2_cs_0_io(),
      .spi2_cs_1_io(),
      .spi2_sck_io(),
      .pdm2pcm_clk_io(),
      .pdm2pcm_pdm_io(),
      .i2s_sck_io(),
      .i2s_ws_io(),
      .i2s_sd_io(),
      .ext_dma_slot_tx_i('0),
      .ext_dma_slot_rx_i('0),
      .ext_dma_stop_i('0),
      .intr_ext_peripheral_i('0),
      .hw_fifo_done_i('0),
      .dma_done_o(),
      .usb_clk_i(usb_clk_i),
      .cw_usb_data_io(cw_usb_data_io),
      .cw_usb_addr_i(cw_usb_addr_i),
      .cw_usb_rd_ni(cw_usb_rd_ni),
      .cw_usb_we_ni(cw_usb_we_ni),
      .cw_usb_cs_ni(cw_usb_cs_ni),
      .heep_rst_no(heep_rst_n)
  );

  assign exit_value_o = exit_value[0];

endmodule
