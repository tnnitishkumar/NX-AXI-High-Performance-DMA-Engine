// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_irq_if.sv
// Description:   Interrupt Monitor Interface for Top-Level and Channel IRQs.
// ============================================================================

`timescale 1ns / 1ps

interface nx_dma_irq_if #(
  parameter int NUM_CHANNELS = 4
)(
  input logic clk,
  input logic rst_n
);

  logic                      irq;
  logic [NUM_CHANNELS-1:0]   irq_ch;

  clocking monitor_cb @(posedge clk);
    default input #1step;
    input irq;
    input irq_ch;
  endclocking

  modport monitor (clocking monitor_cb, input clk, input rst_n);

endinterface : nx_dma_irq_if
