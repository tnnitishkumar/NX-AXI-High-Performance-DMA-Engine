// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axil_pkg.sv
// Description:   AXI4-Lite UVM Agent Package.
// ============================================================================

`ifndef NX_DMA_AXIL_PKG_SV
`define NX_DMA_AXIL_PKG_SV

package nx_dma_axil_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "nx_dma_axil_seq_item.sv"
  `include "nx_dma_axil_driver.sv"
  `include "nx_dma_axil_monitor.sv"
  `include "nx_dma_axil_sequencer.sv"
  `include "nx_dma_axil_agent.sv"

endpackage : nx_dma_axil_pkg

`endif // NX_DMA_AXIL_PKG_SV
