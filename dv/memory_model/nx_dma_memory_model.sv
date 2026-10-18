// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_memory_model.sv
// Description:   Associative Backing Memory Model for AXI Slave Verification.
//                Supports byte/word/128-bit access, descriptor initialization,
//                range error injection (SLVERR/DECERR), and block comparison.
// ============================================================================

`ifndef NX_DMA_MEMORY_MODEL_SV
`define NX_DMA_MEMORY_MODEL_SV

class nx_dma_memory_model extends uvm_object;
  `uvm_object_utils(nx_dma_memory_model)

  // Byte storage array indexed by 32-bit byte address
  protected byte unsigned mem[logic [31:0]];

  // Error injection range definition
  typedef struct {
    logic [31:0] start_addr;
    logic [31:0] end_addr;
    logic [1:0]  err_resp; // 2'b10 = SLVERR, 2'b11 = DECERR
    bit          is_read;
    bit          is_write;
  } err_range_t;

  protected err_range_t err_ranges[$];

  function new(string name = "nx_dma_memory_model");
    super.new(name);
  endfunction

  // Clear memory and error ranges
  function void clear();
    mem.delete();
    err_ranges.delete();
  endfunction

  // Byte-level read and write
  function void write_byte(logic [31:0] addr, byte unsigned data);
    mem[addr] = data;
  endfunction

  function byte unsigned read_byte(logic [31:0] addr);
    if (mem.exists(addr)) begin
      return mem[addr];
    end else begin
      return 8'h00; // Uninitialized memory returns 0
    end
  endfunction

  // 32-bit Word access (Little Endian)
  function void write_word(logic [31:0] addr, logic [31:0] data);
    for (int i = 0; i < 4; i++) begin
      mem[addr + i] = data[i*8 +: 8];
    end
  endfunction

  function logic [31:0] read_word(logic [31:0] addr);
    logic [31:0] val = '0;
    for (int i = 0; i < 4; i++) begin
      val[i*8 +: 8] = read_byte(addr + i);
    end
    return val;
  endfunction

  // 128-bit Beat access with write strobes
  function void write_128(logic [31:0] addr, logic [127:0] data, logic [15:0] strb);
    for (int i = 0; i < 16; i++) begin
      if (strb[i]) begin
        mem[addr + i] = data[i*8 +: 8];
      end
    end
  endfunction

  function logic [127:0] read_128(logic [31:0] addr);
    logic [127:0] val = '0;
    for (int i = 0; i < 16; i++) begin
      val[i*8 +: 8] = read_byte(addr + i);
    end
    return val;
  endfunction

  // Block write from dynamic array
  function void write_block(logic [31:0] addr, const ref byte unsigned data_bytes[]);
    foreach (data_bytes[i]) begin
      mem[addr + i] = data_bytes[i];
    end
  endfunction

  // Block read into dynamic array
  function void read_block(logic [31:0] addr, int len_bytes, ref byte unsigned data_bytes[]);
    data_bytes = new[len_bytes];
    for (int i = 0; i < len_bytes; i++) begin
      data_bytes[i] = read_byte(addr + i);
    end
  endfunction

  // Initialize buffer with incremental or pattern data
  function void init_pattern(logic [31:0] addr, int len_bytes, byte unsigned seed = 8'hA0);
    for (int i = 0; i < len_bytes; i++) begin
      mem[addr + i] = byte'(seed + (i & 8'hFF));
    end
  endfunction

  // Write a 32-byte Scatter-Gather Descriptor into memory
  function void write_descriptor(
    logic [31:0] desc_addr,
    logic [31:0] src_addr,
    logic [31:0] dst_addr,
    logic [31:0] length_bytes,
    logic [31:0] ctrl,
    logic [31:0] next_desc_addr,
    logic [31:0] status = 32'h0
  );
    write_word(desc_addr + 32'd0,  src_addr);
    write_word(desc_addr + 32'd4,  dst_addr);
    write_word(desc_addr + 32'd8,  length_bytes);
    write_word(desc_addr + 32'd12, ctrl);
    write_word(desc_addr + 32'd16, next_desc_addr);
    write_word(desc_addr + 32'd20, status);
    write_word(desc_addr + 32'd24, 32'h0); // reserved0
    write_word(desc_addr + 32'd28, 32'h0); // reserved1
  endfunction

  // Compare source buffer against destination buffer
  function bit compare_blocks(
    logic [31:0] src_addr,
    logic [31:0] dst_addr,
    int          len_bytes,
    output int   mismatch_idx,
    output byte unsigned exp_b,
    output byte unsigned act_b
  );
    for (int i = 0; i < len_bytes; i++) begin
      byte unsigned s_val = read_byte(src_addr + i);
      byte unsigned d_val = read_byte(dst_addr + i);
      if (s_val !== d_val) begin
        mismatch_idx = i;
        exp_b        = s_val;
        act_b        = d_val;
        return 1'b0; // Mismatch detected
      end
    end
    mismatch_idx = -1;
    return 1'b1; // Identical
  endfunction

  // Error range injection
  function void add_error_range(
    logic [31:0] start_addr,
    logic [31:0] end_addr,
    logic [1:0]  err_resp,
    bit          is_read  = 1'b1,
    bit          is_write = 1'b1
  );
    err_range_t range;
    range.start_addr = start_addr;
    range.end_addr   = end_addr;
    range.err_resp   = err_resp;
    range.is_read    = is_read;
    range.is_write   = is_write;
    err_ranges.push_back(range);
  endfunction

  // Check if address hits an error injection range
  function bit check_error(
    logic [31:0] addr,
    bit          is_write_req,
    output logic [1:0] resp
  );
    foreach (err_ranges[i]) begin
      if (addr >= err_ranges[i].start_addr && addr <= err_ranges[i].end_addr) begin
        if ((is_write_req && err_ranges[i].is_write) || (!is_write_req && err_ranges[i].is_read)) begin
          resp = err_ranges[i].err_resp;
          return 1'b1;
        end
      end
    end
    resp = 2'b00; // OKAY
    return 1'b0;
  endfunction

endclass : nx_dma_memory_model

`endif // NX_DMA_MEMORY_MODEL_SV
