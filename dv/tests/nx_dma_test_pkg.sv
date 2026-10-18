// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_test_pkg.sv
// Description:   UVM Test Package containing all test suites.
// ============================================================================

`ifndef NX_DMA_TEST_PKG_SV
`define NX_DMA_TEST_PKG_SV

package nx_dma_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import nx_dma_pkg::*;
  import nx_dma_axil_pkg::*;
  import nx_dma_axi_mem_pkg::*;
  import nx_dma_irq_pkg::*;
  import nx_dma_env_pkg::*;
  import nx_dma_seq_pkg::*;

  `include "nx_dma_base_test.sv"
  `include "nx_dma_sanity_test.sv"
  `include "nx_dma_direct_aligned_test.sv"
  `include "nx_dma_direct_unaligned_test.sv"
  `include "nx_dma_burst_size_test.sv"
  `include "nx_dma_4kb_crossing_test.sv"
  `include "nx_dma_sg_chain_test.sv"
  `include "nx_dma_concurrency_test.sv"
  `include "nx_dma_arbitration_test.sv"
  `include "nx_dma_error_response_test.sv"
  `include "nx_dma_stress_test.sv"
  `include "nx_dma_regression_test.sv"

endpackage : nx_dma_test_pkg

`endif // NX_DMA_TEST_PKG_SV
