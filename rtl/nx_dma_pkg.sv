// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_pkg.sv
// Description:   SystemVerilog package defining constants, parameters, types,
//                enums, structs, and utility functions for the DMA IP.
// ============================================================================

package nx_dma_pkg;

  // --------------------------------------------------------------------------
  // Global Architectural Parameters
  // --------------------------------------------------------------------------
  localparam int AXI_ADDR_WIDTH        = 32;
  localparam int AXI_DATA_WIDTH        = 128;
  localparam int AXI_STRB_WIDTH        = AXI_DATA_WIDTH / 8; // 16 bytes
  localparam int AXI_ID_WIDTH          = 4;
  localparam int AXI_LEN_WIDTH         = 8;
  localparam int AXI_SIZE_WIDTH        = 3;
  localparam int AXI_BURST_WIDTH       = 2;
  localparam int AXI_RESP_WIDTH        = 2;

  localparam int AXI_LITE_ADDR_WIDTH   = 32;
  localparam int AXI_LITE_DATA_WIDTH   = 32;
  localparam int AXI_LITE_STRB_WIDTH   = AXI_LITE_DATA_WIDTH / 8; // 4 bytes

  localparam int NUM_CHANNELS          = 4;
  localparam int CH_ID_WIDTH           = $clog2(NUM_CHANNELS); // 2 bits
  localparam int MAX_OUTSTANDING_REQ   = 8;
  localparam int TRACKER_ID_WIDTH      = $clog2(MAX_OUTSTANDING_REQ); // 3 bits

  localparam int FIFO_DEPTH            = 16;
  localparam int FIFO_ADDR_WIDTH       = $clog2(FIFO_DEPTH); // 4 bits
  localparam int FIFO_ALMOST_FULL_TH   = 12;
  localparam int FIFO_ALMOST_EMPTY_TH  = 4;

  localparam int BYTES_PER_BEAT        = AXI_DATA_WIDTH / 8; // 16
  localparam int BEAT_OFFSET_WIDTH     = $clog2(BYTES_PER_BEAT); // 4 bits

  // 4KB boundary constant (4096 bytes)
  localparam int AXI_PAGE_SIZE_BYTES   = 4096;
  localparam int AXI_PAGE_OFFSET_WIDTH = 12;

  // --------------------------------------------------------------------------
  // AXI Protocol Constants
  // --------------------------------------------------------------------------
  localparam logic [AXI_BURST_WIDTH-1:0] AXI_BURST_FIXED = 2'b00;
  localparam logic [AXI_BURST_WIDTH-1:0] AXI_BURST_INCR  = 2'b01;
  localparam logic [AXI_BURST_WIDTH-1:0] AXI_BURST_WRAP  = 2'b10;

  localparam logic [AXI_RESP_WIDTH-1:0]  AXI_RESP_OKAY   = 2'b00;
  localparam logic [AXI_RESP_WIDTH-1:0]  AXI_RESP_EXOKAY = 2'b01;
  localparam logic [AXI_RESP_WIDTH-1:0]  AXI_RESP_SLVERR = 2'b10;
  localparam logic [AXI_RESP_WIDTH-1:0]  AXI_RESP_DECERR = 2'b11;

  // AXI Size for 128-bit data: 2^4 = 16 bytes = 3'b100 (4)
  localparam logic [AXI_SIZE_WIDTH-1:0]  AXI_SIZE_128BIT = 3'b100;
  localparam logic [AXI_SIZE_WIDTH-1:0]  AXI_SIZE_32BIT  = 3'b010;

  // --------------------------------------------------------------------------
  // Register Map Offsets
  // --------------------------------------------------------------------------
  // Global Registers (0x000 - 0x03F)
  localparam logic [AXI_LITE_ADDR_WIDTH-1:0] ADDR_GLOBAL_CTRL       = 32'h0000_0000;
  localparam logic [AXI_LITE_ADDR_WIDTH-1:0] ADDR_GLOBAL_STATUS     = 32'h0000_0004;
  localparam logic [AXI_LITE_ADDR_WIDTH-1:0] ADDR_GLOBAL_IRQ_STATUS = 32'h0000_0008;
  localparam logic [AXI_LITE_ADDR_WIDTH-1:0] ADDR_GLOBAL_IRQ_ENABLE = 32'h0000_000C;
  localparam logic [AXI_LITE_ADDR_WIDTH-1:0] ADDR_GLOBAL_VERSION    = 32'h0000_0010;

  // Channel Register Base and Stride
  localparam logic [AXI_LITE_ADDR_WIDTH-1:0] CH_BASE_OFFSET         = 32'h0000_0040;
  localparam logic [AXI_LITE_ADDR_WIDTH-1:0] CH_STRIDE              = 32'h0000_0040;

  // Offsets within a Channel
  localparam logic [5:0] CH_OFFSET_CTRL              = 6'h00;
  localparam logic [5:0] CH_OFFSET_STATUS            = 6'h04;
  localparam logic [5:0] CH_OFFSET_SRC_ADDR          = 6'h08;
  localparam logic [5:0] CH_OFFSET_DST_ADDR          = 6'h0C;
  localparam logic [5:0] CH_OFFSET_TRANSFER_LEN      = 6'h10;
  localparam logic [5:0] CH_OFFSET_BURST_CONFIG      = 6'h14;
  localparam logic [5:0] CH_OFFSET_PRIORITY          = 6'h18;
  localparam logic [5:0] CH_OFFSET_DESC_ADDR         = 6'h1C;
  localparam logic [5:0] CH_OFFSET_INT_ENABLE        = 6'h20;
  localparam logic [5:0] CH_OFFSET_INT_STATUS        = 6'h24;
  localparam logic [5:0] CH_OFFSET_ERROR_STATUS      = 6'h28;
  localparam logic [5:0] CH_OFFSET_BYTES_TRANSFERRED = 6'h2C;
  localparam logic [5:0] CH_OFFSET_CURRENT_DESC      = 6'h30;
  localparam logic [5:0] CH_OFFSET_SW_RESET          = 6'h34;

  // IP Version: v1.0.0
  localparam logic [31:0] IP_VERSION = 32'h0001_0000;

  // --------------------------------------------------------------------------
  // Enumerations
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    CH_IDLE       = 3'b000,
    CH_FETCH_DESC = 3'b001,
    CH_RUNNING    = 3'b010,
    CH_PAUSED     = 3'b011,
    CH_WAIT_FLUSH = 3'b100,
    CH_DONE       = 3'b101,
    CH_ERROR      = 3'b110
  } channel_state_e;

  typedef enum logic {
    ARB_ROUND_ROBIN   = 1'b0,
    ARB_FIXED_PRIORITY = 1'b1
  } arb_mode_e;

  typedef enum logic [3:0] {
    ERR_NONE            = 4'h0,
    ERR_AXI_SLVERR_RD   = 4'h1,
    ERR_AXI_DECERR_RD   = 4'h2,
    ERR_AXI_SLVERR_WR   = 4'h3,
    ERR_AXI_DECERR_WR   = 4'h4,
    ERR_INVALID_CFG     = 4'h5,
    ERR_INVALID_DESC    = 4'h6,
    ERR_ZERO_LEN        = 4'h7,
    ERR_UNALIGNED_DESC  = 4'h8,
    ERR_DESC_FETCH      = 4'h9,
    ERR_TIMEOUT         = 4'hA
  } dma_err_e;

  typedef enum logic [2:0] {
    BURST_1_BEAT  = 3'b000, // ARLEN/AWLEN = 0
    BURST_2_BEAT  = 3'b001, // ARLEN/AWLEN = 1
    BURST_4_BEAT  = 3'b010, // ARLEN/AWLEN = 3
    BURST_8_BEAT  = 3'b011, // ARLEN/AWLEN = 7
    BURST_16_BEAT = 3'b100  // ARLEN/AWLEN = 15
  } max_burst_e;

  // --------------------------------------------------------------------------
  // Structs
  // --------------------------------------------------------------------------
  // Channel configuration struct
  typedef struct packed {
    logic        enable;
    logic        start;
    logic        pause;
    logic        resume;
    logic        abort;
    logic        desc_mode;
    logic        src_inc;
    logic        dst_inc;
    max_burst_e  max_burst;
    logic [1:0]  priority_level;
  } ch_cfg_t;

  // Channel status struct
  typedef struct packed {
    logic        idle;
    logic        busy;
    logic        paused;
    logic        done;
    logic        error;
    logic        desc_active;
    logic        enabled;
  } ch_status_t;

  // Interrupt enable / status flags
  typedef struct packed {
    logic        err_ie;
    logic        desc_done_ie;
    logic        xfer_done_ie;
  } ch_irq_t;

  // Descriptor layout (32 bytes / 256 bits)
  typedef struct packed {
    logic [31:0] reserved1;       // Word 7
    logic [31:0] reserved0;       // Word 6
    logic [31:0] status;          // Word 5
    logic [31:0] next_desc_addr;  // Word 4
    logic [31:0] ctrl;            // Word 3: [0]=EOC, [1]=INT_CMPL, [2]=STOP_ON_ERR, [6:4]=BURST, [7]=SRC_INC, [8]=DST_INC
    logic [31:0] length_bytes;    // Word 2
    logic [31:0] dst_addr;        // Word 1
    logic [31:0] src_addr;        // Word 0
  } desc_t;

  // Internal FIFO entry holding one 128-bit data beat + metadata
  typedef struct packed {
    logic [AXI_DATA_WIDTH-1:0] data;
    logic [AXI_STRB_WIDTH-1:0] strb;
    logic                      last;
    logic [BEAT_OFFSET_WIDTH:0] byte_count; // Number of valid bytes in this beat (1..16)
  } fifo_entry_t;

  // Transaction Tracker Entry (for tracking in-flight AXI bursts)
  typedef struct packed {
    logic                      valid;
    logic [CH_ID_WIDTH-1:0]    channel_id;
    logic                      is_desc;      // 1 if descriptor fetch, 0 if data transfer
    logic [AXI_ADDR_WIDTH-1:0] addr;
    logic [AXI_LEN_WIDTH-1:0]  len;          // Number of beats minus 1
    logic [AXI_LEN_WIDTH-1:0]  beats_done;   // Received / written beats
    logic [AXI_RESP_WIDTH-1:0] resp;
    logic                      err;
  } tracker_entry_t;

  // --------------------------------------------------------------------------
  // Helper Functions
  // --------------------------------------------------------------------------

  // Return maximum beats for a given burst enum
  function automatic logic [AXI_LEN_WIDTH-1:0] get_max_burst_beats(input max_burst_e burst_cfg);
    case (burst_cfg)
      BURST_1_BEAT:  return 8'd1;
      BURST_2_BEAT:  return 8'd2;
      BURST_4_BEAT:  return 8'd4;
      BURST_8_BEAT:  return 8'd8;
      BURST_16_BEAT: return 8'd16;
      default:       return 8'd16;
    endcase
  endfunction

  // Calculate AXI burst length (len = beats - 1) clamped to 4KB boundary and remaining bytes
  function automatic logic [AXI_LEN_WIDTH-1:0] calc_axi_burst_len(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [31:0]               remaining_bytes,
    input logic [AXI_LEN_WIDTH-1:0]  max_beats
  );
    logic [31:0] bytes_to_4k_boundary;
    logic [31:0] beats_to_4k_boundary;
    logic [31:0] total_span_bytes;
    logic [31:0] remaining_beats;
    logic [31:0] allowed_beats;
    logic [11:0] page_offset;

    page_offset = addr[11:0];
    bytes_to_4k_boundary = 32'd4096 - {20'd0, page_offset};
    beats_to_4k_boundary = (bytes_to_4k_boundary + BYTES_PER_BEAT - 1) >> 4;

    total_span_bytes = remaining_bytes + {28'd0, addr[3:0]};
    remaining_beats = (total_span_bytes + BYTES_PER_BEAT - 1) >> 4;
    if (remaining_beats == 0) remaining_beats = 1;

    allowed_beats = max_beats;
    if (allowed_beats > beats_to_4k_boundary && beats_to_4k_boundary > 0)
      allowed_beats = beats_to_4k_boundary;
    if (allowed_beats > remaining_beats)
      allowed_beats = remaining_beats;
    if (allowed_beats > 16)
      allowed_beats = 16;
    if (allowed_beats == 0)
      allowed_beats = 1;

    return allowed_beats[AXI_LEN_WIDTH-1:0] - 8'd1;
  endfunction

  // Generate byte strobe for start offset and byte count within a 16-byte beat
  function automatic logic [AXI_STRB_WIDTH-1:0] gen_byte_strb(
    input logic [BEAT_OFFSET_WIDTH-1:0] start_offset,
    input logic [31:0]                  valid_bytes
  );
    logic [AXI_STRB_WIDTH-1:0] mask;
    int i;
    mask = '0;
    for (i = 0; i < AXI_STRB_WIDTH; i++) begin
      if (i >= start_offset && (i - start_offset) < valid_bytes) begin
        mask[i] = 1'b1;
      end
    end
    return mask;
  endfunction

endpackage : nx_dma_pkg
