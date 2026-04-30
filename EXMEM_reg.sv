////////
// EX/MEM register
// Updated to carry RVFI signals (PC, Instruction, Raw Data)
///////

import riscv_pkg::*;
module EXMEM_reg #(
    parameter ADDR_WIDTH = 32,
    parameter INST_COUNT = 37, //for RV32I
    parameter DATA_WIDTH = 32,
    parameter INST_WIDTH = 32
)(
    input  logic                   clk,
    input  logic                   resetn,
`ifdef MEM_AXI4LITE
    input  logic                   i_stall,
`endif

    // Existing Data Inputs
    input  logic [DATA_WIDTH-1:0]  i_rs1_data,
    input  logic [DATA_WIDTH-1:0]  i_rs2_data,
    input  logic [DATA_WIDTH-1:0]  i_rd_data, // ALU Result
    input  logic [4:0]             i_rd,
    input  logic [4:0]             i_rs1,
    input  logic [4:0]             i_rs2,
    input  logic [$clog2(INST_COUNT)-1:0] i_ALUOp,
    input  logic                   i_MemRead,
    input  logic                   i_MemWrite,
    input  logic                   i_RegWrite,
    input  logic                   i_MemToReg,

    // Existing Data Outputs
    output logic [DATA_WIDTH-1:0]  o_rs1_data,
    output logic [DATA_WIDTH-1:0]  o_rs2_data,
    output logic [DATA_WIDTH-1:0]  o_rd_data,
    output logic [4:0]             o_rd,
    output logic [4:0]             o_rs1,
    output logic [4:0]             o_rs2,
    output logic [$clog2(INST_COUNT)-1:0] o_ALUOp,
    output logic                   o_MemRead,
    output logic                   o_MemWrite,
    output logic                   o_RegWrite,
    output logic                   o_MemToReg

`ifdef RISCV_FORMAL
    , // NEW: RVFI Pipeline Inputs
    input  logic [ADDR_WIDTH-1:0]  i_pc,
    input  logic [INST_WIDTH-1:0]  i_instruction,
    input  logic [ADDR_WIDTH-1:0]  i_next_pc,
    input  logic [DATA_WIDTH-1:0]  i_rs1_data_rvfi, // Raw/Forwarded data for verification
    input  logic [DATA_WIDTH-1:0]  i_rs2_data_rvfi,
    input  logic [ADDR_WIDTH-1:0]  i_branch_next_pc_rvfi,

    // NEW: RVFI Pipeline Outputs
    output logic [ADDR_WIDTH-1:0]  o_pc,
    output logic [INST_WIDTH-1:0]  o_instruction,
    output logic [ADDR_WIDTH-1:0]  o_next_pc,
    output logic [DATA_WIDTH-1:0]  o_rs1_data_rvfi,
    output logic [DATA_WIDTH-1:0]  o_rs2_data_rvfi,
    output logic [ADDR_WIDTH-1:0]  o_branch_next_pc_rvfi,
    input  logic                   i_rvfi_valid,
    output logic                   o_rvfi_valid
`endif
);

    always_ff @(posedge clk or negedge resetn) begin
        if(!resetn) begin
            // Data Reset
            o_rs1_data      <= '0;
            o_rs2_data      <= '0;
            o_rd_data       <= '0;
            o_rd            <= '0;
            o_rs1           <= '0;
            o_rs2           <= '0;
            
            // Control Reset
            o_ALUOp         <= '0;
            o_MemRead       <= '0;
            o_MemWrite      <= '0;
            o_RegWrite      <= '0;
            o_MemToReg      <= '0;

`ifdef RISCV_FORMAL
            o_pc            <= '0;
            o_instruction   <= INST_NOP;
            o_next_pc       <= '0;
            o_rs1_data_rvfi <= '0;
            o_rs2_data_rvfi <= '0;
            o_branch_next_pc_rvfi <= '0;
            o_rvfi_valid    <= 1'b0;
`endif

`ifdef MEM_AXI4LITE
        end else if (i_stall) begin
            // Bus stall: freeze — hold all outputs unchanged.
`endif
        end else begin
            // Data Propagation
            o_rs1_data      <= i_rs1_data;
            o_rs2_data      <= i_rs2_data;
            o_rd_data       <= i_rd_data;
            o_rd            <= i_rd;
            o_rs1           <= i_rs1;
            o_rs2           <= i_rs2;

            // Control Propagation
            o_ALUOp         <= i_ALUOp;
            o_MemRead       <= i_MemRead;
            o_MemWrite      <= i_MemWrite;
            o_RegWrite      <= i_RegWrite;
            o_MemToReg      <= i_MemToReg;

`ifdef RISCV_FORMAL
            o_pc            <= i_pc;
            o_instruction   <= i_instruction;
            o_next_pc       <= i_next_pc;
            o_rs1_data_rvfi <= i_rs1_data_rvfi;
            o_rs2_data_rvfi <= i_rs2_data_rvfi;
            o_branch_next_pc_rvfi <= i_branch_next_pc_rvfi;
            o_rvfi_valid    <= i_rvfi_valid;
`endif
        end
    end

endmodule