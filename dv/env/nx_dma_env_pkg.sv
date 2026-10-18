// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_env_pkg.sv
// Description:   Top-Level Environment Package for NX-AXI DMA Engine.
// ============================================================================

`ifndef NX_DMA_ENV_PKG_SV
`define NX_DMA_ENV_PKG_SV

package nx_dma_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import nx_dma_pkg::*;
  import nx_dma_axil_pkg::*;
  import nx_dma_axi_mem_pkg::*;
  import nx_dma_irq_pkg::*;

  `include "nx_dma_ref_model.sv"
  `include "nx_dma_scoreboard.sv"
  `include "nx_dma_coverage.sv"
  `include "nx_dma_env.sv"

endpackage : nx_dma_env_pkg

`endif // NX_DMA_ENV_PKG_SV
