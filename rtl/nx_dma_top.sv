// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_top.sv
// Description:   Top-Level Integration Module. Integrates AXI4-Lite Slave,
//                Register File, 4 DMA Channels, Central Arbiter/Scheduler,
//                AXI4 Read and Write Master Engines, Scatter-Gather Descriptor
//                Engine, Channel FIFOs, Interrupt and Error Controllers.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_top
  import nx_dma_pkg::*;
(
  input  logic                               clk,
  input  logic                               rst_n,

  // ==========================================================================
  // AXI4-Lite Slave Interface (Control & Status Registers)
  // ==========================================================================
  input  logic [AXI_LITE_ADDR_WIDTH-1:0]     s_axil_awaddr,
  input  logic [2:0]                         s_axil_awprot,
  input  logic                               s_axil_awvalid,
  output logic                               s_axil_awready,

  input  logic [AXI_LITE_DATA_WIDTH-1:0]     s_axil_wdata,
  input  logic [AXI_LITE_STRB_WIDTH-1:0]     s_axil_wstrb,
  input  logic                               s_axil_wvalid,
  output logic                               s_axil_wready,

  output logic [AXI_RESP_WIDTH-1:0]          s_axil_bresp,
  output logic                               s_axil_bvalid,
  input  logic                               s_axil_bready,

  input  logic [AXI_LITE_ADDR_WIDTH-1:0]     s_axil_araddr,
  input  logic [2:0]                         s_axil_arprot,
  input  logic                               s_axil_arvalid,
  output logic                               s_axil_arready,

  output logic [AXI_LITE_DATA_WIDTH-1:0]     s_axil_rdata,
  output logic [AXI_RESP_WIDTH-1:0]          s_axil_rresp,
  output logic                               s_axil_rvalid,
  input  logic                               s_axil_rready,

  // ==========================================================================
  // AXI4 Master Memory-Mapped Interface (High-Performance 128-bit Data)
  // ==========================================================================
  // Write Address (AW) Channel
  output logic [AXI_ID_WIDTH-1:0]            m_axi_awid,
  output logic [AXI_ADDR_WIDTH-1:0]          m_axi_awaddr,
  output logic [AXI_LEN_WIDTH-1:0]           m_axi_awlen,
  output logic [AXI_SIZE_WIDTH-1:0]          m_axi_awsize,
  output logic [AXI_BURST_WIDTH-1:0]         m_axi_awburst,
  output logic                               m_axi_awlock,
  output logic [3:0]                         m_axi_awcache,
  output logic [2:0]                         m_axi_awprot,
  output logic                               m_axi_awvalid,
  input  logic                               m_axi_awready,

  // Write Data (W) Channel
  output logic [AXI_DATA_WIDTH-1:0]          m_axi_wdata,
  output logic [AXI_STRB_WIDTH-1:0]          m_axi_wstrb,
  output logic                               m_axi_wlast,
  output logic                               m_axi_wvalid,
  input  logic                               m_axi_wready,

  // Write Response (B) Channel
  input  logic [AXI_ID_WIDTH-1:0]            m_axi_bid,
  input  logic [AXI_RESP_WIDTH-1:0]          m_axi_bresp,
  input  logic                               m_axi_bvalid,
  output logic                               m_axi_bready,

  // Read Address (AR) Channel
  output logic [AXI_ID_WIDTH-1:0]            m_axi_arid,
  output logic [AXI_ADDR_WIDTH-1:0]          m_axi_araddr,
  output logic [AXI_LEN_WIDTH-1:0]           m_axi_arlen,
  output logic [AXI_SIZE_WIDTH-1:0]          m_axi_arsize,
  output logic [AXI_BURST_WIDTH-1:0]         m_axi_arburst,
  output logic                               m_axi_arlock,
  output logic [3:0]                         m_axi_arcache,
  output logic [2:0]                         m_axi_arprot,
  output logic                               m_axi_arvalid,
  input  logic                               m_axi_arready,

  // Read Data (R) Channel
  input  logic [AXI_ID_WIDTH-1:0]            m_axi_rid,
  input  logic [AXI_DATA_WIDTH-1:0]          m_axi_rdata,
  input  logic [AXI_RESP_WIDTH-1:0]          m_axi_rresp,
  input  logic                               m_axi_rlast,
  input  logic                               m_axi_rvalid,
  output logic                               m_axi_rready,

  // ==========================================================================
  // Interrupt Outputs
  // ==========================================================================
  output logic                               irq,
  output logic [NUM_CHANNELS-1:0]            irq_ch
);

  // AXI Master Sideband Defaults
  assign m_axi_awlock  = 1'b0;
  assign m_axi_awcache = 4'b0011;
  assign m_axi_awprot  = 3'b000;
  assign m_axi_arlock  = 1'b0;
  assign m_axi_arcache = 4'b0011;
  assign m_axi_arprot  = 3'b000;

  // --------------------------------------------------------------------------
  // Internal Signals & Interconnects
  // --------------------------------------------------------------------------
  // Register Access
  logic                              reg_wr_en;
  logic [AXI_LITE_ADDR_WIDTH-1:0]    reg_wr_addr;
  logic [AXI_LITE_DATA_WIDTH-1:0]    reg_wr_data;
  logic [AXI_LITE_STRB_WIDTH-1:0]    reg_wr_strb;
  logic                              reg_wr_ack;
  logic [AXI_RESP_WIDTH-1:0]         reg_wr_resp;

  logic                              reg_rd_en;
  logic [AXI_LITE_ADDR_WIDTH-1:0]    reg_rd_addr;
  logic [AXI_LITE_DATA_WIDTH-1:0]    reg_rd_data;
  logic                              reg_rd_ack;
  logic [AXI_RESP_WIDTH-1:0]         reg_rd_resp;

  // Configuration and Control
  logic                              global_en;
  logic                              sw_reset_global;
  arb_mode_e                         arb_mode;
  logic [NUM_CHANNELS-1:0]           global_irq_en_sig;
  logic [1:0]                        ch_priority[NUM_CHANNELS];

  ch_cfg_t                           ch_cfg[NUM_CHANNELS];
  logic [AXI_ADDR_WIDTH-1:0]         ch_src_addr[NUM_CHANNELS];
  logic [AXI_ADDR_WIDTH-1:0]         ch_dst_addr[NUM_CHANNELS];
  logic [31:0]                       ch_transfer_len[NUM_CHANNELS];
  logic [AXI_ADDR_WIDTH-1:0]         ch_desc_addr[NUM_CHANNELS];
  ch_irq_t                           ch_int_enable[NUM_CHANNELS];
  ch_irq_t                           ch_int_status[NUM_CHANNELS];
  dma_err_e                          ch_error_status[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0]           ch_sw_reset;

  channel_state_e                    ch_state[NUM_CHANNELS];
  ch_status_t                        ch_status[NUM_CHANNELS];
  logic [31:0]                       ch_bytes_transferred[NUM_CHANNELS];
  logic [AXI_ADDR_WIDTH-1:0]         ch_curr_desc[NUM_CHANNELS];
  dma_err_e                          ch_err_code[NUM_CHANNELS];

  logic [NUM_CHANNELS-1:0]           ch_xfer_done_pulse;
  logic [NUM_CHANNELS-1:0]           ch_desc_done_pulse;
  logic [NUM_CHANNELS-1:0]           ch_error_event_pulse;

  // Global Error Handler
  logic                              global_err_valid;
  logic [CH_ID_WIDTH-1:0]            global_err_channel;
  dma_err_e                          global_err_code;

  logic                              rd_err_event_out;
  logic [CH_ID_WIDTH-1:0]            rd_err_channel_out;
  dma_err_e                          rd_err_code_out;

  logic                              wr_err_event_out;
  logic [CH_ID_WIDTH-1:0]            wr_err_channel_out;
  dma_err_e                          wr_err_code_out;

  // Channel FIFOs Data & Status
  fifo_entry_t                       fifo_wr_data[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0]           fifo_wr_en;
  fifo_entry_t                       fifo_rd_data[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0]           fifo_rd_en;
  logic [NUM_CHANNELS-1:0]           fifo_flush;
  logic [FIFO_ADDR_WIDTH:0]          fifo_count[NUM_CHANNELS];
  logic [FIFO_ADDR_WIDTH:0]          fifo_avail_space[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0]           fifo_empty;
  logic [NUM_CHANNELS-1:0]           fifo_full;

  // Read Requests: Channels -> Scheduler -> Read Engine
  logic [NUM_CHANNELS-1:0]           ch_rd_req_valid;
  logic [AXI_ADDR_WIDTH-1:0]         ch_rd_req_addr[NUM_CHANNELS];
  logic [AXI_LEN_WIDTH-1:0]          ch_rd_req_len[NUM_CHANNELS];
  logic [31:0]                       ch_rd_req_bytes[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0]           ch_rd_req_grant;
  logic [NUM_CHANNELS-1:0]           ch_rd_burst_done;
  logic [NUM_CHANNELS-1:0]           ch_rd_err_event;
  dma_err_e                          ch_rd_err_code_sig[NUM_CHANNELS];

  logic                              desc_rd_req_valid;
  logic [AXI_ADDR_WIDTH-1:0]         desc_rd_req_addr;
  logic [AXI_LEN_WIDTH-1:0]          desc_rd_req_len;
  logic [31:0]                       desc_rd_req_bytes;
  logic                              desc_rd_req_grant;

  logic                              sched_rd_valid;
  logic [CH_ID_WIDTH-1:0]            sched_rd_channel_id;
  logic                              sched_rd_is_desc;
  logic [AXI_ADDR_WIDTH-1:0]         sched_rd_addr;
  logic [AXI_LEN_WIDTH-1:0]          sched_rd_len;
  logic [31:0]                       sched_rd_bytes;
  logic                              read_engine_ready;

  // Write Requests: Channels -> Scheduler -> Write Engine
  logic [NUM_CHANNELS-1:0]           ch_wr_req_valid;
  logic [AXI_ADDR_WIDTH-1:0]         ch_wr_req_addr[NUM_CHANNELS];
  logic [AXI_LEN_WIDTH-1:0]          ch_wr_req_len[NUM_CHANNELS];
  logic [31:0]                       ch_wr_req_bytes[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0]           ch_wr_req_last;
  logic [NUM_CHANNELS-1:0]           ch_wr_req_grant;
  logic [31:0]                       ch_wr_bytes_done[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0]           ch_wr_resp_done;
  logic [NUM_CHANNELS-1:0]           ch_wr_err_event;
  dma_err_e                          ch_wr_err_code_sig[NUM_CHANNELS];

  logic                              sched_wr_valid;
  logic [CH_ID_WIDTH-1:0]            sched_wr_channel_id;
  logic [AXI_ADDR_WIDTH-1:0]         sched_wr_addr;
  logic [AXI_LEN_WIDTH-1:0]          sched_wr_len;
  logic [31:0]                       sched_wr_bytes;
  logic                              sched_wr_last;
  logic                              write_engine_ready;

  // Descriptor Engine Interfaces
  logic [NUM_CHANNELS-1:0]           desc_fetch_req;
  logic [AXI_ADDR_WIDTH-1:0]         desc_fetch_addr[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0]           desc_fetch_ack;
  logic [NUM_CHANNELS-1:0]           desc_fetch_valid;
  desc_t                             desc_data_out[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0]           desc_fetch_err;
  dma_err_e                          desc_err_code_sig[NUM_CHANNELS];

  logic                              desc_data_wr_en;
  logic [AXI_DATA_WIDTH-1:0]         desc_data_wr_data;
  logic                              desc_data_wr_last;
  logic                              desc_rd_done;
  logic                              desc_rd_err_event;
  dma_err_e                          desc_rd_err_code;

  // Interrupt aggregation
  logic [NUM_CHANNELS-1:0]           ch_irq_asserted;

  always_comb begin
    for (int c = 0; c < NUM_CHANNELS; c++) begin
      ch_irq_asserted[c] = (ch_int_status[c].xfer_done_ie && ch_int_enable[c].xfer_done_ie) ||
                           (ch_int_status[c].desc_done_ie && ch_int_enable[c].desc_done_ie) ||
                           (ch_int_status[c].err_ie       && ch_int_enable[c].err_ie);
    end
  end

  // --------------------------------------------------------------------------
  // AXI4-Lite Slave Interface
  // --------------------------------------------------------------------------
  nx_dma_axi_lite_slave u_axil_slave (
    .clk             (clk),
    .rst_n           (rst_n),
    .s_axil_awaddr   (s_axil_awaddr),
    .s_axil_awprot   (s_axil_awprot),
    .s_axil_awvalid  (s_axil_awvalid),
    .s_axil_awready  (s_axil_awready),
    .s_axil_wdata    (s_axil_wdata),
    .s_axil_wstrb    (s_axil_wstrb),
    .s_axil_wvalid   (s_axil_wvalid),
    .s_axil_wready   (s_axil_wready),
    .s_axil_bresp    (s_axil_bresp),
    .s_axil_bvalid   (s_axil_bvalid),
    .s_axil_bready   (s_axil_bready),
    .s_axil_araddr   (s_axil_araddr),
    .s_axil_arprot   (s_axil_arprot),
    .s_axil_arvalid  (s_axil_arvalid),
    .s_axil_arready  (s_axil_arready),
    .s_axil_rdata    (s_axil_rdata),
    .s_axil_rresp    (s_axil_rresp),
    .s_axil_rvalid   (s_axil_rvalid),
    .s_axil_rready   (s_axil_rready),
    .reg_wr_en       (reg_wr_en),
    .reg_wr_addr     (reg_wr_addr),
    .reg_wr_data     (reg_wr_data),
    .reg_wr_strb     (reg_wr_strb),
    .reg_wr_ack      (reg_wr_ack),
    .reg_wr_resp     (reg_wr_resp),
    .reg_rd_en       (reg_rd_en),
    .reg_rd_addr     (reg_rd_addr),
    .reg_rd_data     (reg_rd_data),
    .reg_rd_ack      (reg_rd_ack),
    .reg_rd_resp     (reg_rd_resp)
  );

  // --------------------------------------------------------------------------
  // Register File
  // --------------------------------------------------------------------------
  nx_dma_reg_file u_reg_file (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .reg_wr_en             (reg_wr_en),
    .reg_wr_addr           (reg_wr_addr),
    .reg_wr_data           (reg_wr_data),
    .reg_wr_strb           (reg_wr_strb),
    .reg_wr_ack            (reg_wr_ack),
    .reg_wr_resp           (reg_wr_resp),
    .reg_rd_en             (reg_rd_en),
    .reg_rd_addr           (reg_rd_addr),
    .reg_rd_data           (reg_rd_data),
    .reg_rd_ack            (reg_rd_ack),
    .reg_rd_resp           (reg_rd_resp),
    .global_en             (global_en),
    .global_sw_reset       (sw_reset_global),
    .global_arb_mode       (arb_mode),
    .global_irq_en         (global_irq_en_sig),
    .ch_cfg                (ch_cfg),
    .ch_src_addr           (ch_src_addr),
    .ch_dst_addr           (ch_dst_addr),
    .ch_transfer_len       (ch_transfer_len),
    .ch_priority           (ch_priority),
    .ch_desc_addr          (ch_desc_addr),
    .ch_int_enable         (ch_int_enable),
    .ch_sw_reset           (ch_sw_reset),
    .ch_state_in           (ch_state),
    .ch_status_in          (ch_status),
    .ch_bytes_xferred_in   (ch_bytes_transferred),
    .ch_curr_desc_in       (ch_curr_desc),
    .hw_xfer_done          (ch_xfer_done_pulse),
    .hw_desc_done          (ch_desc_done_pulse),
    .hw_error_event        (ch_error_event_pulse),
    .hw_error_code         (ch_err_code),
    .ch_int_status         (ch_int_status),
    .ch_error_status       (ch_error_status)
  );

  // --------------------------------------------------------------------------
  // Channel Controllers & FIFO Buffers
  // --------------------------------------------------------------------------
  generate
    for (genvar c = 0; c < NUM_CHANNELS; c++) begin : gen_channels
      nx_dma_channel #(
        .CHANNEL_ID(c)
      ) u_channel (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .cfg                   (ch_cfg[c]),
        .src_addr_in           (ch_src_addr[c]),
        .dst_addr_in           (ch_dst_addr[c]),
        .transfer_len_in       (ch_transfer_len[c]),
        .desc_addr_in          (ch_desc_addr[c]),
        .sw_reset              (sw_reset_global || ch_sw_reset[c]),
        .ch_state_out          (ch_state[c]),
        .ch_status_out         (ch_status[c]),
        .bytes_transferred_out (ch_bytes_transferred[c]),
        .curr_desc_out         (ch_curr_desc[c]),
        .xfer_done_pulse       (ch_xfer_done_pulse[c]),
        .desc_done_pulse       (ch_desc_done_pulse[c]),
        .error_event_pulse     (ch_error_event_pulse[c]),
        .error_code_out        (ch_err_code[c]),
        .desc_fetch_req        (desc_fetch_req[c]),
        .desc_fetch_addr       (desc_fetch_addr[c]),
        .desc_fetch_ack        (desc_fetch_ack[c]),
        .desc_fetch_valid      (desc_fetch_valid[c]),
        .desc_data_in          (desc_data_out[c]),
        .desc_fetch_err        (desc_fetch_err[c]),
        .desc_err_code         (desc_err_code_sig[c]),
        .fifo_avail_space      (fifo_avail_space[c]),
        .fifo_count            (fifo_count[c]),
        .fifo_empty            (fifo_empty[c]),
        .fifo_flush            (fifo_flush[c]),
        .rd_req_valid          (ch_rd_req_valid[c]),
        .rd_req_addr           (ch_rd_req_addr[c]),
        .rd_req_len            (ch_rd_req_len[c]),
        .rd_req_bytes          (ch_rd_req_bytes[c]),
        .rd_req_grant          (ch_rd_req_grant[c]),
        .rd_burst_done         (ch_rd_burst_done[c]),
        .rd_err_event          (ch_rd_err_event[c]),
        .rd_err_code           (ch_rd_err_code_sig[c]),
        .wr_req_valid          (ch_wr_req_valid[c]),
        .wr_req_addr           (ch_wr_req_addr[c]),
        .wr_req_len            (ch_wr_req_len[c]),
        .wr_req_bytes          (ch_wr_req_bytes[c]),
        .wr_req_last           (ch_wr_req_last[c]),
        .wr_req_grant          (ch_wr_req_grant[c]),
        .wr_bytes_done         (ch_wr_bytes_done[c]),
        .wr_resp_done          (ch_wr_resp_done[c]),
        .wr_err_event          (ch_wr_err_event[c]),
        .wr_err_code           (ch_wr_err_code_sig[c])
      );

      nx_dma_data_buffer #(
        .DEPTH(FIFO_DEPTH)
      ) u_data_buffer (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush           (fifo_flush[c] || sw_reset_global || ch_sw_reset[c]),
        .wr_en           (fifo_wr_en[c]),
        .wr_data         (fifo_wr_data[c]),
        .rd_en           (fifo_rd_en[c]),
        .rd_data         (fifo_rd_data[c]),
        .full            (fifo_full[c]),
        .empty           (fifo_empty[c]),
        .count           (fifo_count[c]),
        .available_space (fifo_avail_space[c])
      );
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Central Arbiter / Scheduler
  // --------------------------------------------------------------------------
  nx_dma_scheduler u_scheduler (
    .clk                 (clk),
    .rst_n               (rst_n),
    .arb_mode            (arb_mode),
    .ch_priority         (ch_priority),
    .ch_rd_req_valid     (ch_rd_req_valid),
    .ch_rd_req_addr      (ch_rd_req_addr),
    .ch_rd_req_len       (ch_rd_req_len),
    .ch_rd_req_bytes     (ch_rd_req_bytes),
    .ch_rd_req_grant     (ch_rd_req_grant),
    .desc_rd_req_valid   (desc_rd_req_valid),
    .desc_rd_req_addr    (desc_rd_req_addr),
    .desc_rd_req_len     (desc_rd_req_len),
    .desc_rd_req_bytes   (desc_rd_req_bytes),
    .desc_rd_req_grant   (desc_rd_req_grant),
    .sched_rd_valid      (sched_rd_valid),
    .sched_rd_channel_id (sched_rd_channel_id),
    .sched_rd_is_desc    (sched_rd_is_desc),
    .sched_rd_addr       (sched_rd_addr),
    .sched_rd_len        (sched_rd_len),
    .sched_rd_bytes      (sched_rd_bytes),
    .read_engine_ready   (read_engine_ready),
    .ch_wr_req_valid     (ch_wr_req_valid),
    .ch_wr_req_addr      (ch_wr_req_addr),
    .ch_wr_req_len       (ch_wr_req_len),
    .ch_wr_req_bytes     (ch_wr_req_bytes),
    .ch_wr_req_last      (ch_wr_req_last),
    .ch_wr_req_grant     (ch_wr_req_grant),
    .sched_wr_valid      (sched_wr_valid),
    .sched_wr_channel_id (sched_wr_channel_id),
    .sched_wr_addr       (sched_wr_addr),
    .sched_wr_len        (sched_wr_len),
    .sched_wr_bytes      (sched_wr_bytes),
    .sched_wr_last       (sched_wr_last),
    .write_engine_ready  (write_engine_ready)
  );

  // --------------------------------------------------------------------------
  // AXI4 Master Read Engine
  // --------------------------------------------------------------------------
  nx_dma_axi_read_engine u_read_engine (
    .clk                 (clk),
    .rst_n               (rst_n),
    .m_axi_araddr        (m_axi_araddr),
    .m_axi_arlen         (m_axi_arlen),
    .m_axi_arsize        (m_axi_arsize),
    .m_axi_arburst       (m_axi_arburst),
    .m_axi_arid          (m_axi_arid),
    .m_axi_arvalid       (m_axi_arvalid),
    .m_axi_arready       (m_axi_arready),
    .m_axi_rdata         (m_axi_rdata),
    .m_axi_rresp         (m_axi_rresp),
    .m_axi_rlast         (m_axi_rlast),
    .m_axi_rid           (m_axi_rid),
    .m_axi_rvalid        (m_axi_rvalid),
    .m_axi_rready        (m_axi_rready),
    .sched_rd_valid      (sched_rd_valid),
    .sched_rd_channel_id (sched_rd_channel_id),
    .sched_rd_is_desc    (sched_rd_is_desc),
    .sched_rd_addr       (sched_rd_addr),
    .sched_rd_len        (sched_rd_len),
    .sched_rd_bytes      (sched_rd_bytes),
    .read_engine_ready   (read_engine_ready),
    .fifo_wr_en          (fifo_wr_en),
    .fifo_wr_data        (fifo_wr_data),
    .desc_data_wr_en     (desc_data_wr_en),
    .desc_data_wr_data   (desc_data_wr_data),
    .desc_data_wr_last   (desc_data_wr_last),
    .ch_rd_burst_done    (ch_rd_burst_done),
    .ch_rd_err_event     (ch_rd_err_event),
    .ch_rd_err_code      (ch_rd_err_code_sig),
    .desc_rd_done        (desc_rd_done),
    .desc_rd_err_event   (desc_rd_err_event),
    .desc_rd_err_code    (desc_rd_err_code),
    .rd_err_event_out    (rd_err_event_out),
    .rd_err_channel_out  (rd_err_channel_out),
    .rd_err_code_out     (rd_err_code_out)
  );

  // --------------------------------------------------------------------------
  // AXI4 Master Write Engine
  // --------------------------------------------------------------------------
  nx_dma_axi_write_engine u_write_engine (
    .clk                 (clk),
    .rst_n               (rst_n),
    .m_axi_awaddr        (m_axi_awaddr),
    .m_axi_awlen         (m_axi_awlen),
    .m_axi_awsize        (m_axi_awsize),
    .m_axi_awburst       (m_axi_awburst),
    .m_axi_awid          (m_axi_awid),
    .m_axi_awvalid       (m_axi_awvalid),
    .m_axi_awready       (m_axi_awready),
    .m_axi_wdata         (m_axi_wdata),
    .m_axi_wstrb         (m_axi_wstrb),
    .m_axi_wlast         (m_axi_wlast),
    .m_axi_wvalid        (m_axi_wvalid),
    .m_axi_wready        (m_axi_wready),
    .m_axi_bresp         (m_axi_bresp),
    .m_axi_bid           (m_axi_bid),
    .m_axi_bvalid        (m_axi_bvalid),
    .m_axi_bready        (m_axi_bready),
    .sched_wr_valid      (sched_wr_valid),
    .sched_wr_channel_id (sched_wr_channel_id),
    .sched_wr_addr       (sched_wr_addr),
    .sched_wr_len        (sched_wr_len),
    .sched_wr_bytes      (sched_wr_bytes),
    .sched_wr_last       (sched_wr_last),
    .write_engine_ready  (write_engine_ready),
    .fifo_rd_en          (fifo_rd_en),
    .fifo_rd_data        (fifo_rd_data),
    .ch_wr_bytes_done    (ch_wr_bytes_done),
    .ch_wr_resp_done     (ch_wr_resp_done),
    .ch_wr_err_event     (ch_wr_err_event),
    .ch_wr_err_code      (ch_wr_err_code_sig),
    .wr_err_event_out    (wr_err_event_out),
    .wr_err_channel_out  (wr_err_channel_out),
    .wr_err_code_out     (wr_err_code_out)
  );

  // --------------------------------------------------------------------------
  // Scatter-Gather Descriptor Engine
  // --------------------------------------------------------------------------
  nx_dma_descriptor_engine u_desc_engine (
    .clk                 (clk),
    .rst_n               (rst_n),
    .desc_fetch_req      (desc_fetch_req),
    .desc_fetch_addr     (desc_fetch_addr),
    .desc_fetch_ack      (desc_fetch_ack),
    .desc_fetch_valid    (desc_fetch_valid),
    .desc_data_out       (desc_data_out),
    .desc_fetch_err      (desc_fetch_err),
    .desc_err_code       (desc_err_code_sig),
    .desc_rd_req_valid   (desc_rd_req_valid),
    .desc_rd_req_addr    (desc_rd_req_addr),
    .desc_rd_req_len     (desc_rd_req_len),
    .desc_rd_req_bytes   (desc_rd_req_bytes),
    .desc_rd_req_grant   (desc_rd_req_grant),
    .desc_data_wr_en     (desc_data_wr_en),
    .desc_data_wr_data   (desc_data_wr_data),
    .desc_data_wr_last   (desc_data_wr_last),
    .desc_rd_done        (desc_rd_done),
    .desc_rd_err_event   (desc_rd_err_event),
    .desc_rd_err_code    (desc_rd_err_code)
  );

  // --------------------------------------------------------------------------
  // Interrupt Controller
  // --------------------------------------------------------------------------
  nx_dma_interrupt u_interrupt (
    .clk                 (clk),
    .rst_n               (rst_n),
    .global_irq_en       (global_irq_en_sig),
    .global_irq_status   ('0),
    .ch_irq_status       (ch_irq_asserted),
    .ch_irq_out          (irq_ch),
    .irq_out             (irq)
  );

  // --------------------------------------------------------------------------
  // Centralized Error Handler
  // --------------------------------------------------------------------------
  nx_dma_error_handler u_error_handler (
    .clk                 (clk),
    .rst_n               (rst_n),
    .sw_reset            (sw_reset_global),
    .rd_err_event        (rd_err_event_out),
    .rd_err_channel      (rd_err_channel_out),
    .rd_err_code         (rd_err_code_out),
    .wr_err_event        (wr_err_event_out),
    .wr_err_channel      (wr_err_channel_out),
    .wr_err_code         (wr_err_code_out),
    .ch_err_event        (ch_error_event_pulse),
    .ch_err_code         (ch_err_code),
    .global_err_valid    (global_err_valid),
    .global_err_channel  (global_err_channel),
    .global_err_code     (global_err_code)
  );

endmodule : nx_dma_top
