// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_error_handler.sv
// Description:   Centralized Error Handling Unit. Captures, logs, and attributes
//                AXI bus response errors, channel parameter validation errors,
//                and descriptor parse errors.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_error_handler
  import nx_dma_pkg::*;
(
  input  logic                           clk,
  input  logic                           rst_n,
  input  logic                           sw_reset,

  // Read Engine Error Input
  input  logic                           rd_err_event,
  input  logic [CH_ID_WIDTH-1:0]         rd_err_channel,
  input  dma_err_e                       rd_err_code,

  // Write Engine Error Input
  input  logic                           wr_err_event,
  input  logic [CH_ID_WIDTH-1:0]         wr_err_channel,
  input  dma_err_e                       wr_err_code,

  // Channel Error Events
  input  logic [NUM_CHANNELS-1:0]        ch_err_event,
  input  dma_err_e                       ch_err_code[NUM_CHANNELS],

  // Global Error Outputs to Register File
  output logic                           global_err_valid,
  output logic [CH_ID_WIDTH-1:0]         global_err_channel,
  output dma_err_e                       global_err_code
);

  logic                  err_latched_q;
  logic [CH_ID_WIDTH-1:0] err_channel_q;
  dma_err_e              err_code_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      err_latched_q <= 1'b0;
      err_channel_q <= '0;
      err_code_q    <= ERR_NONE;
    end else if (sw_reset) begin
      err_latched_q <= 1'b0;
      err_channel_q <= '0;
      err_code_q    <= ERR_NONE;
    end else begin
      if (!err_latched_q) begin
        if (rd_err_event) begin
          err_latched_q <= 1'b1;
          err_channel_q <= rd_err_channel;
          err_code_q    <= rd_err_code;
        end else if (wr_err_event) begin
          err_latched_q <= 1'b1;
          err_channel_q <= wr_err_channel;
          err_code_q    <= wr_err_code;
        end else begin
          for (int c = 0; c < NUM_CHANNELS; c++) begin
            if (ch_err_event[c] && !err_latched_q) begin
              err_latched_q <= 1'b1;
              err_channel_q <= CH_ID_WIDTH'(c);
              err_code_q    <= ch_err_code[c];
            end
          end
        end
      end
    end
  end

  assign global_err_valid   = err_latched_q;
  assign global_err_channel = err_channel_q;
  assign global_err_code    = err_code_q;

endmodule : nx_dma_error_handler
