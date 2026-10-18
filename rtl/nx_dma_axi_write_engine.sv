// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_write_engine.sv
// Description:   AXI4 Master Write Engine. Coordinates AW, W, and B channels,
//                dynamic WSTRB byte-enable generation, WLAST generation,
//                write response tracking, and commit feedback to channels.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_axi_write_engine
  import nx_dma_pkg::*;
(
  input  logic                           clk,
  input  logic                           rst_n,

  // AXI4 Master AW Channel
  output logic [AXI_ADDR_WIDTH-1:0]      m_axi_awaddr,
  output logic [AXI_LEN_WIDTH-1:0]       m_axi_awlen,
  output logic [AXI_SIZE_WIDTH-1:0]      m_axi_awsize,
  output logic [AXI_BURST_WIDTH-1:0]     m_axi_awburst,
  output logic [AXI_ID_WIDTH-1:0]        m_axi_awid,
  output logic                           m_axi_awvalid,
  input  logic                           m_axi_awready,

  // AXI4 Master W Channel
  output logic [AXI_DATA_WIDTH-1:0]      m_axi_wdata,
  output logic [AXI_STRB_WIDTH-1:0]      m_axi_wstrb,
  output logic                           m_axi_wlast,
  output logic                           m_axi_wvalid,
  input  logic                           m_axi_wready,

  // AXI4 Master B Channel
  input  logic [AXI_RESP_WIDTH-1:0]      m_axi_bresp,
  input  logic [AXI_ID_WIDTH-1:0]        m_axi_bid,
  input  logic                           m_axi_bvalid,
  output logic                           m_axi_bready,

  // Request Interface from Scheduler
  input  logic                           sched_wr_valid,
  input  logic [CH_ID_WIDTH-1:0]         sched_wr_channel_id,
  input  logic [AXI_ADDR_WIDTH-1:0]      sched_wr_addr,
  input  logic [AXI_LEN_WIDTH-1:0]       sched_wr_len,
  input  logic [31:0]                    sched_wr_bytes,
  input  logic                           sched_wr_last,
  output logic                           write_engine_ready,

  // Pop Data from Channel FIFOs
  output logic [NUM_CHANNELS-1:0]        fifo_rd_en,
  input  fifo_entry_t                    fifo_rd_data[NUM_CHANNELS],

  // Event & Status to Channels
  output logic [31:0]                    ch_wr_bytes_done[NUM_CHANNELS],
  output logic [NUM_CHANNELS-1:0]        ch_wr_resp_done,
  output logic [NUM_CHANNELS-1:0]        ch_wr_err_event,
  output dma_err_e                       ch_wr_err_code[NUM_CHANNELS],

  // Global Error Handler
  output logic                           wr_err_event_out,
  output logic [CH_ID_WIDTH-1:0]         wr_err_channel_out,
  output dma_err_e                       wr_err_code_out
);

  // --------------------------------------------------------------------------
  // AW and W Channel State Machines
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AW_IDLE = 2'b00,
    AW_BUSY = 2'b01
  } aw_state_e;

  typedef enum logic [1:0] {
    W_IDLE  = 2'b00,
    W_DATA  = 2'b01
  } w_state_e;

  aw_state_e aw_state;
  w_state_e  w_state;

  logic [CH_ID_WIDTH-1:0]      alloc_ch_id;
  logic [AXI_ADDR_WIDTH-1:0]   alloc_addr;
  logic [AXI_LEN_WIDTH-1:0]    alloc_len;
  logic [31:0]                 alloc_bytes;
  logic                        alloc_last;
  logic                        alloc_ready;
  logic [TRACKER_ID_WIDTH-1:0] alloc_tag;

  logic                        alloc_req;
  assign alloc_req = (aw_state == AW_IDLE) && sched_wr_valid && (w_state == W_IDLE) && alloc_ready;

  logic                        trk_valid[MAX_OUTSTANDING_REQ];
  logic [CH_ID_WIDTH-1:0]      trk_channel_id[MAX_OUTSTANDING_REQ];
  logic                        trk_is_desc[MAX_OUTSTANDING_REQ];
  logic [31:0]                 trk_bytes[MAX_OUTSTANDING_REQ];
  logic                        trk_last[MAX_OUTSTANDING_REQ];

  logic                        beat_valid;
  logic [TRACKER_ID_WIDTH-1:0] beat_tag;
  logic                        beat_last;
  logic [AXI_RESP_WIDTH-1:0]   beat_resp;

  logic                        cmpl_valid;
  logic [TRACKER_ID_WIDTH-1:0] cmpl_tag;
  logic [AXI_RESP_WIDTH-1:0]   cmpl_resp;

  assign beat_valid = 1'b0;
  assign beat_tag   = '0;
  assign beat_last  = 1'b0;
  assign beat_resp  = AXI_RESP_OKAY;

  nx_dma_transaction_tracker #(
    .NUM_ENTRIES(MAX_OUTSTANDING_REQ)
  ) u_tracker (
    .clk              (clk),
    .rst_n            (rst_n),
    .flush            (1'b0),
    .alloc_req        (alloc_req),
    .alloc_channel_id (alloc_ch_id),
    .alloc_is_desc    (1'b0),
    .alloc_addr       (alloc_addr),
    .alloc_len        (alloc_len),
    .alloc_bytes      (alloc_bytes),
    .alloc_last       (alloc_last),
    .alloc_ready      (alloc_ready),
    .alloc_tag        (alloc_tag),
    .beat_valid       (beat_valid),
    .beat_tag         (beat_tag),
    .beat_last        (beat_last),
    .beat_resp        (beat_resp),
    .cmpl_valid       (cmpl_valid),
    .cmpl_tag         (cmpl_tag),
    .cmpl_resp        (cmpl_resp),
    .entry_valid      (trk_valid),
    .entry_channel_id (trk_channel_id),
    .entry_is_desc    (trk_is_desc),
    .entry_bytes      (trk_bytes),
    .entry_last       (trk_last),
    .active_count     ()
  );

  logic [AXI_ADDR_WIDTH-1:0] awaddr_q;
  logic [AXI_LEN_WIDTH-1:0]  awlen_q;
  logic [AXI_ID_WIDTH-1:0]   awid_q;
  logic                      awvalid_q;

  logic [CH_ID_WIDTH-1:0]    curr_w_ch_id;
  logic [AXI_LEN_WIDTH-1:0]  w_beats_rem;
  logic [AXI_ADDR_WIDTH-1:0] w_base_addr;
  logic [31:0]               w_bytes_total;
  logic [31:0]               w_bytes_done;
  logic                      w_is_last_burst;

  assign m_axi_awaddr  = awaddr_q;
  assign m_axi_awlen   = awlen_q;
  assign m_axi_awsize  = AXI_SIZE_128BIT;
  assign m_axi_awburst = AXI_BURST_INCR;
  assign m_axi_awid    = awid_q;
  assign m_axi_awvalid = awvalid_q;

  assign write_engine_ready = (aw_state == AW_IDLE) && (w_state == W_IDLE) && alloc_ready;

  assign alloc_ch_id   = sched_wr_channel_id;
  assign alloc_addr    = sched_wr_addr;
  assign alloc_len     = sched_wr_len;
  assign alloc_bytes   = sched_wr_bytes;
  assign alloc_last    = sched_wr_last;

  // --------------------------------------------------------------------------
  // AW State Machine
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_state    <= AW_IDLE;
      awaddr_q    <= '0;
      awlen_q     <= '0;
      awid_q      <= '0;
      awvalid_q   <= 1'b0;
    end else begin
      case (aw_state)
        AW_IDLE: begin
          if (sched_wr_valid && (w_state == W_IDLE) && alloc_ready) begin
            $display("[DBG-WE-AW] t=%0t sched_wr addr=0x%08x len=%0d bytes=%0d tag=%0d",
              $time, sched_wr_addr, sched_wr_len, sched_wr_bytes, alloc_tag);
            awaddr_q    <= sched_wr_addr;
            awlen_q     <= sched_wr_len;
            awid_q      <= { {(AXI_ID_WIDTH-TRACKER_ID_WIDTH){1'b0}}, alloc_tag};
            awvalid_q   <= 1'b1;
            aw_state    <= AW_BUSY;
          end else begin
            awvalid_q <= 1'b0;
          end
        end

        AW_BUSY: begin
          if (m_axi_awvalid && m_axi_awready) begin
            $display("[DBG-WE-AW-DONE] t=%0t", $time);
            awvalid_q <= 1'b0;
            aw_state  <= AW_IDLE;
          end
        end

        default: aw_state <= AW_IDLE;
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // W Data Channel Generation & Byte Strobe Calculation
  // --------------------------------------------------------------------------
  logic                      wvalid_q;
  logic [AXI_DATA_WIDTH-1:0] wdata_q;
  logic [AXI_STRB_WIDTH-1:0] wstrb_q;
  logic                      wlast_q;

  assign m_axi_wdata  = wdata_q;
  assign m_axi_wstrb  = wstrb_q;
  assign m_axi_wlast  = wlast_q;
  assign m_axi_wvalid = wvalid_q;

  // Calculate WSTRB for current beat
  function automatic logic [AXI_STRB_WIDTH-1:0] calc_beat_wstrb(
    input logic [AXI_ADDR_WIDTH-1:0] base_addr,
    input logic [31:0]               bytes_total,
    input logic [31:0]               bytes_so_far,
    input logic                      is_first_beat,
    input logic                      is_last_beat
  );
    logic [3:0]  start_offset;
    logic [31:0] rem_bytes;
    logic [31:0] valid_in_beat;

    start_offset  = is_first_beat ? base_addr[3:0] : 4'd0;
    rem_bytes     = bytes_total - bytes_so_far;
    valid_in_beat = (rem_bytes > (BYTES_PER_BEAT - start_offset)) ? (BYTES_PER_BEAT - start_offset) : rem_bytes;

    return gen_byte_strb(start_offset, valid_in_beat);
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_state         <= W_IDLE;
      curr_w_ch_id    <= '0;
      w_beats_rem     <= '0;
      w_base_addr     <= '0;
      w_bytes_total   <= '0;
      w_bytes_done    <= '0;
      w_is_last_burst <= 1'b0;
      wvalid_q        <= 1'b0;
      wdata_q         <= '0;
      wstrb_q         <= '0;
      wlast_q         <= 1'b0;
      for (int c = 0; c < NUM_CHANNELS; c++) begin
        fifo_rd_en[c] <= 1'b0;
      end
    end else begin
      for (int c = 0; c < NUM_CHANNELS; c++) begin
        fifo_rd_en[c] <= 1'b0;
      end

      case (w_state)
        W_IDLE: begin
          wvalid_q <= 1'b0;
          if (sched_wr_valid && alloc_ready) begin
            curr_w_ch_id             <= sched_wr_channel_id;
            w_beats_rem              <= sched_wr_len;
            w_base_addr              <= sched_wr_addr;
            w_bytes_total            <= sched_wr_bytes;
            w_bytes_done             <= '0;
            w_is_last_burst          <= sched_wr_last;
            w_state                  <= W_DATA;

            wdata_q                  <= fifo_rd_data[sched_wr_channel_id].data;
            wstrb_q                  <= calc_beat_wstrb(sched_wr_addr, sched_wr_bytes, 32'd0, 1'b1, (sched_wr_len == 8'd0));
            wlast_q                  <= (sched_wr_len == 8'd0);
            wvalid_q                 <= 1'b1;
            fifo_rd_en[sched_wr_channel_id] <= 1'b1;

            begin
              logic [31:0] beat_bytes;
              beat_bytes = BYTES_PER_BEAT - sched_wr_addr[3:0];
              if (sched_wr_bytes < beat_bytes) beat_bytes = sched_wr_bytes;
              w_bytes_done           <= beat_bytes;
            end
          end
        end

        W_DATA: begin
          if (wvalid_q && m_axi_wready) begin
            if (w_beats_rem > 0) begin
              logic is_first;
              logic is_last;
              logic [31:0] beat_bytes;

              is_first = (w_bytes_done == 0);
              is_last  = (w_beats_rem == 8'd1);

              wdata_q  <= fifo_rd_data[curr_w_ch_id].data;
              wstrb_q  <= calc_beat_wstrb(w_base_addr, w_bytes_total, w_bytes_done, is_first, is_last);
              wlast_q  <= is_last;
              wvalid_q <= 1'b1;
              fifo_rd_en[curr_w_ch_id] <= 1'b1;

              beat_bytes = BYTES_PER_BEAT;
              if (w_bytes_done + beat_bytes > w_bytes_total) begin
                beat_bytes = w_bytes_total - w_bytes_done;
              end

              w_bytes_done <= w_bytes_done + beat_bytes;
              w_beats_rem  <= w_beats_rem - 1'b1;
            end else begin
              wvalid_q <= 1'b0;
              wlast_q  <= 1'b0;
              w_state  <= W_IDLE;
            end
          end
        end

        default: w_state <= W_IDLE;
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // B Response Channel Handling
  // --------------------------------------------------------------------------
  assign m_axi_bready = 1'b1; // Always ready to receive write responses

  logic [TRACKER_ID_WIDTH-1:0] b_tag;
  logic [CH_ID_WIDTH-1:0]      b_ch_id;

  assign b_tag   = m_axi_bid[TRACKER_ID_WIDTH-1:0];
  assign b_ch_id = trk_channel_id[b_tag];

  assign cmpl_valid = m_axi_bvalid && m_axi_bready;
  assign cmpl_tag   = b_tag;
  assign cmpl_resp  = m_axi_bresp;

  always_comb begin
    for (int c = 0; c < NUM_CHANNELS; c++) begin
      ch_wr_bytes_done[c] = '0;
      ch_wr_resp_done[c]  = 1'b0;
      ch_wr_err_event[c]  = 1'b0;
      ch_wr_err_code[c]   = ERR_NONE;
    end

    wr_err_event_out   = 1'b0;
    wr_err_channel_out = b_ch_id;
    wr_err_code_out    = ERR_NONE;

    if (m_axi_bvalid && m_axi_bready && trk_valid[b_tag]) begin
      $display("[DBG-WE-B] t=%0t bid=%0d b_ch_id=%0d bytes=%0d", $time, b_tag, b_ch_id, trk_bytes[b_tag]);
      if (m_axi_bresp != AXI_RESP_OKAY) begin
        dma_err_e err_code;
        err_code = (m_axi_bresp == AXI_RESP_DECERR) ? ERR_AXI_DECERR_WR : ERR_AXI_SLVERR_WR;

        wr_err_event_out           = 1'b1;
        wr_err_channel_out         = b_ch_id;
        wr_err_code_out            = err_code;
        ch_wr_err_event[b_ch_id]   = 1'b1;
        ch_wr_err_code[b_ch_id]    = err_code;
      end else begin
        ch_wr_bytes_done[b_ch_id] = trk_bytes[b_tag];
        ch_wr_resp_done[b_ch_id]  = 1'b1;
      end
    end
  end

endmodule : nx_dma_axi_write_engine
