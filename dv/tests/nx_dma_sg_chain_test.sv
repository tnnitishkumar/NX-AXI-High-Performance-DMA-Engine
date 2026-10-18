// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_sg_chain_test.sv
// Description:   Scatter-Gather Descriptor Chain Test (Linear, Multi-Channel).
// ============================================================================

`ifndef NX_DMA_SG_CHAIN_TEST_SV
`define NX_DMA_SG_CHAIN_TEST_SV

class nx_dma_sg_chain_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_sg_chain_test)

  function new(string name = "nx_dma_sg_chain_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    nx_dma_sg_transfer_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "Starting Scatter-Gather Chain Test Suite...", UVM_NONE)

    // Test SG chains of varying lengths across all 4 channels
    for (int ch = 0; ch < 4; ch++) begin
      int num_nodes = (ch + 1) * 2; // 2, 4, 6, 8 descriptors
      `uvm_info("TEST", $sformatf("Running SG Chain on Channel %0d with %0d descriptors", ch, num_nodes), UVM_MEDIUM)

      seq = nx_dma_sg_transfer_seq::type_id::create("seq");
      if (!seq.randomize() with {
        channel_id      == ch;
        num_descriptors == num_nodes;
        head_desc_addr  == (32'h0000_2000 + ch * 32'h0000_1000);
      }) `uvm_fatal("TEST", "Randomization failed!")

      seq.start(env.axil_agent.sequencer);
    end

    #200ns;
    `uvm_info("TEST", "Scatter-Gather Chain Test Suite Completed.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_sg_chain_test

`endif // NX_DMA_SG_CHAIN_TEST_SV
