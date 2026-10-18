// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_mem_sequencer.sv
// Description:   AXI4 Memory Agent Sequencer.
// ============================================================================

`ifndef NX_DMA_AXI_MEM_SEQUENCER_SV
`define NX_DMA_AXI_MEM_SEQUENCER_SV

class nx_dma_axi_mem_sequencer extends uvm_sequencer #(nx_dma_axi_seq_item);
  `uvm_component_utils(nx_dma_axi_mem_sequencer)

  function new(string name = "nx_dma_axi_mem_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass : nx_dma_axi_mem_sequencer

`endif // NX_DMA_AXI_MEM_SEQUENCER_SV
