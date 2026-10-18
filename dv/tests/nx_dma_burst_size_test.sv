// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_burst_size_test.sv
// Description:   Burst Size Configuration Test (1, 2, 4, 8, 16 beats).
// ============================================================================

`ifndef NX_DMA_BURST_SIZE_TEST_SV
`define NX_DMA_BURST_SIZE_TEST_SV

class nx_dma_burst_size_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_burst_size_test)

  function new(string name = "nx_dma_burst_size_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    int burst_configs[] = '{0, 1, 2, 3, 4}; // 1, 2, 4, 8, 16 beats
    nx_dma_direct_transfer_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "Starting Burst Size Configuration Test Suite...", UVM_NONE)

    foreach (burst_configs[i]) begin
      seq = nx_dma_direct_transfer_seq::type_id::create("seq");
      if (!seq.randomize() with {
        channel_id   == (i % 4);
        src_addr     == (32'h0001_0000 + i*32'h0000_1000);
        dst_addr     == (32'h0008_0000 + i*32'h0000_1000);
        length_bytes == 512;
        burst_cfg    == burst_configs[i];
      }) `uvm_fatal("TEST", "Randomization failed!")

      seq.start(env.axil_agent.sequencer);
    end

    #200ns;
    `uvm_info("TEST", "Burst Size Configuration Test Suite Completed.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_burst_size_test

`endif // NX_DMA_BURST_SIZE_TEST_SV
