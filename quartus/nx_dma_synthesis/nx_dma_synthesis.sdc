# ==============================================================================
# SDC Timing Constraints Template for NX-AXI High-Performance DMA Engine
# ==============================================================================

# Define main core clock (e.g. 250 MHz / 4.0 ns period)
create_clock -name clk -period 4.000 [get_ports clk]

# Define AXI-Lite control clock if asynchronous, or set derivative constraints
# Here assuming synchronous single-clock domain clk for core and interfaces

set_clock_uncertainty 0.100 [get_clocks clk]

# Input and Output Delays (placeholder constraints for top-level I/O ports)
set_input_delay -clock clk -max 1.000 [get_ports s_axil_*]
set_input_delay -clock clk -min 0.200 [get_ports s_axil_*]

set_output_delay -clock clk -max 1.000 [get_ports s_axil_*]
set_output_delay -clock clk -min -0.200 [get_ports s_axil_*]

set_input_delay -clock clk -max 1.000 [get_ports m_axi_*]
set_input_delay -clock clk -min 0.200 [get_ports m_axi_*]

set_output_delay -clock clk -max 1.000 [get_ports m_axi_*]
set_output_delay -clock clk -min -0.200 [get_ports m_axi_*]
