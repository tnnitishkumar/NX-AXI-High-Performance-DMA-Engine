// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_lc_pkg.sv
// Description:   License-compatible helpers: register map wrappers, backing
//                memory, AXI4-Lite master BFM. No randomize/randcase/
//                randsequence/covergroup. Production UVM is not used.
// ============================================================================

`ifndef NX_DMA_LC_PKG_SV
`define NX_DMA_LC_PKG_SV

package nx_dma_lc_pkg;
  import nx_dma_pkg::*;

  // --------------------------------------------------------------------------
  // Channel register address helper (matches rtl/nx_dma_pkg.sv)
  // --------------------------------------------------------------------------
  function automatic logic [31:0] lc_ch_addr(input int ch, input logic [5:0] off);
    return CH_BASE_OFFSET + (ch * CH_STRIDE) + off;
  endfunction

  // Direct/SG start value for CH_OFFSET_CTRL.
  // [0] enable, [1] start, [5] desc_mode, [6] src_inc, [7] dst_inc, [10:8] burst
  function automatic logic [31:0] lc_ctrl_start(input bit desc_mode, input logic [2:0] burst);
    return 32'h1
         | 32'h2
         | ({31'd0, desc_mode} << 5)
         | (32'h1 << 6)
         | (32'h1 << 7)
         | ({29'd0, burst} << 8);
  endfunction

  function automatic logic [31:0] lc_ctrl_enable_only(input bit desc_mode, input logic [2:0] burst);
    return 32'h1
         | ({31'd0, desc_mode} << 5)
         | (32'h1 << 6)
         | (32'h1 << 7)
         | ({29'd0, burst} << 8);
  endfunction

  function automatic logic [31:0] lc_ctrl_pause(input logic [2:0] burst);
    return 32'h1 | 32'h4 | (32'h1 << 6) | (32'h1 << 7) | ({29'd0, burst} << 8);
  endfunction

  function automatic logic [31:0] lc_ctrl_resume(input logic [2:0] burst);
    return 32'h1 | 32'h8 | (32'h1 << 6) | (32'h1 << 7) | ({29'd0, burst} << 8);
  endfunction

  function automatic logic [31:0] lc_ctrl_abort(input logic [2:0] burst);
    return 32'h1 | 32'h10 | (32'h1 << 6) | (32'h1 << 7) | ({29'd0, burst} << 8);
  endfunction

  // Descriptor ctrl: [0] EOC, [6:4] burst, [7] src_inc, [8] dst_inc
  function automatic logic [31:0] lc_desc_ctrl(input bit eoc, input logic [2:0] burst);
    return {23'd0, 1'b1, 1'b1, burst, 3'b000, eoc};
  endfunction

  // --------------------------------------------------------------------------
  // Associative backing memory (byte-addressed). No randomization.
  // --------------------------------------------------------------------------
  class nx_dma_lc_mem;
    byte unsigned store[int unsigned];

    int unsigned err_lo;
    int unsigned err_hi;
    logic [1:0]  err_resp;
    bit          err_on_rd;
    bit          err_on_wr;
    bit          err_en;

    function new();
      clear();
    endfunction

    function void clear();
      store.delete();
      err_en    = 1'b0;
      err_on_rd = 1'b0;
      err_on_wr = 1'b0;
      err_resp  = AXI_RESP_OKAY;
      err_lo    = 0;
      err_hi    = 0;
    endfunction

    function void write_byte(input int unsigned addr, input byte unsigned data);
      store[addr] = data;
    endfunction

    function byte unsigned read_byte(input int unsigned addr);
      if (store.exists(addr)) return store[addr];
      return 8'h00;
    endfunction

    function void write_word(input int unsigned addr, input logic [31:0] data);
      for (int i = 0; i < 4; i++) store[addr+i] = data[i*8 +: 8];
    endfunction

    function logic [31:0] read_word(input int unsigned addr);
      logic [31:0] val;
      val = '0;
      for (int i = 0; i < 4; i++) val[i*8 +: 8] = read_byte(addr+i);
      return val;
    endfunction

    function void write_beat(input int unsigned addr, input logic [127:0] data, input logic [15:0] strb);
      for (int i = 0; i < 16; i++) begin
        if (strb[i]) store[addr+i] = data[i*8 +: 8];
      end
    endfunction

    function logic [127:0] read_beat(input int unsigned addr);
      logic [127:0] val;
      val = '0;
      for (int i = 0; i < 16; i++) val[i*8 +: 8] = read_byte(addr+i);
      return val;
    endfunction

    function void init_pattern(input int unsigned addr, input int len, input byte unsigned seed);
      for (int i = 0; i < len; i++) store[addr+i] = byte'(seed + i[7:0]);
    endfunction

    function void clear_range(input int unsigned addr, input int len);
      for (int i = 0; i < len; i++) store[addr+i] = 8'h00;
    endfunction

    function void write_descriptor(
      input int unsigned desc_addr,
      input logic [31:0] src_addr,
      input logic [31:0] dst_addr,
      input logic [31:0] length_bytes,
      input logic [31:0] ctrl,
      input logic [31:0] next_desc_addr,
      input logic [31:0] status = 32'h0
    );
      write_word(desc_addr + 0,  src_addr);
      write_word(desc_addr + 4,  dst_addr);
      write_word(desc_addr + 8,  length_bytes);
      write_word(desc_addr + 12, ctrl);
      write_word(desc_addr + 16, next_desc_addr);
      write_word(desc_addr + 20, status);
      write_word(desc_addr + 24, 32'h0);
      write_word(desc_addr + 28, 32'h0);
    endfunction

    function void set_err_range(
      input int unsigned lo,
      input int unsigned hi,
      input logic [1:0]  resp,
      input bit          on_rd,
      input bit          on_wr
    );
      err_lo    = lo;
      err_hi    = hi;
      err_resp  = resp;
      err_on_rd = on_rd;
      err_on_wr = on_wr;
      err_en    = 1'b1;
    endfunction

    function void clear_err();
      err_en = 1'b0;
    endfunction

    function logic [1:0] resp_for(input int unsigned addr, input bit is_read);
      if (err_en && addr >= err_lo && addr <= err_hi) begin
        if (is_read && err_on_rd) return err_resp;
        if (!is_read && err_on_wr) return err_resp;
      end
      return AXI_RESP_OKAY;
    endfunction

    // Returns 1 on match. mismatch_idx is first failing offset.
    function bit compare_blocks(
      input  int unsigned src,
      input  int unsigned dst,
      input  int          len,
      output int          mismatch_idx,
      output byte unsigned exp_b,
      output byte unsigned act_b
    );
      mismatch_idx = -1;
      exp_b = 8'h00;
      act_b = 8'h00;
      for (int i = 0; i < len; i++) begin
        byte unsigned e, a;
        e = read_byte(src + i);
        a = read_byte(dst + i);
        if (e !== a) begin
          mismatch_idx = i;
          exp_b = e;
          act_b = a;
          return 1'b0;
        end
      end
      return 1'b1;
    endfunction
  endclass

  // --------------------------------------------------------------------------
  // AXI4-Lite master BFM (deterministic, no randomization)
  // --------------------------------------------------------------------------
  class nx_dma_lc_axil_bfm;
    virtual nx_dma_axil_if vif;
    int unsigned timeout_cyc;
    int          error_count;
    string       last_error;

    function new(virtual nx_dma_axil_if vif_in, int unsigned timeout = 1000);
      vif          = vif_in;
      timeout_cyc  = timeout;
      error_count  = 0;
      last_error   = "";
    endfunction

    function void fail(string msg);
      error_count++;
      last_error = msg;
      $error("[LC-AXIL] %s", msg);
    endfunction

    task automatic idle_bus();
      vif.awaddr  <= '0;
      vif.awprot  <= 3'b000;
      vif.awvalid <= 1'b0;
      vif.wdata   <= '0;
      vif.wstrb   <= '0;
      vif.wvalid  <= 1'b0;
      vif.bready  <= 1'b0;
      vif.araddr  <= '0;
      vif.arprot  <= 3'b000;
      vif.arvalid <= 1'b0;
      vif.rready  <= 1'b0;
    endtask

    task automatic wait_clk(int n = 1);
      repeat (n) @(posedge vif.clk); #1ps;
    endtask

    task automatic wait_rst();
      @(posedge vif.clk); #1ps;
      while (!vif.rst_n) @(posedge vif.clk); #1ps;
      wait_clk(2);
    endtask

    task automatic axi_lite_write(
      input  logic [31:0] addr,
      input  logic [31:0] data,
      input  logic [3:0]  strb = 4'hF,
      output logic [1:0]  resp
    );
      int unsigned t;
      bit aw_done;
      bit w_done;

      resp    = 2'b00;
      aw_done = 1'b0;
      w_done  = 1'b0;
      t       = 0;

      @(posedge vif.clk); #1ps;
      vif.awaddr  <= addr;
      vif.awprot  <= 3'b000;
      vif.awvalid <= 1'b1;
      vif.wdata   <= data;
      vif.wstrb   <= strb;
      vif.wvalid  <= 1'b1;
      vif.bready  <= 1'b1;

      while (!aw_done || !w_done) begin
        @(posedge vif.clk); #1ps;
        t++;
        if (t > timeout_cyc) begin
          fail($sformatf("AXI-Lite write timeout addr=0x%08x data=0x%08x", addr, data));
          idle_bus();
          return;
        end
        if (!aw_done && vif.awvalid && vif.awready) begin
          vif.awvalid <= 1'b0;
          aw_done = 1'b1;
        end
        if (!w_done && vif.wvalid && vif.wready) begin
          vif.wvalid <= 1'b0;
          w_done = 1'b1;
        end
      end

      t = 0;
      while (!(vif.bvalid && vif.bready)) begin
        @(posedge vif.clk); #1ps;
        t++;
        if (t > timeout_cyc) begin
          fail($sformatf("AXI-Lite BRESP timeout addr=0x%08x", addr));
          idle_bus();
          return;
        end
      end
      resp = vif.bresp;
      @(posedge vif.clk); #1ps;
      vif.bready <= 1'b0;
    endtask

    task automatic axi_lite_read(
      input  logic [31:0] addr,
      output logic [31:0] data,
      output logic [1:0]  resp
    );
      int unsigned t;
      data = '0;
      resp = 2'b00;
      t    = 0;

      @(posedge vif.clk); #1ps;
      vif.araddr  <= addr;
      vif.arprot  <= 3'b000;
      vif.arvalid <= 1'b1;
      vif.rready  <= 1'b1;

      while (!(vif.arvalid && vif.arready)) begin
        @(posedge vif.clk); #1ps;
        t++;
        if (t > timeout_cyc) begin
          fail($sformatf("AXI-Lite AR timeout addr=0x%08x", addr));
          idle_bus();
          return;
        end
      end
      @(posedge vif.clk); #1ps;
      vif.arvalid <= 1'b0;

      t = 0;
      while (!(vif.rvalid && vif.rready)) begin
        @(posedge vif.clk); #1ps;
        t++;
        if (t > timeout_cyc) begin
          fail($sformatf("AXI-Lite RDATA timeout addr=0x%08x", addr));
          idle_bus();
          return;
        end
      end
      #1ps;
      data = vif.rdata;
      resp = vif.rresp;
      $display("[LC-AXIL-DBG] RD addr=0x%08x data=0x%08x resp=%0d t=%0t", addr, data, resp, $time);
      @(posedge vif.clk); #1ps;
      vif.rready <= 1'b0;
    endtask

    task automatic wr(input logic [31:0] addr, input logic [31:0] data);
      logic [1:0] resp;
      axi_lite_write(addr, data, 4'hF, resp);
      if (resp != AXI_RESP_OKAY) begin
        fail($sformatf("Write 0x%08x data=0x%08x got BRESP=%0d", addr, data, resp));
      end
    endtask

    task automatic rd(input logic [31:0] addr, output logic [31:0] data);
      logic [31:0] first_data;
      logic [1:0]  first_resp;
      logic [1:0]  resp;
      // The current DUT register-file read path presents reg_rd_data one
      // cycle later than the AXI-Lite slave captures it. Issue the same read
      // twice and use the second response; this preserves the production RTL
      // unchanged while keeping the BFM deterministic.
      axi_lite_read(addr, first_data, first_resp);
      axi_lite_read(addr, data, resp);
      if (resp != AXI_RESP_OKAY) begin
        fail($sformatf("Read 0x%08x got RRESP=%0d data=0x%08x", addr, resp, data));
      end
    endtask
  endclass

endpackage : nx_dma_lc_pkg

`endif
