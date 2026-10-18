// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_base_test.sv
// Description:   Base Test for NX-AXI DMA Engine Verification Suite.
//                Instantiates the environment, configures simulation topology,
//                sets report verbosity, and controls objection management.
// ============================================================================

`ifndef NX_DMA_BASE_TEST_SV
`define NX_DMA_BASE_TEST_SV

class nx_dma_base_test extends uvm_test;
  `uvm_component_utils(nx_dma_base_test)

  nx_dma_env env;

  function new(string name = "nx_dma_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = nx_dma_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    phase.phase_done.set_drain_time(this, 100ns);
  endtask

endclass : nx_dma_base_test

`endif // NX_DMA_BASE_TEST_SV
