// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_read_engine.sv
// Description:   AXI4 Master Read Engine. Manages AR and R channels, handles
//                address issue, backpressure, tag allocation, in-flight
//                transaction tracking, and data routing to channel FIFOs.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_axi_read_engine
  import nx_dma_pkg::*;
(
  input  logic                           clk,
  input  logic                           rst_n,

  // AXI4 Master AR Channel
  output logic [AXI_ADDR_WIDTH-1:0]      m_axi_araddr,
  output logic [AXI_LEN_WIDTH-1:0]       m_axi_arlen,
  output logic [AXI_SIZE_WIDTH-1:0]      m_axi_arsize,
  output logic [AXI_BURST_WIDTH-1:0]     m_axi_arburst,
  output logic [AXI_ID_WIDTH-1:0]        m_axi_arid,
  output logic                           m_axi_arvalid,
  input  logic                           m_axi_arready,

  // AXI4 Master R Channel
  input  logic [AXI_DATA_WIDTH-1:0]      m_axi_rdata,
  input  logic [AXI_RESP_WIDTH-1:0]      m_axi_rresp,
  input  logic                           m_axi_rlast,
  input  logic [AXI_ID_WIDTH-1:0]        m_axi_rid,
  input  logic                           m_axi_rvalid,
  output logic                           m_axi_rready,

  // Request Interface from Scheduler
  input  logic                           sched_rd_valid,
  input  logic [CH_ID_WIDTH-1:0]         sched_rd_channel_id,
  input  logic                           sched_rd_is_desc,
  input  logic [AXI_ADDR_WIDTH-1:0]      sched_rd_addr,
  input  logic [AXI_LEN_WIDTH-1:0]       sched_rd_len,
  input  logic [31:0]                    sched_rd_bytes,
  output logic                           read_engine_ready,

  // Push Data to Channel FIFOs
  output logic [NUM_CHANNELS-1:0]        fifo_wr_en,
  output fifo_entry_t                    fifo_wr_data[NUM_CHANNELS],

  // Push Data to Descriptor Engine
  output logic                           desc_data_wr_en,
  output logic [AXI_DATA_WIDTH-1:0]      desc_data_wr_data,
  output logic                           desc_data_wr_last,

  // Event & Status to Channels
  output logic [NUM_CHANNELS-1:0]        ch_rd_burst_done,
  output logic [NUM_CHANNELS-1:0]        ch_rd_err_event,
  output dma_err_e                       ch_rd_err_code[NUM_CHANNELS],

  // Event to Descriptor Engine
  output logic                           desc_rd_done,
  output logic                           desc_rd_err_event,
  output dma_err_e                       desc_rd_err_code,

  // Global Error Handler
  output logic                           rd_err_event_out,
  output logic [CH_ID_WIDTH-1:0]         rd_err_channel_out,
  output dma_err_e                       rd_err_code_out
);

  // --------------------------------------------------------------------------
  // AR Address Channel FSM & Skid Control
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AR_IDLE = 2'b00,
    AR_BUSY = 2'b01
  } ar_state_e;

  ar_state_e ar_state;

  // --------------------------------------------------------------------------
  // Transaction Tracker Instance
  // --------------------------------------------------------------------------
  logic [CH_ID_WIDTH-1:0]      alloc_ch_id;
  logic                        alloc_is_desc;
  logic [AXI_ADDR_WIDTH-1:0]   alloc_addr;
  logic [AXI_LEN_WIDTH-1:0]    alloc_len;
  logic [31:0]                 alloc_bytes;
  logic                        alloc_ready;
  logic [TRACKER_ID_WIDTH-1:0] alloc_tag;

  logic                        alloc_req;
  assign alloc_req = (ar_state == AR_IDLE) && sched_rd_valid && alloc_ready;

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

  nx_dma_transaction_tracker #(
    .NUM_ENTRIES(MAX_OUTSTANDING_REQ)
  ) u_tracker (
    .clk              (clk),
    .rst_n            (rst_n),
    .flush            (1'b0),
    .alloc_req        (alloc_req),
    .alloc_channel_id (alloc_ch_id),
    .alloc_is_desc    (alloc_is_desc),
    .alloc_addr       (alloc_addr),
    .alloc_len        (alloc_len),
    .alloc_bytes      (alloc_bytes),
    .alloc_last       (1'b0),
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

  logic [AXI_ADDR_WIDTH-1:0]  araddr_q;
  logic [AXI_LEN_WIDTH-1:0]   arlen_q;
  logic [AXI_ID_WIDTH-1:0]    arid_q;
  logic                       arvalid_q;

  assign m_axi_araddr  = araddr_q;
  assign m_axi_arlen   = arlen_q;
  assign m_axi_arsize  = AXI_SIZE_128BIT;
  assign m_axi_arburst = AXI_BURST_INCR;
  assign m_axi_arid    = arid_q;
  assign m_axi_arvalid = arvalid_q;

  assign read_engine_ready = (ar_state == AR_IDLE) && alloc_ready;

  assign alloc_ch_id   = sched_rd_channel_id;
  assign alloc_is_desc = sched_rd_is_desc;
  assign alloc_addr    = sched_rd_addr;
  assign alloc_len     = sched_rd_len;
  assign alloc_bytes   = sched_rd_bytes;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ar_state      <= AR_IDLE;
      araddr_q      <= '0;
      arlen_q       <= '0;
      arid_q        <= '0;
      arvalid_q     <= 1'b0;
    end else begin
      case (ar_state)
        AR_IDLE: begin
          if (sched_rd_valid && alloc_ready) begin
            // Launch AR transaction
            araddr_q      <= sched_rd_addr;
            arlen_q       <= sched_rd_len;
            arid_q        <= { {(AXI_ID_WIDTH-TRACKER_ID_WIDTH){1'b0}}, alloc_tag};
            arvalid_q     <= 1'b1;
            ar_state      <= AR_BUSY;
          end else begin
            arvalid_q <= 1'b0;
          end
        end

        AR_BUSY: begin
          if (m_axi_arvalid && m_axi_arready) begin
            arvalid_q <= 1'b0;
            ar_state  <= AR_IDLE;
          end
        end

        default: ar_state <= AR_IDLE;
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // R Data Channel Reception & Routing
  // --------------------------------------------------------------------------
  // R channel is always ready to receive data because buffer space was verified prior to AR launch
  assign m_axi_rready = 1'b1;

  logic [TRACKER_ID_WIDTH-1:0] r_tag;
  logic                        r_is_desc;
  logic [CH_ID_WIDTH-1:0]      r_ch_id;

  assign r_tag     = m_axi_rid[TRACKER_ID_WIDTH-1:0];
  assign r_is_desc = trk_is_desc[r_tag];
  assign r_ch_id   = trk_channel_id[r_tag];

  // Tracker Progress Signals
  assign beat_valid = m_axi_rvalid && m_axi_rready;
  assign beat_tag   = r_tag;
  assign beat_last  = m_axi_rlast;
  assign beat_resp  = m_axi_rresp;

  assign cmpl_valid = m_axi_rvalid && m_axi_rready && m_axi_rlast;
  assign cmpl_tag   = r_tag;
  assign cmpl_resp  = m_axi_rresp;

  // Data Routing to FIFOs and Descriptor Engine
  always_comb begin
    for (int c = 0; c < NUM_CHANNELS; c++) begin
      fifo_wr_en[c]              = 1'b0;
      fifo_wr_data[c].data       = m_axi_rdata;
      fifo_wr_data[c].strb       = 16'hFFFF;
      fifo_wr_data[c].last       = m_axi_rlast;
      fifo_wr_data[c].byte_count = 5'd16;
      ch_rd_burst_done[c]        = 1'b0;
      ch_rd_err_event[c]         = 1'b0;
      ch_rd_err_code[c]          = ERR_NONE;
    end

    desc_data_wr_en    = 1'b0;
    desc_data_wr_data  = m_axi_rdata;
    desc_data_wr_last  = m_axi_rlast;
    desc_rd_done       = 1'b0;
    desc_rd_err_event  = 1'b0;
    desc_rd_err_code   = ERR_NONE;

    rd_err_event_out   = 1'b0;
    rd_err_channel_out = r_ch_id;
    rd_err_code_out    = ERR_NONE;

    if (m_axi_rvalid && m_axi_rready && trk_valid[r_tag]) begin
      // Check for AXI Error Response
      if (m_axi_rresp != AXI_RESP_OKAY) begin
        dma_err_e detected_err;
        detected_err = (m_axi_rresp == AXI_RESP_DECERR) ? ERR_AXI_DECERR_RD : ERR_AXI_SLVERR_RD;

        rd_err_event_out   = 1'b1;
        rd_err_channel_out = r_ch_id;
        rd_err_code_out    = detected_err;

        if (r_is_desc) begin
          desc_rd_err_event = 1'b1;
          desc_rd_err_code  = detected_err;
        end else begin
          ch_rd_err_event[r_ch_id] = 1'b1;
          ch_rd_err_code[r_ch_id]  = detected_err;
        end
      end

      // Route data beat
      if (r_is_desc) begin
        desc_data_wr_en   = 1'b1;
        desc_data_wr_data = m_axi_rdata;
        desc_data_wr_last = m_axi_rlast;
        if (m_axi_rlast) begin
          desc_rd_done = 1'b1;
        end
      end else begin
        fifo_wr_en[r_ch_id]        = 1'b1;
        fifo_wr_data[r_ch_id].data = m_axi_rdata;
        fifo_wr_data[r_ch_id].strb = 16'hFFFF;
        fifo_wr_data[r_ch_id].last = m_axi_rlast;
        if (m_axi_rlast) begin
          ch_rd_burst_done[r_ch_id] = 1'b1;
        end
      end
    end
  end

endmodule : nx_dma_axi_read_engine
