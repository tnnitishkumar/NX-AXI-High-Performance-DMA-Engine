// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axil_if.sv
// Description:   AXI4-Lite Interface for DMA Register Configuration and Status.
// ============================================================================

`timescale 1ns / 1ps

interface nx_dma_axil_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int STRB_WIDTH = DATA_WIDTH / 8
)(
  input logic clk,
  input logic rst_n
);

  // Write Address Channel
  logic [ADDR_WIDTH-1:0] awaddr;
  logic [2:0]            awprot;
  logic                  awvalid;
  logic                  awready;

  // Write Data Channel
  logic [DATA_WIDTH-1:0] wdata;
  logic [STRB_WIDTH-1:0] wstrb;
  logic                  wvalid;
  logic                  wready;

  // Write Response Channel
  logic [1:0]            bresp;
  logic                  bvalid;
  logic                  bready;

  // Read Address Channel
  logic [ADDR_WIDTH-1:0] araddr;
  logic [2:0]            arprot;
  logic                  arvalid;
  logic                  arready;

  // Read Data Channel
  logic [DATA_WIDTH-1:0] rdata;
  logic [1:0]            rresp;
  logic                  rvalid;
  logic                  rready;

  // Master Clocking Block
  clocking master_cb @(posedge clk);
    default input #1step output #1step;
    output awaddr, awprot, awvalid;
    input  awready;
    output wdata, wstrb, wvalid;
    input  wready;
    input  bresp, bvalid;
    output bready;
    output araddr, arprot, arvalid;
    input  arready;
    input  rdata, rresp, rvalid;
    output rready;
  endclocking

  // Monitor Clocking Block
  clocking monitor_cb @(posedge clk);
    default input #1step;
    input awaddr, awprot, awvalid, awready;
    input wdata, wstrb, wvalid, wready;
    input bresp, bvalid, bready;
    input araddr, arprot, arvalid, arready;
    input rdata, rresp, rvalid, rready;
  endclocking

  // Modports
  modport master (clocking master_cb, input clk, input rst_n);
  modport monitor (clocking monitor_cb, input clk, input rst_n);
  modport slave (
    input  awaddr, awprot, awvalid,
    output awready,
    input  wdata, wstrb, wvalid,
    output wready,
    output bresp, bvalid,
    input  bready,
    input  araddr, arprot, arvalid,
    output arready,
    output rdata, rresp, rvalid,
    input  rready,
    input  clk, rst_n
  );

endinterface : nx_dma_axil_if
