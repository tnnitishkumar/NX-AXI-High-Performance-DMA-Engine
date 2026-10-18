// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_mem_monitor.sv
// Description:   AXI4 Master/Slave Monitor. Observes all AXI Master transactions.
// ============================================================================

`ifndef NX_DMA_AXI_MEM_MONITOR_SV
`define NX_DMA_AXI_MEM_MONITOR_SV

class nx_dma_axi_mem_monitor extends uvm_monitor;
  `uvm_component_utils(nx_dma_axi_mem_monitor)

  virtual nx_dma_axi_if vif;
  uvm_analysis_port #(nx_dma_axi_seq_item) ap;

  function new(string name = "nx_dma_axi_mem_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual nx_dma_axi_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("AXI_MEM_MON", "Virtual interface not found in config_db!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    @(posedge vif.rst_n);
    fork
      monitor_reads();
      monitor_writes();
    join
  endtask

  task monitor_reads();
    typedef struct {
      logic [3:0]  id;
      logic [31:0] addr;
      logic [7:0]  len;
      logic [2:0]  size;
      logic [1:0]  burst;
    } ar_item_t;

    ar_item_t ar_queue[$];

    fork
      // Monitor AR
      forever begin
        @(posedge vif.clk);
        if (vif.arvalid && vif.arready) begin
          ar_item_t item;
          item.id    = vif.arid;
          item.addr  = vif.araddr;
          item.len   = vif.arlen;
          item.size  = vif.arsize;
          item.burst = vif.arburst;
          ar_queue.push_back(item);
        end
      end

      // Monitor R
      forever begin
        @(posedge vif.clk);
        if (vif.rvalid && vif.rready && ar_queue.size() > 0) begin
          ar_item_t ar_head = ar_queue[0];
          nx_dma_axi_seq_item item = nx_dma_axi_seq_item::type_id::create("item");
          int num_beats = ar_head.len + 1;

          item.is_write = 1'b0;
          item.id       = ar_head.id;
          item.addr     = ar_head.addr;
          item.len      = ar_head.len;
          item.size     = ar_head.size;
          item.burst    = ar_head.burst;
          item.data     = new[num_beats];
          item.resp     = new[num_beats];

          item.data[0] = vif.rdata;
          item.resp[0] = vif.rresp;

          for (int b = 1; b < num_beats; b++) begin
            do begin
              @(posedge vif.clk);
            end while (!(vif.rvalid && vif.rready));
            item.data[b] = vif.rdata;
            item.resp[b] = vif.rresp;
          end

          void'(ar_queue.pop_front());
          ap.write(item);
        end
      end
    join
  endtask

  task monitor_writes();
    typedef struct {
      logic [3:0]  id;
      logic [31:0] addr;
      logic [7:0]  len;
      logic [2:0]  size;
      logic [1:0]  burst;
    } aw_item_t;

    aw_item_t aw_queue[$];

    fork
      // Monitor AW
      forever begin
        @(posedge vif.clk);
        if (vif.awvalid && vif.awready) begin
          aw_item_t item;
          item.id    = vif.awid;
          item.addr  = vif.awaddr;
          item.len   = vif.awlen;
          item.size  = vif.awsize;
          item.burst = vif.awburst;
          aw_queue.push_back(item);
        end
      end

      // Monitor W and B
      forever begin
        @(posedge vif.clk);
        if (vif.wvalid && vif.wready && aw_queue.size() > 0) begin
          aw_item_t aw_head = aw_queue.pop_front();
          nx_dma_axi_seq_item item = nx_dma_axi_seq_item::type_id::create("item");
          int num_beats = aw_head.len + 1;

          item.is_write = 1'b1;
          item.id       = aw_head.id;
          item.addr     = aw_head.addr;
          item.len      = aw_head.len;
          item.size     = aw_head.size;
          item.burst    = aw_head.burst;
          item.data     = new[num_beats];
          item.strb     = new[num_beats];

          item.data[0] = vif.wdata;
          item.strb[0] = vif.wstrb;

          for (int b = 1; b < num_beats; b++) begin
            do begin
              @(posedge vif.clk);
            end while (!(vif.wvalid && vif.wready));
            item.data[b] = vif.wdata;
            item.strb[b] = vif.wstrb;
          end

          // Wait for B response
          while (!(vif.bvalid && vif.bready)) @(posedge vif.clk);
          item.bresp = vif.bresp;

          ap.write(item);
        end
      end
    join
  endtask

endclass : nx_dma_axi_mem_monitor

`endif // NX_DMA_AXI_MEM_MONITOR_SV
