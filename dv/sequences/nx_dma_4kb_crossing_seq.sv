// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_4kb_crossing_seq.sv
// Description:   4KB Page Boundary Crossing Verification Sequence.
//                Targets boundary-straddling addresses to ensure the DMA burst
//                splitting engine truncates bursts at page boundaries correctly.
// ============================================================================

`ifndef NX_DMA_4KB_CROSSING_SEQ_SV
`define NX_DMA_4KB_CROSSING_SEQ_SV

class nx_dma_4kb_crossing_seq extends nx_dma_base_seq;
  `uvm_object_utils(nx_dma_4kb_crossing_seq)

  rand int          channel_id;
  rand logic [31:0] src_addr;
  rand logic [31:0] dst_addr;
  rand logic [31:0] length_bytes;
  rand int          burst_cfg;

  constraint c_channel {
    channel_id inside {[0:3]};
  }

  constraint c_boundary_cross {
    // Force start address within 256 bytes of 4KB boundary (offset in [4096-256 : 4095])
    src_addr[11:0] inside {[12'hF00 : 12'hFE0]};
    dst_addr[11:0] inside {[12'hF00 : 12'hFE0]};
    src_addr[31:12] == 20'h00010;
    dst_addr[31:12] == 20'h00020;
    length_bytes inside {[256 : 1024]}; // Guaranteed to cross 4KB boundary
    burst_cfg == 4; // Max 16-beat bursts
  }

  function new(string name = "nx_dma_4kb_crossing_seq");
    super.new(name);
  endfunction

  virtual task body();
    nx_dma_memory_model mem_model;

    if (!uvm_config_db#(nx_dma_memory_model)::get(m_sequencer, "", "mem_model", mem_model)) begin
      `uvm_fatal("4KB_SEQ", "Memory model not found in config_db!")
    end

    // 1. Initialize Pattern & Clear Destination
    mem_model.init_pattern(src_addr, length_bytes, 8'hD5);
    for (int i = 0; i < length_bytes; i++) begin
      mem_model.write_byte(dst_addr + i, 8'h00);
    end

    // 2. Enable Global DMA
    enable_dma_global(0);

    // 3. Configure & Start Transfer
    `uvm_info("4KB_SEQ", $sformatf(
      "Starting 4KB Crossing Transfer: Ch %0d | Src=0x%08x (Offset 0x%03x) | Dst=0x%08x (Offset 0x%03x) | Len=%0d Bytes",
      channel_id, src_addr, src_addr[11:0], dst_addr, dst_addr[11:0], length_bytes), UVM_LOW)

    configure_and_start_direct(channel_id, src_addr, dst_addr, length_bytes, burst_cfg);

    // 4. Poll Completion
    poll_channel_idle(channel_id, 5000);
    clear_channel_irq(channel_id);

    // 5. Verify Data Integrity
    begin
      int mismatch_idx;
      byte unsigned exp_b, act_b;
      bit match;

      match = mem_model.compare_blocks(src_addr, dst_addr, length_bytes, mismatch_idx, exp_b, act_b);
      if (!match) begin
        `uvm_error("4KB_SEQ", $sformatf(
          "4KB Crossing Data Mismatch on Ch %0d! Offset +%0d: Exp=0x%02x, Act=0x%02x",
          channel_id, mismatch_idx, exp_b, act_b))
      end else begin
        `uvm_info("4KB_SEQ", $sformatf(
          "4KB Crossing Transfer Verified on Ch %0d (%0d Bytes Match)", channel_id, length_bytes), UVM_LOW)
      end
    end
  endtask

endclass : nx_dma_4kb_crossing_seq

`endif // NX_DMA_4KB_CROSSING_SEQ_SV
