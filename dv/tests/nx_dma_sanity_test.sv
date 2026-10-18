// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_sanity_test.sv
// Description:   Sanity Test verifying register read/write and basic 64-byte transfer.
// ============================================================================

`ifndef NX_DMA_SANITY_TEST_SV
`define NX_DMA_SANITY_TEST_SV

class nx_dma_sanity_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_sanity_test)

  function new(string name = "nx_dma_sanity_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    nx_dma_direct_transfer_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "========================================", UVM_NONE)
    `uvm_info("TEST", "    STARTING NX-AXI DMA SANITY TEST     ", UVM_NONE)
    `uvm_info("TEST", "========================================", UVM_NONE)

    seq = nx_dma_direct_transfer_seq::type_id::create("seq");
    if (!seq.randomize() with {
      channel_id   == 0;
      src_addr     == 32'h0001_0000;
      dst_addr     == 32'h0008_0000;
      length_bytes == 64;
      burst_cfg    == 4; // 16 beats
      arb_mode     == 0;
    }) `uvm_fatal("TEST", "Randomization failed!")

    seq.start(env.axil_agent.sequencer);

    #200ns;
    `uvm_info("TEST", "NX-AXI DMA Sanity Test Completed Successfully!", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_sanity_test

`endif // NX_DMA_SANITY_TEST_SV
