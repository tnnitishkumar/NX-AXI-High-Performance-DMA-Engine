// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axil_seq_item.sv
// Description:   AXI4-Lite Sequence Item for Register Reads and Writes.
// ============================================================================

`ifndef NX_DMA_AXIL_SEQ_ITEM_SV
`define NX_DMA_AXIL_SEQ_ITEM_SV

class nx_dma_axil_seq_item extends uvm_sequence_item;
  `uvm_object_utils(nx_dma_axil_seq_item)

  rand logic [31:0] addr;
  rand logic [31:0] data;
  rand logic [3:0]  strb;
  rand bit          is_write;
  rand int          addr_delay;
  rand int          data_delay;

  logic [1:0]       resp;

  constraint c_default_strb {
    strb == 4'b1111;
  }

  constraint c_delays {
    addr_delay inside {[0:5]};
    data_delay inside {[0:5]};
  }

  function new(string name = "nx_dma_axil_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("AXIL Item: %s | Addr: 0x%08x | Data: 0x%08x | Strb: 4'b%04b | Resp: %0d",
                     is_write ? "WR" : "RD", addr, data, strb, resp);
  endfunction

endclass : nx_dma_axil_seq_item

`endif // NX_DMA_AXIL_SEQ_ITEM_SV
