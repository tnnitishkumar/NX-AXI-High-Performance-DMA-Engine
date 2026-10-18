// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_irq_monitor.sv
// Description:   Interrupt Monitor observing IRQ pin events.
// ============================================================================

`ifndef NX_DMA_IRQ_MONITOR_SV
`define NX_DMA_IRQ_MONITOR_SV

class nx_dma_irq_monitor extends uvm_monitor;
  `uvm_component_utils(nx_dma_irq_monitor)

  virtual nx_dma_irq_if vif;
  uvm_analysis_port #(nx_dma_irq_seq_item) ap;

  function new(string name = "nx_dma_irq_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual nx_dma_irq_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("IRQ_MON", "Virtual interface not found in config_db!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    logic       prev_irq    = 1'b0;
    logic [3:0] prev_irq_ch = 4'b0000;

    @(posedge vif.rst_n);

    forever begin
      @(posedge vif.clk);
      if (vif.irq !== prev_irq || vif.irq_ch !== prev_irq_ch) begin
        nx_dma_irq_seq_item item = nx_dma_irq_seq_item::type_id::create("item");
        item.irq       = vif.irq;
        item.irq_ch    = vif.irq_ch;
        item.timestamp = $time;
        ap.write(item);

        prev_irq    = vif.irq;
        prev_irq_ch = vif.irq_ch;
      end
    end
  endtask

endclass : nx_dma_irq_monitor

`endif // NX_DMA_IRQ_MONITOR_SV
