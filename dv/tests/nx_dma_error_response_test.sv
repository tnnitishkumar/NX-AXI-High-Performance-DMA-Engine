// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_error_response_test.sv
// Description:   Error Handling & Protocol Error Response Test Suite.
// ============================================================================

`ifndef NX_DMA_ERROR_RESPONSE_TEST_SV
`define NX_DMA_ERROR_RESPONSE_TEST_SV

class nx_dma_error_response_test extends nx_dma_base_test;
  `uvm_component_utils(nx_dma_error_response_test)

  function new(string name = "nx_dma_error_response_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    nx_dma_error_inject_seq seq;
    super.run_phase(phase);

    phase.raise_objection(this);
    `uvm_info("TEST", "Starting Error Response & Exception Handling Test Suite...", UVM_NONE)

    // Test across all 4 channels with various error types
    for (int ch = 0; ch < 4; ch++) begin
      seq = nx_dma_error_inject_seq::type_id::create("seq");
      if (!seq.randomize() with {
        error_type == ch; // 0=RD_SLVERR, 1=WR_SLVERR, 2=RD_DECERR, 3=WR_DECERR
      }) `uvm_fatal("TEST", "Randomization failed!")

      seq.start(env.axil_agent.sequencer);
    end

    #200ns;
    `uvm_info("TEST", "Error Response & Exception Handling Test Suite Completed.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : nx_dma_error_response_test

`endif // NX_DMA_ERROR_RESPONSE_TEST_SV
