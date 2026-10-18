// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_scoreboard.sv
// Description:   Comprehensive UVM Scoreboard for NX-AXI DMA Engine.
//                Performs end-to-end data integrity checks, protocol verification,
//                4KB boundary compliance checks, descriptor chain validation,
//                and statistical reporting.
// ============================================================================

`ifndef NX_DMA_SCOREBOARD_SV
`define NX_DMA_SCOREBOARD_SV

class nx_dma_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(nx_dma_scoreboard)

  // Memory Model reference
  nx_dma_memory_model mem_model;

  // Analysis Imports
  `uvm_analysis_imp_decl(_axil)
  `uvm_analysis_imp_decl(_axi)
  `uvm_analysis_imp_decl(_irq)

  uvm_analysis_imp_axil #(nx_dma_axil_seq_item, nx_dma_scoreboard) axil_export;
  uvm_analysis_imp_axi  #(nx_dma_axi_seq_item,  nx_dma_scoreboard) axi_export;
  uvm_analysis_imp_irq  #(nx_dma_irq_seq_item,  nx_dma_scoreboard) irq_export;

  // Scoreboard Verification Statistics
  int unsigned num_direct_transfers_checked = 0;
  int unsigned num_sg_transfers_checked     = 0;
  int unsigned num_sg_descriptors_checked   = 0;
  longint unsigned total_bytes_verified     = 0;
  int unsigned num_axi_read_bursts_checked  = 0;
  int unsigned num_axi_write_bursts_checked = 0;
  int unsigned num_4kb_checks_passed        = 0;
  int unsigned num_irq_events_checked       = 0;
  int unsigned num_errors_detected_checked  = 0;
  int unsigned num_mismatches               = 0;

  function new(string name = "nx_dma_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    axil_export = new("axil_export", this);
    axi_export  = new("axi_export", this);
    irq_export  = new("irq_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(nx_dma_memory_model)::get(this, "", "mem_model", mem_model)) begin
      `uvm_fatal("SCOREBOARD", "Memory model handle not found in config_db!")
    end
  endfunction

  // --------------------------------------------------------------------------
  // AXI-Lite Register Transaction Analysis
  // --------------------------------------------------------------------------
  function void write_axil(nx_dma_axil_seq_item item);
    if (item.resp != 2'b00) begin
      `uvm_warning("SCOREBOARD", $sformatf("AXI-Lite transaction returned non-OKAY response: %0b", item.resp))
    end
  endfunction

  // --------------------------------------------------------------------------
  // AXI4 Master Memory Burst Transaction Analysis & Protocol Check
  // --------------------------------------------------------------------------
  function void write_axi(nx_dma_axi_seq_item item);
    int num_beats = item.len + 1;
    int burst_bytes = num_beats * (1 << item.size);
    logic [11:0] page_offset = item.addr[11:0];

    // 1. Check 4KB Boundary Crossing Protection
    if ((page_offset + burst_bytes) > 4096) begin
      `uvm_error("SCOREBOARD", $sformatf(
        "4KB Boundary Crossing Violation! Addr=0x%08x, Beats=%0d, Size=%0d, EndAddr=0x%08x",
        item.addr, num_beats, item.size, item.addr + burst_bytes))
      num_mismatches++;
    end else begin
      num_4kb_checks_passed++;
    end

    // 2. Check Burst Size (128-bit = 16 bytes/beat = size 3'b100)
    if (item.size != 3'b100) begin
      `uvm_error("SCOREBOARD", $sformatf("Invalid AXI size: %0d (Expected 4 for 128-bit)", item.size))
      num_mismatches++;
    end

    // 3. Check Burst Type (INCR = 2'b01)
    if (item.burst != 2'b01) begin
      `uvm_error("SCOREBOARD", $sformatf("Invalid AXI burst type: %0b (Expected 2'b01 INCR)", item.burst))
      num_mismatches++;
    end

    // Update Statistics
    if (item.is_write) begin
      num_axi_write_bursts_checked++;
    end else begin
      num_axi_read_bursts_checked++;
    end
  endfunction

  // --------------------------------------------------------------------------
  // IRQ Event Analysis
  // --------------------------------------------------------------------------
  function void write_irq(nx_dma_irq_seq_item item);
    num_irq_events_checked++;
    `uvm_info("SCOREBOARD", $sformatf("Observed IRQ transition: irq=%0b, irq_ch=4'b%04b",
              item.irq, item.irq_ch), UVM_HIGH)
  endfunction

  // --------------------------------------------------------------------------
  // Verification Utility: Verify Direct DMA Transfer Buffer Integrity
  // --------------------------------------------------------------------------
  function bit verify_direct_transfer(
    int          ch,
    logic [31:0] src_addr,
    logic [31:0] dst_addr,
    int          len_bytes
  );
    int           mismatch_idx;
    byte unsigned exp_b, act_b;
    bit           match;

    match = mem_model.compare_blocks(src_addr, dst_addr, len_bytes, mismatch_idx, exp_b, act_b);

    if (!match) begin
      `uvm_error("SCOREBOARD", $sformatf(
        "DATA MISMATCH on Ch %0d! Src=0x%08x, Dst=0x%08x, Len=%0d | First Mismatch at Byte Offset +%0d: Expected=0x%02x, Actual=0x%02x",
        ch, src_addr, dst_addr, len_bytes, mismatch_idx, exp_b, act_b))
      num_mismatches++;
      return 1'b0;
    end else begin
      `uvm_info("SCOREBOARD", $sformatf(
        "DATA INTEGRITY VERIFIED on Ch %0d! Src=0x%08x -> Dst=0x%08x (%0d Bytes Match Perfectly)",
        ch, src_addr, dst_addr, len_bytes), UVM_MEDIUM)
      num_direct_transfers_checked++;
      total_bytes_verified += len_bytes;
      return 1'b1;
    end
  endfunction

  // --------------------------------------------------------------------------
  // Verification Utility: Verify Scatter-Gather Descriptor Chain Integrity
  // --------------------------------------------------------------------------
  function bit verify_sg_chain(
    int          ch,
    logic [31:0] head_desc_addr,
    int          max_descriptors = 64
  );
    logic [31:0] curr_desc = head_desc_addr;
    int          desc_cnt  = 0;
    bit          all_match = 1'b1;

    while (curr_desc != 32'h0 && desc_cnt < max_descriptors) begin
      logic [31:0] src_addr, dst_addr, len_bytes, ctrl, next_desc, status;
      int           mismatch_idx;
      byte unsigned exp_b, act_b;
      bit           match;

      src_addr   = mem_model.read_word(curr_desc + 32'd0);
      dst_addr   = mem_model.read_word(curr_desc + 32'd4);
      len_bytes  = mem_model.read_word(curr_desc + 32'd8);
      ctrl       = mem_model.read_word(curr_desc + 32'd12);
      next_desc  = mem_model.read_word(curr_desc + 32'd16);
      status     = mem_model.read_word(curr_desc + 32'd20);

      // Verify Data Buffer Integrity for this descriptor
      match = mem_model.compare_blocks(src_addr, dst_addr, len_bytes, mismatch_idx, exp_b, act_b);
      if (!match) begin
        `uvm_error("SCOREBOARD", $sformatf(
          "SG DATA MISMATCH on Ch %0d, Desc #%0d (Addr=0x%08x)! Src=0x%08x, Dst=0x%08x, Len=%0d | Offset +%0d: Exp=0x%02x, Act=0x%02x",
          ch, desc_cnt, curr_desc, src_addr, dst_addr, len_bytes, mismatch_idx, exp_b, act_b))
        num_mismatches++;
        all_match = 1'b0;
      end else begin
        total_bytes_verified += len_bytes;
        num_sg_descriptors_checked++;
      end

      // Check if this was the End of Chain
      if (ctrl[0] == 1'b1) begin // EOC bit set
        break;
      end

      curr_desc = next_desc;
      desc_cnt++;
    end

    if (all_match) begin
      num_sg_transfers_checked++;
      `uvm_info("SCOREBOARD", $sformatf(
        "SG CHAIN VERIFIED on Ch %0d! Head=0x%08x (%0d Descriptors Verified Successfully)",
        ch, head_desc_addr, desc_cnt + 1), UVM_MEDIUM)
    end

    return all_match;
  endfunction

  // --------------------------------------------------------------------------
  // Check and Report Phases
  // --------------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (num_mismatches > 0) begin
      `uvm_error("SCOREBOARD", $sformatf("CHECK PHASE FAILED: %0d Data/Protocol Mismatches Detected!", num_mismatches))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCOREBOARD", "==================================================================", UVM_NONE)
    `uvm_info("SCOREBOARD", "             NX-AXI DMA SCOREBOARD VERIFICATION REPORT             ", UVM_NONE)
    `uvm_info("SCOREBOARD", "==================================================================", UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf(" Direct Transfers Verified   : %0d", num_direct_transfers_checked), UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf(" SG Chains Verified          : %0d", num_sg_transfers_checked), UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf(" SG Descriptors Verified     : %0d", num_sg_descriptors_checked), UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf(" Total Payload Data Verified : %0d Bytes (%0.2f KB)", total_bytes_verified, total_bytes_verified / 1024.0), UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf(" AXI Read Bursts Monitored   : %0d", num_axi_read_bursts_checked), UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf(" AXI Write Bursts Monitored  : %0d", num_axi_write_bursts_checked), UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf(" 4KB Boundary Checks Passed  : %0d", num_4kb_checks_passed), UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf(" IRQ Events Monitored        : %0d", num_irq_events_checked), UVM_NONE)
    `uvm_info("SCOREBOARD", $sformatf(" Mismatches / Violations     : %0d", num_mismatches), UVM_NONE)
    `uvm_info("SCOREBOARD", "==================================================================", UVM_NONE)
    if (num_mismatches == 0) begin
      `uvm_info("SCOREBOARD", " STATUS: ALL CHECKS PASSED PERFECTLY (100% DATA INTEGRITY)         ", UVM_NONE)
    end else begin
      `uvm_error("SCOREBOARD", " STATUS: FAILED WITH MISMATCHES                                   ")
    end
    `uvm_info("SCOREBOARD", "==================================================================", UVM_NONE)
  endfunction

endclass : nx_dma_scoreboard

`endif // NX_DMA_SCOREBOARD_SV
