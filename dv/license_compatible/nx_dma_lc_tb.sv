// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_lc_tb.sv
// Description:   License-compatible directed testbench. Instantiates the
//                production DUT and SVA. No UVM, randomize, randcase,
//                randsequence, or covergroups.
//
// Plusarg:       +LC_TEST=<name>   (default: all)
// ============================================================================

`timescale 1ns / 1ps

module nx_dma_lc_tb;
  import nx_dma_pkg::*;
  import nx_dma_lc_pkg::*;

  // --------------------------------------------------------------------------
  // Clock / reset
  // --------------------------------------------------------------------------
  logic clk;
  logic rst_n;

  initial begin
    clk = 1'b0;
    forever #5ns clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
  end

  // --------------------------------------------------------------------------
  // Interfaces and DUT
  // --------------------------------------------------------------------------
  nx_dma_axil_if axil_if (.clk(clk), .rst_n(rst_n));
  nx_dma_axi_if  axi_if  (.clk(clk), .rst_n(rst_n));
  nx_dma_irq_if  irq_if  (.clk(clk), .rst_n(rst_n));

  nx_dma_top u_dut (
    .clk             (clk),
    .rst_n           (rst_n),
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
    .irq             (irq_if.irq),
    .irq_ch          (irq_if.irq_ch)
  );

  nx_dma_lc_axi_mem u_mem (
    .clk      (clk),
    .rst_n    (rst_n),
    .awid     (axi_if.awid),
    .awaddr   (axi_if.awaddr),
    .awlen    (axi_if.awlen),
    .awsize   (axi_if.awsize),
    .awburst  (axi_if.awburst),
    .awvalid  (axi_if.awvalid),
    .awready  (axi_if.awready),
    .wdata    (axi_if.wdata),
    .wstrb    (axi_if.wstrb),
    .wlast    (axi_if.wlast),
    .wvalid   (axi_if.wvalid),
    .wready   (axi_if.wready),
    .bid      (axi_if.bid),
    .bresp    (axi_if.bresp),
    .bvalid   (axi_if.bvalid),
    .bready   (axi_if.bready),
    .arid     (axi_if.arid),
    .araddr   (axi_if.araddr),
    .arlen    (axi_if.arlen),
    .arsize   (axi_if.arsize),
    .arburst  (axi_if.arburst),
    .arvalid  (axi_if.arvalid),
    .arready  (axi_if.arready),
    .rid      (axi_if.rid),
    .rdata    (axi_if.rdata),
    .rresp    (axi_if.rresp),
    .rlast    (axi_if.rlast),
    .rvalid   (axi_if.rvalid),
    .rready   (axi_if.rready)
  );

  nx_dma_sva u_sva (
    .clk           (clk),
    .rst_n         (rst_n),
    .m_axi_awid    (axi_if.awid),
    .m_axi_awaddr  (axi_if.awaddr),
    .m_axi_awlen   (axi_if.awlen),
    .m_axi_awsize  (axi_if.awsize),
    .m_axi_awburst (axi_if.awburst),
    .m_axi_awvalid (axi_if.awvalid),
    .m_axi_awready (axi_if.awready),
    .m_axi_wdata   (axi_if.wdata),
    .m_axi_wstrb   (axi_if.wstrb),
    .m_axi_wlast   (axi_if.wlast),
    .m_axi_wvalid  (axi_if.wvalid),
    .m_axi_wready  (axi_if.wready),
    .m_axi_bid     (axi_if.bid),
    .m_axi_bresp   (axi_if.bresp),
    .m_axi_bvalid  (axi_if.bvalid),
    .m_axi_bready  (axi_if.bready),
    .m_axi_arid    (axi_if.arid),
    .m_axi_araddr  (axi_if.araddr),
    .m_axi_arlen   (axi_if.arlen),
    .m_axi_arsize  (axi_if.arsize),
    .m_axi_arburst (axi_if.arburst),
    .m_axi_arvalid (axi_if.arvalid),
    .m_axi_arready (axi_if.arready),
    .m_axi_rid     (axi_if.rid),
    .m_axi_rdata   (axi_if.rdata),
    .m_axi_rresp   (axi_if.rresp),
    .m_axi_rlast   (axi_if.rlast),
    .m_axi_rvalid  (axi_if.rvalid),
    .m_axi_rready  (axi_if.rready),
    .irq           (irq_if.irq),
    .irq_ch        (irq_if.irq_ch)
  );

  // --------------------------------------------------------------------------
  // Test infrastructure
  // --------------------------------------------------------------------------
  nx_dma_lc_axil_bfm bfm;
  int pass_count;
  int fail_count;
  int skip_count;
  string current_test;

  function void check(bit cond, string msg);
    if (cond) begin
      pass_count++;
      $display("[LC PASS] %s: %s", current_test, msg);
    end else begin
      fail_count++;
      $error("[LC FAIL] %s: %s", current_test, msg);
    end
  endfunction

  task automatic poll_ch(input int ch, input int max_cyc, output logic [31:0] status);
    int i;
    status = '0;
    for (i = 0; i < max_cyc; i++) begin
      bfm.rd(lc_ch_addr(ch, CH_OFFSET_STATUS), status);
      if (status[3] || status[4]) return; // done or error
      if (irq_if.irq && irq_if.irq_ch[ch]) begin
        bfm.rd(lc_ch_addr(ch, CH_OFFSET_STATUS), status);
        return;
      end
    end
    $error("[LC] poll timeout ch=%0d last_status=0x%08x", ch, status);
  endtask

  task automatic sw_reset_ch(input int ch);
    bfm.wr(lc_ch_addr(ch, CH_OFFSET_SW_RESET), 32'h1);
    bfm.wait_clk(4);
  endtask

  task automatic enable_irq(input int ch);
    bfm.wr(lc_ch_addr(ch, CH_OFFSET_INT_ENABLE), 32'h7);
    bfm.wr(ADDR_GLOBAL_IRQ_ENABLE, 32'hF);
  endtask

  task automatic clear_irq(input int ch);
    bfm.wr(lc_ch_addr(ch, CH_OFFSET_INT_STATUS), 32'h7);
  endtask

  task automatic program_direct(
    input int ch,
    input logic [31:0] src,
    input logic [31:0] dst,
    input logic [31:0] len,
    input logic [2:0]  burst
  );
    bfm.wr(lc_ch_addr(ch, CH_OFFSET_SRC_ADDR), src);
    bfm.wr(lc_ch_addr(ch, CH_OFFSET_DST_ADDR), dst);
    bfm.wr(lc_ch_addr(ch, CH_OFFSET_TRANSFER_LEN), len);
    bfm.wr(lc_ch_addr(ch, CH_OFFSET_BURST_CONFIG), {29'd0, burst});
    bfm.wr(lc_ch_addr(ch, CH_OFFSET_INT_ENABLE), 32'h7);
    bfm.wr(lc_ch_addr(ch, CH_OFFSET_CTRL), lc_ctrl_start(1'b0, burst));
  endtask

  task automatic check_copy(input logic [31:0] src, input logic [31:0] dst, input int len);
    int mismatch;
    byte unsigned exp_b, act_b;
    bit ok;
    ok = u_mem.mem.compare_blocks(src, dst, len, mismatch, exp_b, act_b);
    if (ok) check(1'b1, $sformatf("data match src=0x%08x dst=0x%08x len=%0d", src, dst, len));
    else check(1'b0, $sformatf("mismatch +%0d exp=0x%02x act=0x%02x src=0x%08x dst=0x%08x",
                               mismatch, exp_b, act_b, src, dst));
  endtask

  task automatic prep_buf(input logic [31:0] src, input logic [31:0] dst, input int len, input byte unsigned seed);
    u_mem.mem.init_pattern(src, len, seed);
    u_mem.mem.clear_range(dst, len);
  endtask

  task automatic wait_mem_ready();
    int g;
    g = 0;
    while (u_mem.mem == null && g < 100) begin
      @(posedge clk);
      g++;
    end
    bfm.wait_rst();
    bfm.idle_bus();
    u_mem.set_always_ready();
    u_mem.mem.clear_err();
  endtask

  // ==========================================================================
  // Directed tests
  // ==========================================================================
  task automatic t_reset_regs();
    logic [31:0] d;
    current_test = "reset_regs";
    bfm.rd(ADDR_GLOBAL_VERSION, d);
    check(d == IP_VERSION, $sformatf("IP_VERSION got=0x%08x", d));
    bfm.rd(ADDR_GLOBAL_CTRL, d);
    check(d[0] == 1'b1, $sformatf("global_en default=1 got=0x%08x", d));
    check(d[2] == 1'b0, "default arb = round-robin");
    bfm.rd(lc_ch_addr(0, CH_OFFSET_STATUS), d);
    check(d[0] == 1'b1, $sformatf("CH0 idle after reset status=0x%08x", d));
    bfm.rd(lc_ch_addr(1, CH_OFFSET_STATUS), d);
    check(d[0] == 1'b1, $sformatf("CH1 idle after reset status=0x%08x", d));
    bfm.rd(lc_ch_addr(2, CH_OFFSET_STATUS), d);
    check(d[0] == 1'b1, "CH2 idle after reset");
    bfm.rd(lc_ch_addr(3, CH_OFFSET_STATUS), d);
    check(d[0] == 1'b1, "CH3 idle after reset");
  endtask

  task automatic t_axil_rw();
    logic [31:0] d;
    logic [1:0]  resp;
    current_test = "axil_rw";
    bfm.wr(lc_ch_addr(0, CH_OFFSET_SRC_ADDR), 32'h1111_0000);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_DST_ADDR), 32'h2222_0000);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_TRANSFER_LEN), 32'd128);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_PRIORITY), 32'd3);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_INT_ENABLE), 32'h5);
    bfm.rd(lc_ch_addr(0, CH_OFFSET_SRC_ADDR), d);
    check(d == 32'h1111_0000, $sformatf("src_addr got=0x%08x", d));
    bfm.rd(lc_ch_addr(0, CH_OFFSET_DST_ADDR), d);
    check(d == 32'h2222_0000, $sformatf("dst_addr got=0x%08x", d));
    bfm.rd(lc_ch_addr(0, CH_OFFSET_TRANSFER_LEN), d);
    check(d == 32'd128, $sformatf("len got=%0d", d));
    bfm.rd(lc_ch_addr(0, CH_OFFSET_PRIORITY), d);
    check(d[1:0] == 2'd3, $sformatf("priority got=0x%08x", d));
    bfm.rd(lc_ch_addr(0, CH_OFFSET_INT_ENABLE), d);
    check(d[2:0] == 3'b101, $sformatf("int_enable got=0x%08x", d));
    // Unmapped global read should DECERR
    bfm.axi_lite_read(32'h0000_0020, d, resp);
    bfm.axi_lite_read(32'h0000_0020, d, resp);
    check(resp == AXI_RESP_DECERR, $sformatf("unmapped read RRESP=%0d", resp));
  endtask

  task automatic t_direct_copy(string name, int ch, logic [31:0] src, logic [31:0] dst,
                               int len, logic [2:0] burst, byte unsigned seed);
    logic [31:0] st, err;
    current_test = name;
    sw_reset_ch(ch);
    prep_buf(src, dst, len, seed);
    enable_irq(ch);
    program_direct(ch, src, dst, len, burst);
    poll_ch(ch, 20000, st);
    check(st[3] == 1'b1, $sformatf("ch%0d done status=0x%08x", ch, st));
    check(st[4] == 1'b0, $sformatf("ch%0d no error status=0x%08x", ch, st));
    bfm.rd(lc_ch_addr(ch, CH_OFFSET_ERROR_STATUS), err);
    check(err[3:0] == ERR_NONE, $sformatf("err_status=0x%08x", err));
    check_copy(src, dst, len);
    clear_irq(ch);
  endtask

  task automatic t_4kb_cross();
    // 0xFF0 + 64 bytes crosses 4KB page at 0x1000
    t_direct_copy("cross_4kb", 0, 32'h0000_0FF0, 32'h0008_0FF0, 64, 3'd4, 8'hC0);
  endtask

  task automatic t_unaligned();
    t_direct_copy("unaligned", 0, 32'h0001_0004, 32'h0008_0004, 37, 3'd2, 8'h5A);
  endtask

  task automatic t_multi_channel();
    logic [31:0] st0, st1;
    current_test = "multi_channel";
    sw_reset_ch(0); sw_reset_ch(1);
    prep_buf(32'h0001_0000, 32'h0008_0000, 64, 8'h10);
    prep_buf(32'h0002_0000, 32'h0009_0000, 64, 8'h20);
    enable_irq(0); enable_irq(1);
    program_direct(0, 32'h0001_0000, 32'h0008_0000, 64, 3'd4);
    program_direct(1, 32'h0002_0000, 32'h0009_0000, 64, 3'd4);
    poll_ch(0, 20000, st0);
    poll_ch(1, 20000, st1);
    check(st0[3], $sformatf("CH0 done status=0x%08x", st0));
    check(st1[3], $sformatf("CH1 done status=0x%08x", st1));
    check_copy(32'h0001_0000, 32'h0008_0000, 64);
    check_copy(32'h0002_0000, 32'h0009_0000, 64);
    clear_irq(0); clear_irq(1);
  endtask

  task automatic t_arb_mode(string name, bit fixed);
    logic [31:0] st;
    int c;
    current_test = name;
    for (c = 0; c < 4; c++) sw_reset_ch(c);
    bfm.wr(ADDR_GLOBAL_CTRL, 32'h1 | ({31'd0, fixed} << 2));
    for (c = 0; c < 4; c++) begin
      bfm.wr(lc_ch_addr(c, CH_OFFSET_PRIORITY), c); // CH3 highest if fixed
      prep_buf(32'h0001_0000 + (c << 16), 32'h0008_0000 + (c << 16), 32, byte'(8'h30 + c));
      enable_irq(c);
    end
    for (c = 0; c < 4; c++) begin
      program_direct(c, 32'h0001_0000 + (c << 16), 32'h0008_0000 + (c << 16), 32, 3'd1);
    end
    for (c = 0; c < 4; c++) begin
      poll_ch(c, 20000, st);
      check(st[3], $sformatf("CH%0d done status=0x%08x", c, st));
      check_copy(32'h0001_0000 + (c << 16), 32'h0008_0000 + (c << 16), 32);
      clear_irq(c);
    end
    bfm.wr(ADDR_GLOBAL_CTRL, 32'h1); // restore RR
  endtask

  task automatic t_sg_chain();
    logic [31:0] st, ctrl0, ctrl1;
    current_test = "sg_chain";
    sw_reset_ch(0);
    prep_buf(32'h0001_1000, 32'h0008_1000, 32, 8'hB1);
    prep_buf(32'h0001_2000, 32'h0008_2000, 48, 8'hB2);
    ctrl0 = lc_desc_ctrl(1'b0, 3'd2);
    ctrl1 = lc_desc_ctrl(1'b1, 3'd2);
    u_mem.mem.write_descriptor(32'h0000_2000, 32'h0001_1000, 32'h0008_1000, 32, ctrl0, 32'h0000_2020, 0);
    u_mem.mem.write_descriptor(32'h0000_2020, 32'h0001_2000, 32'h0008_2000, 48, ctrl1, 32'h0, 0);
    enable_irq(0);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_DESC_ADDR), 32'h0000_2000);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_BURST_CONFIG), 32'd2);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_CTRL), lc_ctrl_start(1'b1, 3'd2));
    poll_ch(0, 30000, st);
    check(st[3], $sformatf("SG done status=0x%08x", st));
    check(st[4] == 1'b0, $sformatf("SG no error status=0x%08x", st));
    check_copy(32'h0001_1000, 32'h0008_1000, 32);
    check_copy(32'h0001_2000, 32'h0008_2000, 48);
    clear_irq(0);
  endtask

  task automatic t_irq();
    logic [31:0] st, istat, gstat;
    current_test = "irq";
    sw_reset_ch(0);
    prep_buf(32'h0001_3000, 32'h0008_3000, 16, 8'h77);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_INT_ENABLE), 32'h1); // xfer_done only
    bfm.wr(ADDR_GLOBAL_IRQ_ENABLE, 32'hF);
    program_direct(0, 32'h0001_3000, 32'h0008_3000, 16, 3'd0);
    poll_ch(0, 10000, st);
    check(irq_if.irq === 1'b1, $sformatf("top irq=%0b ch=%b", irq_if.irq, irq_if.irq_ch));
    check(irq_if.irq_ch[0] === 1'b1, "CH0 irq asserted");
    bfm.rd(lc_ch_addr(0, CH_OFFSET_INT_STATUS), istat);
    check(istat[0] == 1'b1, $sformatf("int_status xfer_done=0x%08x", istat));
    bfm.rd(ADDR_GLOBAL_IRQ_STATUS, gstat);
    check(gstat[0] == 1'b1, $sformatf("global irq status=0x%08x", gstat));
    clear_irq(0);
    bfm.wait_clk(4);
    check(irq_if.irq_ch[0] === 1'b0, "CH0 irq cleared after W1C");
  endtask

  task automatic t_zero_len();
    logic [31:0] st, err;
    current_test = "err_zero_len";
    sw_reset_ch(0);
    enable_irq(0);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_SRC_ADDR), 32'h0001_0000);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_DST_ADDR), 32'h0008_0000);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_TRANSFER_LEN), 32'd0);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_CTRL), lc_ctrl_start(1'b0, 3'd4));
    poll_ch(0, 2000, st);
    check(st[4] == 1'b1, $sformatf("zero-len -> error status=0x%08x", st));
    bfm.rd(lc_ch_addr(0, CH_OFFSET_ERROR_STATUS), err);
    check(err[3:0] == ERR_ZERO_LEN, $sformatf("err code got=0x%08x exp=%0d", err, ERR_ZERO_LEN));
    clear_irq(0);
  endtask

  task automatic t_unaligned_desc();
    logic [31:0] st, err;
    current_test = "err_unaligned_desc";
    sw_reset_ch(0);
    enable_irq(0);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_DESC_ADDR), 32'h0000_2004); // not 16B aligned
    bfm.wr(lc_ch_addr(0, CH_OFFSET_CTRL), lc_ctrl_start(1'b1, 3'd4));
    poll_ch(0, 2000, st);
    check(st[4] == 1'b1, $sformatf("unaligned desc -> error status=0x%08x", st));
    bfm.rd(lc_ch_addr(0, CH_OFFSET_ERROR_STATUS), err);
    check(err[3:0] == ERR_UNALIGNED_DESC, $sformatf("err code got=0x%08x", err));
    clear_irq(0);
  endtask

  task automatic t_slverr_rd();
    logic [31:0] st, err;
    current_test = "err_slverr_rd";
    sw_reset_ch(0);
    prep_buf(32'h0001_4000, 32'h0008_4000, 32, 8'hE1);
    u_mem.mem.set_err_range(32'h0001_4000, 32'h0001_401F, AXI_RESP_SLVERR, 1'b1, 1'b0);
    enable_irq(0);
    program_direct(0, 32'h0001_4000, 32'h0008_4000, 32, 3'd1);
    poll_ch(0, 10000, st);
    check(st[4] == 1'b1, $sformatf("SLVERR -> error status=0x%08x", st));
    bfm.rd(lc_ch_addr(0, CH_OFFSET_ERROR_STATUS), err);
    check(err[3:0] == ERR_AXI_SLVERR_RD, $sformatf("err code got=0x%08x", err));
    u_mem.mem.clear_err();
    clear_irq(0);
  endtask

  task automatic t_decerr_wr();
    logic [31:0] st, err;
    current_test = "err_decerr_wr";
    sw_reset_ch(0);
    prep_buf(32'h0001_5000, 32'h0008_5000, 16, 8'hE2);
    u_mem.mem.set_err_range(32'h0008_5000, 32'h0008_500F, AXI_RESP_DECERR, 1'b0, 1'b1);
    enable_irq(0);
    program_direct(0, 32'h0001_5000, 32'h0008_5000, 16, 3'd0);
    poll_ch(0, 10000, st);
    check(st[4] == 1'b1, $sformatf("DECERR write -> error status=0x%08x", st));
    bfm.rd(lc_ch_addr(0, CH_OFFSET_ERROR_STATUS), err);
    check(err[3:0] == ERR_AXI_DECERR_WR, $sformatf("err code got=0x%08x", err));
    u_mem.mem.clear_err();
    clear_irq(0);
  endtask

  task automatic t_pause_resume();
    logic [31:0] st;
    current_test = "pause_resume";
    sw_reset_ch(0);
    prep_buf(32'h0001_6000, 32'h0008_6000, 256, 8'hA1);
    enable_irq(0);
    program_direct(0, 32'h0001_6000, 32'h0008_6000, 256, 3'd4);
    bfm.wait_clk(8);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_CTRL), lc_ctrl_pause(3'd4));
    bfm.wait_clk(8);
    bfm.rd(lc_ch_addr(0, CH_OFFSET_STATUS), st);
    check(st[2] == 1'b1 || st[3] == 1'b1, $sformatf("paused or already done status=0x%08x", st));
    if (!st[3]) begin
      bfm.wr(lc_ch_addr(0, CH_OFFSET_CTRL), lc_ctrl_resume(3'd4));
      poll_ch(0, 20000, st);
    end
    check(st[3], $sformatf("completed after resume status=0x%08x", st));
    check_copy(32'h0001_6000, 32'h0008_6000, 256);
    clear_irq(0);
  endtask

  task automatic t_abort();
    logic [31:0] st;
    current_test = "abort";
    sw_reset_ch(0);
    prep_buf(32'h0001_7000, 32'h0008_7000, 256, 8'hA2);
    enable_irq(0);
    program_direct(0, 32'h0001_7000, 32'h0008_7000, 256, 3'd4);
    bfm.wait_clk(4);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_CTRL), lc_ctrl_abort(3'd4));
    bfm.wait_clk(16);
    bfm.rd(lc_ch_addr(0, CH_OFFSET_STATUS), st);
    check(st[0] == 1'b1, $sformatf("abort -> idle status=0x%08x", st));
    clear_irq(0);
  endtask

  task automatic t_ready_stall();
    logic [31:0] st;
    current_test = "ready_stall";
    sw_reset_ch(0);
    u_mem.set_stalls(2, 1, 2, 1, 1);
    prep_buf(32'h0001_8000, 32'h0008_8000, 64, 8'h33);
    enable_irq(0);
    program_direct(0, 32'h0001_8000, 32'h0008_8000, 64, 3'd2);
    poll_ch(0, 30000, st);
    check(st[3], $sformatf("stall transfer done status=0x%08x", st));
    check_copy(32'h0001_8000, 32'h0008_8000, 64);
    u_mem.set_always_ready();
    clear_irq(0);
  endtask

  task automatic t_outstanding();
    // 512B / 16 = 32 beats, max burst 16 => multiple outstanding reads possible
    t_direct_copy("outstanding", 0, 32'h0001_9000, 32'h0008_9000, 512, 3'd4, 8'h91);
  endtask

  task automatic t_sg_deep();
    logic [31:0] st, c0, c1, c2, c3;
    current_test = "sg_deep";
    sw_reset_ch(0);
    prep_buf(32'h0001_1000, 32'h0008_1000, 16, 8'hD1);
    prep_buf(32'h0001_2000, 32'h0008_2000, 32, 8'hD2);
    prep_buf(32'h0001_3000, 32'h0008_3000, 48, 8'hD3);
    prep_buf(32'h0001_4000, 32'h0008_4000, 64, 8'hD4);

    c0 = lc_desc_ctrl(1'b0, 3'd2);
    c1 = lc_desc_ctrl(1'b0, 3'd2);
    c2 = lc_desc_ctrl(1'b0, 3'd2);
    c3 = lc_desc_ctrl(1'b1, 3'd2);

    u_mem.mem.write_descriptor(32'h0000_3000, 32'h0001_1000, 32'h0008_1000, 16, c0, 32'h0000_3020, 0);
    u_mem.mem.write_descriptor(32'h0000_3020, 32'h0001_2000, 32'h0008_2000, 32, c1, 32'h0000_3040, 0);
    u_mem.mem.write_descriptor(32'h0000_3040, 32'h0001_3000, 32'h0008_3000, 48, c2, 32'h0000_3060, 0);
    u_mem.mem.write_descriptor(32'h0000_3060, 32'h0001_4000, 32'h0008_4000, 64, c3, 32'h0,          0);

    enable_irq(0);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_DESC_ADDR), 32'h0000_3000);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_BURST_CONFIG), 32'd2);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_CTRL), lc_ctrl_start(1'b1, 3'd2));
    poll_ch(0, 50000, st);
    check(st[3], $sformatf("SG deep done status=0x%08x", st));
    check(st[4] == 1'b0, $sformatf("SG deep no error status=0x%08x", st));
    check_copy(32'h0001_1000, 32'h0008_1000, 16);
    check_copy(32'h0001_2000, 32'h0008_2000, 32);
    check_copy(32'h0001_3000, 32'h0008_3000, 48);
    check_copy(32'h0001_4000, 32'h0008_4000, 64);
    clear_irq(0);
  endtask

  task automatic t_abort_race();
    logic [31:0] st;
    current_test = "abort_race";
    sw_reset_ch(0);
    prep_buf(32'h0001_B000, 32'h0008_B000, 512, 8'hE5);
    enable_irq(0);
    program_direct(0, 32'h0001_B000, 32'h0008_B000, 512, 3'd4);
    bfm.wait_clk(2);
    bfm.wr(lc_ch_addr(0, CH_OFFSET_CTRL), lc_ctrl_abort(3'd4));
    bfm.wait_clk(20);
    bfm.rd(lc_ch_addr(0, CH_OFFSET_STATUS), st);
    check(st[0] == 1'b1, $sformatf("abort race -> idle status=0x%08x", st));
    clear_irq(0);
  endtask

  task automatic t_cross_4kb_corner();
    t_direct_copy("cross_4kb_corner", 0, 32'h0000_FFF0, 32'h0008_FFF0, 64, 3'd4, 8'hE9);
  endtask

  task automatic run_one(string name);
    case (name)
      "reset_regs":         t_reset_regs();
      "axil_rw":            t_axil_rw();
      "direct_16b":         t_direct_copy("direct_16b", 0, 32'h0001_0000, 32'h0008_0000, 16, 3'd0, 8'hA0);
      "direct_64b":         t_direct_copy("direct_64b", 0, 32'h0001_0000, 32'h0008_0000, 64, 3'd4, 8'hA5);
      "direct_256b":        t_direct_copy("direct_256b", 0, 32'h0001_0000, 32'h0008_0000, 256, 3'd4, 8'h11);
      "unaligned":          t_unaligned();
      "cross_4kb":          t_4kb_cross();
      "multi_channel":      t_multi_channel();
      "arb_rr":             t_arb_mode("arb_rr", 1'b0);
      "arb_fixed":          t_arb_mode("arb_fixed", 1'b1);
      "sg_chain":           t_sg_chain();
      "irq":                t_irq();
      "err_zero_len":       t_zero_len();
      "err_unaligned_desc": t_unaligned_desc();
      "err_slverr_rd":      t_slverr_rd();
      "err_decerr_wr":      t_decerr_wr();
      "pause_resume":       t_pause_resume();
      "abort":              t_abort();
      "ready_stall":        t_ready_stall();
      "outstanding":        t_outstanding();
      "sg_deep":            t_sg_deep();
      "abort_race":         t_abort_race();
      "cross_4kb_corner":   t_cross_4kb_corner();
      default: begin
        $error("[LC] unknown test %s", name);
        fail_count++;
      end
    endcase
  endtask

  // --------------------------------------------------------------------------
  // Main
  // --------------------------------------------------------------------------
  initial begin
    string sel;
    pass_count = 0;
    fail_count = 0;
    skip_count = 0;
    bfm = new(axil_if, 2000);
    bfm.idle_bus();
    wait_mem_ready();

    if (!$value$plusargs("LC_TEST=%s", sel)) sel = "all";
    $display("[LC] Starting license-compatible directed run test=%s", sel);

    if (sel == "all") begin
      run_one("reset_regs");
      run_one("axil_rw");
      run_one("direct_16b");
      run_one("direct_64b");
      run_one("direct_256b");
      run_one("unaligned");
      run_one("cross_4kb");
      run_one("multi_channel");
      run_one("arb_rr");
      run_one("arb_fixed");
      run_one("sg_chain");
      run_one("irq");
      run_one("err_zero_len");
      run_one("err_unaligned_desc");
      run_one("err_slverr_rd");
      run_one("err_decerr_wr");
      run_one("pause_resume");
      run_one("abort");
      run_one("ready_stall");
      run_one("outstanding");
      run_one("sg_deep");
      run_one("abort_race");
      run_one("cross_4kb_corner");
    end else begin
      run_one(sel);
    end

    $display("============================================================");
    $display("[LC] RESULT pass=%0d fail=%0d skip=%0d bfm_errors=%0d",
             pass_count, fail_count, skip_count, bfm.error_count);
    if (fail_count == 0 && bfm.error_count == 0) begin
      $display("[LC] SUITE PASS");
      $finish(0);
    end else begin
      $display("[LC] SUITE FAIL");
      $finish(1);
    end
  end

  // Watchdog
  initial begin
    #50ms;
    $error("[LC] global watchdog timeout");
    $finish(1);
  end

endmodule : nx_dma_lc_tb
