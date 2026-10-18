// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_data_buffer.sv
// Description:   Synchronous FIFO data buffer between AXI Read Engine and
//                AXI Write Engine with full/empty flags, occupancy tracking,
//                watermarks, and credit/available space calculation.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_data_buffer
  import nx_dma_pkg::*;
#(
  parameter int DEPTH           = FIFO_DEPTH,
  parameter int ALMOST_FULL_TH  = FIFO_ALMOST_FULL_TH,
  parameter int ALMOST_EMPTY_TH = FIFO_ALMOST_EMPTY_TH
)(
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic                      flush,

  // Write / Push Interface (From Read Engine)
  input  logic                      wr_en,
  input  fifo_entry_t               wr_data,
  output logic                      full,
  output logic                      almost_full,
  output logic [FIFO_ADDR_WIDTH:0]  available_space,

  // Read / Pop Interface (To Write Engine)
  input  logic                      rd_en,
  output fifo_entry_t               rd_data,
  output logic                      empty,
  output logic                      almost_empty,
  output logic [FIFO_ADDR_WIDTH:0]  count
);

  localparam int ADDR_W = $clog2(DEPTH);

  // Storage array
  fifo_entry_t mem [DEPTH];

  logic [ADDR_W:0] wr_ptr;
  logic [ADDR_W:0] rd_ptr;
  logic [ADDR_W:0] fifo_cnt;

  assign count           = fifo_cnt;
  assign available_space = DEPTH - fifo_cnt;
  assign full            = (fifo_cnt == DEPTH);
  assign empty           = (fifo_cnt == 0);
  assign almost_full     = (fifo_cnt >= ALMOST_FULL_TH);
  assign almost_empty    = (fifo_cnt <= ALMOST_EMPTY_TH);

  // Read data output (FWFT or standard synchronous read; let's do standard registered read or comb peek)
  assign rd_data = mem[rd_ptr[ADDR_W-1:0]];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr   <= '0;
      rd_ptr   <= '0;
      fifo_cnt <= '0;
    end else if (flush) begin
      wr_ptr   <= '0;
      rd_ptr   <= '0;
      fifo_cnt <= '0;
    end else begin
      // Simultaneous push and pop
      if (wr_en && !full && rd_en && !empty) begin
        mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
        wr_ptr                  <= wr_ptr + 1'b1;
        rd_ptr                  <= rd_ptr + 1'b1;
        fifo_cnt                <= fifo_cnt; // Unchanged
      end
      // Push only
      else if (wr_en && !full) begin
        mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
        wr_ptr                  <= wr_ptr + 1'b1;
        fifo_cnt                <= fifo_cnt + 1'b1;
      end
      // Pop only
      else if (rd_en && !empty) begin
        rd_ptr                  <= rd_ptr + 1'b1;
        fifo_cnt                <= fifo_cnt - 1'b1;
      end
    end
  end

endmodule : nx_dma_data_buffer
