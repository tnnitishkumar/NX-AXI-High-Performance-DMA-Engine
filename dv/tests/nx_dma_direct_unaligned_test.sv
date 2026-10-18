// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_direct_unaligned_test.sv
// Description:   Direct Unaligned Transfers Test with fractional offsets and odd lengths.
// ============================================================================

`ifndef NX_DMA_DIRECT_UNALIGNED_TEST_SV
`define NX_DMA_DIRECT_UNALIGNED_TEST_SV

class nx_dma_direct_unaligned_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_direct_unaligned_test)

  function new(string name = "nx_dma_direct_unaligned_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    int test_offsets[] = '{1, 2, 3, 5, 7, 9, 11, 13, 15};
    int test_lengths[] = '{1, 3, 7, 15, 17, 33, 99, 255, 513};
    nx_dma_direct_transfer_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "Starting Direct Unaligned Transfers Test Suite...", UVM_NONE)

    foreach (test_offsets[i]) begin
      int ch = i % 4;
      seq = nx_dma_direct_transfer_seq::type_id::create("seq");
      if (!seq.randomize() with {
        channel_id   == ch;
        src_addr     == (32'h0001_0000 + i*32'h0000_1000 + test_offsets[i]);
        dst_addr     == (32'h0008_0000 + i*32'h0000_1000 + test_offsets[i]);
        length_bytes == test_lengths[i];
        burst_cfg    == 4;
      }) `uvm_fatal("TEST", "Randomization failed!")

      seq.start(env.axil_agent.sequencer);
    end

    #200ns;
    `uvm_info("TEST", "Direct Unaligned Transfers Test Suite Completed.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_direct_unaligned_test

`endif // NX_DMA_DIRECT_UNALIGNED_TEST_SV
