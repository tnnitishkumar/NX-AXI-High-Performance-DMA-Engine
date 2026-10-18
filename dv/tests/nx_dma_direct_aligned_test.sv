// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_direct_aligned_test.sv
// Description:   Direct Aligned Transfers Test across all 4 channels with various lengths.
// ============================================================================

`ifndef NX_DMA_DIRECT_ALIGNED_TEST_SV
`define NX_DMA_DIRECT_ALIGNED_TEST_SV

class nx_dma_direct_aligned_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_direct_aligned_test)

  function new(string name = "nx_dma_direct_aligned_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    int test_lengths[] = '{16, 32, 64, 128, 256, 512, 1024, 2048, 4096};
    nx_dma_direct_transfer_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "Starting Direct Aligned Transfers Test Suite...", UVM_NONE)

    foreach (test_lengths[i]) begin
      int ch = i % 4;
      seq = nx_dma_direct_transfer_seq::type_id::create("seq");
      if (!seq.randomize() with {
        channel_id   == ch;
        src_addr     == (32'h0001_0000 + i*32'h0000_1000);
        dst_addr     == (32'h0008_0000 + i*32'h0000_1000);
        length_bytes == test_lengths[i];
        burst_cfg    == 4;
      }) `uvm_fatal("TEST", "Randomization failed!")

      seq.start(env.axil_agent.sequencer);
    end

    #200ns;
    `uvm_info("TEST", "Direct Aligned Transfers Test Suite Completed.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_direct_aligned_test

`endif // NX_DMA_DIRECT_ALIGNED_TEST_SV
