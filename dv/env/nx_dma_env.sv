// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_env.sv
// Description:   Top-Level UVM Verification Environment for NX-AXI DMA Engine.
//                Instantiates and connects agents, reference model, scoreboard,
//                coverage collector, and backing memory model.
// ============================================================================

`ifndef NX_DMA_ENV_SV
`define NX_DMA_ENV_SV

class nx_dma_env extends uvm_env;
  `uvm_component_utils(nx_dma_env)

  // Verification Components
  nx_dma_axil_agent    axil_agent;
  nx_dma_axi_mem_agent axi_mem_agent;
  nx_dma_irq_agent     irq_agent;
  nx_dma_memory_model  mem_model;
  nx_dma_ref_model     ref_model;
  nx_dma_scoreboard    scoreboard;
  nx_dma_coverage      coverage;

  function new(string name = "nx_dma_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // 1. Create Shared Memory Model
    mem_model = nx_dma_memory_model::type_id::create("mem_model");
    uvm_config_db#(nx_dma_memory_model)::set(this, "*", "mem_model", mem_model);

    // 2. Create UVM Agents
    axil_agent    = nx_dma_axil_agent::type_id::create("axil_agent", this);
    axi_mem_agent = nx_dma_axi_mem_agent::type_id::create("axi_mem_agent", this);
    irq_agent     = nx_dma_irq_agent::type_id::create("irq_agent", this);

    // Configure Agent activity
    uvm_config_db#(int)::set(this, "axil_agent", "is_active", UVM_ACTIVE);
    uvm_config_db#(int)::set(this, "axi_mem_agent", "is_active", UVM_ACTIVE);
    uvm_config_db#(int)::set(this, "irq_agent", "is_active", UVM_PASSIVE);

    // 3. Create Reference Model, Scoreboard, and Coverage
    ref_model  = nx_dma_ref_model::type_id::create("ref_model", this);
    scoreboard = nx_dma_scoreboard::type_id::create("scoreboard", this);
    coverage   = nx_dma_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // 1. Connect AXI-Lite Monitor -> Ref Model, Scoreboard, Coverage
    axil_agent.ap.connect(ref_model.axil_export);
    axil_agent.ap.connect(scoreboard.axil_export);
    axil_agent.ap.connect(coverage.analysis_export);

    // 2. Connect AXI Memory Monitor -> Ref Model, Scoreboard, Coverage
    axi_mem_agent.ap.connect(ref_model.axi_export);
    axi_mem_agent.ap.connect(scoreboard.axi_export);
    axi_mem_agent.ap.connect(coverage.axi_cov_export);

    // 3. Connect IRQ Monitor -> Scoreboard, Coverage
    irq_agent.ap.connect(scoreboard.irq_export);
    irq_agent.ap.connect(coverage.irq_cov_export);
  endfunction

endclass : nx_dma_env

`endif // NX_DMA_ENV_SV
