//////////////////////////////////////////////////////////////////////////////////
// Company: NewAE
// Engineer: Jean-Pierre Thibault
// 
// Create Date: 
// Design Name: 
// Module Name: cw305_usb_reg_fe
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Generic CW305 USB interface front-end, to be paired with
// project-specifc register block.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module cw305_usb_reg_fe #(
    parameter pADDR_WIDTH = 21,
    parameter pBYTECNT_SIZE = 7,
    parameter pREG_RDDLY_LEN = 3
) (
    input wire usb_clk_i,
    input wire rst_i,

    /* Interface to host */
    input  wire [            7:0] usb_data_i,
    output wire [            7:0] usb_data_o,
    output wire                   usb_isout_o,
    input  wire [pADDR_WIDTH-1:0] usb_addr_i,
    input  wire                   usb_rdn_i,
    input  wire                   usb_wrn_i,
    input  wire                   usb_cen_i,

    /* Interface to registers */
    input wire I_drive_data,
    output wire [13:0] reg_addr_o,  // Address of register
    output wire [pBYTECNT_SIZE-1:0] reg_bytecnt_o,  // Current byte count
    output wire [7:0] reg_data_o,  // Data to write
    input wire [7:0] reg_data_i,  // Data to read
    output reg reg_read_o,  // Read flag. One clock cycle AFTER this flag is high, valid data must be present on the reg_data_i bus
    output wire reg_write_o,  // Write flag. When high on rising edge valid data is present on reg_data_o
    output wire reg_addrvalid_o  // Address valid flag
);


  reg [pADDR_WIDTH-1:0] usb_addr_i_r;
  reg usb_rdn_i_r;
  reg usb_wrn_i_r;
  reg usb_cen_i_r;
  reg [pREG_RDDLY_LEN-1:0] isoutreg;

  // register USB interface inputs:
  always @(posedge usb_clk_i) begin
    usb_addr_i_r <= usb_addr_i;
    usb_rdn_i_r  <= usb_rdn_i;
    usb_wrn_i_r  <= usb_wrn_i;
    usb_cen_i_r  <= usb_cen_i;
  end

  assign reg_addrvalid_o = 1'b1;

  // reg_addr_o selects the register:
  assign reg_addr_o = usb_addr_i_r[pADDR_WIDTH-1:pBYTECNT_SIZE];

  // reg_bytecnt_o selects the byte within the register:
  assign reg_bytecnt_o = usb_addr_i_r[pBYTECNT_SIZE-1:0];

  assign reg_write_o = ~usb_cen_i_r & ~usb_wrn_i_r;

  always @(posedge usb_clk_i) begin
    if (~usb_cen_i & ~usb_rdn_i) reg_read_o <= 1'b1;
    else if (usb_rdn_i) reg_read_o <= 1'b0;
  end

  // drive output data bus:
  always @(posedge usb_clk_i) begin
    if (rst_i) begin
      isoutreg <= 0;
    end else begin
      isoutreg[0] <= ~usb_rdn_i_r;
      isoutreg[pREG_RDDLY_LEN-1:1] <= isoutreg[pREG_RDDLY_LEN-2:0];
    end
  end
  assign usb_isout_o = (|isoutreg) | (~usb_rdn_i_r) | I_drive_data;


  assign reg_data_o  = usb_data_i;
  assign usb_data_o  = reg_data_i;


endmodule
