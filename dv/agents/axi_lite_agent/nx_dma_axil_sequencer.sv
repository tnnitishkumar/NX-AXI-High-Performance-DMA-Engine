// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axil_sequencer.sv
// Description:   AXI4-Lite Sequencer for DMA Register Transactions.
// ============================================================================

`ifndef NX_DMA_AXIL_SEQUENCER_SV
`define NX_DMA_AXIL_SEQUENCER_SV

class nx_dma_axil_sequencer extends uvm_sequencer #(nx_dma_axil_seq_item);
  `uvm_component_utils(nx_dma_axil_sequencer)

  function new(string name = "nx_dma_axil_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass : nx_dma_axil_sequencer

`endif // NX_DMA_AXIL_SEQUENCER_SV
