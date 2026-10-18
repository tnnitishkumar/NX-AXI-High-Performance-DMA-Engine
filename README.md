# NX-AXI High-Performance DMA Engine

## 1. Project Overview

The **NX-AXI High-Performance DMA Engine** is a high-performance, multi-channel direct memory access (DMA) controller designed for AXI4 memory-mapped systems and AXI4-Lite control/status interfaces. It provides efficient burst data movement, scatter-gather descriptor chaining, dynamic channel arbitration (Round-Robin and Fixed Priority), advanced transaction tracking, robust error handling, and programmable interrupt management.

---

## 2. Feature List

Substantiated by RTL implementation and deterministic regression verification:
- **AXI4 Master Interface**: Supports unaligned transfers, burst slicing (ARM IHI 0022E A3.4.1), 4KB page boundary crossing handling, and outstanding read/write transaction tracking.
- **AXI4-Lite Slave Interface**: Register file access for channel control, source/destination addresses, transfer lengths, status reporting, and interrupt masks.
- **Multi-Channel Operation**: 4 independent DMA channels with hardware scheduling and priority arbitration.
- **Dynamic Channel Arbitration**: Round-Robin (RR) and Fixed Priority arbitration modes.
- **Scatter-Gather (SG) Descriptor Chaining**: Multi-descriptor linked lists with `next_desc_addr` pointer progression, end-of-chain (EOC) control, and deferred completion gated by `last_desc_q`.
- **Transaction Tracking & ID Synchronization**: Zero-skew alignment between allocation requests and AXI read/write engines.
- **Error Handling & Recovery**: Detection of zero-length errors, unaligned descriptors, AXI slave errors (SLVERR), and decode errors (DECERR), with channel status logging (W1C) and software reset (`CH_OFFSET_SW_RESET`).
- **Interrupt Management**: Channel-specific and global interrupt assertion monitoring and clear controls.

---

## 3. Architecture & RTL Hierarchy

The core design is structured into modular RTL blocks located in `rtl/`:

- `nx_dma_top.sv`: Top-level integration wrapping register file, scheduler, descriptor engine, read/write engines, and channels.
- `nx_dma_channel.sv`: Channel state machine and control logic for direct and scatter-gather transfers.
- `nx_dma_scheduler.sv`: Multi-channel arbitration (Round-Robin / Fixed Priority) and request scheduling.
- `nx_dma_descriptor_engine.sv`: Fetches and processes scatter-gather descriptors from memory.
- `nx_dma_axi_read_engine.sv`: Manages AXI4 read address and read data channels, burst slicing, and unaligned alignment.
- `nx_dma_axi_write_engine.sv`: Manages AXI4 write address and write data channels, write responses, and completion tracking.
- `nx_dma_transaction_tracker.sv`: Tracks outstanding transactions and ID synchronization.
- `nx_dma_data_buffer.sv`: Internal data FIFO buffering between read and write engines.
- `nx_dma_axi_lite_slave.sv`: Implements AXI4-Lite register access interface.
- `nx_dma_reg_file.sv`: DMA control, status, address, and counter register bank.
- `nx_dma_error_handler.sv`: Captures interface errors and fault codes.
- `nx_dma_interrupt.sv`: Generates channel and global interrupt signals (`irq`, `irq_ch`).
- `nx_dma_sva.sv`: SystemVerilog assertions for protocol and invariant verification.

---

## 4. Repository Structure

```
.
├── rtl/                          # Core RTL source files (SystemVerilog)
├── dv/
│   ├── license_compatible/       # Deterministic verification testbench & runner
│   │   ├── nx_dma_lc_tb.sv       # License-compatible testbench (27 tests)
│   │   ├── nx_dma_lc_axi_mem.sv  # Deterministic AXI4 slave memory BFM
│   │   ├── filelist.f            # Compilation file list
│   │   └── run_regression.sh     # Automated regression runner script
│   ├── agents/                   # UVM / verification agents
│   ├── env/                      # Verification environment
│   ├── interfaces/               # AXI4, AXI-Lite, and IRQ interfaces
│   ├── sequences/                # Verification sequences
│   ├── tests/                    # UVM test definitions
│   └── scoreboard/               # Scoreboard & reference model
├── quartus/
│   └── nx_dma_synthesis/         # Quartus Prime project files (.qpf, .qsf, .sdc)
└── README.md
```

---

## 5. Verification & Test Results

### Verification Frameworks
1. **UVM Environment (`dv/`)**: Full verification environment with constrained randomization and covergroups (requires Siemens `svverification` license).
2. **License-Compatible Environment (`dv/license_compatible/`)**: Deterministic verification framework designed to run under standard Questa editions without `svverification` licenses. Avoids `randomize()`, `randcase`, `randsequence`, and covergroups, relying on directed SystemVerilog test tasks and a programmable AXI memory BFM (`nx_dma_lc_axi_mem`).

### Observed Regression Results
Executing the license-compatible regression suite (`dv/license_compatible/run_regression.sh`):
- **Total Tests Executed**: 27
- **Passed**: 27
- **Failed**: 0
- **Exit Code**: `0`

#### Test Suite Breakdown (27 Tests)
1. `reset_regs`
2. `axil_rw`
3. `direct_16b`
4. `direct_64b`
5. `direct_256b`
6. `unaligned`
7. `cross_4kb`
8. `multi_channel`
9. `arb_rr`
10. `arb_fixed`
11. `sg_chain`
12. `irq`
13. `err_zero_len`
14. `err_unaligned_desc`
15. `err_slverr_rd`
16. `err_decerr_wr`
17. `pause_resume`
18. `abort`
19. `ready_stall`
20. `outstanding`
21. `sg_deep`
22. `abort_race`
23. `cross_4kb_corner`
24. `multi_channel_concurrency`
25. `error_recovery_restart`
26. `multi_channel_concurrency_stress`
27. `error_interrupt_assertion`

---

## 6. Tool Requirements & Usage

### Simulation Requirements
- **Simulator**: Questa Altera FPGA Edition (or compatible Questa/ModelSim supporting SystemVerilog).
- **Compiler Options**: GCC (`-dpicpppath /usr/bin/gcc`).

#### Running the Regression Suite
```bash
cd dv/license_compatible
./run_regression.sh
```
To run a single directed test:
```bash
./run_regression.sh error_interrupt_assertion
```

### Synthesis Status & Limitations
- **Synthesis Tool**: Intel Quartus Prime Pro Edition.
- **Project Files**: Located under `quartus/nx_dma_synthesis/`.
- **Current Status**: Synthesis and timing analysis (SDC 250 MHz / 4.0 ns clock constraint) have not yet successfully completed due to local environment device-family package limitations (specifically, the Quartus Stratix 10 device family package `quartus_map` error: `Family Stratix 10 is not installed`).

---

## 7. Engineering Status

| Capability | Status | Notes |
|---|---|---|
| **RTL Design** | Complete | All 13 core modules implemented under `rtl/` |
| **Simulation Verification** | Complete & Passing | 27/27 tests passing in license-compatible testbench |
| **Functional Coverage** | Not Measured | Requires `svverification` license |
| **Synthesis & P&R** | Pending Environment Setup | Blocked by missing Stratix 10 FPGA family package in local Quartus installation |
| **Hardware Validation** | Not Tested | Laboratory FPGA target validation pending |

---

## 8. License & Attribution

This project is proprietary engineering software. Please consult the repository owner for licensing and usage terms.
