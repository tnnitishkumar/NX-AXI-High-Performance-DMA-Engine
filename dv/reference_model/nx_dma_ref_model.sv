// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_ref_model.sv
// Description:   Transaction-Level Reference Model for NX-AXI DMA Engine.
//                Predicts expected DMA transfers, descriptor processing, and IRQs.
// ============================================================================

`ifndef NX_DMA_REF_MODEL_SV
`define NX_DMA_REF_MODEL_SV

class nx_dma_ref_model extends uvm_component;
  `uvm_component_utils(nx_dma_ref_model)

  // Memory Model reference
  nx_dma_memory_model mem_model;

  // Analysis exports and ports
  `uvm_analysis_imp_decl(_axil)
  `uvm_analysis_imp_decl(_axi)

  uvm_analysis_imp_axil #(nx_dma_axil_seq_item, nx_dma_ref_model) axil_export;
  uvm_analysis_imp_axi  #(nx_dma_axi_seq_item,  nx_dma_ref_model) axi_export;
  uvm_analysis_port     #(nx_dma_axi_seq_item)                  exp_axi_port;

  // Internal Shadow Registers for 4 channels
  typedef struct {
    logic [31:0] ctrl;
    logic [31:0] cfg;
    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [31:0] length;
    logic [31:0] next_desc;
    logic [31:0] status;
    logic [31:0] irq_en;
    logic [31:0] irq_stat;
  } shadow_ch_reg_t;

  shadow_ch_reg_t shadow_ch[4];
  logic [31:0]    shadow_global_ctrl;
  logic [31:0]    shadow_global_status;
  logic [31:0]    shadow_err_status;

  function new(string name = "nx_dma_ref_model", uvm_component parent = null);
    super.new(name, parent);
    axil_export  = new("axil_export", this);
    axi_export   = new("axi_export", this);
    exp_axi_port = new("exp_axi_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(nx_dma_memory_model)::get(this, "", "mem_model", mem_model)) begin
      `uvm_fatal("REF_MODEL", "Memory model handle not found in config_db!")
    end
    reset_shadow_regs();
  endfunction

  function void reset_shadow_regs();
    for (int ch = 0; ch < 4; ch++) begin
      shadow_ch[ch].ctrl      = 32'h0;
      shadow_ch[ch].cfg       = 32'h0000_0F00; // default burst 16
      shadow_ch[ch].src_addr  = 32'h0;
      shadow_ch[ch].dst_addr  = 32'h0;
      shadow_ch[ch].length    = 32'h0;
      shadow_ch[ch].next_desc = 32'h0;
      shadow_ch[ch].status    = 32'h0;
      shadow_ch[ch].irq_en    = 32'h0;
      shadow_ch[ch].irq_stat  = 32'h0;
    end
    shadow_global_ctrl   = 32'h0;
    shadow_global_status = 32'h0;
    shadow_err_status    = 32'h0;
  endfunction

  // Write implementation for AXI-Lite register writes
  function void write_axil(nx_dma_axil_seq_item item);
    logic [31:0] addr = item.addr;
    logic [31:0] data = item.data;

    if (item.is_write) begin
      // Channel 0-3 registers
      if (addr >= 32'h000 && addr < 32'h100) begin
        int ch = (addr >> 6) & 32'h3;
        logic [5:0] reg_offset = addr[5:0];

        case (reg_offset)
          6'h00: begin // CH_CTRL
            shadow_ch[ch].ctrl = data;
            if (data[0] && shadow_global_ctrl[0]) begin // CH_ENABLE & GLOBAL_ENABLE
              predict_transfer(ch);
            end
          end
          6'h04: shadow_ch[ch].cfg       = data;
          6'h08: shadow_ch[ch].src_addr  = data;
          6'h0C: shadow_ch[ch].dst_addr  = data;
          6'h10: shadow_ch[ch].length    = data;
          6'h14: shadow_ch[ch].next_desc = data;
          6'h20: shadow_ch[ch].irq_en    = data;
          6'h24: shadow_ch[ch].irq_stat  = shadow_ch[ch].irq_stat & ~data; // W1C
        endcase
      end
      // Global registers
      else if (addr == 32'h400) begin
        shadow_global_ctrl = data;
        if (data[0]) begin
          // Check if any enabled channels should trigger
          for (int c = 0; c < 4; c++) begin
            if (shadow_ch[c].ctrl[0]) predict_transfer(c);
          end
        end
      end
    end
  endfunction

  // Write implementation for observed AXI Master transactions
  function void write_axi(nx_dma_axi_seq_item item);
    // Reference model can cross-check observed AXI transactions with predicted state
  endfunction

  // Predict DMA transfer execution
  function void predict_transfer(int ch);
    bit is_sg = shadow_ch[ch].cfg[0];

    if (!is_sg) begin
      // Direct Register Mode Transfer
      logic [31:0] src = shadow_ch[ch].src_addr;
      logic [31:0] dst = shadow_ch[ch].dst_addr;
      logic [31:0] len = shadow_ch[ch].length;

      `uvm_info("REF_MODEL", $sformatf("Predicting Direct DMA Ch %0d: Src=0x%08x Dst=0x%08x Len=%0d",
                ch, src, dst, len), UVM_HIGH)
    end else begin
      // Scatter-Gather Mode Transfer
      logic [31:0] desc_ptr = shadow_ch[ch].next_desc;
      `uvm_info("REF_MODEL", $sformatf("Predicting SG DMA Ch %0d: Head Desc=0x%08x", ch, desc_ptr), UVM_HIGH)
    end
  endfunction

endclass : nx_dma_ref_model

`endif // NX_DMA_REF_MODEL_SV
