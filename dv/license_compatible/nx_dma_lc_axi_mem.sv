// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_lc_axi_mem.sv
// Description:   Deterministic AXI4 slave memory. Supports outstanding
//                read transactions, programmable READY delay, and
//                SLVERR/DECERR injection. No randomize/randcase/
//                randsequence/covergroup.
// ============================================================================

`ifndef NX_DMA_LC_AXI_MEM_SV
`define NX_DMA_LC_AXI_MEM_SV

`timescale 1ns / 1ps

module nx_dma_lc_axi_mem
  import nx_dma_pkg::*;
  import nx_dma_lc_pkg::*;
#(
  parameter int ADDR_WIDTH = AXI_ADDR_WIDTH,
  parameter int DATA_WIDTH = AXI_DATA_WIDTH,
  parameter int ID_WIDTH   = AXI_ID_WIDTH,
  parameter int LEN_WIDTH  = AXI_LEN_WIDTH
)(
  input  logic                      clk,
  input  logic                      rst_n,

  input  logic [ID_WIDTH-1:0]       awid,
  input  logic [ADDR_WIDTH-1:0]     awaddr,
  input  logic [LEN_WIDTH-1:0]      awlen,
  input  logic [2:0]                awsize,
  input  logic [1:0]                awburst,
  input  logic                      awvalid,
  output logic                      awready,

  input  logic [DATA_WIDTH-1:0]     wdata,
  input  logic [(DATA_WIDTH/8)-1:0] wstrb,
  input  logic                      wlast,
  input  logic                      wvalid,
  output logic                      wready,

  output logic [ID_WIDTH-1:0]       bid,
  output logic [1:0]                bresp,
  output logic                      bvalid,
  input  logic                      bready,

  input  logic [ID_WIDTH-1:0]       arid,
  input  logic [ADDR_WIDTH-1:0]     araddr,
  input  logic [LEN_WIDTH-1:0]      arlen,
  input  logic [2:0]                arsize,
  input  logic [1:0]                arburst,
  input  logic                      arvalid,
  output logic                      arready,

  output logic [ID_WIDTH-1:0]       rid,
  output logic [DATA_WIDTH-1:0]     rdata,
  output logic [1:0]                rresp,
  output logic                      rlast,
  output logic                      rvalid,
  input  logic                      rready
);

  nx_dma_lc_mem mem;

  int unsigned stall_ar;
  int unsigned stall_r;
  int unsigned stall_aw;
  int unsigned stall_w;
  int unsigned stall_b;

  function void set_always_ready();
    stall_ar = 0; stall_r = 0; stall_aw = 0; stall_w = 0; stall_b = 0;
  endfunction

  function void set_stalls(int unsigned ar, int unsigned r, int unsigned aw,
                           int unsigned w, int unsigned b);
    stall_ar = ar; stall_r = r; stall_aw = aw; stall_w = w; stall_b = b;
  endfunction

  initial begin
    mem = new();
    set_always_ready();
  end

  typedef struct packed {
    logic [ID_WIDTH-1:0]   id;
    logic [ADDR_WIDTH-1:0] addr;
    logic [LEN_WIDTH-1:0]  beats_left;
    logic [1:0]            resp;
  } rd_txn_t;

  typedef struct packed {
    logic [ID_WIDTH-1:0]   id;
    logic [ADDR_WIDTH-1:0] addr;
    logic [LEN_WIDTH-1:0]  beats_got;
    logic [LEN_WIDTH-1:0]  beats_exp;
    logic [1:0]            resp;
    bit                    active;
  } wr_txn_t;

  typedef struct packed {
    logic [ID_WIDTH-1:0] id;
    logic [1:0]          resp;
  } b_txn_t;

  rd_txn_t rd_q[$];
  wr_txn_t wr_cur;
  b_txn_t  b_q[$];

  int unsigned ar_cnt;
  int unsigned r_cnt;
  int unsigned aw_cnt;
  int unsigned w_cnt;
  int unsigned b_cnt;

  // --------------------------------------------------------------------------
  // Read address + read data
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      arready <= 1'b1;
      ar_cnt  <= 0;
      rvalid  <= 1'b0;
      rdata   <= '0;
      rresp   <= AXI_RESP_OKAY;
      rlast   <= 1'b0;
      rid     <= '0;
      r_cnt   <= 0;
      rd_q.delete();
    end else begin
      if (arvalid && arready) begin
        rd_txn_t t;
        t.id         = arid;
        t.addr       = {araddr[31:4], 4'b0000};
        t.beats_left = arlen + 8'd1;
        t.resp       = mem.resp_for(araddr, 1'b1);
        rd_q.push_back(t);
        arready <= 1'b0;
        ar_cnt  <= stall_ar;
      end else if (!arready) begin
        if (ar_cnt == 0) arready <= 1'b1;
        else ar_cnt <= ar_cnt - 1;
      end

      if (rvalid && rready) begin
        rvalid <= 1'b0;
        r_cnt  <= stall_r;
        if (rd_q.size() > 0) begin
          rd_txn_t t;
          t = rd_q[0];
          t.beats_left = t.beats_left - 1'b1;
          t.addr       = t.addr + BYTES_PER_BEAT;
          if (t.beats_left == 0) void'(rd_q.pop_front());
          else rd_q[0] = t;
        end
      end else if (!rvalid) begin
        if (r_cnt > 0) begin
          r_cnt <= r_cnt - 1;
        end else if (rd_q.size() > 0) begin
          rd_txn_t t;
          t      = rd_q[0];
          rid    <= t.id;
          rdata  <= mem.read_beat(t.addr);
          rresp  <= t.resp;
          rlast  <= (t.beats_left == 8'd1);
          rvalid <= 1'b1;
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Write address + write data + write response
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      awready      <= 1'b1;
      aw_cnt       <= 0;
      wready       <= 1'b0;
      w_cnt        <= 0;
      bvalid       <= 1'b0;
      bid          <= '0;
      bresp        <= AXI_RESP_OKAY;
      b_cnt        <= 0;
      wr_cur       <= '0;
      b_q.delete();
    end else begin
      if (awvalid && awready) begin
        wr_cur.id        <= awid;
        wr_cur.addr      <= {awaddr[31:4], 4'b0000};
        wr_cur.beats_got <= '0;
        wr_cur.beats_exp <= awlen + 8'd1;
        wr_cur.resp      <= mem.resp_for(awaddr, 1'b0);
        wr_cur.active    <= 1'b1;
        awready          <= 1'b0;
        aw_cnt           <= stall_aw;
        wready           <= (stall_w == 0);
        w_cnt            <= stall_w;
      end else if (!wr_cur.active) begin
        if (!awready) begin
          if (aw_cnt == 0) awready <= 1'b1;
          else aw_cnt <= aw_cnt - 1;
        end
      end

      if (wr_cur.active && !wready) begin
        if (w_cnt == 0) wready <= 1'b1;
        else w_cnt <= w_cnt - 1;
      end

      if (wvalid && wready && wr_cur.active) begin
        logic [1:0] beat_resp;
        beat_resp = mem.resp_for(wr_cur.addr, 1'b0);
        if (beat_resp != AXI_RESP_OKAY) wr_cur.resp <= beat_resp;
        mem.write_beat(wr_cur.addr, wdata, wstrb);
        wr_cur.addr      <= wr_cur.addr + BYTES_PER_BEAT;
        wr_cur.beats_got <= wr_cur.beats_got + 1'b1;
        wready           <= 1'b0;
        w_cnt            <= stall_w;
        if (wlast) begin
          b_txn_t bt;
          bt.id   = wr_cur.id;
          bt.resp = (beat_resp != AXI_RESP_OKAY) ? beat_resp : wr_cur.resp;
          b_q.push_back(bt);
          wr_cur.active <= 1'b0;
          wready        <= 1'b0;
        end
      end

      if (bvalid && bready) begin
        bvalid <= 1'b0;
        if (b_q.size() > 0) void'(b_q.pop_front());
        b_cnt <= stall_b;
      end else if (!bvalid) begin
        if (b_cnt > 0) begin
          b_cnt <= b_cnt - 1;
        end else if (b_q.size() > 0) begin
          bid    <= b_q[0].id;
          bresp  <= b_q[0].resp;
          bvalid <= 1'b1;
        end
      end
    end
  end

endmodule : nx_dma_lc_axi_mem

`endif
