// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axil_monitor.sv
// Description:   AXI4-Lite Monitor. Observes Read and Write Transactions on AXI-Lite.
// ============================================================================

`ifndef NX_DMA_AXIL_MONITOR_SV
`define NX_DMA_AXIL_MONITOR_SV

class nx_dma_axil_monitor extends uvm_monitor;
  `uvm_component_utils(nx_dma_axil_monitor)

  virtual nx_dma_axil_if vif;
  uvm_analysis_port #(nx_dma_axil_seq_item) ap;

  function new(string name = "nx_dma_axil_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual nx_dma_axil_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("AXIL_MON", "Virtual interface not found in config_db!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    @(posedge vif.rst_n);
    fork
      monitor_writes();
      monitor_reads();
    join
  endtask

  task monitor_writes();
    logic [31:0] wr_addr;
    logic [31:0] wr_data;
    logic [3:0]  wr_strb;

    forever begin
      @(posedge vif.clk);
      if (vif.awvalid && vif.awready) begin
        wr_addr = vif.awaddr;
      end
      if (vif.wvalid && vif.wready) begin
        wr_data = vif.wdata;
        wr_strb = vif.wstrb;
      end
      if (vif.bvalid && vif.bready) begin
        nx_dma_axil_seq_item item = nx_dma_axil_seq_item::type_id::create("item");
        item.is_write = 1'b1;
        item.addr     = wr_addr;
        item.data     = wr_data;
        item.strb     = wr_strb;
        item.resp     = vif.bresp;
        ap.write(item);
      end
    end
  endtask

  task monitor_reads();
    logic [31:0] rd_addr;

    forever begin
      @(posedge vif.clk);
      if (vif.arvalid && vif.arready) begin
        rd_addr = vif.araddr;
      end
      if (vif.rvalid && vif.rready) begin
        nx_dma_axil_seq_item item = nx_dma_axil_seq_item::type_id::create("item");
        item.is_write = 1'b0;
        item.addr     = rd_addr;
        item.data     = vif.rdata;
        item.resp     = vif.rresp;
        ap.write(item);
      end
    end
  endtask

endclass : nx_dma_axil_monitor

`endif // NX_DMA_AXIL_MONITOR_SV
