// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_arbitration_test.sv
// Description:   Scheduler Arbitration Test (Round-Robin vs Fixed-Priority).
// ============================================================================

`ifndef NX_DMA_ARBITRATION_TEST_SV
`define NX_DMA_ARBITRATION_TEST_SV

class nx_dma_arbitration_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_arbitration_test)

  function new(string name = "nx_dma_arbitration_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    nx_dma_concurrency_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "Starting Scheduler Arbitration Test Suite...", UVM_NONE)

    // 1. Test Round-Robin Mode
    `uvm_info("TEST", "Phase 1: Testing Round-Robin Arbitration...", UVM_MEDIUM)
    seq = nx_dma_concurrency_seq::type_id::create("seq_rr");
    if (!seq.randomize() with {
      arb_mode == 0; // Round Robin
    }) `uvm_fatal("TEST", "Randomization failed!")
    seq.start(env.axil_agent.sequencer);

    #100ns;

    // 2. Test Fixed-Priority Mode
    `uvm_info("TEST", "Phase 2: Testing Fixed-Priority Arbitration...", UVM_MEDIUM)
    seq = nx_dma_concurrency_seq::type_id::create("seq_prio");
    if (!seq.randomize() with {
      arb_mode == 1; // Fixed Priority (CH0 highest)
    }) `uvm_fatal("TEST", "Randomization failed!")
    seq.start(env.axil_agent.sequencer);

    #200ns;
    `uvm_info("TEST", "Scheduler Arbitration Test Suite Completed.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_arbitration_test

`endif // NX_DMA_ARBITRATION_TEST_SV
