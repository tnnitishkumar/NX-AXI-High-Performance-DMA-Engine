// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_channel.sv
// Description:   Independent DMA Channel Controller. Manages channel state
//                machine, address calculation, burst slicing, transfer length
//                tracking, pause/resume/abort flow control, and event reporting.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_channel
  import nx_dma_pkg::*;
#(
  parameter int CHANNEL_ID = 0
)(
  input  logic                           clk,
  input  logic                           rst_n,

  // Channel Configuration from Register File
  input  ch_cfg_t                        cfg,
  input  logic [AXI_ADDR_WIDTH-1:0]      src_addr_in,
  input  logic [AXI_ADDR_WIDTH-1:0]      dst_addr_in,
  input  logic [31:0]                    transfer_len_in,
  input  logic [AXI_ADDR_WIDTH-1:0]      desc_addr_in,
  input  logic                           sw_reset,

  // Channel Status to Register File
  output channel_state_e                 ch_state_out,
  output ch_status_t                     ch_status_out,
  output logic [31:0]                    bytes_transferred_out,
  output logic [AXI_ADDR_WIDTH-1:0]      curr_desc_out,

  // Hardware Events to Register File
  output logic                           xfer_done_pulse,
  output logic                           desc_done_pulse,
  output logic                           error_event_pulse,
  output dma_err_e                       error_code_out,

  // Interface with Descriptor Engine
  output logic                           desc_fetch_req,
  output logic [AXI_ADDR_WIDTH-1:0]      desc_fetch_addr,
  input  logic                           desc_fetch_ack,
  input  logic                           desc_fetch_valid,
  input  desc_t                          desc_data_in,
  input  logic                           desc_fetch_err,
  input  dma_err_e                       desc_err_code,

  // Interface with FIFO Data Buffer
  input  logic [FIFO_ADDR_WIDTH:0]       fifo_avail_space,
  input  logic [FIFO_ADDR_WIDTH:0]       fifo_count,
  input  logic                           fifo_empty,
  output logic                           fifo_flush,

  // Read Request Interface to Scheduler / Read Engine
  output logic                           rd_req_valid,
  output logic [AXI_ADDR_WIDTH-1:0]      rd_req_addr,
  output logic [AXI_LEN_WIDTH-1:0]       rd_req_len,      // ARLEN = beats - 1
  output logic [31:0]                    rd_req_bytes,
  input  logic                           rd_req_grant,
  input  logic                           rd_burst_done,
  input  logic                           rd_err_event,
  input  dma_err_e                       rd_err_code,

  // Write Request Interface to Scheduler / Write Engine
  output logic                           wr_req_valid,
  output logic [AXI_ADDR_WIDTH-1:0]      wr_req_addr,
  output logic [AXI_LEN_WIDTH-1:0]       wr_req_len,      // AWLEN = beats - 1
  output logic [31:0]                    wr_req_bytes,
  output logic                           wr_req_last,
  input  logic                           wr_req_grant,
  input  logic [31:0]                    wr_bytes_done,
  input  logic                           wr_resp_done,
  input  logic                           wr_err_event,
  input  dma_err_e                       wr_err_code
);

  // --------------------------------------------------------------------------
  // Internal State & Registers
  // --------------------------------------------------------------------------
  channel_state_e state, state_next;

  logic [AXI_ADDR_WIDTH-1:0] src_addr_q;
  logic [AXI_ADDR_WIDTH-1:0] dst_addr_q;
  logic [31:0]               total_len_q;
  logic [31:0]               bytes_rem_rd_q;
  logic [31:0]               bytes_rem_wr_q;
  logic [31:0]               bytes_committed_q;

  logic [AXI_ADDR_WIDTH-1:0] curr_desc_addr_q;
  logic                      is_desc_mode_q;
  logic                      last_desc_q;
  logic                      src_inc_q;
  logic                      dst_inc_q;
  max_burst_e                max_burst_q;

  dma_err_e                  err_code_q;
  logic                      paused_q;

  // Active in-flight counters
  logic [3:0]                inflight_rd_bursts;
  logic [3:0]                inflight_wr_bursts;

  // Computed next burst lengths
  logic [AXI_LEN_WIDTH-1:0]  calc_rd_len;
  logic [31:0]               calc_rd_bytes;
  logic [AXI_LEN_WIDTH-1:0]  calc_wr_len;
  logic [31:0]               calc_wr_bytes;
  logic [AXI_LEN_WIDTH-1:0]  max_burst_beats_val;

  assign max_burst_beats_val = get_max_burst_beats(max_burst_q);

  // Calculate next read burst length based on 4KB boundary and remaining bytes
  always_comb begin
    logic [AXI_LEN_WIDTH-1:0] beats_minus1;
    logic [31:0] burst_capacity;
    beats_minus1 = calc_axi_burst_len(src_addr_q, bytes_rem_rd_q, max_burst_beats_val);
    calc_rd_len  = beats_minus1;

    // Total bytes covered by this burst
    burst_capacity = (BYTES_PER_BEAT - src_addr_q[3:0]) + (32'(beats_minus1) * BYTES_PER_BEAT);
    if (burst_capacity > bytes_rem_rd_q) begin
      calc_rd_bytes = bytes_rem_rd_q;
    end else begin
      calc_rd_bytes = burst_capacity;
    end
  end

  // Calculate next write burst length based on 4KB boundary, FIFO content, and remaining write bytes
  always_comb begin
    logic [AXI_LEN_WIDTH-1:0] beats_minus1;
    logic [AXI_LEN_WIDTH-1:0] max_wbeats;
    logic [31:0] burst_capacity;

    // Write engine cannot issue more beats than available in FIFO unless this is final fragment
    max_wbeats = max_burst_beats_val;
    if (max_wbeats > AXI_LEN_WIDTH'(fifo_count) && fifo_count > 0) begin
      max_wbeats = AXI_LEN_WIDTH'(fifo_count);
    end

    beats_minus1 = calc_axi_burst_len(dst_addr_q, bytes_rem_wr_q, max_wbeats);
    calc_wr_len  = beats_minus1;

    burst_capacity = (BYTES_PER_BEAT - dst_addr_q[3:0]) + (32'(beats_minus1) * BYTES_PER_BEAT);
    if (burst_capacity > bytes_rem_wr_q) begin
      calc_wr_bytes = bytes_rem_wr_q;
    end else begin
      calc_wr_bytes = burst_capacity;
    end
  end

  // Read request validity:
  // Must be in RUNNING state, have bytes remaining to read, and FIFO must have space for the burst beats!
  assign rd_req_valid = (state == CH_RUNNING) &&
                        (bytes_rem_rd_q > 0) &&
                        (!paused_q) &&
                        (fifo_avail_space >= (calc_rd_len + 8'd1));

  assign rd_req_addr  = src_addr_q;
  assign rd_req_len   = calc_rd_len;
  assign rd_req_bytes = calc_rd_bytes;

  // Write request validity:
  // Must have bytes remaining to write, and FIFO must have at least required beats or all remaining data
  assign wr_req_valid = (state == CH_RUNNING || state == CH_WAIT_FLUSH) &&
                        (bytes_rem_wr_q > 0) &&
                        (fifo_count >= (calc_wr_len + 8'd1) || (bytes_rem_rd_q == 0 && fifo_count > 0));

  assign wr_req_addr  = dst_addr_q;
  assign wr_req_len   = calc_wr_len;
  assign wr_req_bytes = calc_wr_bytes;
  assign wr_req_last  = (bytes_rem_wr_q <= calc_wr_bytes);

  // Status and Output Assignments
  assign ch_state_out            = state;
  assign ch_status_out.idle      = (state == CH_IDLE);
  assign ch_status_out.busy      = (state == CH_RUNNING || state == CH_FETCH_DESC || state == CH_WAIT_FLUSH);
  assign ch_status_out.paused    = paused_q;
  assign ch_status_out.done      = (state == CH_DONE);
  assign ch_status_out.error     = (state == CH_ERROR);
  assign ch_status_out.desc_active = is_desc_mode_q && (state != CH_IDLE);
  assign ch_status_out.enabled   = cfg.enable;

  assign bytes_transferred_out   = bytes_committed_q;
  assign curr_desc_out           = curr_desc_addr_q;
  assign error_code_out          = err_code_q;

  assign desc_fetch_addr         = curr_desc_addr_q;

  // --------------------------------------------------------------------------
  // Channel State Machine & Control Logic
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state               <= CH_IDLE;
      src_addr_q          <= '0;
      dst_addr_q          <= '0;
      total_len_q         <= '0;
      bytes_rem_rd_q      <= '0;
      bytes_rem_wr_q      <= '0;
      bytes_committed_q   <= '0;
      curr_desc_addr_q    <= '0;
      is_desc_mode_q      <= 1'b0;
      last_desc_q         <= 1'b0;
      src_inc_q           <= 1'b1;
      dst_inc_q           <= 1'b1;
      max_burst_q         <= BURST_16_BEAT;
      err_code_q          <= ERR_NONE;
      paused_q            <= 1'b0;
      inflight_rd_bursts  <= '0;
      inflight_wr_bursts  <= '0;
      desc_fetch_req      <= 1'b0;
      fifo_flush          <= 1'b0;
      xfer_done_pulse     <= 1'b0;
      desc_done_pulse     <= 1'b0;
      error_event_pulse   <= 1'b0;
    end else if (sw_reset || cfg.abort) begin
      state               <= CH_IDLE;
      bytes_rem_rd_q      <= '0;
      bytes_rem_wr_q      <= '0;
      paused_q            <= 1'b0;
      inflight_rd_bursts  <= '0;
      inflight_wr_bursts  <= '0;
      desc_fetch_req      <= 1'b0;
      fifo_flush          <= 1'b1;
      xfer_done_pulse     <= 1'b0;
      desc_done_pulse     <= 1'b0;
      error_event_pulse   <= 1'b0;
      if (sw_reset) err_code_q <= ERR_NONE;
    end else begin
      // Default pulse deassertions
      fifo_flush        <= 1'b0;
      xfer_done_pulse   <= 1'b0;
      desc_done_pulse   <= 1'b0;
      error_event_pulse <= 1'b0;

      // Track in-flight transactions
      if (CHANNEL_ID == 0) begin
        if (wr_req_valid && wr_req_grant) begin
          $display("[DBG-WR-GRANT] t=%0t inflight_wr=%0d bytes_rem_wr=%0d", $time, inflight_wr_bursts, bytes_rem_wr_q);
        end
        if (wr_resp_done) begin
          $display("[DBG-WR-RESP] t=%0t inflight_wr=%0d", $time, inflight_wr_bursts);
        end
      end
      case ({ (rd_req_valid && rd_req_grant), (rd_burst_done && inflight_rd_bursts > 0) })
        2'b10:   inflight_rd_bursts <= inflight_rd_bursts + 1'b1;
        2'b01:   inflight_rd_bursts <= inflight_rd_bursts - 1'b1;
        default: ; // 2'b00 or 2'b11: unchanged
      endcase

      case ({ (wr_req_valid && wr_req_grant), (wr_resp_done && inflight_wr_bursts > 0) })
        2'b10:   inflight_wr_bursts <= inflight_wr_bursts + 1'b1;
        2'b01:   inflight_wr_bursts <= inflight_wr_bursts - 1'b1;
        default: ; // 2'b00 or 2'b11: unchanged
      endcase

      // Update bytes committed from Write Engine
      if (wr_bytes_done > 0) begin
        bytes_committed_q <= bytes_committed_q + wr_bytes_done;
      end

      // Handle Pause and Resume
      if (cfg.pause && (state == CH_RUNNING)) begin
        paused_q <= 1'b1;
      end else if (cfg.resume && paused_q) begin
        paused_q <= 1'b0;
      end

      // Handle Read Address and Remaining Bytes update on grant
      if (rd_req_valid && rd_req_grant) begin
        if (src_inc_q) begin
          src_addr_q <= src_addr_q + calc_rd_bytes;
        end
        if (bytes_rem_rd_q >= calc_rd_bytes) begin
          bytes_rem_rd_q <= bytes_rem_rd_q - calc_rd_bytes;
        end else begin
          bytes_rem_rd_q <= '0;
        end
      end

      // Handle Write Address and Remaining Bytes update on grant
      if (wr_req_valid && wr_req_grant) begin
        if (dst_inc_q) begin
          dst_addr_q <= dst_addr_q + calc_wr_bytes;
        end
        if (bytes_rem_wr_q >= calc_wr_bytes) begin
          bytes_rem_wr_q <= bytes_rem_wr_q - calc_wr_bytes;
        end else begin
          bytes_rem_wr_q <= '0;
        end
      end

      // Check for Error conditions
      if (rd_err_event || wr_err_event) begin
        state             <= CH_ERROR;
        err_code_q        <= rd_err_event ? rd_err_code : wr_err_code;
        error_event_pulse <= 1'b1;
        fifo_flush        <= 1'b1;
      end

      // Main Channel FSM
      case (state)
        CH_IDLE: begin
          paused_q           <= 1'b0;
          inflight_rd_bursts <= '0;
          inflight_wr_bursts <= '0;

          if (cfg.enable && cfg.start) begin
            bytes_committed_q <= '0;
            err_code_q        <= ERR_NONE;

            if (cfg.desc_mode) begin
              // Descriptor Mode Start
              is_desc_mode_q   <= 1'b1;
              curr_desc_addr_q <= desc_addr_in;

              // Validate starting descriptor address alignment (must be 16-byte aligned)
              if (|desc_addr_in[3:0]) begin
                state             <= CH_ERROR;
                err_code_q        <= ERR_UNALIGNED_DESC;
                error_event_pulse <= 1'b1;
              end else begin
                state          <= CH_FETCH_DESC;
                desc_fetch_req <= 1'b1;
              end
            end else begin
              // Direct / Register Mode Start
              is_desc_mode_q <= 1'b0;

              // Validate direct mode configuration
              if (transfer_len_in == 0) begin
                state             <= CH_ERROR;
                err_code_q        <= ERR_ZERO_LEN;
                error_event_pulse <= 1'b1;
              end else begin
                src_addr_q     <= src_addr_in;
                dst_addr_q     <= dst_addr_in;
                total_len_q    <= transfer_len_in;
                bytes_rem_rd_q <= transfer_len_in;
                bytes_rem_wr_q <= transfer_len_in;
                src_inc_q      <= cfg.src_inc;
                dst_inc_q      <= cfg.dst_inc;
                max_burst_q    <= cfg.max_burst;
                state          <= CH_RUNNING;
              end
            end
          end
        end

        CH_FETCH_DESC: begin
          if (desc_fetch_ack) begin
            desc_fetch_req <= 1'b0;
          end

          if (desc_fetch_err) begin
            state             <= CH_ERROR;
            err_code_q        <= desc_err_code;
            error_event_pulse <= 1'b1;
          end else if (desc_fetch_valid) begin
            // Validate descriptor fields
            if (desc_data_in.length_bytes == 0) begin
              state             <= CH_ERROR;
              err_code_q        <= ERR_ZERO_LEN;
              error_event_pulse <= 1'b1;
            end else begin
              src_addr_q       <= desc_data_in.src_addr;
              dst_addr_q       <= desc_data_in.dst_addr;
              total_len_q      <= desc_data_in.length_bytes;
              bytes_rem_rd_q   <= desc_data_in.length_bytes;
              bytes_rem_wr_q   <= desc_data_in.length_bytes;
              last_desc_q      <= desc_data_in.ctrl[0]; // EOC bit
              src_inc_q        <= desc_data_in.ctrl[7];
              dst_inc_q        <= desc_data_in.ctrl[8];
              max_burst_q      <= max_burst_e'(desc_data_in.ctrl[6:4]);
              curr_desc_addr_q <= desc_data_in.next_desc_addr;
              state            <= CH_RUNNING;
            end
          end
        end

        CH_RUNNING: begin
          if (bytes_rem_rd_q == 0 && bytes_rem_wr_q == 0) begin
            $display("[DBG-CH%0d] t=%0t rem_rd=%0d rem_wr=%0d inflight_wr=%0d fifo_empty=%0b count=%0d",
              CHANNEL_ID, $time, bytes_rem_rd_q, bytes_rem_wr_q, inflight_wr_bursts, fifo_empty, fifo_count);
          end
          // When all read requests have been issued and all write requests have completed
          if (bytes_rem_rd_q == 0 && bytes_rem_wr_q == 0 && inflight_wr_bursts == 0 && fifo_empty) begin
            if (is_desc_mode_q) begin
              if (last_desc_q) begin
                // End of descriptor chain
                xfer_done_pulse <= 1'b1;
                desc_done_pulse <= 1'b1;
                state           <= CH_DONE;
              end else begin
                // Fetch next descriptor
                if (|curr_desc_addr_q[3:0]) begin
                  state             <= CH_ERROR;
                  err_code_q        <= ERR_UNALIGNED_DESC;
                  error_event_pulse <= 1'b1;
                end else begin
                  state          <= CH_FETCH_DESC;
                  desc_fetch_req <= 1'b1;
                end
              end
            end else begin
              xfer_done_pulse <= 1'b1;
              state <= CH_DONE;
            end
          end
        end

        CH_DONE: begin
          // Remain in DONE state until cleared or new start
          if (cfg.start) begin
            state <= CH_IDLE;
          end
        end

        CH_ERROR: begin
          // Remain in ERROR state until software reset or restart
          if (cfg.start || sw_reset) begin
            state <= CH_IDLE;
          end
        end

        default: state <= CH_IDLE;
      endcase
    end
  end

endmodule : nx_dma_channel
