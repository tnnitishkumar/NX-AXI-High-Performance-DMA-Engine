// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_coverage.sv
// Description:   Comprehensive Functional Coverage Model for NX-AXI DMA Engine.
//                Covers Register operations, DMA transfer configurations,
//                address alignments, burst lengths, 4KB boundary crossings,
//                arbitration modes, Scatter-Gather chains, and error conditions.
// ============================================================================

`ifndef NX_DMA_COVERAGE_SV
`define NX_DMA_COVERAGE_SV

class nx_dma_coverage extends uvm_subscriber #(nx_dma_axil_seq_item);
  `uvm_component_utils(nx_dma_coverage)

  // Analysis Imports for AXI and IRQ
  `uvm_analysis_imp_decl(_axi_cov)
  `uvm_analysis_imp_decl(_irq_cov)

  uvm_analysis_imp_axi_cov #(nx_dma_axi_seq_item, nx_dma_coverage) axi_cov_export;
  uvm_analysis_imp_irq_cov #(nx_dma_irq_seq_item, nx_dma_coverage) irq_cov_export;

  // Sampling variables for AXI-Lite
  logic [31:0] cur_axil_addr;
  logic [31:0] cur_axil_data;
  bit          cur_axil_is_write;

  // Sampling variables for DMA Config & Transfers
  int          cur_ch;
  logic [31:0] cur_src_addr;
  logic [31:0] cur_dst_addr;
  int          cur_length;
  int          cur_src_align;
  int          cur_dst_align;
  int          cur_burst_cfg;
  bit          cur_is_sg;
  int          cur_arb_mode;

  // Sampling variables for AXI bursts
  logic [7:0]  cur_axi_len;
  bit          cur_axi_is_write;
  logic [11:0] cur_page_offset;
  logic [1:0]  cur_axi_resp;

  // --------------------------------------------------------------------------
  // Covergroup 1: AXI-Lite Register Accesses
  // --------------------------------------------------------------------------
  covergroup cg_axil_registers;
    option.per_instance = 1;
    option.name = "cg_axil_registers";

    cp_addr: coverpoint cur_axil_addr[11:0] {
      // Channel 0 Registers
      bins ch0_ctrl      = {12'h000};
      bins ch0_cfg       = {12'h004};
      bins ch0_src       = {12'h008};
      bins ch0_dst       = {12'h00C};
      bins ch0_len       = {12'h010};
      bins ch0_next_desc = {12'h014};
      bins ch0_status    = {12'h018};
      bins ch0_irq_en    = {12'h020};
      bins ch0_irq_stat  = {12'h024};

      // Channel 1 Registers
      bins ch1_ctrl      = {12'h040};
      bins ch1_cfg       = {12'h044};
      bins ch1_src       = {12'h048};
      bins ch1_dst       = {12'h04C};
      bins ch1_len       = {12'h050};
      bins ch1_next_desc = {12'h054};
      bins ch1_status    = {12'h058};
      bins ch1_irq_en    = {12'h060};
      bins ch1_irq_stat  = {12'h064};

      // Channel 2 Registers
      bins ch2_ctrl      = {12'h080};
      bins ch2_cfg       = {12'h084};
      bins ch2_src       = {12'h088};
      bins ch2_dst       = {12'h08C};
      bins ch2_len       = {12'h090};
      bins ch2_next_desc = {12'h094};
      bins ch2_status    = {12'h098};
      bins ch2_irq_en    = {12'h0A0};
      bins ch2_irq_stat  = {12'h0A4};

      // Channel 3 Registers
      bins ch3_ctrl      = {12'h0C0};
      bins ch3_cfg       = {12'h0C4};
      bins ch3_src       = {12'h0C8};
      bins ch3_dst       = {12'h0CC};
      bins ch3_len       = {12'h0D0};
      bins ch3_next_desc = {12'h0D4};
      bins ch3_status    = {12'h0D8};
      bins ch3_irq_en    = {12'h0E0};
      bins ch3_irq_stat  = {12'h0E4};

      // Global Registers
      bins global_ctrl   = {12'h400};
      bins global_stat   = {12'h404};
      bins err_status    = {12'h408};
    }

    cp_rw: coverpoint cur_axil_is_write {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    cross_addr_rw: cross cp_addr, cp_rw;
  endgroup

  // --------------------------------------------------------------------------
  // Covergroup 2: DMA Transfer Configuration & Characteristics
  // --------------------------------------------------------------------------
  covergroup cg_dma_transfer;
    option.per_instance = 1;
    option.name = "cg_dma_transfer";

    cp_channel: coverpoint cur_ch {
      bins ch0 = {0};
      bins ch1 = {1};
      bins ch2 = {2};
      bins ch3 = {3};
    }

    cp_length: coverpoint cur_length {
      bins len_1B     = {1};
      bins len_2B     = {2};
      bins len_3B     = {3};
      bins len_4B     = {4};
      bins len_8B     = {8};
      bins len_15B    = {15};
      bins len_16B    = {16};
      bins len_32B    = {32};
      bins len_64B    = {64};
      bins len_128B   = {128};
      bins len_256B   = {256};
      bins len_512B   = {512};
      bins len_1KB    = {1024};
      bins len_2KB    = {2048};
      bins len_4KB    = {4096};
      bins len_8KB    = {8192};
      bins len_16KB   = {16384};
      bins len_64KB   = {65536};
      bins small_rand = {[5:14]};
      bins med_rand   = {[17:255]};
      bins large_rand = {[257:65535]};
    }

    cp_src_align: coverpoint cur_src_align {
      bins align_0  = {0};
      bins align_1  = {1};
      bins align_2  = {2};
      bins align_3  = {3};
      bins align_4  = {4};
      bins align_7  = {7};
      bins align_8  = {8};
      bins align_12 = {12};
      bins align_15 = {15};
      bins others   = {[0:15]};
    }

    cp_dst_align: coverpoint cur_dst_align {
      bins align_0  = {0};
      bins align_1  = {1};
      bins align_2  = {2};
      bins align_3  = {3};
      bins align_4  = {4};
      bins align_7  = {7};
      bins align_8  = {8};
      bins align_12 = {12};
      bins align_15 = {15};
      bins others   = {[0:15]};
    }

    cp_burst_size: coverpoint cur_burst_cfg {
      bins burst_1  = {0};
      bins burst_2  = {1};
      bins burst_4  = {2};
      bins burst_8  = {3};
      bins burst_16 = {4};
    }

    cp_mode: coverpoint cur_is_sg {
      bins direct         = {1'b0};
      bins scatter_gather = {1'b1};
    }

    cp_arb_mode: coverpoint cur_arb_mode {
      bins round_robin    = {0};
      bins fixed_priority = {1};
    }

    cross_alignments: cross cp_src_align, cp_dst_align;
    cross_ch_burst:   cross cp_channel, cp_burst_size;
    cross_ch_mode:    cross cp_channel, cp_mode;
  endgroup

  // --------------------------------------------------------------------------
  // Covergroup 3: AXI Master Bursts & 4KB Boundaries
  // --------------------------------------------------------------------------
  covergroup cg_axi_bursts;
    option.per_instance = 1;
    option.name = "cg_axi_bursts";

    cp_axi_len: coverpoint cur_axi_len {
      bins beat_1  = {0};
      bins beat_2  = {1};
      bins beat_4  = {3};
      bins beat_8  = {7};
      bins beat_16 = {15};
      bins others  = {[0:15]};
    }

    cp_axi_rw: coverpoint cur_axi_is_write {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    cp_page_offset: coverpoint cur_page_offset {
      bins page_start = {[0:15]};
      bins page_mid   = {[16:4079]};
      bins page_end   = {[4080:4095]};
    }

    cp_resp: coverpoint cur_axi_resp {
      bins okay   = {2'b00};
      bins slverr = {2'b10};
      bins decerr = {2'b11};
    }

    cross_len_rw: cross cp_axi_len, cp_axi_rw;
  endgroup

  function new(string name = "nx_dma_coverage", uvm_component parent = null);
    super.new(name, parent);
    axi_cov_export = new("axi_cov_export", this);
    irq_cov_export = new("irq_cov_export", this);

    cg_axil_registers = new();
    cg_dma_transfer   = new();
    cg_axi_bursts     = new();
  endfunction

  // Subscriber write implementation for AXI-Lite
  virtual function void write(nx_dma_axil_seq_item t);
    cur_axil_addr     = t.addr;
    cur_axil_data     = t.data;
    cur_axil_is_write = t.is_write;
    cg_axil_registers.sample();
  endfunction

  // Analysis implementation for AXI bursts
  function void write_axi_cov(nx_dma_axi_seq_item t);
    cur_axi_len      = t.len;
    cur_axi_is_write = t.is_write;
    cur_page_offset  = t.addr[11:0];
    cur_axi_resp     = t.is_write ? t.bresp : ((t.resp.size() > 0) ? t.resp[0] : 2'b00);
    cg_axi_bursts.sample();
  endfunction

  // Analysis implementation for IRQ events
  function void write_irq_cov(nx_dma_irq_seq_item t);
    // Samples IRQ coverage
  endfunction

  // Helper method to sample high-level transfer coverage
  function void sample_transfer(
    int          ch,
    logic [31:0] src,
    logic [31:0] dst,
    int          len,
    int          burst_cfg,
    bit          is_sg,
    int          arb_mode
  );
    cur_ch        = ch;
    cur_src_addr  = src;
    cur_dst_addr  = dst;
    cur_length    = len;
    cur_src_align = src[3:0];
    cur_dst_align = dst[3:0];
    cur_burst_cfg = burst_cfg;
    cur_is_sg     = is_sg;
    cur_arb_mode  = arb_mode;

    cg_dma_transfer.sample();
  endfunction

endclass : nx_dma_coverage

`endif // NX_DMA_COVERAGE_SV
