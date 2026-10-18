// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axil_driver.sv
// Description:   AXI4-Lite Master Driver. Drives Register Reads and Writes to DUT.
// ============================================================================

`ifndef NX_DMA_AXIL_DRIVER_SV
`define NX_DMA_AXIL_DRIVER_SV

class nx_dma_axil_driver extends uvm_driver #(nx_dma_axil_seq_item);
  `uvm_component_utils(nx_dma_axil_driver)

  virtual nx_dma_axil_if vif;

  function new(string name = "nx_dma_axil_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual nx_dma_axil_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("AXIL_DRV", "Virtual interface not found in config_db!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(req);
      if (req.is_write) begin
        drive_write(req);
      end else begin
        drive_read(req);
      end
      seq_item_port.item_done();
    end
  endtask

  task reset_signals();
    vif.awaddr  <= '0;
    vif.awprot  <= 3'b000;
    vif.awvalid <= 1'b0;
    vif.wdata   <= '0;
    vif.wstrb   <= 4'b0000;
    vif.wvalid  <= 1'b0;
    vif.bready  <= 1'b0;
    vif.araddr  <= '0;
    vif.arprot  <= 3'b000;
    vif.arvalid <= 1'b0;
    vif.rready  <= 1'b0;
  endtask

  task drive_write(nx_dma_axil_seq_item item);
    // Address delay
    repeat (item.addr_delay) @(posedge vif.clk);

    vif.awaddr  <= item.addr;
    vif.awprot  <= 3'b000;
    vif.awvalid <= 1'b1;
    vif.wdata   <= item.data;
    vif.wstrb   <= item.strb;
    vif.wvalid  <= 1'b1;
    vif.bready  <= 1'b1;

    fork
      begin
        // Wait for AWREADY
        while (!vif.awready) @(posedge vif.clk);
        @(posedge vif.clk);
        vif.awvalid <= 1'b0;
      end
      begin
        // Wait for WREADY
        while (!vif.wready) @(posedge vif.clk);
        @(posedge vif.clk);
        vif.wvalid <= 1'b0;
      end
    join

    // Wait for BVALID
    while (!vif.bvalid) @(posedge vif.clk);
    item.resp = vif.bresp;
    @(posedge vif.clk);
    vif.bready <= 1'b0;
  endtask

  task drive_read(nx_dma_axil_seq_item item);
    // Address delay
    repeat (item.addr_delay) @(posedge vif.clk);

    vif.araddr  <= item.addr;
    vif.arprot  <= 3'b000;
    vif.arvalid <= 1'b1;
    vif.rready  <= 1'b1;

    // Wait for ARREADY
    while (!vif.arready) @(posedge vif.clk);
    @(posedge vif.clk);
    vif.arvalid <= 1'b0;

    // Wait for RVALID
    while (!vif.rvalid) @(posedge vif.clk);
    item.data = vif.rdata;
    item.resp = vif.rresp;
    @(posedge vif.clk);
    vif.rready <= 1'b0;
  endtask

endclass : nx_dma_axil_driver

`endif // NX_DMA_AXIL_DRIVER_SV
