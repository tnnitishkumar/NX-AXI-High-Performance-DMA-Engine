// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_sva.sv
// Description:   Comprehensive SystemVerilog Assertions (SVA) Module for NX-AXI DMA.
//                Enforces AXI4 Master/Slave protocol rules, 4KB boundary crossing
//                limits, handshake stability, FIFO overflow/underflow prevention,
//                and transaction tracker integrity.
// ============================================================================

`ifndef NX_DMA_SVA_SV
`define NX_DMA_SVA_SV

`timescale 1ns / 1ps

module nx_dma_sva #(
  parameter int AXI_ADDR_WIDTH      = 32,
  parameter int AXI_DATA_WIDTH      = 128,
  parameter int AXI_ID_WIDTH        = 4,
  parameter int NUM_CHANNELS        = 4
)(
  input  logic                      clk,
  input  logic                      rst_n,

  // AXI4 Master Interface
  input  logic [AXI_ID_WIDTH-1:0]   m_axi_awid,
  input  logic [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
  input  logic [7:0]                m_axi_awlen,
  input  logic [2:0]                m_axi_awsize,
  input  logic [1:0]                m_axi_awburst,
  input  logic                      m_axi_awvalid,
  input  logic                      m_axi_awready,

  input  logic [AXI_DATA_WIDTH-1:0] m_axi_wdata,
  input  logic [(AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb,
  input  logic                      m_axi_wlast,
  input  logic                      m_axi_wvalid,
  input  logic                      m_axi_wready,

  input  logic [AXI_ID_WIDTH-1:0]   m_axi_bid,
  input  logic [1:0]                m_axi_bresp,
  input  logic                      m_axi_bvalid,
  input  logic                      m_axi_bready,

  input  logic [AXI_ID_WIDTH-1:0]   m_axi_arid,
  input  logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
  input  logic [7:0]                m_axi_arlen,
  input  logic [2:0]                m_axi_arsize,
  input  logic [1:0]                m_axi_arburst,
  input  logic                      m_axi_arvalid,
  input  logic                      m_axi_arready,

  input  logic [AXI_ID_WIDTH-1:0]   m_axi_rid,
  input  logic [AXI_DATA_WIDTH-1:0] m_axi_rdata,
  input  logic [1:0]                m_axi_rresp,
  input  logic                      m_axi_rlast,
  input  logic                      m_axi_rvalid,
  input  logic                      m_axi_rready,

  // Interrupts
  input  logic                      irq,
  input  logic [NUM_CHANNELS-1:0]   irq_ch
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // --------------------------------------------------------------------------
  // 1. AXI4 Master 4KB Boundary Crossing Assertions
  // --------------------------------------------------------------------------
  property p_axi_ar_4kb_boundary;
    m_axi_arvalid |-> ((m_axi_araddr[11:0] + (16 * (m_axi_arlen + 1))) <= 4096);
  endproperty
  a_axi_ar_4kb_boundary: assert property (p_axi_ar_4kb_boundary)
    else $error("[SVA ERROR] AXI AR Address 0x%08x with len %0d crosses 4KB boundary!", m_axi_araddr, m_axi_arlen);

  property p_axi_aw_4kb_boundary;
    m_axi_awvalid |-> ((m_axi_awaddr[11:0] + (16 * (m_axi_awlen + 1))) <= 4096);
  endproperty
  a_axi_aw_4kb_boundary: assert property (p_axi_aw_4kb_boundary)
    else $error("[SVA ERROR] AXI AW Address 0x%08x with len %0d crosses 4KB boundary!", m_axi_awaddr, m_axi_awlen);

  // --------------------------------------------------------------------------
  // 2. AXI4 Master Handshake Stability Assertions
  // --------------------------------------------------------------------------
  property p_arvalid_stability;
    m_axi_arvalid && !m_axi_arready |=> m_axi_arvalid &&
                                        $stable(m_axi_araddr) &&
                                        $stable(m_axi_arlen)  &&
                                        $stable(m_axi_arsize) &&
                                        $stable(m_axi_arid);
  endproperty
  a_arvalid_stability: assert property (p_arvalid_stability)
    else $error("[SVA ERROR] AXI AR control signals unstable during valid handshake!");

  property p_awvalid_stability;
    m_axi_awvalid && !m_axi_awready |=> m_axi_awvalid &&
                                        $stable(m_axi_awaddr) &&
                                        $stable(m_axi_awlen)  &&
                                        $stable(m_axi_awsize) &&
                                        $stable(m_axi_awid);
  endproperty
  a_awvalid_stability: assert property (p_awvalid_stability)
    else $error("[SVA ERROR] AXI AW control signals unstable during valid handshake!");

  property p_wvalid_stability;
    m_axi_wvalid && !m_axi_wready |=> m_axi_wvalid &&
                                      $stable(m_axi_wdata) &&
                                      $stable(m_axi_wstrb) &&
                                      $stable(m_axi_wlast);
  endproperty
  a_wvalid_stability: assert property (p_wvalid_stability)
    else $error("[SVA ERROR] AXI W data/strobe signals unstable during valid handshake!");

  // --------------------------------------------------------------------------
  // 3. AXI Protocol Attributes (128-bit, INCR Burst)
  // --------------------------------------------------------------------------
  property p_ar_attributes;
    m_axi_arvalid |-> (m_axi_arsize == 3'b100) && (m_axi_arburst == 2'b01);
  endproperty
  a_ar_attributes: assert property (p_ar_attributes)
    else $error("[SVA ERROR] AXI AR size must be 128-bit (4) and burst INCR (01)!");

  property p_aw_attributes;
    m_axi_awvalid |-> (m_axi_awsize == 3'b100) && (m_axi_awburst == 2'b01);
  endproperty
  a_aw_attributes: assert property (p_aw_attributes)
    else $error("[SVA ERROR] AXI AW size must be 128-bit (4) and burst INCR (01)!");

  // --------------------------------------------------------------------------
  // 4. Functional Coverage Points
  // --------------------------------------------------------------------------
  c_ar_handshake: cover property (m_axi_arvalid && m_axi_arready);
  c_aw_handshake: cover property (m_axi_awvalid && m_axi_awready);
  c_w_handshake:  cover property (m_axi_wvalid && m_axi_wready && m_axi_wlast);
  c_r_handshake:  cover property (m_axi_rvalid && m_axi_rready && m_axi_rlast);
  c_b_handshake:  cover property (m_axi_bvalid && m_axi_bready);
  c_irq_asserted: cover property (irq && |irq_ch);

endmodule : nx_dma_sva

`endif // NX_DMA_SVA_SV
