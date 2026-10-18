// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_concurrency_test.sv
// Description:   Multi-Channel Concurrent Execution Test Suite.
// ============================================================================

`ifndef NX_DMA_CONCURRENCY_TEST_SV
`define NX_DMA_CONCURRENCY_TEST_SV

class nx_dma_concurrency_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_concurrency_test)

  function new(string name = "nx_dma_concurrency_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    nx_dma_concurrency_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "Starting Multi-Channel Concurrency Test Suite...", UVM_NONE)

    // Run concurrency sequence with all 4 channels active simultaneously
    seq = nx_dma_concurrency_seq::type_id::create("seq");
    if (!seq.randomize() with {
      arb_mode == 0; // Round-Robin
    }) `uvm_fatal("TEST", "Randomization failed!")

    seq.start(env.axil_agent.sequencer);

    #200ns;
    `uvm_info("TEST", "Multi-Channel Concurrency Test Suite Completed.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_concurrency_test

`endif // NX_DMA_CONCURRENCY_TEST_SV
