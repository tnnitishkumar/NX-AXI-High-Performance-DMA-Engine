// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_irq_seq_item.sv
// Description:   Interrupt Monitor Sequence Item.
// ============================================================================

`ifndef NX_DMA_IRQ_SEQ_ITEM_SV
`define NX_DMA_IRQ_SEQ_ITEM_SV

class nx_dma_irq_seq_item extends uvm_sequence_item;
  `uvm_object_utils(nx_dma_irq_seq_item)

  logic       irq;
  logic [3:0] irq_ch;
  time        timestamp;

  function new(string name = "nx_dma_irq_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("IRQ Item: irq=%0b | irq_ch=4'b%04b @ %0t", irq, irq_ch, timestamp);
  endfunction

endclass : nx_dma_irq_seq_item

`endif // NX_DMA_IRQ_SEQ_ITEM_SV
