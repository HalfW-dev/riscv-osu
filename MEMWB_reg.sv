////////
// MEM/WB register
// Updated to carry RVFI signals (PC, Instruction, Raw Data, Memory Access)
///////

import riscv_pkg::*;
module MEMWB_reg #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32
)(
    input logic clk,
    input logic resetn,
`ifdef MEM_AXI4LITE
    input logic i_stall,
`endif

    // Data Inputs (Results from MEM stage)
    input logic [DATA_WIDTH-1:0] i_dmem_data,   // Data read from Memory (LSU output)
    input logic [DATA_WIDTH-1:0] i_rd_data,     // ALU Result (passed through MEM)
    input logic [4:0]            i_rd,          // Destination Register Address
    input logic [4:0]            i_rs1,
    input logic [4:0]            i_rs2,

    // Control Signals (Only those needed for WB)
    input logic                  i_RegWrite,    // Write Enable for RegFile
    input logic                  i_MemToReg,    // Mux Select (0=ALU, 1=Mem)

    // Outputs to WB Stage
    output logic [DATA_WIDTH-1:0] o_dmem_data,
    output logic [DATA_WIDTH-1:0] o_rd_data,
    output logic [4:0]            o_rd,
    output logic [4:0]            o_rs1,
    output logic [4:0]            o_rs2,
    
    output logic                  o_RegWrite,
    output logic                  o_MemToReg

`ifdef RISCV_FORMAL
    , // NEW: RVFI Pipeline Inputs
    input logic [ADDR_WIDTH-1:0] i_pc,
    input logic [INST_WIDTH-1:0] i_instruction,
    input logic [ADDR_WIDTH-1:0] i_next_pc,
    input logic [DATA_WIDTH-1:0] i_rs1_data_rvfi,
    input logic [DATA_WIDTH-1:0] i_rs2_data_rvfi,
    input logic [ADDR_WIDTH-1:0] i_branch_next_pc_rvfi,
    input logic [DATA_WIDTH-1:0] i_mem_addr,
    input logic [DATA_WIDTH-1:0] i_mem_wdata,
    input logic [DATA_WIDTH-1:0] i_mem_rdata_raw,
    input logic                  i_rvfi_valid,

    // NEW: RVFI Pipeline Outputs
    output logic [ADDR_WIDTH-1:0] o_pc,
    output logic [INST_WIDTH-1:0] o_instruction,
    output logic [ADDR_WIDTH-1:0] o_next_pc,
    output logic [DATA_WIDTH-1:0] o_rs1_data_rvfi,
    output logic [DATA_WIDTH-1:0] o_rs2_data_rvfi,
    output logic [ADDR_WIDTH-1:0] o_branch_next_pc_rvfi,
    output logic [ADDR_WIDTH-1:0] o_mem_addr,
    output logic [DATA_WIDTH-1:0] o_mem_wdata,
    output logic [DATA_WIDTH-1:0] o_mem_rdata_raw,
    output logic                  o_rvfi_valid
`endif
);

    // Sequential Logic
    always_ff @(posedge clk or negedge resetn) begin : propagate
        if (!resetn) begin
            // Data Reset
            o_dmem_data     <= '0;
            o_rd_data       <= '0;
            o_rd            <= '0;
            o_rs1           <= '0;
            o_rs2           <= '0;
            o_RegWrite      <= '0;
            o_MemToReg      <= '0;

`ifdef RISCV_FORMAL
            o_pc            <= '0;
            o_instruction   <= INST_NOP;
            o_next_pc       <= '0;
            o_rs1_data_rvfi <= '0;
            o_rs2_data_rvfi <= '0;
            o_branch_next_pc_rvfi <= '0;
            o_mem_addr      <= '0;
            o_mem_wdata     <= '0;
            o_mem_rdata_raw <= '0;
            o_rvfi_valid    <= 1'b0;
`endif

`ifdef MEM_AXI4LITE
        end else if (i_stall) begin
            // Bus stall: freeze — hold all outputs unchanged.
`endif
        end else begin
            // Data Propagation
            o_dmem_data     <= i_dmem_data;
            o_rd_data       <= i_rd_data;
            o_rd            <= i_rd;
            o_rs1           <= i_rs1;
            o_rs2           <= i_rs2;
            o_RegWrite      <= i_RegWrite;
            o_MemToReg      <= i_MemToReg;

`ifdef RISCV_FORMAL
            o_pc            <= i_pc;
            o_instruction   <= i_instruction;
            o_next_pc       <= i_next_pc;
            o_rs1_data_rvfi <= i_rs1_data_rvfi;
            o_rs2_data_rvfi <= i_rs2_data_rvfi;
            o_branch_next_pc_rvfi <= i_branch_next_pc_rvfi;
            o_mem_addr      <= i_mem_addr;
            o_mem_wdata     <= i_mem_wdata;
            o_mem_rdata_raw <= i_mem_rdata_raw;
            o_rvfi_valid    <= i_rvfi_valid;
`endif
        end
    end

endmodule