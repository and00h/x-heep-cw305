module cw305_usb
  import obi_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,
    // Register interface (connected to the external peripheral bus)
    input reg_pkg::reg_req_t reg_req_i,
    output reg_pkg::reg_rsp_t reg_rsp_o,

    // Master ports on the system bus
    output obi_req_t  peripheral_master_bus_req_o,
    input  obi_resp_t peripheral_master_bus_resp_i,

    // ChipWhisperer USB interface
    input logic        usb_clk_i,
    inout logic [ 7:0] cw_usb_data_io,
    input logic [20:0] cw_usb_addr_i,
    input logic        cw_usb_rd_ni,
    input logic        cw_usb_we_ni,
    input logic        cw_usb_cs_ni,

    output logic heep_rst_no
);

  // ==========================================================================
  // Tristate Buffer for Bidirectional USB Data
  // ==========================================================================
  logic [ 7:0] usb_data_i;
  logic [ 7:0] usb_data_o;

  // ==========================================================================
  // USB Front-end
  // ==========================================================================

  logic [13:0] usb_addr_r;
  logic [ 6:0] usb_bytecnt_r;
  logic [ 7:0] usb_data_to_bridge_r;
  logic [ 7:0] usb_data_from_bridge_r;
  logic        usb_read_r;
  logic        usb_write_r;
  logic        usb_addrvalid_r;
  logic        usb_isout;

  assign cw_usb_data_io = usb_isout ? usb_data_o : 8'bZ;
  assign usb_data_i = cw_usb_data_io;

  cw305_usb_reg_fe cw305_usb_frontend (
      .usb_clk_i(usb_clk_i),
      .rst_i(~rst_ni),
      .usb_addr_i(cw_usb_addr_i),
      .usb_data_i(usb_data_i),
      .usb_data_o(usb_data_o),
      .usb_isout_o(usb_isout),
      .usb_rdn_i(cw_usb_rd_ni),
      .usb_wrn_i(cw_usb_we_ni),
      .usb_cen_i(cw_usb_cs_ni),
      .I_drive_data(1'b0),
      .reg_addr_o(usb_addr_r),
      .reg_bytecnt_o(usb_bytecnt_r),
      .reg_data_o(usb_data_to_bridge_r),
      .reg_data_i(usb_data_from_bridge_r),
      .reg_read_o(usb_read_r),
      .reg_write_o(usb_write_r),
      .reg_addrvalid_o(usb_addrvalid_r)
  );

  // ==========================================================================
  // CDC Bridge Instantiation
  // ==========================================================================

  cw305_xheep_bridge u_bridge (
      .usb_clk_i(usb_clk_i),
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),

      .cw_addr_i      (usb_addr_r),
      .cw_bytecnt_i   (usb_bytecnt_r),
      .cw_read_data_o (usb_data_from_bridge_r),
      .cw_write_data_i(usb_data_to_bridge_r),
      .cw_read_req_i  (usb_read_r),
      .cw_write_req_i (usb_write_r),
      .cw_addrvalid_i (usb_addrvalid_r),

      .bus_req_o  (peripheral_master_bus_req_o),
      .bus_resp_i (peripheral_master_bus_resp_i),
      .heep_rst_no(heep_rst_no)
  );
endmodule
