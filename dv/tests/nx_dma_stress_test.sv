// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_stress_test.sv
// Description:   Randomized Multi-Channel Stress Test Suite.
// ============================================================================

`ifndef NX_DMA_STRESS_TEST_SV
`define NX_DMA_STRESS_TEST_SV

class nx_dma_stress_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_stress_test)

  function new(string name = "nx_dma_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    nx_dma_random_stress_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "Starting Randomized Multi-Channel Stress Test Suite...", UVM_NONE)

    seq = nx_dma_random_stress_seq::type_id::create("seq");
    if (!seq.randomize()) `uvm_fatal("TEST", "Randomization failed!")
    seq.num_iterations = 32;

    seq.start(env.axil_agent.sequencer);

    #500ns;
    `uvm_info("TEST", "Randomized Multi-Channel Stress Test Suite Completed.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_stress_test

`endif // NX_DMA_STRESS_TEST_SV
