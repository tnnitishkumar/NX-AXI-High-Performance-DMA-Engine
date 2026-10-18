// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_seq_pkg.sv
// Description:   Sequence Package for NX-AXI DMA Engine Verification.
// ============================================================================

`ifndef NX_DMA_SEQ_PKG_SV
`define NX_DMA_SEQ_PKG_SV

package nx_dma_seq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import nx_dma_pkg::*;
  import nx_dma_axil_pkg::*;
  import nx_dma_axi_mem_pkg::*;
  import nx_dma_irq_pkg::*;
  import nx_dma_env_pkg::*;

  `include "nx_dma_base_seq.sv"
  `include "nx_dma_direct_transfer_seq.sv"
  `include "nx_dma_sg_transfer_seq.sv"
  `include "nx_dma_concurrency_seq.sv"
  `include "nx_dma_4kb_crossing_seq.sv"
  `include "nx_dma_error_inject_seq.sv"
  `include "nx_dma_random_stress_seq.sv"

endpackage : nx_dma_seq_pkg

`endif // NX_DMA_SEQ_PKG_SV
