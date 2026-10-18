// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_transaction_tracker.sv
// Description:   Transaction tracking table for multiple outstanding AXI4 read
//                and write requests. Maintains active transaction status,
//                ID-to-channel mapping, beat progress, and error response state.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_transaction_tracker
  import nx_dma_pkg::*;
#(
  parameter int NUM_ENTRIES = MAX_OUTSTANDING_REQ // 8 entries
)(
  input  logic                           clk,
  input  logic                           rst_n,
  input  logic                           flush,

  // Allocation Interface (when request is launched onto AXI)
  input  logic                           alloc_req,
  input  logic [CH_ID_WIDTH-1:0]         alloc_channel_id,
  input  logic                           alloc_is_desc,
  input  logic [AXI_ADDR_WIDTH-1:0]      alloc_addr,
  input  logic [AXI_LEN_WIDTH-1:0]       alloc_len,
  input  logic [31:0]                    alloc_bytes,
  input  logic                           alloc_last,
  output logic                           alloc_ready,
  output logic [TRACKER_ID_WIDTH-1:0]    alloc_tag,

  // Beat Progress Interface (from R or W channel)
  input  logic                           beat_valid,
  input  logic [TRACKER_ID_WIDTH-1:0]    beat_tag,
  input  logic                           beat_last,
  input  logic [AXI_RESP_WIDTH-1:0]      beat_resp,

  // Completion Interface (when RLAST or B-response arrives)
  input  logic                           cmpl_valid,
  input  logic [TRACKER_ID_WIDTH-1:0]    cmpl_tag,
  input  logic [AXI_RESP_WIDTH-1:0]      cmpl_resp,

  // Completed Status Query / Broadcast
  output logic                           entry_valid[NUM_ENTRIES],
  output logic [CH_ID_WIDTH-1:0]         entry_channel_id[NUM_ENTRIES],
  output logic                           entry_is_desc[NUM_ENTRIES],
  output logic [31:0]                    entry_bytes[NUM_ENTRIES],
  output logic                           entry_last[NUM_ENTRIES],
  output logic [TRACKER_ID_WIDTH:0]      active_count
);

  // Table storage
  tracker_entry_t entries [NUM_ENTRIES];
  logic [31:0]    bytes_tbl [NUM_ENTRIES];
  logic           last_tbl [NUM_ENTRIES];
  logic [TRACKER_ID_WIDTH:0] count_q;

  // Find free entry combinational search
  logic [TRACKER_ID_WIDTH-1:0] free_tag;
  logic                        free_found;

  always_comb begin
    free_found = 1'b0;
    free_tag   = '0;
    for (int i = 0; i < NUM_ENTRIES; i++) begin
      if (!entries[i].valid && !free_found) begin
        free_found = 1'b1;
        free_tag   = TRACKER_ID_WIDTH'(i);
      end
    end
  end

  assign alloc_ready   = free_found;
  assign alloc_tag     = free_tag;
  assign active_count  = count_q;

  generate
    for (genvar i = 0; i < NUM_ENTRIES; i++) begin : gen_entry_outputs
      assign entry_valid[i]      = entries[i].valid;
      assign entry_channel_id[i] = entries[i].channel_id;
      assign entry_is_desc[i]    = entries[i].is_desc;
      assign entry_bytes[i]      = bytes_tbl[i];
      assign entry_last[i]       = last_tbl[i];
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Table Management Logic
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count_q <= '0;
      for (int i = 0; i < NUM_ENTRIES; i++) begin
        entries[i].valid       <= 1'b0;
        entries[i].channel_id  <= '0;
        entries[i].is_desc     <= 1'b0;
        entries[i].addr        <= '0;
        entries[i].len         <= '0;
        entries[i].beats_done  <= '0;
        entries[i].resp        <= AXI_RESP_OKAY;
        entries[i].err         <= 1'b0;
        bytes_tbl[i]           <= '0;
        last_tbl[i]            <= 1'b0;
      end
    end else if (flush) begin
      count_q <= '0;
      for (int i = 0; i < NUM_ENTRIES; i++) begin
        entries[i].valid <= 1'b0;
      end
    end else begin
      // Allocation
      if (alloc_req && alloc_ready) begin
        $display("[DBG-TRK-ALLOC] t=%0t tag=%0d", $time, free_tag);
        entries[free_tag].valid       <= 1'b1;
        entries[free_tag].channel_id  <= alloc_channel_id;
        entries[free_tag].is_desc     <= alloc_is_desc;
        entries[free_tag].addr        <= alloc_addr;
        entries[free_tag].len         <= alloc_len;
        entries[free_tag].beats_done  <= '0;
        entries[free_tag].resp        <= AXI_RESP_OKAY;
        entries[free_tag].err         <= 1'b0;
        bytes_tbl[free_tag]           <= alloc_bytes;
        last_tbl[free_tag]            <= alloc_last;
      end

      // Beat Progress
      if (beat_valid && entries[beat_tag].valid) begin
        entries[beat_tag].beats_done <= entries[beat_tag].beats_done + 1'b1;
        if (beat_resp != AXI_RESP_OKAY) begin
          entries[beat_tag].resp <= beat_resp;
          entries[beat_tag].err  <= 1'b1;
        end
      end

      // Completion & Deallocation
      if (cmpl_valid && entries[cmpl_tag].valid) begin
        $display("[DBG-TRK-CMPL] t=%0t tag=%0d", $time, cmpl_tag);
        entries[cmpl_tag].valid <= 1'b0;
      end

      // Active count update
      case ({alloc_req && alloc_ready, cmpl_valid && entries[cmpl_tag].valid})
        2'b10: count_q <= count_q + 1'b1;
        2'b01: count_q <= count_q - 1'b1;
        default: count_q <= count_q;
      endcase
    end
  end

endmodule : nx_dma_transaction_tracker
