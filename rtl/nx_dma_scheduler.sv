// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_scheduler.sv
// Description:   Central DMA Arbiter and Scheduler. Supports Round-Robin and
//                Fixed-Priority arbitration modes with starvation-free
//                fairness for Read and Write request streams.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_scheduler
  import nx_dma_pkg::*;
(
  input  logic                           clk,
  input  logic                           rst_n,

  // Global Arbitration Configuration
  input  arb_mode_e                      arb_mode,
  input  logic [1:0]                     ch_priority[NUM_CHANNELS],

  // Read Requests from Channels
  input  logic [NUM_CHANNELS-1:0]        ch_rd_req_valid,
  input  logic [AXI_ADDR_WIDTH-1:0]      ch_rd_req_addr[NUM_CHANNELS],
  input  logic [AXI_LEN_WIDTH-1:0]       ch_rd_req_len[NUM_CHANNELS],
  input  logic [31:0]                    ch_rd_req_bytes[NUM_CHANNELS],
  output logic [NUM_CHANNELS-1:0]        ch_rd_req_grant,

  // Read Request from Descriptor Engine
  input  logic                           desc_rd_req_valid,
  input  logic [AXI_ADDR_WIDTH-1:0]      desc_rd_req_addr,
  input  logic [AXI_LEN_WIDTH-1:0]       desc_rd_req_len,
  input  logic [31:0]                    desc_rd_req_bytes,
  output logic                           desc_rd_req_grant,

  // Read Grant & Request to AXI Read Engine
  output logic                           sched_rd_valid,
  output logic [CH_ID_WIDTH-1:0]         sched_rd_channel_id,
  output logic                           sched_rd_is_desc,
  output logic [AXI_ADDR_WIDTH-1:0]      sched_rd_addr,
  output logic [AXI_LEN_WIDTH-1:0]       sched_rd_len,
  output logic [31:0]                    sched_rd_bytes,
  input  logic                           read_engine_ready,

  // Write Requests from Channels
  input  logic [NUM_CHANNELS-1:0]        ch_wr_req_valid,
  input  logic [AXI_ADDR_WIDTH-1:0]      ch_wr_req_addr[NUM_CHANNELS],
  input  logic [AXI_LEN_WIDTH-1:0]       ch_wr_req_len[NUM_CHANNELS],
  input  logic [31:0]                    ch_wr_req_bytes[NUM_CHANNELS],
  input  logic [NUM_CHANNELS-1:0]        ch_wr_req_last,
  output logic [NUM_CHANNELS-1:0]        ch_wr_req_grant,

  // Write Grant & Request to AXI Write Engine
  output logic                           sched_wr_valid,
  output logic [CH_ID_WIDTH-1:0]         sched_wr_channel_id,
  output logic [AXI_ADDR_WIDTH-1:0]      sched_wr_addr,
  output logic [AXI_LEN_WIDTH-1:0]       sched_wr_len,
  output logic [31:0]                    sched_wr_bytes,
  output logic                           sched_wr_last,
  input  logic                           write_engine_ready
);

  // --------------------------------------------------------------------------
  // Read Arbitration Logic
  // --------------------------------------------------------------------------
  logic [CH_ID_WIDTH-1:0] rd_rr_ptr;
  logic                   rd_grant_found;
  logic [CH_ID_WIDTH-1:0] rd_grant_idx;
  logic                   rd_desc_selected;

  // Read Arbiter Combinational Selection
  always_comb begin
    rd_grant_found   = 1'b0;
    rd_grant_idx     = '0;
    rd_desc_selected = 1'b0;

    // Descriptor fetch has high priority to keep DMA pipelines fed
    if (desc_rd_req_valid) begin
      rd_desc_selected = 1'b1;
      rd_grant_found   = 1'b1;
    end else if (|ch_rd_req_valid) begin
      if (arb_mode == ARB_ROUND_ROBIN) begin
        // Round Robin Search starting from rd_rr_ptr
        for (int i = 0; i < NUM_CHANNELS; i++) begin
          int idx;
          idx = (rd_rr_ptr + i) % NUM_CHANNELS;
          if (ch_rd_req_valid[idx] && !rd_grant_found) begin
            rd_grant_found = 1'b1;
            rd_grant_idx   = CH_ID_WIDTH'(idx);
          end
        end
      end else begin
        // Fixed Priority Search (Priority 3 -> 2 -> 1 -> 0)
        for (int p = 3; p >= 0; p--) begin
          for (int i = 0; i < NUM_CHANNELS; i++) begin
            int idx;
            idx = (rd_rr_ptr + i) % NUM_CHANNELS; // Tie-breaker RR
            if (ch_rd_req_valid[idx] && (ch_priority[idx] == p[1:0]) && !rd_grant_found) begin
              rd_grant_found = 1'b1;
              rd_grant_idx   = CH_ID_WIDTH'(idx);
            end
          end
        end
      end
    end
  end

  // Read Engine Handshake & Multiplexing
  assign sched_rd_valid = rd_grant_found;
  assign sched_rd_is_desc = rd_desc_selected;

  assign sched_rd_channel_id = rd_desc_selected ? '0 : rd_grant_idx;
  assign sched_rd_addr       = rd_desc_selected ? desc_rd_req_addr  : ch_rd_req_addr[rd_grant_idx];
  assign sched_rd_len        = rd_desc_selected ? desc_rd_req_len   : ch_rd_req_len[rd_grant_idx];
  assign sched_rd_bytes      = rd_desc_selected ? desc_rd_req_bytes : ch_rd_req_bytes[rd_grant_idx];

  assign desc_rd_req_grant = rd_desc_selected && read_engine_ready;

  generate
    for (genvar c = 0; c < NUM_CHANNELS; c++) begin : gen_rd_grants
      assign ch_rd_req_grant[c] = (!rd_desc_selected) && (rd_grant_idx == c) && rd_grant_found && read_engine_ready;
    end
  endgenerate

  // Update Read Round-Robin pointer
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_rr_ptr <= '0;
    end else if (sched_rd_valid && read_engine_ready && !rd_desc_selected) begin
      rd_rr_ptr <= (rd_grant_idx + 1'b1) % NUM_CHANNELS;
    end
  end

  // --------------------------------------------------------------------------
  // Write Arbitration Logic
  // --------------------------------------------------------------------------
  logic [CH_ID_WIDTH-1:0] wr_rr_ptr;
  logic                   wr_grant_found;
  logic [CH_ID_WIDTH-1:0] wr_grant_idx;

  // Write Arbiter Combinational Selection
  always_comb begin
    wr_grant_found = 1'b0;
    wr_grant_idx   = '0;

    if (|ch_wr_req_valid) begin
      if (arb_mode == ARB_ROUND_ROBIN) begin
        for (int i = 0; i < NUM_CHANNELS; i++) begin
          int idx;
          idx = (wr_rr_ptr + i) % NUM_CHANNELS;
          if (ch_wr_req_valid[idx] && !wr_grant_found) begin
            wr_grant_found = 1'b1;
            wr_grant_idx   = CH_ID_WIDTH'(idx);
          end
        end
      end else begin
        for (int p = 3; p >= 0; p--) begin
          for (int i = 0; i < NUM_CHANNELS; i++) begin
            int idx;
            idx = (wr_rr_ptr + i) % NUM_CHANNELS;
            if (ch_wr_req_valid[idx] && (ch_priority[idx] == p[1:0]) && !wr_grant_found) begin
              wr_grant_found = 1'b1;
              wr_grant_idx   = CH_ID_WIDTH'(idx);
            end
          end
        end
      end
    end
  end

  // Write Engine Handshake & Multiplexing
  assign sched_wr_valid      = wr_grant_found;
  assign sched_wr_channel_id = wr_grant_idx;
  assign sched_wr_addr       = ch_wr_req_addr[wr_grant_idx];
  assign sched_wr_len        = ch_wr_req_len[wr_grant_idx];
  assign sched_wr_bytes      = ch_wr_req_bytes[wr_grant_idx];
  assign sched_wr_last       = ch_wr_req_last[wr_grant_idx];

  generate
    for (genvar c = 0; c < NUM_CHANNELS; c++) begin : gen_wr_grants
      assign ch_wr_req_grant[c] = (wr_grant_idx == c) && wr_grant_found && write_engine_ready;
    end
  endgenerate

  // Update Write Round-Robin pointer
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_rr_ptr <= '0;
    end else if (sched_wr_valid && write_engine_ready) begin
      wr_rr_ptr <= (wr_grant_idx + 1'b1) % NUM_CHANNELS;
    end
  end

endmodule : nx_dma_scheduler
