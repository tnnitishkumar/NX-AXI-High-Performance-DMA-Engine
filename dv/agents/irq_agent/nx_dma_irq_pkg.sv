// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_irq_pkg.sv
// Description:   Interrupt Monitor Agent Package.
// ============================================================================

`ifndef NX_DMA_IRQ_PKG_SV
`define NX_DMA_IRQ_PKG_SV

package nx_dma_irq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "nx_dma_irq_seq_item.sv"
  `include "nx_dma_irq_monitor.sv"
  `include "nx_dma_irq_agent.sv"

endpackage : nx_dma_irq_pkg

`endif // NX_DMA_IRQ_PKG_SV
