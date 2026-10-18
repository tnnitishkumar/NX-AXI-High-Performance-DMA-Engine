// ============================================================================
// Design:        NX-AXI High-Performance DMA Engine
// File:          nx_dma_random_stress_seq.sv
// Description:   Constrained-Random Multi-Channel Stress Sequence.
//                Generates randomized direct, SG, aligned/unaligned, and
//                boundary-crossing transfers across all 4 DMA channels.
// ============================================================================

`ifndef NX_DMA_RANDOM_STRESS_SEQ_SV
`define NX_DMA_RANDOM_STRESS_SEQ_SV

class nx_dma_random_stress_seq extends nx_dma_base_seq;
  `uvm_object_utils(nx_dma_random_stress_seq)

  int num_iterations = 20;

  function new(string name = "nx_dma_random_stress_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("STRESS_SEQ", $sformatf("Starting Constrained-Random Stress Sequence (%0d Iterations)...", num_iterations), UVM_LOW)

    for (int iter = 0; iter < num_iterations; iter++) begin
      int seq_type = $urandom_range(0, 3);
      `uvm_info("STRESS_SEQ", $sformatf("--- Stress Iteration %0d/%0d (Type: %0d) ---", iter+1, num_iterations, seq_type), UVM_MEDIUM)

      case (seq_type)
        0, 1: begin // Direct Transfer
          nx_dma_direct_transfer_seq dir_seq;
          dir_seq = nx_dma_direct_transfer_seq::type_id::create("dir_seq");
          if (!dir_seq.randomize()) `uvm_fatal("STRESS_SEQ", "Randomization failed for dir_seq")
          dir_seq.start(m_sequencer);
        end

        2: begin // SG Transfer
          nx_dma_sg_transfer_seq sg_seq;
          sg_seq = nx_dma_sg_transfer_seq::type_id::create("sg_seq");
          if (!sg_seq.randomize()) `uvm_fatal("STRESS_SEQ", "Randomization failed for sg_seq")
          sg_seq.start(m_sequencer);
        end

        3: begin // 4KB Crossing Transfer
          nx_dma_4kb_crossing_seq cross_seq;
          cross_seq = nx_dma_4kb_crossing_seq::type_id::create("cross_seq");
          if (!cross_seq.randomize()) `uvm_fatal("STRESS_SEQ", "Randomization failed for cross_seq")
          cross_seq.start(m_sequencer);
        end
      endcase
    end

    `uvm_info("STRESS_SEQ", "Constrained-Random Stress Sequence Completed Successfully.", UVM_LOW)
  endtask

endclass : nx_dma_random_stress_seq

`endif // NX_DMA_RANDOM_STRESS_SEQ_SV
