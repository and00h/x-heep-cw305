module cw305_xheep_bridge
  import obi_pkg::*;
#(
    parameter ADDR_WIDTH   = 21,
    parameter BYTECNT_SIZE = 7
) (
    input  logic clk_i,
    input  logic usb_clk_i,
    input  logic rst_ni,
    output logic target_rst_no,

    // Interface to USB frontend
    input  logic      [            13:0] cw_addr_i,
    input  logic      [BYTECNT_SIZE-1:0] cw_bytecnt_i,
    output logic      [             7:0] cw_read_data_o,
    input  logic      [             7:0] cw_write_data_i,
    input  logic                         cw_read_req_i,
    input  logic                         cw_write_req_i,
    input  logic                         cw_addrvalid_i,
    // OBI Interface
    output obi_req_t                     bus_req_o,
    input  obi_resp_t                    bus_resp_i
);

  // =================================================================
  // USB CLOCK DOMAIN
  // =================================================================

  // 2. Write Address Translation (USB to SRAM/ROM)
  logic [31:0] translated_write_addr;
  always_comb begin
    if (cw_addr_i >= 14'h2000) begin
      translated_write_addr = 32'h2000_0000 + {11'b0, (cw_addr_i - 14'h2000), cw_bytecnt_i};
      // SoC Control Peripheral (0x20000000)
    end else if (cw_addr_i >= 14'h1000) begin
      translated_write_addr = 32'h0000_0000 + {11'b0, (cw_addr_i - 14'h1000), cw_bytecnt_i};
    end else begin
      translated_write_addr = {11'b0, cw_addr_i, cw_bytecnt_i};
    end
  end

  logic [1:0] byte_offset;
  assign byte_offset = translated_write_addr[1:0];

  // 3. Control Registers (Reset & Read Mailbox)
  logic reg_reset_n;
  logic [31:0] mailbox_read_addr;
  logic mailbox_trigger_req;
  logic mailbox_trigger_ack;
  logic [31:0] mailbox_read_data;

  assign xheep_core_rst_no = reg_reset_n;

  always_ff @(posedge usb_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reg_reset_n         <= 1'b0;
      mailbox_read_addr   <= 32'h0;
      mailbox_trigger_req <= 1'b0;
    end else if (cw_write_req_i) begin
      // Capture the reset register
      if (cw_addr_i == 14'h0000) begin
        reg_reset_n <= ~cw_write_data_i[0];
      end  // Capture the ENTIRE 4-byte burst for the Mailbox Address (0x04 to 0x07)
      else if (cw_addr_i == 14'h0004) begin
        mailbox_read_addr[(byte_offset*8)+:8] <= cw_write_data_i;

        // Fire the trigger to X-HEEP ONLY when the 4th byte (offset 3) lands
        if (byte_offset == 2'b11) begin
          mailbox_trigger_req <= 1'b1;
        end
      end
    end else if (mailbox_trigger_ack) begin
      mailbox_trigger_req <= 1'b0;  // Clear request when X-HEEP acks
    end
  end

  // 4. USB Read Data Mux
  always_comb begin
    cw_read_data_o = 8'hAA;
    if (cw_addr_i == 14'h0000) begin
      if (cw_bytecnt_i == 7'h00) cw_read_data_o = 8'h55;
    end else if (cw_addr_i == 14'h0008) begin
      case (cw_bytecnt_i)
        7'b000_0000: cw_read_data_o = mailbox_read_data[7:0];
        7'b000_0001: cw_read_data_o = mailbox_read_data[15:8];
        7'b000_0010: cw_read_data_o = mailbox_read_data[23:16];
        7'b000_0011: cw_read_data_o = mailbox_read_data[31:24];
        default:     cw_read_data_o = 8'hEE;
      endcase
    end
  end
  // always_comb begin
  //     // Default value (your 'AA' helps us see when we miss a match)
  //     cw_read_data_o = 8'hAA; 

  //     // 1. Address 0 check (Version/ID)
  //     if (full_cw_addr == 21'h00_0000) begin
  //         cw_read_data_o = 8'h55;
  //     end 

  //     // 2. Mailbox Read Range (0x08, 0x09, 0x0A, 0x0B)
  //     // We check if the "Register" part is 0 and the "Byte" part is 8-11
  //     else if (cw_addr_i == 14'h0000 && (cw_bytecnt_i >= 7'h08 && cw_bytecnt_i <= 7'h0B)) begin
  //         case (cw_bytecnt_i[1:0])
  //             2'b00: cw_read_data_o = mailbox_read_data[7:0];
  //             2'b01: cw_read_data_o = mailbox_read_data[15:8];
  //             2'b10: cw_read_data_o = cw_bytecnt_i;
  //             2'b11: cw_read_data_o = cw_addr_i[7:0];
  //         endcase
  //     end
  // end

  // 5. Async FIFO logic for Writes
  logic fifo_full, fifo_empty, fifo_rd_en;
  logic [41:0] fifo_din, fifo_dout;

  // Only push to FIFO if writing to memory regions (>= 0x08_0000)
  logic fifo_wr_en;
  assign fifo_wr_en = cw_write_req_i && (cw_addr_i >= 14'h1000 && cw_addr_i <= 14'h207F);
  assign fifo_din   = {translated_write_addr, cw_write_data_i, byte_offset};

  xpm_fifo_async #(
      .FIFO_MEMORY_TYPE("distributed"),
      .FIFO_WRITE_DEPTH(32),
      .WRITE_DATA_WIDTH(42),
      .READ_DATA_WIDTH (42),
      .CDC_SYNC_STAGES (4),
      .READ_MODE       ("fwft")
  ) u_write_fifo (
      .rst          (~rst_ni),
      .wr_clk       (usb_clk_i),
      .wr_en        (fifo_wr_en),
      .din          (fifo_din),
      .full         (fifo_full),
      .rd_clk       (clk_i),
      .rd_en        (fifo_rd_en),
      .dout         (fifo_dout),
      .empty        (fifo_empty),
      .sleep        (1'b0),
      .injectsbiterr(1'b0),
      .injectdbiterr(1'b0)
  );

  // =================================================================
  // X-HEEP CLOCK DOMAIN (heep_clk_i)
  // =================================================================

  // CDC Handshake instances
  logic        heep_read_req;
  logic [31:0] heep_read_addr;
  logic        heep_read_ack;

  xpm_cdc_handshake #(
      .WIDTH(32),
      .DEST_EXT_HSK(1)
  ) u_cdc_read_req (
      .src_clk (usb_clk_i),
      .src_in  (mailbox_read_addr),
      .src_send(mailbox_trigger_req),
      .src_rcv (mailbox_trigger_ack),
      .dest_clk(clk_i),
      .dest_out(heep_read_addr),
      .dest_req(heep_read_req),
      .dest_ack(heep_read_ack)
  );

  xpm_cdc_handshake #(
      .WIDTH(32),
      .DEST_EXT_HSK(0)
  ) u_cdc_read_resp (
      .src_clk(clk_i),
      .src_in(bus_resp_i.rdata),
      .src_send(heep_read_ack),  // Send back exactly when OBI read is done
      .dest_clk(usb_clk_i),
      .dest_out(mailbox_read_data),
      .dest_req(),
      .dest_ack(1'b1)
  );

  // OBI Arbiter / State Machine
  typedef enum logic [1:0] {
    IDLE,
    WAIT_GNT,
    WAIT_RVALID
  } state_t;
  state_t state_q, state_d;
  logic is_read_op_q, is_read_op_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      is_read_op_q <= 1'b0;
    end else begin
      state_q <= state_d;
      is_read_op_q <= is_read_op_d;
    end
  end

  always_comb begin
    state_d         = state_q;
    is_read_op_d    = is_read_op_q;


    bus_req_o.req   = 1'b0;
    bus_req_o.addr  = 32'h0;
    bus_req_o.wdata = 32'h0;
    bus_req_o.be    = 4'h0;
    bus_req_o.we    = 1'b0;

    fifo_rd_en      = 1'b0;
    heep_read_ack   = 1'b0;

    case (state_q)
      IDLE: begin
        // Priority 1: CDC Mailbox Reads
        if (heep_read_req) begin
          is_read_op_d = 1'b1;
          state_d = WAIT_GNT;
        end  // Priority 2: FIFO Writes
        else if (!fifo_empty) begin
          is_read_op_d = 1'b0;
          state_d = WAIT_GNT;
        end
      end

      WAIT_GNT: begin
        bus_req_o.req = 1'b1;

        if (is_read_op_q) begin
          // Execute Read
          bus_req_o.addr = heep_read_addr;
          bus_req_o.we   = 1'b0;
          if (bus_resp_i.gnt) state_d = WAIT_RVALID;
        end else begin
          // Execute Write from FIFO
          bus_req_o.addr  = {fifo_dout[41:12], 2'b00};
          bus_req_o.wdata = {24'b0, fifo_dout[9:2]} << (fifo_dout[1:0] * 8);
          bus_req_o.be    = 4'b0001 << fifo_dout[1:0];
          bus_req_o.we    = 1'b1;

          if (bus_resp_i.gnt) begin
            fifo_rd_en = 1'b1;  // Pop FIFO
            state_d = IDLE;
          end
        end
      end

      WAIT_RVALID: begin
        if (bus_resp_i.rvalid) begin
          heep_read_ack = 1'b1;  // Signal CDC macro that data is valid
          state_d = IDLE;
        end
      end
    endcase
  end

endmodule
