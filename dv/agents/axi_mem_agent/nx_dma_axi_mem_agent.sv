// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_mem_agent.sv
// Description:   AXI4 Reactive Slave Memory UVM Agent. Encapsulates driver,
//                monitor, and sequencer for AXI Master verification.
// ============================================================================

`ifndef NX_DMA_AXI_MEM_AGENT_SV
`define NX_DMA_AXI_MEM_AGENT_SV

class nx_dma_axi_mem_agent extends uvm_agent;
  `uvm_component_utils(nx_dma_axi_mem_agent)

  nx_dma_axi_mem_driver    driver;
  nx_dma_axi_mem_monitor   monitor;
  nx_dma_axi_mem_sequencer sequencer;

  uvm_analysis_port #(nx_dma_axi_seq_item) ap;

  function new(string name = "nx_dma_axi_mem_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = nx_dma_axi_mem_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      driver    = nx_dma_axi_mem_driver::type_id::create("driver", this);
      sequencer = nx_dma_axi_mem_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ap = monitor.ap;
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass : nx_dma_axi_mem_agent

`endif // NX_DMA_AXI_MEM_AGENT_SV
