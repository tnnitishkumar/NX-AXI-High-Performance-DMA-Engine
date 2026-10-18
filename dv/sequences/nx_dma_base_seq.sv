// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_base_seq.sv
// Description:   Base Sequence for NX-AXI DMA Engine Verification.
//                Provides low-level register access API, channel polling,
//                transfer initiation, and descriptor configuration utilities.
// ============================================================================

`ifndef NX_DMA_BASE_SEQ_SV
`define NX_DMA_BASE_SEQ_SV

class nx_dma_base_seq extends uvm_sequence #(nx_dma_axil_seq_item);
  `uvm_object_utils(nx_dma_base_seq)

  // Register Offsets
  localparam logic [31:0] REG_GLOBAL_CTRL   = 32'h400;
  localparam logic [31:0] REG_GLOBAL_STATUS = 32'h404;
  localparam logic [31:0] REG_ERR_STATUS    = 32'h408;

  function new(string name = "nx_dma_base_seq");
    super.new(name);
  endfunction

  // --------------------------------------------------------------------------
  // Register Read/Write Helpers
  // --------------------------------------------------------------------------
  task reg_write(logic [31:0] addr, logic [31:0] data);
    nx_dma_axil_seq_item item;
    item = nx_dma_axil_seq_item::type_id::create("item");
    start_item(item);
    item.is_write = 1'b1;
    item.addr     = addr;
    item.data     = data;
    finish_item(item);
  endtask

  task reg_read(logic [31:0] addr, output logic [31:0] data);
    nx_dma_axil_seq_item item;
    item = nx_dma_axil_seq_item::type_id::create("item");
    start_item(item);
    item.is_write = 1'b0;
    item.addr     = addr;
    finish_item(item);
    data = item.data;
  endtask

  // Channel Register Offset Calculators
  function logic [31:0] ch_reg(int ch, logic [5:0] offset);
    return 32'h000 + (ch * 32'h40) + offset;
  endfunction

  // --------------------------------------------------------------------------
  // Global & Channel Control Helpers
  // --------------------------------------------------------------------------
  task enable_dma_global(int arb_mode = 0);
    // Bit 0 = Global Enable, Bit 1 = Arb Mode (0: RR, 1: Priority)
    reg_write(REG_GLOBAL_CTRL, 32'h1 | (arb_mode << 1));
  endtask

  task disable_dma_global();
    reg_write(REG_GLOBAL_CTRL, 32'h0);
  endtask

  task reset_channel(int ch);
    reg_write(ch_reg(ch, 6'h00), 32'h2); // CH_RESET
  endtask

  // --------------------------------------------------------------------------
  // Direct Register-Mode Transfer Configuration & Execution
  // --------------------------------------------------------------------------
  task configure_and_start_direct(
    int          ch,
    logic [31:0] src_addr,
    logic [31:0] dst_addr,
    logic [31:0] length_bytes,
    int          burst_cfg  = 4, // 16 beats (4'b0100)
    int          irq_enable = 1
  );
    // 1. Set Config (Direct mode = bit 0 is 0, burst_cfg in bits [11:8])
    reg_write(ch_reg(ch, 6'h04), (burst_cfg << 8));

    // 2. Set Source and Destination addresses
    reg_write(ch_reg(ch, 6'h08), src_addr);
    reg_write(ch_reg(ch, 6'h0C), dst_addr);

    // 3. Set Transfer Length
    reg_write(ch_reg(ch, 6'h10), length_bytes);

    // 4. Configure IRQ Enable if requested
    if (irq_enable) begin
      reg_write(ch_reg(ch, 6'h20), 32'hF); // Enable EOC, DESC_DONE, HALF, ERR
    end

    // 5. Start Channel (Bit 0 = CH_ENABLE / START)
    reg_write(ch_reg(ch, 6'h00), 32'h1);
  endtask

  // --------------------------------------------------------------------------
  // Scatter-Gather Transfer Configuration & Execution
  // --------------------------------------------------------------------------
  task configure_and_start_sg(
    int          ch,
    logic [31:0] head_desc_addr,
    int          burst_cfg  = 4,
    int          irq_enable = 1
  );
    // 1. Set Config (SG mode = bit 0 is 1, burst_cfg in bits [11:8])
    reg_write(ch_reg(ch, 6'h04), 32'h1 | (burst_cfg << 8));

    // 2. Set Head Descriptor Address
    reg_write(ch_reg(ch, 6'h14), head_desc_addr);

    // 3. Configure IRQ Enable
    if (irq_enable) begin
      reg_write(ch_reg(ch, 6'h20), 32'hF);
    end

    // 4. Start Channel
    reg_write(ch_reg(ch, 6'h00), 32'h1);
  endtask

  // --------------------------------------------------------------------------
  // Polling Channel Completion
  // --------------------------------------------------------------------------
  task poll_channel_idle(int ch, int max_polls = 1000);
    logic [31:0] status;
    int polls = 0;
    do begin
      reg_read(ch_reg(ch, 6'h18), status); // CH_STATUS
      polls++;
      if (polls > max_polls) begin
        `uvm_error("POLL_TIMEOUT", $sformatf("Channel %0d completion timeout! Status=0x%08x", ch, status))
        break;
      end
    end while (status[0] == 1'b1); // While Busy
  endtask

  task clear_channel_irq(int ch);
    reg_write(ch_reg(ch, 6'h24), 32'hF); // W1C all IRQ status bits
  endtask

endclass : nx_dma_base_seq

`endif // NX_DMA_BASE_SEQ_SV
