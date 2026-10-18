// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_regression_test.sv
// Description:   Comprehensive Full-Feature Regression Test Suite.
// ============================================================================

`ifndef NX_DMA_REGRESSION_TEST_SV
`define NX_DMA_REGRESSION_TEST_SV

class nx_dma_regression_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_regression_test)

  function new(string name = "nx_dma_regression_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    nx_dma_direct_transfer_seq direct_seq;
    nx_dma_sg_transfer_seq     sg_seq;
    nx_dma_4kb_crossing_seq    cross_seq;
    nx_dma_concurrency_seq     conc_seq;
    nx_dma_error_inject_seq    err_seq;
    nx_dma_random_stress_seq   stress_seq;

    super.run_phase(phase);
    phase.raise_objection(this);

    `uvm_info("REGRESSION", "==================================================", UVM_NONE)
    `uvm_info("REGRESSION", "   STARTING NX-AXI DMA FULL REGRESSION SUITE      ", UVM_NONE)
    `uvm_info("REGRESSION", "==================================================", UVM_NONE)

    // Phase 1: Aligned Direct Transfers
    `uvm_info("REGRESSION", "Phase 1: Running Aligned Direct Transfers...", UVM_NONE)
    for (int ch = 0; ch < 4; ch++) begin
      direct_seq = nx_dma_direct_transfer_seq::type_id::create("direct_seq");
      if (!direct_seq.randomize() with {
        channel_id   == ch;
        src_addr     == (32'h0001_0000 + ch*32'h0000_1000);
        dst_addr     == (32'h0008_0000 + ch*32'h0000_1000);
        length_bytes == (128 * (ch + 1));
        burst_cfg    == 4;
      }) `uvm_fatal("REGRESSION", "Randomization failed!")
      direct_seq.start(env.axil_agent.sequencer);
    end

    // Phase 2: Unaligned Direct Transfers
    `uvm_info("REGRESSION", "Phase 2: Running Unaligned Direct Transfers...", UVM_NONE)
    for (int ch = 0; ch < 4; ch++) begin
      direct_seq = nx_dma_direct_transfer_seq::type_id::create("direct_seq");
      if (!direct_seq.randomize() with {
        channel_id   == ch;
        src_addr     == (32'h0002_0003 + ch*32'h0000_1000);
        dst_addr     == (32'h0009_0007 + ch*32'h0000_1000);
        length_bytes == (127 * (ch + 1));
        burst_cfg    == 4;
      }) `uvm_fatal("REGRESSION", "Randomization failed!")
      direct_seq.start(env.axil_agent.sequencer);
    end

    // Phase 3: 4KB Boundary Crossing Transfers
    `uvm_info("REGRESSION", "Phase 3: Running 4KB Boundary Crossing Transfers...", UVM_NONE)
    for (int ch = 0; ch < 4; ch++) begin
      cross_seq = nx_dma_4kb_crossing_seq::type_id::create("cross_seq");
      if (!cross_seq.randomize() with {
        channel_id == ch;
      }) `uvm_fatal("REGRESSION", "Randomization failed!")
      cross_seq.start(env.axil_agent.sequencer);
    end

    // Phase 4: Scatter-Gather Descriptor Chains
    `uvm_info("REGRESSION", "Phase 4: Running Scatter-Gather Chains...", UVM_NONE)
    for (int ch = 0; ch < 4; ch++) begin
      sg_seq = nx_dma_sg_transfer_seq::type_id::create("sg_seq");
      if (!sg_seq.randomize() with {
        channel_id    == ch;
        num_descriptors == (ch + 2);
        head_desc_addr  == (32'h0000_4000 + ch*32'h0000_1000);
      }) `uvm_fatal("REGRESSION", "Randomization failed!")
      sg_seq.start(env.axil_agent.sequencer);
    end

    // Phase 5: Multi-Channel Concurrency & Arbitration
    `uvm_info("REGRESSION", "Phase 5: Running Multi-Channel Concurrency...", UVM_NONE)
    conc_seq = nx_dma_concurrency_seq::type_id::create("conc_seq");
    if (!conc_seq.randomize() with {
      arb_mode == 0;
    }) `uvm_fatal("REGRESSION", "Randomization failed!")
    conc_seq.start(env.axil_agent.sequencer);

    // Phase 6: Error Injection & Recovery
    `uvm_info("REGRESSION", "Phase 6: Running Error Injection and Recovery...", UVM_NONE)
    for (int ch = 0; ch < 4; ch++) begin
      err_seq = nx_dma_error_inject_seq::type_id::create("err_seq");
      if (!err_seq.randomize() with {
        error_type == ch;
      }) `uvm_fatal("REGRESSION", "Randomization failed!")
      err_seq.start(env.axil_agent.sequencer);
    end

    // Phase 7: Randomized Multi-Channel Stress
    `uvm_info("REGRESSION", "Phase 7: Running Randomized Multi-Channel Stress...", UVM_NONE)
    stress_seq = nx_dma_random_stress_seq::type_id::create("stress_seq");
    if (!stress_seq.randomize()) `uvm_fatal("REGRESSION", "Randomization failed!")
    stress_seq.num_iterations = 16;
    stress_seq.start(env.axil_agent.sequencer);

    #500ns;
    `uvm_info("REGRESSION", "==================================================", UVM_NONE)
    `uvm_info("REGRESSION", "   NX-AXI DMA FULL REGRESSION SUITE COMPLETED!    ", UVM_NONE)
    `uvm_info("REGRESSION", "==================================================", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_regression_test

`endif // NX_DMA_REGRESSION_TEST_SV
