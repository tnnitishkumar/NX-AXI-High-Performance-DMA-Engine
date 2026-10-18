# License-Compatible NX-AXI Verification Path

This directory is a separate deterministic verification path for the production
NX-AXI RTL. It does not modify or replace the existing UVM environment and does
not duplicate the RTL.

## Intent

The Questa environment available for this project does not provide the Siemens
`svverification` feature. The production UVM tests use constrained randomization
and covergroups, so they remain preserved under `dv/` and are not used here.

This path intentionally avoids:

- `randomize()`
- `randcase`
- `randsequence`
- covergroups
- UVM

It uses deterministic SystemVerilog tasks, the existing AXI-Lite and AXI4
interfaces, the production `nx_dma_top`, the existing SVA module, and a
byte-addressed AXI4 memory slave with explicit READY stalls and response-error
injection.

## Run

```bash
cd "/home/nitish/Documents/NX-AXI High-Performance DMA Engine/dv/license_compatible"
./run_regression.sh
./run_regression.sh reset_regs
```

The runner compiles, elaborates, and runs each directed test with
`-dpicpppath /usr/bin/gcc`. Logs are written under `sim/logs/`.

## Directed scope

The testbench contains deterministic tests for:

- reset and register defaults
- AXI-Lite register reads/writes and unmapped-read response
- direct transfers at several sizes
- unaligned transfers
- 4KB boundary crossing
- multi-channel transfers
- round-robin and fixed-priority scheduler modes
- scatter-gather descriptor chain
- interrupt status, global IRQ, and W1C clear
- zero-length and unaligned-descriptor errors
- AXI SLVERR/DECERR injection
- pause/resume and abort controls
- READY backpressure
- multi-burst/outstanding request behavior

A test is only considered passing when the simulation emits its directed
checks and ends with `[LC] SUITE PASS`. Compilation or elaboration alone is
not a functional PASS.

## Coverage statement

Functional coverage: **NOT MEASURED**.

Reason: `svverification` license unavailable. The deterministic path contains
no covergroups. Any code coverage experiment must be reported separately and
only from actual simulator output.
