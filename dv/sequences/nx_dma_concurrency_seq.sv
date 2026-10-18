// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_concurrency_seq.sv
// Description:   Multi-Channel Concurrent DMA Transfer Sequence.
//                Simultaneously programs and activates all 4 channels to test
//                interleaved AXI bus arbitration, FIFO flow control, and multi-ID tracking.
// ============================================================================

`ifndef NX_DMA_CONCURRENCY_SEQ_SV
`define NX_DMA_CONCURRENCY_SEQ_SV

class nx_dma_concurrency_seq extends nx_dma_base_seq;
  `uvm_object_utils(nx_dma_concurrency_seq)

  rand int          arb_mode;
  rand int          transfer_lens[4];
  rand logic [31:0] src_bases[4];
  rand logic [31:0] dst_bases[4];
  rand int          burst_cfgs[4];

  constraint c_arb {
    arb_mode inside {0, 1};
  }

  constraint c_transfers {
    foreach (transfer_lens[i]) {
      transfer_lens[i] inside {[64 : 2048]};
      burst_cfgs[i] inside {[0 : 4]};
      src_bases[i] == (32'h0001_0000 + i * 32'h0001_0000);
      dst_bases[i] == (32'h0008_0000 + i * 32'h0001_0000);
    }
  }

  function new(string name = "nx_dma_concurrency_seq");
    super.new(name);
  endfunction

  virtual task body();
    nx_dma_memory_model mem_model;

    if (!uvm_config_db#(nx_dma_memory_model)::get(m_sequencer, "", "mem_model", mem_model)) begin
      `uvm_fatal("CONC_SEQ", "Memory model not found in config_db!")
    end

    // 1. Initialize all 4 Channel Source and Destination Buffers
    for (int ch = 0; ch < 4; ch++) begin
      mem_model.init_pattern(src_bases[ch], transfer_lens[ch], byte'(8'hC0 + ch*8'h10));
      for (int i = 0; i < transfer_lens[ch]; i++) begin
        mem_model.write_byte(dst_bases[ch] + i, 8'h00);
      end
    end

    // 2. Enable Global DMA
    enable_dma_global(arb_mode);

    // 3. Configure and Launch all 4 Channels in Rapid Succession
    `uvm_info("CONC_SEQ", $sformatf(
      "Launching 4 Concurrent Channels (ArbMode=%0s)...", (arb_mode == 0) ? "Round-Robin" : "Fixed-Priority"), UVM_LOW)

    for (int ch = 0; ch < 4; ch++) begin
      configure_and_start_direct(ch, src_bases[ch], dst_bases[ch], transfer_lens[ch], burst_cfgs[ch]);
    end

    // 4. Poll all Channels for Completion
    for (int ch = 0; ch < 4; ch++) begin
      poll_channel_idle(ch, 10000);
      clear_channel_irq(ch);
    end

    // 5. Verify Data Integrity across all 4 Channels
    for (int ch = 0; ch < 4; ch++) begin
      int mismatch_idx;
      byte unsigned exp_b, act_b;
      bit match;

      match = mem_model.compare_blocks(src_bases[ch], dst_bases[ch], transfer_lens[ch], mismatch_idx, exp_b, act_b);
      if (!match) begin
        `uvm_error("CONC_SEQ", $sformatf(
          "Concurrent Transfer Mismatch on Ch %0d! Offset +%0d: Exp=0x%02x, Act=0x%02x",
          ch, mismatch_idx, exp_b, act_b))
      end else begin
        `uvm_info("CONC_SEQ", $sformatf(
          "Concurrent Transfer Verified on Ch %0d (%0d Bytes Match)", ch, transfer_lens[ch]), UVM_LOW)
      end
    end
  endtask

endclass : nx_dma_concurrency_seq

`endif // NX_DMA_CONCURRENCY_SEQ_SV
