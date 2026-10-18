// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_descriptor_engine.sv
// Description:   Scatter-Gather Descriptor Engine. Handles descriptor fetch
//                arbitration across channels, issues 32-byte (2-beat) AXI read
//                requests, unpacks and parses descriptor records, and returns
//                validated descriptors to the requesting channel.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_descriptor_engine
  import nx_dma_pkg::*;
(
  input  logic                           clk,
  input  logic                           rst_n,

  // Channel Fetch Interface
  input  logic [NUM_CHANNELS-1:0]        desc_fetch_req,
  input  logic [AXI_ADDR_WIDTH-1:0]      desc_fetch_addr[NUM_CHANNELS],
  output logic [NUM_CHANNELS-1:0]        desc_fetch_ack,
  output logic [NUM_CHANNELS-1:0]        desc_fetch_valid,
  output desc_t                          desc_data_out[NUM_CHANNELS],
  output logic [NUM_CHANNELS-1:0]        desc_fetch_err,
  output dma_err_e                       desc_err_code[NUM_CHANNELS],

  // Read Request Interface to Scheduler
  output logic                           desc_rd_req_valid,
  output logic [AXI_ADDR_WIDTH-1:0]      desc_rd_req_addr,
  output logic [AXI_LEN_WIDTH-1:0]       desc_rd_req_len,   // ARLEN = 1 (2 beats)
  output logic [31:0]                    desc_rd_req_bytes, // 32 bytes
  input  logic                           desc_rd_req_grant,

  // Read Data Return from AXI Read Engine
  input  logic                           desc_data_wr_en,
  input  logic [AXI_DATA_WIDTH-1:0]      desc_data_wr_data,
  input  logic                           desc_data_wr_last,
  input  logic                           desc_rd_done,
  input  logic                           desc_rd_err_event,
  input  dma_err_e                       desc_rd_err_code
);

  // --------------------------------------------------------------------------
  // Descriptor Engine FSM States
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    DESC_IDLE      = 3'b000,
    DESC_REQ_RD    = 3'b001,
    DESC_WAIT_BEAT0 = 3'b010,
    DESC_WAIT_BEAT1 = 3'b011,
    DESC_RESP      = 3'b100
  } desc_state_e;

  desc_state_e state;

  logic [CH_ID_WIDTH-1:0]    curr_ch_id;
  logic [AXI_ADDR_WIDTH-1:0] curr_addr;
  logic [CH_ID_WIDTH-1:0]    rr_ptr;
  desc_t                     parsed_desc;
  logic                      fetch_err_q;
  dma_err_e                  err_code_q;

  // --------------------------------------------------------------------------
  // Channel Arbitration for Descriptor Fetch
  // --------------------------------------------------------------------------
  logic                   ch_selected;
  logic [CH_ID_WIDTH-1:0] selected_ch_id;

  always_comb begin
    ch_selected    = 1'b0;
    selected_ch_id = '0;

    for (int i = 0; i < NUM_CHANNELS; i++) begin
      int idx;
      idx = (rr_ptr + i) % NUM_CHANNELS;
      if (desc_fetch_req[idx] && !ch_selected) begin
        ch_selected    = 1'b1;
        selected_ch_id = CH_ID_WIDTH'(idx);
      end
    end
  end

  // Scheduler Interface Assignments
  assign desc_rd_req_valid = (state == DESC_REQ_RD);
  assign desc_rd_req_addr  = curr_addr;
  assign desc_rd_req_len   = 8'd1;        // 2 beats = 32 bytes (128 bits/beat)
  assign desc_rd_req_bytes = 32'd32;

  // --------------------------------------------------------------------------
  // Main FSM
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= DESC_IDLE;
      curr_ch_id       <= '0;
      curr_addr        <= '0;
      rr_ptr           <= '0;
      fetch_err_q      <= 1'b0;
      err_code_q       <= ERR_NONE;
      parsed_desc      <= '0;
      for (int c = 0; c < NUM_CHANNELS; c++) begin
        desc_fetch_ack[c]   <= 1'b0;
        desc_fetch_valid[c] <= 1'b0;
        desc_data_out[c]    <= '0;
        desc_fetch_err[c]   <= 1'b0;
        desc_err_code[c]    <= ERR_NONE;
      end
    end else begin
      // Default pulse deassertions
      for (int c = 0; c < NUM_CHANNELS; c++) begin
        desc_fetch_ack[c]   <= 1'b0;
        desc_fetch_valid[c] <= 1'b0;
        desc_fetch_err[c]   <= 1'b0;
      end

      case (state)
        DESC_IDLE: begin
          fetch_err_q <= 1'b0;
          err_code_q  <= ERR_NONE;

          if (ch_selected) begin
            curr_ch_id                 <= selected_ch_id;
            curr_addr                  <= desc_fetch_addr[selected_ch_id];
            desc_fetch_ack[selected_ch_id] <= 1'b1;
            rr_ptr                     <= (selected_ch_id + 1'b1) % NUM_CHANNELS;

            // Validate descriptor address 16-byte alignment
            if (|desc_fetch_addr[selected_ch_id][3:0]) begin
              fetch_err_q <= 1'b1;
              err_code_q  <= ERR_UNALIGNED_DESC;
              state       <= DESC_RESP;
            end else begin
              state       <= DESC_REQ_RD;
            end
          end
        end

        DESC_REQ_RD: begin
          if (desc_rd_req_grant) begin
            state <= DESC_WAIT_BEAT0;
          end
        end

        DESC_WAIT_BEAT0: begin
          if (desc_rd_err_event) begin
            fetch_err_q <= 1'b1;
            err_code_q  <= desc_rd_err_code;
            state       <= DESC_RESP;
          end else if (desc_data_wr_en) begin
            // Beat 0 contains: src_addr, dst_addr, length_bytes, ctrl
            parsed_desc.src_addr     <= desc_data_wr_data[31:0];
            parsed_desc.dst_addr     <= desc_data_wr_data[63:32];
            parsed_desc.length_bytes <= desc_data_wr_data[95:64];
            parsed_desc.ctrl         <= desc_data_wr_data[127:96];
            state                    <= DESC_WAIT_BEAT1;
          end
        end

        DESC_WAIT_BEAT1: begin
          if (desc_rd_err_event) begin
            fetch_err_q <= 1'b1;
            err_code_q  <= desc_rd_err_code;
            state       <= DESC_RESP;
          end else if (desc_data_wr_en) begin
            // Beat 1 contains: next_desc_addr, status, reserved
            parsed_desc.next_desc_addr <= desc_data_wr_data[31:0];
            parsed_desc.status         <= desc_data_wr_data[63:32];
            parsed_desc.reserved0      <= desc_data_wr_data[95:64];
            parsed_desc.reserved1      <= desc_data_wr_data[127:96];
            state                      <= DESC_RESP;
          end
        end

        DESC_RESP: begin
          if (fetch_err_q) begin
            desc_fetch_err[curr_ch_id] <= 1'b1;
            desc_err_code[curr_ch_id]  <= err_code_q;
          end else begin
            desc_fetch_valid[curr_ch_id] <= 1'b1;
            desc_data_out[curr_ch_id]    <= parsed_desc;
          end
          state <= DESC_IDLE;
        end

        default: state <= DESC_IDLE;
      endcase
    end
  end

endmodule : nx_dma_descriptor_engine
