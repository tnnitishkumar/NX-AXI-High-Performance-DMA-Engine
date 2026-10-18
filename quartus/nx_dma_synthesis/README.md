# NX-AXI High-Performance DMA Engine - Quartus Synthesis README

## Overview
This directory contains the Quartus Prime Pro Edition (v26.1.1) synthesis project configuration for the `nx_dma_top` top-level entity.

## Project Files
- `nx_dma_synthesis.qpf`: Quartus Project File
- `nx_dma_synthesis.qsf`: Quartus Settings File (specifying target device Agilex 7 `AGFB014R24B2E2V`, synthesizable RTL files, and SDC constraints)
- `nx_dma_synthesis.sdc`: Synopsys Design Constraints file (250 MHz clock definition and I/O delays)

## Running Synthesis (quartus_syn)
To run analysis and synthesis (elaboration and synthesis):
```bash
quartus_syn nx_dma_synthesis -c nx_dma_synthesis
```

## Running Full Flow (Synthesis -> Fitting -> STA -> Assembly)
```bash
quartus_sh --flow compile nx_dma_synthesis
```
