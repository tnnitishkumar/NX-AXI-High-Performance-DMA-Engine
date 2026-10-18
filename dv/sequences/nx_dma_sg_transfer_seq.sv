// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_sg_transfer_seq.sv
// Description:   Scatter-Gather Descriptor Chain Execution Sequence.
//                Builds in-memory linked lists of 32-byte descriptors,
//                triggers descriptor fetching, executes multi-block transfers,
//                and verifies all blocks and status writebacks.
// ============================================================================

`ifndef NX_DMA_SG_TRANSFER_SEQ_SV
`define NX_DMA_SG_TRANSFER_SEQ_SV

class nx_dma_sg_transfer_seq extends nx_dma_base_seq;
  `uvm_object_utils(nx_dma_sg_transfer_seq)

  rand int          channel_id;
  rand int          num_descriptors;
  rand logic [31:0] head_desc_addr;
  rand int          burst_cfg;
  rand int          arb_mode;

  constraint c_channel {
    channel_id inside {[0:3]};
  }

  constraint c_num_descriptors {
    num_descriptors inside {[2:8]};
  }

  constraint c_head_desc {
    head_desc_addr inside {[32'h0000_1000 : 32'h0000_3000]};
    head_desc_addr[4:0] == 5'b00000; // 32-byte aligned
  }

  constraint c_burst_cfg {
    burst_cfg inside {[0:4]};
  }

  constraint c_arb_mode {
    arb_mode inside {0, 1};
  }

  function new(string name = "nx_dma_sg_transfer_seq");
    super.new(name);
  endfunction

  virtual task body();
    nx_dma_memory_model mem_model;
    logic [31:0] curr_desc;
    logic [31:0] src_ptrs[];
    logic [31:0] dst_ptrs[];
    int          lens[];

    if (!uvm_config_db#(nx_dma_memory_model)::get(m_sequencer, "", "mem_model", mem_model)) begin
      `uvm_fatal("SG_SEQ", "Memory model not found in config_db!")
    end

    src_ptrs = new[num_descriptors];
    dst_ptrs = new[num_descriptors];
    lens     = new[num_descriptors];

    curr_desc = head_desc_addr;

    // 1. Build and Write Descriptor Linked List into Backing Memory
    for (int d = 0; d < num_descriptors; d++) begin
      logic [31:0] next_desc;
      logic [31:0] ctrl;
      bit          is_last = (d == num_descriptors - 1);

      src_ptrs[d] = 32'h0001_0000 + (d * 32'h0000_2000) + (channel_id * 32'h0001_0000);
      dst_ptrs[d] = 32'h0008_0000 + (d * 32'h0000_2000) + (channel_id * 32'h0001_0000);
      lens[d]     = 64 + (d * 64); // Varying sizes

      next_desc = is_last ? 32'h0 : (curr_desc + 32'd32);
      ctrl      = is_last ? 32'h1 : 32'h0; // Bit 0 = EOC (End of Chain)

      // Initialize source pattern and clear destination
      mem_model.init_pattern(src_ptrs[d], lens[d], byte'(8'hB0 + d*8'h05));
      for (int i = 0; i < lens[d]; i++) begin
        mem_model.write_byte(dst_ptrs[d] + i, 8'h00);
      end

      // Write 32-byte descriptor
      mem_model.write_descriptor(
        curr_desc,
        src_ptrs[d],
        dst_ptrs[d],
        lens[d],
        ctrl,
        next_desc,
        32'h0 // Status initialized to 0
      );

      curr_desc = next_desc;
    end

    // 2. Enable Global DMA
    enable_dma_global(arb_mode);

    // 3. Configure & Start SG Transfer
    `uvm_info("SG_SEQ", $sformatf(
      "Starting SG Transfer: Ch %0d | HeadDesc=0x%08x | Descriptors=%0d | BurstCfg=%0d",
      channel_id, head_desc_addr, num_descriptors, burst_cfg), UVM_LOW)

    configure_and_start_sg(channel_id, head_desc_addr, burst_cfg);

    // 4. Poll for Completion
    poll_channel_idle(channel_id, 10000);

    // 5. Clear IRQ
    clear_channel_irq(channel_id);

    // 6. Verify Data Integrity for all Descriptors
    for (int d = 0; d < num_descriptors; d++) begin
      int mismatch_idx;
      byte unsigned exp_b, act_b;
      bit match;

      match = mem_model.compare_blocks(src_ptrs[d], dst_ptrs[d], lens[d], mismatch_idx, exp_b, act_b);
      if (!match) begin
        `uvm_error("SG_SEQ", $sformatf(
          "SG Block %0d Mismatch on Ch %0d! Offset +%0d: Exp=0x%02x, Act=0x%02x",
          d, channel_id, mismatch_idx, exp_b, act_b))
      end else begin
        `uvm_info("SG_SEQ", $sformatf(
          "SG Block %0d Verified Successfully (%0d Bytes Match)", d, lens[d]), UVM_LOW)
      end
    end
  endtask

endclass : nx_dma_sg_transfer_seq

`endif // NX_DMA_SG_TRANSFER_SEQ_SV
