// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_if.sv
// Description:   AXI4 Memory-Mapped Master/Slave Interface (128-bit Data).
// ============================================================================

`timescale 1ns / 1ps

interface nx_dma_axi_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 128,
  parameter int ID_WIDTH   = 4,
  parameter int LEN_WIDTH  = 8,
  parameter int SIZE_WIDTH = 3,
  parameter int STRB_WIDTH = DATA_WIDTH / 8
)(
  input logic clk,
  input logic rst_n
);

  // Write Address Channel
  logic [ID_WIDTH-1:0]   awid;
  logic [ADDR_WIDTH-1:0] awaddr;
  logic [LEN_WIDTH-1:0]  awlen;
  logic [SIZE_WIDTH-1:0] awsize;
  logic [1:0]            awburst;
  logic                  awlock;
  logic [3:0]            awcache;
  logic [2:0]            awprot;
  logic                  awvalid;
  logic                  awready;

  // Write Data Channel
  logic [DATA_WIDTH-1:0] wdata;
  logic [STRB_WIDTH-1:0] wstrb;
  logic                  wlast;
  logic                  wvalid;
  logic                  wready;

  // Write Response Channel
  logic [ID_WIDTH-1:0]   bid;
  logic [1:0]            bresp;
  logic                  bvalid;
  logic                  bready;

  // Read Address Channel
  logic [ID_WIDTH-1:0]   arid;
  logic [ADDR_WIDTH-1:0] araddr;
  logic [LEN_WIDTH-1:0]  arlen;
  logic [SIZE_WIDTH-1:0] arsize;
  logic [1:0]            arburst;
  logic                  arlock;
  logic [3:0]            arcache;
  logic [2:0]            arprot;
  logic                  arvalid;
  logic                  arready;

  // Read Data Channel
  logic [ID_WIDTH-1:0]   rid;
  logic [DATA_WIDTH-1:0] rdata;
  logic [1:0]            rresp;
  logic                  rlast;
  logic                  rvalid;
  logic                  rready;

  // Slave Clocking Block (For Slave Memory Driver)
  clocking slave_cb @(posedge clk);
    default input #1step output #1step;
    input  awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid;
    output awready;
    input  wdata, wstrb, wlast, wvalid;
    output wready;
    output bid, bresp, bvalid;
    input  bready;
    input  arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid;
    output arready;
    output rid, rdata, rresp, rlast, rvalid;
    input  rready;
  endclocking

  // Master Clocking Block
  clocking master_cb @(posedge clk);
    default input #1step output #1step;
    output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid;
    input  awready;
    output wdata, wstrb, wlast, wvalid;
    input  wready;
    input  bid, bresp, bvalid;
    output bready;
    output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid;
    input  arready;
    input  rid, rdata, rresp, rlast, rvalid;
    output rready;
  endclocking

  // Monitor Clocking Block
  clocking monitor_cb @(posedge clk);
    default input #1step;
    input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid, awready;
    input wdata, wstrb, wlast, wvalid, wready;
    input bid, bresp, bvalid, bready;
    input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid, arready;
    input rid, rdata, rresp, rlast, rvalid, rready;
  endclocking

  // Modports
  modport slave (clocking slave_cb, input clk, input rst_n);
  modport master (clocking master_cb, input clk, input rst_n);
  modport monitor (clocking monitor_cb, input clk, input rst_n);

endinterface : nx_dma_axi_if
