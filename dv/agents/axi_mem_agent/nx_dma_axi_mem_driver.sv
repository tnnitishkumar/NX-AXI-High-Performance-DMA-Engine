// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_axi_mem_driver.sv
// Description:   AXI4 Reactive Slave Memory Driver. Services AR/R and AW/W/B
//                requests from the DMA Master and interfaces with the Memory Model.
// ============================================================================

`ifndef NX_DMA_AXI_MEM_DRIVER_SV
`define NX_DMA_AXI_MEM_DRIVER_SV

class nx_dma_axi_mem_driver extends uvm_driver #(nx_dma_axi_seq_item);
  `uvm_component_utils(nx_dma_axi_mem_driver)

  virtual nx_dma_axi_if vif;
  nx_dma_memory_model    mem_model;

  // Queue for pending Read requests
  typedef struct {
    logic [3:0]   id;
    logic [31:0]  addr;
    logic [7:0]   len;
    logic [2:0]   size;
    logic [1:0]   burst;
  } rd_req_t;

  rd_req_t rd_queue[$];

  // Queue for pending Write requests
  typedef struct {
    logic [3:0]   id;
    logic [31:0]  addr;
    logic [7:0]   len;
    logic [2:0]   size;
    logic [1:0]   burst;
  } wr_req_t;

  wr_req_t wr_queue[$];

  // Queue for pending Write responses
  typedef struct {
    logic [3:0]  id;
    logic [1:0]  resp;
  } b_resp_t;

  b_resp_t b_queue[$];

  // Read and Write response delays
  int ar_ready_delay = 0;
  int aw_ready_delay = 0;
  int w_ready_delay  = 0;
  int r_valid_delay  = 0;
  int b_valid_delay  = 0;

  function new(string name = "nx_dma_axi_mem_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual nx_dma_axi_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("AXI_MEM_DRV", "Virtual interface not found in config_db!")
    end
    if (!uvm_config_db#(nx_dma_memory_model)::get(this, "", "mem_model", mem_model)) begin
      `uvm_fatal("AXI_MEM_DRV", "Memory model not found in config_db!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    @(posedge vif.rst_n);
    @(posedge vif.clk);

    fork
      handle_ar_channel();
      handle_r_channel();
      handle_aw_channel();
      handle_w_channel();
      handle_b_channel();
    join
  endtask

  task reset_signals();
    vif.arready <= 1'b0;
    vif.rvalid  <= 1'b0;
    vif.rdata   <= '0;
    vif.rresp   <= 2'b00;
    vif.rlast   <= 1'b0;
    vif.rid     <= '0;

    vif.awready <= 1'b0;
    vif.wready  <= 1'b0;
    vif.bvalid  <= 1'b0;
    vif.bresp   <= 2'b00;
    vif.bid     <= '0;

    rd_queue.delete();
    wr_queue.delete();
    b_queue.delete();
  endtask

  // --------------------------------------------------------------------------
  // AR Channel Handler (Read Address)
  // --------------------------------------------------------------------------
  task handle_ar_channel();
    forever begin
      vif.arready <= 1'b1;
      @(posedge vif.clk);
      if (vif.arvalid && vif.arready) begin
        rd_req_t req;
        req.id    = vif.arid;
        req.addr  = vif.araddr;
        req.len   = vif.arlen;
        req.size  = vif.arsize;
        req.burst = vif.arburst;
        rd_queue.push_back(req);

        if (ar_ready_delay > 0) begin
          vif.arready <= 1'b0;
          repeat (ar_ready_delay) @(posedge vif.clk);
        end
      end
    end
  endtask

  // --------------------------------------------------------------------------
  // R Channel Handler (Read Data Return)
  // --------------------------------------------------------------------------
  task handle_r_channel();
    forever begin
      @(posedge vif.clk);
      if (rd_queue.size() > 0) begin
        rd_req_t req;
        int beats;
        logic [31:0] beat_addr;
        logic [1:0]  err_resp;
        bit          is_err;

        req = rd_queue.pop_front();
        beats = req.len + 1;
        beat_addr = {req.addr[31:4], 4'b0000}; // 16-byte aligned beat address

        // Check if burst triggers an error range
        is_err = mem_model.check_error(req.addr, 1'b0, err_resp);

        if (r_valid_delay > 0) begin
          repeat (r_valid_delay) @(posedge vif.clk);
        end

        for (int b = 0; b < beats; b++) begin
          logic [127:0] beat_data;
          beat_data = mem_model.read_128(beat_addr);

          vif.rvalid <= 1'b1;
          vif.rid    <= req.id;
          vif.rdata  <= beat_data;
          vif.rresp  <= is_err ? err_resp : 2'b00;
          vif.rlast  <= (b == beats - 1);

          do begin
            @(posedge vif.clk);
          end while (!vif.rready);

          beat_addr = beat_addr + 32'd16;
        end

        vif.rvalid <= 1'b0;
        vif.rlast  <= 1'b0;
      end
    end
  endtask

  // --------------------------------------------------------------------------
  // AW Channel Handler (Write Address)
  // --------------------------------------------------------------------------
  task handle_aw_channel();
    forever begin
      vif.awready <= 1'b1;
      @(posedge vif.clk);
      if (vif.awvalid && vif.awready) begin
        wr_req_t req;
        req.id    = vif.awid;
        req.addr  = vif.awaddr;
        req.len   = vif.awlen;
        req.size  = vif.awsize;
        req.burst = vif.awburst;
        wr_queue.push_back(req);

        if (aw_ready_delay > 0) begin
          vif.awready <= 1'b0;
          repeat (aw_ready_delay) @(posedge vif.clk);
        end
      end
    end
  endtask

  // --------------------------------------------------------------------------
  // W Channel Handler (Write Data Consumption)
  // --------------------------------------------------------------------------
  task handle_w_channel();
    forever begin
      @(posedge vif.clk);
      if (wr_queue.size() > 0) begin
        wr_req_t req;
        int beats;
        logic [31:0] beat_addr;
        logic [1:0]  err_resp;
        bit          is_err;
        b_resp_t     b_resp_item;

        req = wr_queue.pop_front();
        beats = req.len + 1;
        beat_addr = {req.addr[31:4], 4'b0000};

        is_err = mem_model.check_error(req.addr, 1'b1, err_resp);

        for (int b = 0; b < beats; b++) begin
          vif.wready <= 1'b1;
          do begin
            @(posedge vif.clk);
          end while (!vif.wvalid);

          // Write beat into backing memory model
          mem_model.write_128(beat_addr, vif.wdata, vif.wstrb);
          beat_addr = beat_addr + 32'd16;

          if (w_ready_delay > 0) begin
            vif.wready <= 1'b0;
            repeat (w_ready_delay) @(posedge vif.clk);
          end
        end

        vif.wready <= 1'b0;

        // Queue B response
        b_resp_item.id   = req.id;
        b_resp_item.resp = is_err ? err_resp : 2'b00;
        b_queue.push_back(b_resp_item);
      end
    end
  endtask

  // --------------------------------------------------------------------------
  // B Channel Handler (Write Response)
  // --------------------------------------------------------------------------
  task handle_b_channel();
    forever begin
      @(posedge vif.clk);
      if (b_queue.size() > 0) begin
        b_resp_t b_item;
        b_item = b_queue.pop_front();

        if (b_valid_delay > 0) begin
          repeat (b_valid_delay) @(posedge vif.clk);
        end

        vif.bvalid <= 1'b1;
        vif.bid    <= b_item.id;
        vif.bresp  <= b_item.resp;

        do begin
          @(posedge vif.clk);
        end while (!vif.bready);

        vif.bvalid <= 1'b0;
      end
    end
  endtask

endclass : nx_dma_axi_mem_driver

`endif // NX_DMA_AXI_MEM_DRIVER_SV
