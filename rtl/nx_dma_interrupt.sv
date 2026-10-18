// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_interrupt.sv
// Description:   Interrupt Controller. Aggregates per-channel interrupt status,
//                applies channel and global interrupt masks, and generates
//                individual channel IRQs and top-level aggregated IRQ.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_interrupt
  import nx_dma_pkg::*;
(
  input  logic                           clk,
  input  logic                           rst_n,

  // Global Interrupt Control from Register File
  input  logic [NUM_CHANNELS-1:0]        global_irq_en,
  input  logic [NUM_CHANNELS-1:0]        global_irq_status,

  // Channel Interrupt Status from Register File
  input  logic [NUM_CHANNELS-1:0]        ch_irq_status,

  // Output Interrupt Lines
  output logic [NUM_CHANNELS-1:0]        ch_irq_out,
  output logic                           irq_out
);

  logic [NUM_CHANNELS-1:0] irq_per_ch_q;
  logic                    irq_top_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      irq_per_ch_q <= '0;
      irq_top_q    <= 1'b0;
    end else begin
      for (int c = 0; c < NUM_CHANNELS; c++) begin
        irq_per_ch_q[c] <= global_irq_en[c] && ch_irq_status[c];
      end
      irq_top_q <= |(global_irq_en & (ch_irq_status | global_irq_status));
    end
  end

  assign ch_irq_out = irq_per_ch_q;
  assign irq_out    = irq_top_q;

endmodule : nx_dma_interrupt
