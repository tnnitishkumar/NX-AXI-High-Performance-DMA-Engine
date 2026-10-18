// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_mem_pkg.sv
// Description:   AXI4 Memory Slave Agent Package.
// ============================================================================

`ifndef NX_DMA_AXI_MEM_PKG_SV
`define NX_DMA_AXI_MEM_PKG_SV

package nx_dma_axi_mem_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "nx_dma_memory_model.sv"
  `include "nx_dma_axi_seq_item.sv"
  `include "nx_dma_axi_mem_driver.sv"
  `include "nx_dma_axi_mem_monitor.sv"
  `include "nx_dma_axi_mem_sequencer.sv"
  `include "nx_dma_axi_mem_agent.sv"

endpackage : nx_dma_axi_mem_pkg

`endif // NX_DMA_AXI_MEM_PKG_SV
