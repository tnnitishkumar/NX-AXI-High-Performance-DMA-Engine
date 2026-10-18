// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_tb_top.sv
// Description:   Top-Level Testbench Module for UVM Verification.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import nx_dma_pkg::*;
  import nx_dma_axil_pkg::*;
  import nx_dma_axi_mem_pkg::*;
  import nx_dma_irq_pkg::*;
  import nx_dma_env_pkg::*;
  import nx_dma_seq_pkg::*;
  import nx_dma_test_pkg::*;

  // --------------------------------------------------------------------------
  // Clock and Reset Signals
  // --------------------------------------------------------------------------
  logic clk;
  logic rst_n;

  // 100 MHz System Clock Generation (10ns Period)
  initial begin
    clk = 1'b0;
    forever #5ns clk = ~clk;
  end

  // Synchronous Reset Generation
  initial begin
    rst_n = 1'b0;
    #50ns;
    @(posedge clk);
    rst_n = 1'b1;
  end

  // --------------------------------------------------------------------------
  // Interface Instantiations
  // --------------------------------------------------------------------------
  nx_dma_axil_if axil_if (.clk(clk), .rst_n(rst_n));
  nx_dma_axi_if  axi_if  (.clk(clk), .rst_n(rst_n));
  nx_dma_irq_if  irq_if  (.clk(clk), .rst_n(rst_n));

  // --------------------------------------------------------------------------
  // DUT (Device Under Test) Instantiation
  // --------------------------------------------------------------------------
  nx_dma_top u_dut (
    .clk             (clk),
    .rst_n           (rst_n),

    // AXI4-Lite Slave Interface
    .s_axil_awaddr   (axil_if.awaddr),
    .s_axil_awprot   (axil_if.awprot),
    .s_axil_awvalid  (axil_if.awvalid),
    .s_axil_awready  (axil_if.awready),

    .s_axil_wdata    (axil_if.wdata),
    .s_axil_wstrb    (axil_if.wstrb),
    .s_axil_wvalid   (axil_if.wvalid),
    .s_axil_wready   (axil_if.wready),

    .s_axil_bresp    (axil_if.bresp),
    .s_axil_bvalid   (axil_if.bvalid),
    .s_axil_bready   (axil_if.bready),

    .s_axil_araddr   (axil_if.araddr),
    .s_axil_arprot   (axil_if.arprot),
    .s_axil_arvalid  (axil_if.arvalid),
    .s_axil_arready  (axil_if.arready),

    .s_axil_rdata    (axil_if.rdata),
    .s_axil_rresp    (axil_if.rresp),
    .s_axil_rvalid   (axil_if.rvalid),
    .s_axil_rready   (axil_if.rready),

    // AXI4 Master Interface
    .m_axi_awid      (axi_if.awid),
    .m_axi_awaddr    (axi_if.awaddr),
    .m_axi_awlen     (axi_if.awlen),
    .m_axi_awsize    (axi_if.awsize),
    .m_axi_awburst   (axi_if.awburst),
    .m_axi_awlock    (axi_if.awlock),
    .m_axi_awcache   (axi_if.awcache),
    .m_axi_awprot    (axi_if.awprot),
    .m_axi_awvalid   (axi_if.awvalid),
    .m_axi_awready   (axi_if.awready),

    .m_axi_wdata     (axi_if.wdata),
    .m_axi_wstrb     (axi_if.wstrb),
    .m_axi_wlast     (axi_if.wlast),
    .m_axi_wvalid    (axi_if.wvalid),
    .m_axi_wready    (axi_if.wready),

    .m_axi_bid       (axi_if.bid),
    .m_axi_bresp     (axi_if.bresp),
    .m_axi_bvalid    (axi_if.bvalid),
    .m_axi_bready    (axi_if.bready),

    .m_axi_arid      (axi_if.arid),
    .m_axi_araddr    (axi_if.araddr),
    .m_axi_arlen     (axi_if.arlen),
    .m_axi_arsize    (axi_if.arsize),
    .m_axi_arburst   (axi_if.arburst),
    .m_axi_arlock    (axi_if.arlock),
    .m_axi_arcache   (axi_if.arcache),
    .m_axi_arprot    (axi_if.arprot),
    .m_axi_arvalid   (axi_if.arvalid),
    .m_axi_arready   (axi_if.arready),

    .m_axi_rid       (axi_if.rid),
    .m_axi_rdata     (axi_if.rdata),
    .m_axi_rresp     (axi_if.rresp),
    .m_axi_rlast     (axi_if.rlast),
    .m_axi_rvalid    (axi_if.rvalid),
    .m_axi_rready    (axi_if.rready),

    // Interrupts
    .irq             (irq_if.irq),
    .irq_ch          (irq_if.irq_ch)
  );

  // --------------------------------------------------------------------------
  // SystemVerilog Assertions (SVA) Module Instantiation
  // --------------------------------------------------------------------------
  nx_dma_sva u_sva (
    .clk             (clk),
    .rst_n           (rst_n),
    .m_axi_awid      (axi_if.awid),
    .m_axi_awaddr    (axi_if.awaddr),
    .m_axi_awlen     (axi_if.awlen),
    .m_axi_awsize    (axi_if.awsize),
    .m_axi_awburst   (axi_if.awburst),
    .m_axi_awvalid   (axi_if.awvalid),
    .m_axi_awready   (axi_if.awready),
    .m_axi_wdata     (axi_if.wdata),
    .m_axi_wstrb     (axi_if.wstrb),
    .m_axi_wlast     (axi_if.wlast),
    .m_axi_wvalid    (axi_if.wvalid),
    .m_axi_wready    (axi_if.wready),
    .m_axi_bid       (axi_if.bid),
    .m_axi_bresp     (axi_if.bresp),
    .m_axi_bvalid    (axi_if.bvalid),
    .m_axi_bready    (axi_if.bready),
    .m_axi_arid      (axi_if.arid),
    .m_axi_araddr    (axi_if.araddr),
    .m_axi_arlen     (axi_if.arlen),
    .m_axi_arsize    (axi_if.arsize),
    .m_axi_arburst   (axi_if.arburst),
    .m_axi_arvalid   (axi_if.arvalid),
    .m_axi_arready   (axi_if.arready),
    .m_axi_rid       (axi_if.rid),
    .m_axi_rdata     (axi_if.rdata),
    .m_axi_rresp     (axi_if.rresp),
    .m_axi_rlast     (axi_if.rlast),
    .m_axi_rvalid    (axi_if.rvalid),
    .m_axi_rready    (axi_if.rready),
    .irq             (irq_if.irq),
    .irq_ch          (irq_if.irq_ch)
  );

  // --------------------------------------------------------------------------
  // UVM Test Configuration & Execution
  // --------------------------------------------------------------------------
  initial begin
    // Register interfaces into UVM Configuration Database
    uvm_config_db#(virtual nx_dma_axil_if)::set(null, "*axil_agent*", "vif", axil_if);
    uvm_config_db#(virtual nx_dma_axi_if)::set(null, "*axi_mem_agent*", "vif", axi_if);
    uvm_config_db#(virtual nx_dma_irq_if)::set(null, "*irq_agent*", "vif", irq_if);

    // Also register at global level for any other monitors/checkers
    uvm_config_db#(virtual nx_dma_axil_if)::set(null, "*", "axil_vif", axil_if);
    uvm_config_db#(virtual nx_dma_axi_if)::set(null, "*", "axi_vif", axi_if);
    uvm_config_db#(virtual nx_dma_irq_if)::set(null, "*", "irq_vif", irq_if);

    // Waveform Dumping (optional, enabled via +DUMP)
    if ($test$plusargs("DUMP")) begin
      $dumpfile("sim/nx_dma_sim.vcd");
      $dumpvars(0, nx_dma_tb_top);
    end

    // Start UVM Phase Execution
    run_test();
  end

endmodule : nx_dma_tb_top
