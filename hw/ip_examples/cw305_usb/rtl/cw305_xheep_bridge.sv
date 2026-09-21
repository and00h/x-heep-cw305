module cw305_xheep_bridge
  import obi_pkg::*;
#(
    parameter ADDR_WIDTH   = 21,
    parameter BYTECNT_SIZE = 7
) (
    input logic clk_i,
    input logic usb_clk_i,
    input logic rst_ni,

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
    input  obi_resp_t                    bus_resp_i,

    output logic heep_rst_no
);
  // =================================================================
  // Signal Definitions
  // =================================================================

  // OBI State Machine
  typedef enum logic [2:0] {
    IDLE,
    WAIT_GNT,
    WAIT_RVALID,
    WAIT_CDC_ACK,
    WAIT_REQ_DROP,
    COOLDOWN
  } obi_fsm_state_e;

  typedef struct packed {
    obi_fsm_state_e state;
    logic           is_read_op;
    logic           heep_resp_req;
    logic [31:0]    captured_rdata;
    logic [7:0]     obi_timeout_cnt;
    logic [7:0]     last_obi_error;
  } obi_fsm_state_t;

  obi_fsm_state_t obi_state_q, obi_state_d;

  // Block write State Machine
  typedef enum logic [1:0] {
    BLOCK_IDLE,
    PUSH
  } block_fifo_state_e;

  typedef struct packed {
    block_fifo_state_e state;
    logic              busy;
    logic [6:0]        remaining;
  } block_fifo_state_t;

  block_fifo_state_t block_fifo_state_q, block_fifo_state_d;
  logic        issue_block_transfer;

  // Block registers
  logic [31:0] block_base_addr_r;
  logic [ 6:0] block_len_r;
  logic [ 7:0] block_r              [127:0];

  // CDC Handshake signals 
  logic        heep_read_req;
  logic [31:0] heep_read_addr;
  logic        heep_read_ack;

  logic        heep_resp_ack;

  // Mailbox signals 
  logic        reg_reset_n;
  logic [ 7:0] reg_read_data_r;

  logic [31:0] mailbox_read_addr;
  logic        mailbox_trigger_req;
  logic        mailbox_trigger_ack;
  logic [31:0] mailbox_read_data;
  logic        mailbox_busy;

  // FIFO signals
  logic fifo_full, fifo_empty, fifo_rd_en;
  logic [41:0] fifo_din, fifo_dout;
  logic fifo_wr_en;

  // Error Codes: 
  // 8'h00 = No Error
  // 8'h01 = Timeout waiting for GNT
  // 8'h02 = Timeout waiting for RVALID

  logic [2:0] dbg_state_sync_q[2];
  logic [7:0] dbg_error_sync_q[2];

  // =================================================================
  // USB CLOCK DOMAIN
  // =================================================================

  always_ff @(posedge usb_clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      reg_reset_n         <= 1'b1;
      mailbox_read_addr   <= 32'h0;
      mailbox_trigger_req <= 1'b0;
      mailbox_busy        <= 1'b0;

      block_base_addr_r   <= 32'b0;
      block_len_r         <= 7'h7F;
      issue_block_transfer <= 1'b0;
      for (integer i = 0; i < 128; i++) begin
        block_r[i] <= 0;
      end
    end else begin
      if (mailbox_trigger_req) mailbox_busy <= 1'b1;
      if (mailbox_trigger_ack) begin
        mailbox_busy        <= 1'b0;
        mailbox_trigger_req <= 1'b0;  // Clear request when X-HEEP acks
      end
      if (issue_block_transfer) issue_block_transfer <= 1'b0;

      if (cw_write_req_i) begin
        case (cw_addr_i)
          14'h0000: reg_reset_n <= cw_write_data_i[0];
          14'h0004: begin
            case (cw_bytecnt_i[1:0])
              2'b00: mailbox_read_addr[7:0] <= cw_write_data_i;
              2'b01: mailbox_read_addr[15:8] <= cw_write_data_i;
              2'b10: mailbox_read_addr[23:16] <= cw_write_data_i;
              2'b11: begin
                mailbox_read_addr[31:24] <= cw_write_data_i;
                mailbox_trigger_req      <= 1'b1;  // Fire trigger on the 4th byte
              end
            endcase
          end
          14'h0010: begin
            if (!block_fifo_state_q.busy) begin
              case (cw_bytecnt_i[1:0])
                2'b00: block_base_addr_r[7:0] <= cw_write_data_i;
                2'b01: block_base_addr_r[15:8] <= cw_write_data_i;
                2'b10: block_base_addr_r[23:16] <= cw_write_data_i;
                2'b11: block_base_addr_r[31:24] <= cw_write_data_i;
              endcase
            end
          end
          14'h0011: begin
            if (!block_fifo_state_q.busy) begin
              block_r[cw_bytecnt_i] <= cw_write_data_i;
            end
          end
          14'h0012: begin
            if (!block_fifo_state_q.busy) begin
              block_len_r <= cw_write_data_i[6:0];
              issue_block_transfer <= 1'b1;
            end
          end
        endcase
      end
    end
  end

  // Best-effort 2-FF synchronizer for debug read-back only.
  // Multi-bit binary values are not safe for production CDC; momentary glitches
  // during transitions are possible but do not affect functional correctness.
  always_ff @(posedge usb_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dbg_state_sync_q[0] <= 3'b000;
      dbg_state_sync_q[1] <= 3'b000;
      dbg_error_sync_q[0] <= 8'h00;
      dbg_error_sync_q[1] <= 8'h00;
    end else begin
      dbg_state_sync_q[0] <= obi_state_q.state;
      dbg_state_sync_q[1] <= dbg_state_sync_q[0];

      dbg_error_sync_q[0] <= obi_state_q.last_obi_error;
      dbg_error_sync_q[1] <= dbg_error_sync_q[0];
    end
  end

  // 4. USB Read Data Mux
  always_comb begin
    reg_read_data_r = 8'hCB;
    if (cw_read_req_i) begin
      case (cw_addr_i)
        14'h0000: reg_read_data_r = (cw_bytecnt_i == 7'h00) ? 8'h55 : 8'h66;
        14'h0004:
        case (cw_bytecnt_i)
          7'b000_0000: reg_read_data_r = mailbox_read_addr[7:0];
          7'b000_0001: reg_read_data_r = mailbox_read_addr[15:8];
          7'b000_0010: reg_read_data_r = mailbox_read_addr[23:16];
          7'b000_0011: reg_read_data_r = mailbox_read_addr[31:24];
          7'b000_0100: reg_read_data_r = {7'h00, mailbox_busy};
          default:     reg_read_data_r = 8'hEE;
        endcase
        14'h0008:
        case (cw_bytecnt_i)
          7'b000_0000: reg_read_data_r = mailbox_read_data[7:0];
          7'b000_0001: reg_read_data_r = mailbox_read_data[15:8];
          7'b000_0010: reg_read_data_r = mailbox_read_data[23:16];
          7'b000_0011: reg_read_data_r = mailbox_read_data[31:24];
          default:     reg_read_data_r = 8'hEE;
        endcase
        14'h000C:  // New Trace/Debug Address
        case (cw_bytecnt_i)
          7'b000_0000: reg_read_data_r = {5'b00000, dbg_state_sync_q[1]};  // Byte 0: Current State
          7'b000_0001: reg_read_data_r = dbg_error_sync_q[1];  // Byte 1: Last Error
          default: reg_read_data_r = 8'hEE;
        endcase
        14'h0010:
        case (cw_bytecnt_i)
          7'b000_0000: reg_read_data_r = block_base_addr_r[7:0];
          7'b000_0001: reg_read_data_r = block_base_addr_r[15:8];
          7'b000_0010: reg_read_data_r = block_base_addr_r[23:16];
          7'b000_0011: reg_read_data_r = block_base_addr_r[31:24];
          default:     reg_read_data_r = 8'hEE;
        endcase
        14'h0011: reg_read_data_r = block_r[cw_bytecnt_i];
        14'h0012: reg_read_data_r = block_len_r;
        14'h0013: reg_read_data_r = {block_fifo_state_q.busy, block_fifo_state_q.remaining};
        14'h0020: reg_read_data_r = {1'b0, cw_bytecnt_i};
        14'h0030: reg_read_data_r = {7'b0, obi_state_q.is_read_op};
        14'h0040:
        case (cw_bytecnt_i)
          7'h00: reg_read_data_r = {5'b0, fifo_wr_en, fifo_empty, fifo_full};
          7'h01: reg_read_data_r = {6'b0, bus_resp_i.gnt, bus_resp_i.rvalid};
          7'h02: reg_read_data_r = {2'b0, bus_req_o.req, bus_req_o.we, bus_req_o.be};
        endcase
        default: reg_read_data_r = 8'hAA;
      endcase
    end else begin
      reg_read_data_r = 8'hCC;
    end
  end

  assign cw_read_data_o = reg_read_data_r;
  assign heep_rst_no    = reg_reset_n;

  always_ff @(posedge usb_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      block_fifo_state_q <= '0;
      block_fifo_state_q.state <= BLOCK_IDLE;
    end else begin
      block_fifo_state_q <= block_fifo_state_d;
    end
  end

  logic [31:0] effective_address;
  logic [ 1:0] byte_offset;
  assign effective_address = block_base_addr_r + block_fifo_state_q.remaining;
  assign byte_offset = effective_address[1:0];

  always_comb begin
    block_fifo_state_d = block_fifo_state_q;
    fifo_wr_en = 1'b0;
    fifo_din = '0;

    case (block_fifo_state_q.state)
      BLOCK_IDLE: begin
        if (issue_block_transfer) begin
          block_fifo_state_d.state     = PUSH;
          block_fifo_state_d.busy      = 1'b1;
          block_fifo_state_d.remaining = block_len_r;
          fifo_wr_en                   = 1'b0;
        end
      end
      PUSH: begin
        if (!fifo_full) begin
          fifo_din = {
            block_base_addr_r + block_fifo_state_q.remaining,
            block_r[block_fifo_state_q.remaining],
            byte_offset
          };
          fifo_wr_en = 1'b1;
          block_fifo_state_d.remaining = block_fifo_state_q.remaining - 1;
          if (block_fifo_state_q.remaining == 7'h00) begin
            block_fifo_state_d.state = BLOCK_IDLE;
            block_fifo_state_d.busy  = 1'b0;
          end
        end
      end
      default: begin
        block_fifo_state_d.state = BLOCK_IDLE;
        block_fifo_state_d.busy  = 1'b0;
      end
    endcase
  end
  // 5. Async FIFO logic for Writes

  xpm_fifo_async #(
      .FIFO_MEMORY_TYPE("block"),
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
      .src_clk (clk_i),
      .src_in  (obi_state_q.captured_rdata),  // 1. Use stable, captured data
      .src_send(obi_state_q.heep_resp_req),   // 2. Hold high until acknowledged
      .src_rcv (heep_resp_ack),               // 3. Listen for macro acknowledgement
      .dest_clk(usb_clk_i),
      .dest_out(mailbox_read_data),
      .dest_req(),
      .dest_ack()
  );


  // OBI Arbiter / State Machine
  logic [31:0] obi_addr;
  logic [31:0] obi_wdata, obi_rdata;
  logic obi_we;
  logic [3:0] obi_be;

  logic [31:0] addr_reg_d, addr_reg_q;
  logic [31:0] wdata_reg_d, wdata_reg_q;
  logic [1:0] byte_offset_reg_d, byte_offset_reg_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      obi_state_q       <= '0;
      obi_state_q.state <= IDLE;
      addr_reg_q        <= '0;
      wdata_reg_q       <= '0;
      byte_offset_reg_q <= '0;
    end else begin
      obi_state_q <= obi_state_d;
      addr_reg_q <= addr_reg_d;
      wdata_reg_q <= wdata_reg_d;
      byte_offset_reg_q <= byte_offset_reg_d;
    end
  end

  assign obi_addr = addr_reg_q;
  assign obi_wdata = wdata_reg_q;
  assign obi_we = !obi_state_q.is_read_op;
  assign obi_be = (obi_state_q.is_read_op) ? 4'b1111 : (4'b0001 << byte_offset_reg_q);

  // Next-state
  always_comb begin
    obi_state_d = obi_state_q;
    addr_reg_d = addr_reg_q;
    wdata_reg_d = wdata_reg_q;
    byte_offset_reg_d = byte_offset_reg_q;

    case (obi_state_q.state)
      IDLE: begin
        obi_state_d.obi_timeout_cnt = 8'h00;
        if (heep_read_req) begin
          addr_reg_d             = heep_read_addr;
          obi_state_d.is_read_op = 1'b1;
          obi_state_d.state      = WAIT_GNT;
        end  // Priority 2: FIFO Writes
        else if (!fifo_empty) begin
          addr_reg_d             = {fifo_dout[41:12], 2'b00};
          wdata_reg_d            = {4{fifo_dout[9:2]}};
          byte_offset_reg_d      = fifo_dout[11:10];
          obi_state_d.is_read_op = 1'b0;
          obi_state_d.state      = WAIT_GNT;
        end
      end
      WAIT_GNT: begin
        if (bus_resp_i.gnt) begin
          obi_state_d.state = WAIT_RVALID;  // ALL transactions must wait for rvalid
          obi_state_d.obi_timeout_cnt = 8'h00;
        end  // Priority 2: Timeout occurs
        else if (obi_state_q.obi_timeout_cnt == 8'hFE) begin
          obi_state_d.last_obi_error = 8'h01;  // GNT Error
          obi_state_d.state          = IDLE;
        end  // Priority 3: Increment counter
        else if (obi_state_q.obi_timeout_cnt < 8'hFF) begin
          obi_state_d.obi_timeout_cnt = obi_state_q.obi_timeout_cnt + 1;
        end
      end
      WAIT_RVALID: begin
        if (bus_resp_i.rvalid) begin
          obi_state_d.obi_timeout_cnt = 8'h00;
          if (obi_state_q.is_read_op) begin
            // Read complete: capture data and signal CDC
            obi_state_d.captured_rdata = bus_resp_i.rdata;
            obi_state_d.heep_resp_req  = 1'b1;
            obi_state_d.state          = WAIT_CDC_ACK;
          end else begin
            // Write complete: return to IDLE to allow the next FIFO pop
            obi_state_d.state = COOLDOWN;
          end
        end  // Priority 2: Timeout occurs
        else if (obi_state_q.obi_timeout_cnt == 8'hFE) begin
          obi_state_d.last_obi_error = 8'h02;  // RVALID Error
          obi_state_d.state          = IDLE;
        end  // Priority 3: Increment counter
        else if (obi_state_q.obi_timeout_cnt < 8'hFF) begin
          obi_state_d.obi_timeout_cnt = obi_state_q.obi_timeout_cnt + 1;
        end
      end
      COOLDOWN: begin
        // Re-using the timeout counter for the cooldown delay
        if (obi_state_q.obi_timeout_cnt >= 8'h04) begin  // Wait 4 clock cycles
          obi_state_d.state           = IDLE;
          obi_state_d.obi_timeout_cnt = 8'h00;
        end else begin
          obi_state_d.obi_timeout_cnt = obi_state_q.obi_timeout_cnt + 1;
        end
      end
      WAIT_CDC_ACK: begin
        // Wait until the CDC macro safely registers the data across domains
        if (heep_resp_ack) begin
          obi_state_d.heep_resp_req = 1'b0;  // De-assert send request
          obi_state_d.state         = WAIT_REQ_DROP;
        end
      end

      WAIT_REQ_DROP: begin
        if (!heep_read_req) begin
          obi_state_d.state = IDLE;
        end
      end
    endcase
  end

  // Output
  always_comb begin
    bus_req_o.req   = 1'b0;
    bus_req_o.addr  = obi_addr;
    bus_req_o.wdata = obi_wdata;
    bus_req_o.be    = obi_be;
    bus_req_o.we    = obi_we;

    fifo_rd_en      = 1'b0;
    heep_read_ack   = 1'b0;

    case (obi_state_q.state)
      IDLE: begin
        if (!heep_read_req && !fifo_empty) begin
          fifo_rd_en = 1'b1;
        end
      end
      WAIT_GNT: begin
        bus_req_o.req = 1'b1;
      end

      WAIT_CDC_ACK: begin
        // Wait until the CDC macro safely registers the data across domains
        if (heep_resp_ack) begin
          heep_read_ack = 1'b1;  // Acknowledge the ORIGINAL read request to unblock it
        end
      end

      WAIT_REQ_DROP: begin
        heep_read_ack = heep_read_req;
      end
    endcase
  end

endmodule
