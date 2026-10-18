// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_irq_agent.sv
// Description:   Interrupt Monitor UVM Agent (Passive).
// ============================================================================

`ifndef NX_DMA_IRQ_AGENT_SV
`define NX_DMA_IRQ_AGENT_SV

class nx_dma_irq_agent extends uvm_agent;
  `uvm_component_utils(nx_dma_irq_agent)

  nx_dma_irq_monitor monitor;
  uvm_analysis_port #(nx_dma_irq_seq_item) ap;

  function new(string name = "nx_dma_irq_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = nx_dma_irq_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ap = monitor.ap;
  endfunction

endclass : nx_dma_irq_agent

`endif // NX_DMA_IRQ_AGENT_SV
