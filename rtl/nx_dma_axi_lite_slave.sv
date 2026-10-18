// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_lite_slave.sv
// Description:   AXI4-Lite Slave Controller for CPU configuration and register
//                access. Compliant with standard AXI4-Lite handshake rules.
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_axi_lite_slave
  import nx_dma_pkg::*;
(
  input  logic                           clk,
  input  logic                           rst_n,

  // AXI4-Lite Slave Write Address Channel
  input  logic [AXI_LITE_ADDR_WIDTH-1:0] s_axil_awaddr,
  input  logic [2:0]                     s_axil_awprot,
  input  logic                           s_axil_awvalid,
  output logic                           s_axil_awready,

  // AXI4-Lite Slave Write Data Channel
  input  logic [AXI_LITE_DATA_WIDTH-1:0] s_axil_wdata,
  input  logic [AXI_LITE_STRB_WIDTH-1:0] s_axil_wstrb,
  input  logic                           s_axil_wvalid,
  output logic                           s_axil_wready,

  // AXI4-Lite Slave Write Response Channel
  output logic [AXI_RESP_WIDTH-1:0]      s_axil_bresp,
  output logic                           s_axil_bvalid,
  input  logic                           s_axil_bready,

  // AXI4-Lite Slave Read Address Channel
  input  logic [AXI_LITE_ADDR_WIDTH-1:0] s_axil_araddr,
  input  logic [2:0]                     s_axil_arprot,
  input  logic                           s_axil_arvalid,
  output logic                           s_axil_arready,

  // AXI4-Lite Slave Read Data Channel
  output logic [AXI_LITE_DATA_WIDTH-1:0] s_axil_rdata,
  output logic [AXI_RESP_WIDTH-1:0]      s_axil_rresp,
  output logic                           s_axil_rvalid,
  input  logic                           s_axil_rready,

  // Internal Register File Interface
  output logic                           reg_wr_en,
  output logic [AXI_LITE_ADDR_WIDTH-1:0] reg_wr_addr,
  output logic [AXI_LITE_DATA_WIDTH-1:0] reg_wr_data,
  output logic [AXI_LITE_STRB_WIDTH-1:0] reg_wr_strb,
  input  logic                           reg_wr_ack,
  input  logic [AXI_RESP_WIDTH-1:0]      reg_wr_resp,

  output logic                           reg_rd_en,
  output logic [AXI_LITE_ADDR_WIDTH-1:0] reg_rd_addr,
  input  logic [AXI_LITE_DATA_WIDTH-1:0] reg_rd_data,
  input  logic                           reg_rd_ack,
  input  logic [AXI_RESP_WIDTH-1:0]      reg_rd_resp
);

  // --------------------------------------------------------------------------
  // Write Channel State Machine
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    WR_IDLE = 2'b00,
    WR_DATA = 2'b01,
    WR_RESP = 2'b10
  } wr_state_e;

  wr_state_e wr_state, wr_state_next;

  logic [AXI_LITE_ADDR_WIDTH-1:0] awaddr_q;
  logic [AXI_LITE_DATA_WIDTH-1:0] wdata_q;
  logic [AXI_LITE_STRB_WIDTH-1:0] wstrb_q;
  logic                           aw_latched;
  logic                           w_latched;

  // --------------------------------------------------------------------------
  // Read Channel State Machine
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    RD_IDLE = 2'b00,
    RD_WAIT = 2'b01,
    RD_RESP = 2'b10
  } rd_state_e;

  rd_state_e rd_state, rd_state_next;

  logic [AXI_LITE_ADDR_WIDTH-1:0] araddr_q;

  // ==========================================================================
  // Write Channel Logic
  // ==========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_state       <= WR_IDLE;
      s_axil_awready <= 1'b0;
      s_axil_wready  <= 1'b0;
      s_axil_bvalid  <= 1'b0;
      s_axil_bresp   <= AXI_RESP_OKAY;
      awaddr_q       <= '0;
      wdata_q        <= '0;
      wstrb_q        <= '0;
      aw_latched     <= 1'b0;
      w_latched      <= 1'b0;
      reg_wr_en      <= 1'b0;
      reg_wr_addr    <= '0;
      reg_wr_data    <= '0;
      reg_wr_strb    <= '0;
    end else begin
      case (wr_state)
        WR_IDLE: begin
          s_axil_bvalid <= 1'b0;
          reg_wr_en     <= 1'b0;

          // Accept AW and W either together or independently
          if (s_axil_awvalid && s_axil_wvalid) begin
            s_axil_awready <= 1'b1;
            s_axil_wready  <= 1'b1;
            reg_wr_en      <= 1'b1;
            reg_wr_addr    <= s_axil_awaddr;
            reg_wr_data    <= s_axil_wdata;
            reg_wr_strb    <= s_axil_wstrb;
            aw_latched     <= 1'b0;
            w_latched      <= 1'b0;
            wr_state       <= WR_RESP;
          end else if (s_axil_awvalid) begin
            s_axil_awready <= 1'b1;
            awaddr_q       <= s_axil_awaddr;
            aw_latched     <= 1'b1;
            wr_state       <= WR_DATA;
          end else if (s_axil_wvalid) begin
            s_axil_wready <= 1'b1;
            wdata_q       <= s_axil_wdata;
            wstrb_q       <= s_axil_wstrb;
            w_latched     <= 1'b1;
            wr_state      <= WR_DATA;
          end
        end

        WR_DATA: begin
          s_axil_awready <= 1'b0;
          s_axil_wready  <= 1'b0;

          if (aw_latched && s_axil_wvalid) begin
            s_axil_wready <= 1'b1;
            reg_wr_en     <= 1'b1;
            reg_wr_addr   <= awaddr_q;
            reg_wr_data   <= s_axil_wdata;
            reg_wr_strb   <= s_axil_wstrb;
            aw_latched    <= 1'b0;
            wr_state      <= WR_RESP;
          end else if (w_latched && s_axil_awvalid) begin
            s_axil_awready <= 1'b1;
            reg_wr_en      <= 1'b1;
            reg_wr_addr    <= s_axil_awaddr;
            reg_wr_data    <= wdata_q;
            reg_wr_strb    <= wstrb_q;
            w_latched      <= 1'b0;
            wr_state       <= WR_RESP;
          end
        end

        WR_RESP: begin
          s_axil_awready <= 1'b0;
          s_axil_wready  <= 1'b0;
          reg_wr_en      <= 1'b0;

          if (!s_axil_bvalid) begin
            s_axil_bvalid <= 1'b1;
            s_axil_bresp  <= reg_wr_resp;
          end else if (s_axil_bvalid && s_axil_bready) begin
            s_axil_bvalid <= 1'b0;
            wr_state      <= WR_IDLE;
          end
        end

        default: wr_state <= WR_IDLE;
      endcase
    end
  end

  // ==========================================================================
  // Read Channel Logic
  // ==========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_state       <= RD_IDLE;
      s_axil_arready <= 1'b0;
      s_axil_rvalid  <= 1'b0;
      s_axil_rdata   <= '0;
      s_axil_rresp   <= AXI_RESP_OKAY;
      araddr_q       <= '0;
      reg_rd_en      <= 1'b0;
      reg_rd_addr    <= '0;
    end else begin
      case (rd_state)
        RD_IDLE: begin
          if (s_axil_arvalid) begin
            s_axil_arready <= 1'b1;
            reg_rd_en      <= 1'b1;
            reg_rd_addr    <= s_axil_araddr;
            araddr_q       <= s_axil_araddr;
            rd_state       <= RD_WAIT;
          end else begin
            s_axil_arready <= 1'b0;
            reg_rd_en      <= 1'b0;
          end
        end

        RD_WAIT: begin
          s_axil_arready <= 1'b0;
          reg_rd_en      <= 1'b0;
          // Reg file provides data either combinational or 1-cycle
          s_axil_rvalid  <= 1'b1;
          s_axil_rdata   <= reg_rd_data;
          s_axil_rresp   <= reg_rd_resp;
          rd_state       <= RD_RESP;
        end

        RD_RESP: begin
          if (s_axil_rvalid && s_axil_rready) begin
            s_axil_rvalid <= 1'b0;
            rd_state      <= RD_IDLE;
          end
        end

        default: rd_state <= RD_IDLE;
      endcase
    end
  end

endmodule : nx_dma_axi_lite_slave
