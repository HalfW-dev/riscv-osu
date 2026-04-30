////////
// ID_EX register
// Updated to carry Control Unit signals and RVFI Instruction data
///////

import riscv_pkg::*;
module IDEX_reg #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter INST_COUNT = 37  // Needed for ALUOp width calculation
)(
    input  logic                   clk,
    input  logic                   resetn,
    input  logic                   i_branch_taken,
`ifdef MEM_AXI4LITE
    input  logic                   i_stall,
`endif

    // Data Inputs (From ID Stage / Forwarding Logic)
    input  logic [DATA_WIDTH-1:0]  i_rs1_data,
    input  logic [DATA_WIDTH-1:0]  i_rs2_data,
    input  logic [DATA_WIDTH-1:0]  i_imm,
    input  logic [ADDR_WIDTH-1:0]  i_address,
    input  logic [6:0]             i_opcode,
    input  logic [2:0]             i_funct3,
    input  logic [6:0]             i_funct7,
    input  logic [4:0]             i_rd,
    input  logic [4:0]             i_rs1,
    input  logic [4:0]             i_rs2,

    // CONTROL SIGNALS (INPUTS FROM CU in ID Stage)
    input  logic                   i_ALUSrc,
    input  logic [$clog2(INST_COUNT)-1:0] i_ALUOp,
    input  logic                   i_MemRead,
    input  logic                   i_MemWrite,
    input  logic                   i_RegWrite,
    input  logic                   i_MemToReg,

    // Data Outputs (To EX Stage)
    output logic [DATA_WIDTH-1:0]  o_rs1_data,
    output logic [DATA_WIDTH-1:0]  o_rs2_data,
    output logic [DATA_WIDTH-1:0]  o_imm,
    output logic [ADDR_WIDTH-1:0]  o_address,
    output logic [6:0]             o_opcode,
    output logic [2:0]             o_funct3,
    output logic [6:0]             o_funct7,
    output logic [4:0]             o_rd,
    output logic [4:0]             o_rs1,
    output logic [4:0]             o_rs2,

    // CONTROL SIGNALS (OUTPUTS To EX Stage)
    output logic                   o_ALUSrc,
    output logic [$clog2(INST_COUNT)-1:0] o_ALUOp,
    output logic                   o_MemRead,
    output logic                   o_MemWrite,
    output logic                   o_RegWrite,
    output logic                   o_MemToReg

`ifdef RISCV_FORMAL
    , // NEW: Instruction + valid bit for RVFI (Must pass through to WB)
    input  logic [INST_WIDTH-1:0]  i_instruction,
    output logic [INST_WIDTH-1:0]  o_instruction,
    input  logic                   i_rvfi_valid,
    output logic                   o_rvfi_valid
`endif
);

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Reset Data
            o_rs1_data <= '0; o_rs2_data <= '0; o_imm <= '0; o_address <= '0;
            o_opcode <= '0; o_funct3 <= '0; o_funct7 <= '0;
            o_rd <= '0; o_rs1 <= '0; o_rs2 <= '0;
            
            // Reset Control
            o_ALUSrc <= '0; o_ALUOp <= '0;
            o_MemRead <= '0; o_MemWrite <= '0;
            o_RegWrite <= '0; o_MemToReg <= '0;

`ifdef RISCV_FORMAL
            o_instruction <= INST_NOP;
            o_rvfi_valid  <= 1'b0;
`endif

`ifdef MEM_AXI4LITE
        end else if (i_stall) begin
            // Bus stall: freeze — hold all outputs unchanged.
            // Must take priority over i_branch_taken so that a branch
            // (JAL/JALR/taken-branch) fired while an AXI transaction is
            // in-flight does not flush IDEX before EXMEM has a chance to
            // capture the result.  EXMEM is also frozen by bus_freeze, so
            // the branch instruction stays in IDEX until the stall clears,
            // at which point EXMEM captures it and IDEX flushes normally.
`endif
        end else if (i_branch_taken) begin
            // Flush Data (Insert Bubble)
            o_rs1_data <= '0; o_rs2_data <= '0; o_imm <= '0; o_address <= '0;
            o_opcode <= NOP_IMM; // NOP (addi x0, x0, 0)
            o_funct3 <= '0; o_funct7 <= '0;
            o_rd <= '0; o_rs1 <= '0; o_rs2 <= '0;

            // Flush Control (CRITICAL: Set Control Signals to 0)
            o_ALUSrc <= '0; o_ALUOp <= '0;
            o_MemRead <= '0; o_MemWrite <= '0;
            o_RegWrite <= '0; o_MemToReg <= '0;

`ifdef RISCV_FORMAL
            o_instruction <= INST_NOP;
            o_rvfi_valid  <= 1'b0;
`endif
        end else begin
            // Normal Operation: Propagate Signals
            o_rs1_data <= i_rs1_data;
            o_rs2_data <= i_rs2_data;
            o_imm      <= i_imm;
            o_address  <= i_address;
            o_opcode   <= i_opcode;
            o_funct3   <= i_funct3;
            o_funct7   <= i_funct7;
            o_rd       <= i_rd;
            o_rs1      <= i_rs1;
            o_rs2      <= i_rs2;
            
            // Register Control Signals
            o_ALUSrc   <= i_ALUSrc;
            o_ALUOp    <= i_ALUOp;
            o_MemRead  <= i_MemRead;
            o_MemWrite <= i_MemWrite;
            o_RegWrite <= i_RegWrite;
            o_MemToReg <= i_MemToReg;

`ifdef RISCV_FORMAL
            o_instruction <= i_instruction;
            o_rvfi_valid  <= i_rvfi_valid;
`endif
        end
    end

endmodule