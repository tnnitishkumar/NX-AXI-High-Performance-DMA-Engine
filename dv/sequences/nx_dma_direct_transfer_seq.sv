// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_direct_transfer_seq.sv
// Description:   Direct Register-Mode Transfer Sequence.
//                Executes aligned/unaligned, single/multi-burst DMA transfers
//                and coordinates with backing memory model for data integrity.
// ============================================================================

`ifndef NX_DMA_DIRECT_TRANSFER_SEQ_SV
`define NX_DMA_DIRECT_TRANSFER_SEQ_SV

class nx_dma_direct_transfer_seq extends nx_dma_base_seq;
  `uvm_object_utils(nx_dma_direct_transfer_seq)

  // Transfer parameters
  rand int          channel_id;
  rand logic [31:0] src_addr;
  rand logic [31:0] dst_addr;
  rand logic [31:0] length_bytes;
  rand int          burst_cfg;
  rand int          arb_mode;

  // Constraints
  constraint c_channel {
    channel_id inside {[0:3]};
  }

  constraint c_burst_cfg {
    burst_cfg inside {[0:4]}; // 1, 2, 4, 8, 16 beats
  }

  constraint c_arb_mode {
    arb_mode inside {0, 1};
  }

  constraint c_addresses {
    src_addr inside {[32'h0001_0000 : 32'h0007_FFFF]};
    dst_addr inside {[32'h0008_0000 : 32'h000F_FFFF]};
    (src_addr + length_bytes) < dst_addr;
  }

  constraint c_length {
    length_bytes inside {[1 : 4096]};
  }

  function new(string name = "nx_dma_direct_transfer_seq");
    super.new(name);
  endfunction

  virtual task body();
    nx_dma_memory_model mem_model;
    nx_dma_scoreboard   scb;
    byte unsigned seed;

    if (!uvm_config_db#(nx_dma_memory_model)::get(m_sequencer, "", "mem_model", mem_model)) begin
      `uvm_fatal("DIRECT_SEQ", "Memory model not found in config_db!")
    end

    // 1. Initialize Source Buffer with test pattern in backing memory
    seed = byte'(8'hA0 + channel_id*8'h10 + length_bytes[7:0]);
    mem_model.init_pattern(src_addr, length_bytes, seed);

    // 2. Clear Destination Buffer in backing memory
    for (int i = 0; i < length_bytes; i++) begin
      mem_model.write_byte(dst_addr + i, 8'h00);
    end

    // 3. Enable Global DMA
    enable_dma_global(arb_mode);

    // 4. Configure & Start Channel Transfer
    `uvm_info("DIRECT_SEQ", $sformatf(
      "Starting Direct Transfer: Ch %0d | Src=0x%08x | Dst=0x%08x | Len=%0d Bytes | BurstCfg=%0d | ArbMode=%0d",
      channel_id, src_addr, dst_addr, length_bytes, burst_cfg, arb_mode), UVM_LOW)

    configure_and_start_direct(channel_id, src_addr, dst_addr, length_bytes, burst_cfg);

    // 5. Poll for Channel Completion
    poll_channel_idle(channel_id, 5000);

    // 6. Clear IRQ
    clear_channel_irq(channel_id);

    // 7. Verify Data Integrity via Memory Model
    begin
      int mismatch_idx;
      byte unsigned exp_b, act_b;
      bit match;

      match = mem_model.compare_blocks(src_addr, dst_addr, length_bytes, mismatch_idx, exp_b, act_b);
      if (!match) begin
        `uvm_error("DIRECT_SEQ", $sformatf(
          "Direct DMA Data Mismatch on Ch %0d! First error at offset +%0d: Expected=0x%02x, Actual=0x%02x",
          channel_id, mismatch_idx, exp_b, act_b))
      end else begin
        `uvm_info("DIRECT_SEQ", $sformatf(
          "Direct DMA Verified Successfully on Ch %0d (%0d Bytes Match)", channel_id, length_bytes), UVM_LOW)
      end
    end
  endtask

endclass : nx_dma_direct_transfer_seq

`endif // NX_DMA_DIRECT_TRANSFER_SEQ_SV
