// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_reg_file.sv
// Description:   Central DMA Register File containing global registers and
//                per-channel control, status, address, interrupt, error, and
//                scatter-gather descriptor registers.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_reg_file
  import nx_dma_pkg::*;
(
  input  logic                           clk,
  input  logic                           rst_n,

  // Register Access Interface from AXI-Lite Slave
  input  logic                           reg_wr_en,
  input  logic [AXI_LITE_ADDR_WIDTH-1:0] reg_wr_addr,
  input  logic [AXI_LITE_DATA_WIDTH-1:0] reg_wr_data,
  input  logic [AXI_LITE_STRB_WIDTH-1:0] reg_wr_strb,
  output logic                           reg_wr_ack,
  output logic [AXI_RESP_WIDTH-1:0]      reg_wr_resp,

  input  logic                           reg_rd_en,
  input  logic [AXI_LITE_ADDR_WIDTH-1:0] reg_rd_addr,
  output logic [AXI_LITE_DATA_WIDTH-1:0] reg_rd_data,
  output logic                           reg_rd_ack,
  output logic [AXI_RESP_WIDTH-1:0]      reg_rd_resp,

  // Global Control Outputs
  output logic                           global_en,
  output logic                           global_sw_reset,
  output arb_mode_e                      global_arb_mode,
  output logic [NUM_CHANNELS-1:0]        global_irq_en,

  // Per-Channel Configuration Outputs to Channels
  output ch_cfg_t                        ch_cfg[NUM_CHANNELS],
  output logic [AXI_ADDR_WIDTH-1:0]      ch_src_addr[NUM_CHANNELS],
  output logic [AXI_ADDR_WIDTH-1:0]      ch_dst_addr[NUM_CHANNELS],
  output logic [31:0]                    ch_transfer_len[NUM_CHANNELS],
  output logic [1:0]                     ch_priority[NUM_CHANNELS],
  output logic [AXI_ADDR_WIDTH-1:0]      ch_desc_addr[NUM_CHANNELS],
  output ch_irq_t                        ch_int_enable[NUM_CHANNELS],
  output logic [NUM_CHANNELS-1:0]        ch_sw_reset,

  // Per-Channel Status Inputs from Channels / Engines
  input  channel_state_e                 ch_state_in[NUM_CHANNELS],
  input  ch_status_t                     ch_status_in[NUM_CHANNELS],
  input  logic [31:0]                    ch_bytes_xferred_in[NUM_CHANNELS],
  input  logic [AXI_ADDR_WIDTH-1:0]      ch_curr_desc_in[NUM_CHANNELS],

  // Hardware Event Inputs (Interrupts and Errors)
  input  logic [NUM_CHANNELS-1:0]        hw_xfer_done,
  input  logic [NUM_CHANNELS-1:0]        hw_desc_done,
  input  logic [NUM_CHANNELS-1:0]        hw_error_event,
  input  dma_err_e                       hw_error_code[NUM_CHANNELS],

  // Channel Interrupt Status Outputs
  output ch_irq_t                        ch_int_status[NUM_CHANNELS],
  output dma_err_e                       ch_error_status[NUM_CHANNELS]
);

  // --------------------------------------------------------------------------
  // Internal Registers
  // --------------------------------------------------------------------------
  // Global Registers
  logic                    global_en_q;
  logic                    global_sw_reset_q;
  arb_mode_e               global_arb_mode_q;
  logic [NUM_CHANNELS-1:0] global_irq_en_q;

  // Per-Channel Registers
  logic [NUM_CHANNELS-1:0]        ch_en_q;
  logic [NUM_CHANNELS-1:0]        ch_desc_mode_q;
  logic [NUM_CHANNELS-1:0]        ch_src_inc_q;
  logic [NUM_CHANNELS-1:0]        ch_dst_inc_q;
  max_burst_e                     ch_max_burst_q[NUM_CHANNELS];
  logic [1:0]                     ch_priority_q[NUM_CHANNELS];
  logic [AXI_ADDR_WIDTH-1:0]      ch_src_addr_q[NUM_CHANNELS];
  logic [AXI_ADDR_WIDTH-1:0]      ch_dst_addr_q[NUM_CHANNELS];
  logic [31:0]                    ch_transfer_len_q[NUM_CHANNELS];
  logic [AXI_ADDR_WIDTH-1:0]      ch_desc_addr_q[NUM_CHANNELS];
  ch_irq_t                        ch_int_enable_q[NUM_CHANNELS];
  ch_irq_t                        ch_int_status_q[NUM_CHANNELS];
  dma_err_e                       ch_error_status_q[NUM_CHANNELS];

  // Self-clearing command pulses (1 cycle pulse)
  logic [NUM_CHANNELS-1:0]        ch_start_pulse;
  logic [NUM_CHANNELS-1:0]        ch_pause_pulse;
  logic [NUM_CHANNELS-1:0]        ch_resume_pulse;
  logic [NUM_CHANNELS-1:0]        ch_abort_pulse;
  logic [NUM_CHANNELS-1:0]        ch_sw_reset_pulse;

  // Assign Global Outputs
  assign global_en       = global_en_q;
  assign global_sw_reset = global_sw_reset_q;
  assign global_arb_mode = global_arb_mode_q;
  assign global_irq_en   = global_irq_en_q;

  // Assign Channel Outputs
  generate
    for (genvar c = 0; c < NUM_CHANNELS; c++) begin : gen_ch_assign
      assign ch_cfg[c].enable         = ch_en_q[c];
      assign ch_cfg[c].start          = ch_start_pulse[c];
      assign ch_cfg[c].pause          = ch_pause_pulse[c];
      assign ch_cfg[c].resume         = ch_resume_pulse[c];
      assign ch_cfg[c].abort          = ch_abort_pulse[c];
      assign ch_cfg[c].desc_mode      = ch_desc_mode_q[c];
      assign ch_cfg[c].src_inc        = ch_src_inc_q[c];
      assign ch_cfg[c].dst_inc        = ch_dst_inc_q[c];
      assign ch_cfg[c].max_burst      = ch_max_burst_q[c];
      assign ch_cfg[c].priority_level = ch_priority_q[c];

      assign ch_src_addr[c]           = ch_src_addr_q[c];
      assign ch_dst_addr[c]           = ch_dst_addr_q[c];
      assign ch_transfer_len[c]       = ch_transfer_len_q[c];
      assign ch_priority[c]           = ch_priority_q[c];
      assign ch_desc_addr[c]          = ch_desc_addr_q[c];
      assign ch_int_enable[c]         = ch_int_enable_q[c];
      assign ch_int_status[c]         = ch_int_status_q[c];
      assign ch_error_status[c]       = ch_error_status_q[c];
      assign ch_sw_reset[c]           = ch_sw_reset_pulse[c];
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Register Write Logic
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      global_en_q       <= 1'b1;
      global_sw_reset_q <= 1'b0;
      global_arb_mode_q <= ARB_ROUND_ROBIN;
      global_irq_en_q   <= '1;

      ch_start_pulse    <= '0;
      ch_pause_pulse    <= '0;
      ch_resume_pulse   <= '0;
      ch_abort_pulse    <= '0;
      ch_sw_reset_pulse <= '0;

      for (int i = 0; i < NUM_CHANNELS; i++) begin
        ch_en_q[i]           <= 1'b0;
        ch_desc_mode_q[i]    <= 1'b0;
        ch_src_inc_q[i]      <= 1'b1;
        ch_dst_inc_q[i]      <= 1'b1;
        ch_max_burst_q[i]    <= BURST_16_BEAT;
        ch_priority_q[i]     <= 2'd0;
        ch_src_addr_q[i]     <= '0;
        ch_dst_addr_q[i]     <= '0;
        ch_transfer_len_q[i] <= '0;
        ch_desc_addr_q[i]    <= '0;
        ch_int_enable_q[i]   <= '0;
        ch_int_status_q[i]   <= '0;
        ch_error_status_q[i] <= ERR_NONE;
      end

      reg_wr_ack  <= 1'b0;
      reg_wr_resp <= AXI_RESP_OKAY;
    end else begin
      // Default: clear self-clearing command pulses
      ch_start_pulse    <= '0;
      ch_pause_pulse    <= '0;
      ch_resume_pulse   <= '0;
      ch_abort_pulse    <= '0;
      ch_sw_reset_pulse <= '0;
      global_sw_reset_q <= 1'b0;

      // Handle Hardware Interrupt and Error Events
      for (int i = 0; i < NUM_CHANNELS; i++) begin
        if (hw_xfer_done[i]) begin
          ch_int_status_q[i].xfer_done_ie <= 1'b1;
        end
        if (hw_desc_done[i]) begin
          ch_int_status_q[i].desc_done_ie <= 1'b1;
        end
        if (hw_error_event[i]) begin
          ch_int_status_q[i].err_ie <= 1'b1;
          ch_error_status_q[i]      <= hw_error_code[i];
        end
      end

      // Process Register Writes from AXI-Lite
      if (reg_wr_en) begin
        reg_wr_ack  <= 1'b1;
        reg_wr_resp <= AXI_RESP_OKAY;

        // Global Registers Decoded
        if (reg_wr_addr < CH_BASE_OFFSET) begin
          case (reg_wr_addr)
            ADDR_GLOBAL_CTRL: begin
              if (reg_wr_strb[0]) begin
                global_en_q       <= reg_wr_data[0];
                global_sw_reset_q <= reg_wr_data[1];
                global_arb_mode_q <= arb_mode_e'(reg_wr_data[2]);
              end
            end
            ADDR_GLOBAL_IRQ_ENABLE: begin
              if (reg_wr_strb[0]) begin
                global_irq_en_q <= reg_wr_data[NUM_CHANNELS-1:0];
              end
            end
            default: begin
              // Read-only or unmapped
              reg_wr_resp <= AXI_RESP_OKAY;
            end
          endcase
        end
        // Channel Registers Decoded
        else begin
          logic [AXI_LITE_ADDR_WIDTH-1:0] ch_addr_offset;
          int ch_idx;
          logic [5:0] reg_offset;

          ch_addr_offset = reg_wr_addr - CH_BASE_OFFSET;
          ch_idx         = ch_addr_offset / CH_STRIDE;
          reg_offset     = ch_addr_offset % CH_STRIDE;

          if (ch_idx < NUM_CHANNELS) begin
            case (reg_offset)
              CH_OFFSET_CTRL: begin
                if (reg_wr_strb[0]) begin
                  ch_en_q[ch_idx]           <= reg_wr_data[0];
                  ch_start_pulse[ch_idx]    <= reg_wr_data[1];
                  ch_pause_pulse[ch_idx]    <= reg_wr_data[2];
                  ch_resume_pulse[ch_idx]   <= reg_wr_data[3];
                  ch_abort_pulse[ch_idx]    <= reg_wr_data[4];
                  ch_desc_mode_q[ch_idx]    <= reg_wr_data[5];
                  ch_src_inc_q[ch_idx]      <= reg_wr_data[6];
                  ch_dst_inc_q[ch_idx]      <= reg_wr_data[7];
                end
                if (reg_wr_strb[1]) begin
                  ch_max_burst_q[ch_idx]    <= max_burst_e'(reg_wr_data[10:8]);
                end
              end

              CH_OFFSET_SRC_ADDR: begin
                for (int b = 0; b < 4; b++) begin
                  if (reg_wr_strb[b]) ch_src_addr_q[ch_idx][b*8 +: 8] <= reg_wr_data[b*8 +: 8];
                end
              end

              CH_OFFSET_DST_ADDR: begin
                for (int b = 0; b < 4; b++) begin
                  if (reg_wr_strb[b]) ch_dst_addr_q[ch_idx][b*8 +: 8] <= reg_wr_data[b*8 +: 8];
                end
              end

              CH_OFFSET_TRANSFER_LEN: begin
                for (int b = 0; b < 4; b++) begin
                  if (reg_wr_strb[b]) ch_transfer_len_q[ch_idx][b*8 +: 8] <= reg_wr_data[b*8 +: 8];
                end
              end

              CH_OFFSET_BURST_CONFIG: begin
                if (reg_wr_strb[0]) begin
                  ch_max_burst_q[ch_idx] <= max_burst_e'(reg_wr_data[2:0]);
                end
              end

              CH_OFFSET_PRIORITY: begin
                if (reg_wr_strb[0]) begin
                  ch_priority_q[ch_idx] <= reg_wr_data[1:0];
                end
              end

              CH_OFFSET_DESC_ADDR: begin
                for (int b = 0; b < 4; b++) begin
                  if (reg_wr_strb[b]) ch_desc_addr_q[ch_idx][b*8 +: 8] <= reg_wr_data[b*8 +: 8];
                end
              end

              CH_OFFSET_INT_ENABLE: begin
                if (reg_wr_strb[0]) begin
                  ch_int_enable_q[ch_idx].xfer_done_ie <= reg_wr_data[0];
                  ch_int_enable_q[ch_idx].desc_done_ie <= reg_wr_data[1];
                  ch_int_enable_q[ch_idx].err_ie       <= reg_wr_data[2];
                end
              end

              CH_OFFSET_INT_STATUS: begin
                // W1C (Write 1 to clear)
                if (reg_wr_strb[0]) begin
                  if (reg_wr_data[0]) ch_int_status_q[ch_idx].xfer_done_ie <= 1'b0;
                  if (reg_wr_data[1]) ch_int_status_q[ch_idx].desc_done_ie <= 1'b0;
                  if (reg_wr_data[2]) ch_int_status_q[ch_idx].err_ie       <= 1'b0;
                end
              end

              CH_OFFSET_ERROR_STATUS: begin
                // W1C for error code
                if (reg_wr_strb[0]) begin
                  if (|reg_wr_data[3:0]) ch_error_status_q[ch_idx] <= ERR_NONE;
                end
              end

              CH_OFFSET_SW_RESET: begin
                if (reg_wr_strb[0] && reg_wr_data[0]) begin
                  ch_sw_reset_pulse[ch_idx] <= 1'b1;
                  ch_en_q[ch_idx]           <= 1'b0;
                  ch_int_status_q[ch_idx]   <= '0;
                  ch_error_status_q[ch_idx] <= ERR_NONE;
                end
              end

              default: begin
                reg_wr_resp <= AXI_RESP_OKAY;
              end
            endcase
          end else begin
            reg_wr_resp <= AXI_RESP_DECERR;
          end
        end
      end else begin
        reg_wr_ack <= 1'b0;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Register Read Logic
  // --------------------------------------------------------------------------
  logic [AXI_LITE_DATA_WIDTH-1:0] rd_data_comb;
  logic [AXI_RESP_WIDTH-1:0]      rd_resp_comb;

  always_comb begin
    rd_data_comb = '0;
    rd_resp_comb = AXI_RESP_OKAY;

    // Global Registers Read
    if (reg_rd_addr < CH_BASE_OFFSET) begin
      case (reg_rd_addr)
        ADDR_GLOBAL_CTRL: begin
          rd_data_comb = {29'd0, logic'(global_arb_mode_q), global_sw_reset_q, global_en_q};
        end
        ADDR_GLOBAL_STATUS: begin
          logic [3:0] busy_mask, done_mask, err_mask;
          logic       any_busy;
          busy_mask = '0;
          done_mask = '0;
          err_mask  = '0;
          for (int i = 0; i < NUM_CHANNELS; i++) begin
            busy_mask[i] = ch_status_in[i].busy;
            done_mask[i] = ch_status_in[i].done;
            err_mask[i]  = ch_status_in[i].error;
          end
          any_busy = |busy_mask;
          rd_data_comb = {15'd0, any_busy, 4'd0, err_mask, done_mask, busy_mask};
        end
        ADDR_GLOBAL_IRQ_STATUS: begin
          logic [NUM_CHANNELS-1:0] irq_pending;
          irq_pending = '0;
          for (int i = 0; i < NUM_CHANNELS; i++) begin
            irq_pending[i] = (ch_int_status_q[i].xfer_done_ie && ch_int_enable_q[i].xfer_done_ie) ||
                             (ch_int_status_q[i].desc_done_ie && ch_int_enable_q[i].desc_done_ie) ||
                             (ch_int_status_q[i].err_ie       && ch_int_enable_q[i].err_ie);
          end
          rd_data_comb = {28'd0, irq_pending};
        end
        ADDR_GLOBAL_IRQ_ENABLE: begin
          rd_data_comb = {28'd0, global_irq_en_q};
        end
        ADDR_GLOBAL_VERSION: begin
          rd_data_comb = IP_VERSION;
        end
        default: begin
          rd_data_comb = '0;
          rd_resp_comb = AXI_RESP_DECERR;
        end
      endcase
    end
    // Channel Registers Read
    else begin
      logic [AXI_LITE_ADDR_WIDTH-1:0] ch_addr_offset;
      int ch_idx;
      logic [5:0] reg_offset;

      ch_addr_offset = reg_rd_addr - CH_BASE_OFFSET;
      ch_idx         = ch_addr_offset / CH_STRIDE;
      reg_offset     = ch_addr_offset % CH_STRIDE;

      if (ch_idx < NUM_CHANNELS) begin
        case (reg_offset)
          CH_OFFSET_CTRL: begin
            rd_data_comb = {21'd0,
                            ch_max_burst_q[ch_idx],
                            ch_dst_inc_q[ch_idx],
                            ch_src_inc_q[ch_idx],
                            ch_desc_mode_q[ch_idx],
                            5'd0,
                            ch_en_q[ch_idx]};
          end

          CH_OFFSET_STATUS: begin
            rd_data_comb = {21'd0,
                            ch_state_in[ch_idx],
                            1'b0,
                            ch_status_in[ch_idx].enabled,
                            ch_status_in[ch_idx].desc_active,
                            ch_status_in[ch_idx].error,
                            ch_status_in[ch_idx].done,
                            ch_status_in[ch_idx].paused,
                            ch_status_in[ch_idx].busy,
                            ch_status_in[ch_idx].idle};
          end

          CH_OFFSET_SRC_ADDR: begin
            rd_data_comb = ch_src_addr_q[ch_idx];
          end

          CH_OFFSET_DST_ADDR: begin
            rd_data_comb = ch_dst_addr_q[ch_idx];
          end

          CH_OFFSET_TRANSFER_LEN: begin
            rd_data_comb = ch_transfer_len_q[ch_idx];
          end

          CH_OFFSET_BURST_CONFIG: begin
            rd_data_comb = {26'd0, 2'b01, 1'b0, ch_max_burst_q[ch_idx]};
          end

          CH_OFFSET_PRIORITY: begin
            rd_data_comb = {30'd0, ch_priority_q[ch_idx]};
          end

          CH_OFFSET_DESC_ADDR: begin
            rd_data_comb = ch_desc_addr_q[ch_idx];
          end

          CH_OFFSET_INT_ENABLE: begin
            rd_data_comb = {29'd0,
                            ch_int_enable_q[ch_idx].err_ie,
                            ch_int_enable_q[ch_idx].desc_done_ie,
                            ch_int_enable_q[ch_idx].xfer_done_ie};
          end

          CH_OFFSET_INT_STATUS: begin
            rd_data_comb = {29'd0,
                            ch_int_status_q[ch_idx].err_ie,
                            ch_int_status_q[ch_idx].desc_done_ie,
                            ch_int_status_q[ch_idx].xfer_done_ie};
          end

          CH_OFFSET_ERROR_STATUS: begin
            rd_data_comb = {28'd0, ch_error_status_q[ch_idx]};
          end

          CH_OFFSET_BYTES_TRANSFERRED: begin
            rd_data_comb = ch_bytes_xferred_in[ch_idx];
          end

          CH_OFFSET_CURRENT_DESC: begin
            rd_data_comb = ch_curr_desc_in[ch_idx];
          end

          CH_OFFSET_SW_RESET: begin
            rd_data_comb = '0;
          end

          default: begin
            rd_data_comb = '0;
            rd_resp_comb = AXI_RESP_DECERR;
          end
        endcase
      end else begin
        rd_data_comb = '0;
        rd_resp_comb = AXI_RESP_DECERR;
      end
    end
  end

  // Register the read outputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_rd_data <= '0;
      reg_rd_resp <= AXI_RESP_OKAY;
      reg_rd_ack  <= 1'b0;
    end else begin
      if (reg_rd_en) begin
        reg_rd_data <= rd_data_comb;
        reg_rd_resp <= rd_resp_comb;
        reg_rd_ack  <= 1'b1;
      end else begin
        reg_rd_ack  <= 1'b0;
      end
    end
  end

endmodule : nx_dma_reg_file
