// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_error_inject_seq.sv
// Description:   Error Injection and Exception Handling Verification Sequence.
//                Injects AXI SLVERR/DECERR, zero-length requests, and unaligned
//                descriptors to verify robust error containment and reporting.
// ============================================================================

`ifndef NX_DMA_ERROR_INJECT_SEQ_SV
`define NX_DMA_ERROR_INJECT_SEQ_SV

class nx_dma_error_inject_seq extends nx_dma_base_seq;
  `uvm_object_utils(nx_dma_error_inject_seq)

  rand int error_type; // 0: Read SLVERR, 1: Write SLVERR, 2: Zero-Length, 3: Unaligned Desc

  constraint c_err {
    error_type inside {[0:3]};
  }

  function new(string name = "nx_dma_error_inject_seq");
    super.new(name);
  endfunction

  virtual task body();
    nx_dma_memory_model mem_model;
    logic [31:0] err_stat, ch_stat;

    if (!uvm_config_db#(nx_dma_memory_model)::get(m_sequencer, "", "mem_model", mem_model)) begin
      `uvm_fatal("ERR_SEQ", "Memory model not found in config_db!")
    end

    enable_dma_global(0);

    case (error_type)
      0: begin // Read SLVERR Injection
        logic [31:0] src = 32'h0001_5000;
        logic [31:0] dst = 32'h0008_5000;
        `uvm_info("ERR_SEQ", "Injecting AXI Read SLVERR on address 0x0001_5000...", UVM_LOW)
        mem_model.add_error_range(src, src + 32'h100, 2'b10, 1'b1, 1'b0);

        configure_and_start_direct(0, src, dst, 256, 4);
        poll_channel_idle(0, 2000);

        reg_read(REG_ERR_STATUS, err_stat);
        reg_read(ch_reg(0, 6'h18), ch_stat);
        `uvm_info("ERR_SEQ", $sformatf("Read Error Status: 0x%08x | Ch0 Status: 0x%08x", err_stat, ch_stat), UVM_LOW)

        // Clear error and reset channel
        reset_channel(0);
        reg_write(REG_ERR_STATUS, 32'hFFFF_FFFF);
        mem_model.clear();
      end

      1: begin // Write SLVERR Injection
        logic [31:0] src = 32'h0001_6000;
        logic [31:0] dst = 32'h0008_6000;
        `uvm_info("ERR_SEQ", "Injecting AXI Write SLVERR on address 0x0008_6000...", UVM_LOW)
        mem_model.init_pattern(src, 256, 8'hEE);
        mem_model.add_error_range(dst, dst + 32'h100, 2'b10, 1'b0, 1'b1);

        configure_and_start_direct(1, src, dst, 256, 4);
        poll_channel_idle(1, 2000);

        reg_read(REG_ERR_STATUS, err_stat);
        reg_read(ch_reg(1, 6'h18), ch_stat);
        `uvm_info("ERR_SEQ", $sformatf("Write Error Status: 0x%08x | Ch1 Status: 0x%08x", err_stat, ch_stat), UVM_LOW)

        reset_channel(1);
        reg_write(REG_ERR_STATUS, 32'hFFFF_FFFF);
        mem_model.clear();
      end

      2: begin // Zero-Length Configuration
        `uvm_info("ERR_SEQ", "Testing Zero-Length Configuration Error...", UVM_LOW)
        configure_and_start_direct(2, 32'h0001_7000, 32'h0008_7000, 32'h0, 4);
        poll_channel_idle(2, 500);

        reg_read(ch_reg(2, 6'h18), ch_stat);
        `uvm_info("ERR_SEQ", $sformatf("Zero-Length Ch2 Status: 0x%08x", ch_stat), UVM_LOW)
        reset_channel(2);
      end

      3: begin // Unaligned Descriptor Address Error
        `uvm_info("ERR_SEQ", "Testing Unaligned SG Descriptor Address (0x0000_1004)...", UVM_LOW)
        configure_and_start_sg(3, 32'h0000_1004, 4); // Not 32-byte aligned
        poll_channel_idle(3, 500);

        reg_read(REG_ERR_STATUS, err_stat);
        `uvm_info("ERR_SEQ", $sformatf("Unaligned Desc Error Status: 0x%08x", err_stat), UVM_LOW)
        reset_channel(3);
        reg_write(REG_ERR_STATUS, 32'hFFFF_FFFF);
      end
    endcase
  endtask

endclass : nx_dma_error_inject_seq

`endif // NX_DMA_ERROR_INJECT_SEQ_SV
