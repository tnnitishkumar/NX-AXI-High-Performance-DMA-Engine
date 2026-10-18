// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_4kb_crossing_test.sv
// Description:   4KB Page Boundary Crossing Test Suite.
// ============================================================================

`ifndef NX_DMA_4KB_CROSSING_TEST_SV
`define NX_DMA_4KB_CROSSING_TEST_SV

class nx_dma_4kb_crossing_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_4kb_crossing_test)

  function new(string name = "nx_dma_4kb_crossing_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    nx_dma_4kb_crossing_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "Starting 4KB Boundary Crossing Test Suite...", UVM_NONE)

    for (int i = 0; i < 8; i++) begin
      seq = nx_dma_4kb_crossing_seq::type_id::create("seq");
      if (!seq.randomize() with {
        channel_id == (i % 4);
      }) `uvm_fatal("TEST", "Randomization failed!")

      seq.start(env.axil_agent.sequencer);
    end

    #200ns;
    `uvm_info("TEST", "4KB Boundary Crossing Test Suite Completed.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_4kb_crossing_test

`endif // NX_DMA_4KB_CROSSING_TEST_SV
