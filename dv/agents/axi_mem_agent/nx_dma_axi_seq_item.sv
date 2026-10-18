// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_seq_item.sv
// Description:   AXI4 Master/Slave Transaction Sequence Item (128-bit Data).
// ============================================================================

`ifndef NX_DMA_AXI_SEQ_ITEM_SV
`define NX_DMA_AXI_SEQ_ITEM_SV

class nx_dma_axi_seq_item extends uvm_sequence_item;
  `uvm_object_utils(nx_dma_axi_seq_item)

  rand logic [3:0]   id;
  rand logic [31:0]  addr;
  rand logic [7:0]   len;       // ARLEN / AWLEN (beats - 1)
  rand logic [2:0]   size;      // ARSIZE / AWSIZE (4 = 16 bytes/beat)
  rand logic [1:0]   burst;     // 2'b01 = INCR
  rand bit           is_write;

  // Burst Data and Strobes
  rand logic [127:0] data[];
  rand logic [15:0]  strb[];
  logic [1:0]        resp[];
  logic [1:0]        bresp;

  // Timing / Delays
  rand int           ready_delay;
  rand int           beat_delay[];

  constraint c_default_fields {
    size == 3'b100; // 16 bytes (128-bit)
    burst == 2'b01; // INCR
  }

  constraint c_delays {
    ready_delay inside {[0:4]};
  }

  function new(string name = "nx_dma_axi_seq_item");
    super.new(name);
  endfunction

  function void post_randomize();
    int num_beats = len + 1;
    if (data.size() != num_beats) begin
      data = new[num_beats];
    end
    if (strb.size() != num_beats) begin
      strb = new[num_beats];
      foreach (strb[i]) strb[i] = 16'hFFFF;
    end
    if (beat_delay.size() != num_beats) begin
      beat_delay = new[num_beats];
      foreach (beat_delay[i]) beat_delay[i] = 0;
    end
  endfunction

  function string convert2string();
    return $sformatf("AXI Item: %s | ID: %0d | Addr: 0x%08x | Beats: %0d | Size: %0d",
                     is_write ? "WRITE" : "READ", id, addr, len + 1, size);
  endfunction

endclass : nx_dma_axi_seq_item

`endif // NX_DMA_AXI_SEQ_ITEM_SV
