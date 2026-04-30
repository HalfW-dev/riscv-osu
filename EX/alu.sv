////////
// Main execution unit - ALU (operand2 chosen outside)
///////

import riscv_pkg::*;
module alu #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter INST_COUNT = 37
)(
    input  logic [DATA_WIDTH-1:0]         i_rs1_data,
    input  logic [DATA_WIDTH-1:0]         i_rs2_data,
    input  logic [ADDR_WIDTH-1:0]         i_address, 
    input  logic [$clog2(INST_COUNT)-1:0] i_ALUOp,
    input  logic                          i_invalid_instruction,

    output logic [DATA_WIDTH-1:0]         o_rd_data
);

    logic [DATA_WIDTH-1:0] rd_data;
    assign o_rd_data = rd_data;

    always_comb begin
        unique case (i_ALUOp)
            // ADD / ADDI / address calc for loads & stores
            ALUOP_ADD, ALUOP_ADDI,
            ALUOP_LB, ALUOP_LH, ALUOP_LW, ALUOP_LBU, ALUOP_LHU,
            ALUOP_SB, ALUOP_SH, ALUOP_SW:
                rd_data = i_rs1_data + i_rs2_data;

            // SUB
            ALUOP_SUB: rd_data = i_rs1_data - i_rs2_data;

            // XOR / XORI
            ALUOP_XOR, ALUOP_XORI: rd_data = i_rs1_data ^ i_rs2_data;

            // OR / ORI
            ALUOP_OR, ALUOP_ORI: rd_data = i_rs1_data | i_rs2_data;

            // AND / ANDI
            ALUOP_AND, ALUOP_ANDI: rd_data = i_rs1_data & i_rs2_data;

            // SLL / SLLI
            ALUOP_SLL, ALUOP_SLLI: rd_data = i_rs1_data << i_rs2_data[4:0];

            // SRL / SRLI
            ALUOP_SRL, ALUOP_SRLI: rd_data = i_rs1_data >> i_rs2_data[4:0];

            // SRA / SRAI
            ALUOP_SRA, ALUOP_SRAI: rd_data = $signed(i_rs1_data) >>> i_rs2_data[4:0];

            // SLT / SLTI (signed)
            ALUOP_SLT, ALUOP_SLTI: rd_data = ($signed(i_rs1_data) < $signed(i_rs2_data)) ? 32'd1 : 32'd0;

            // SLTU / SLTIU (unsigned)
            ALUOP_SLTU, ALUOP_SLTIU: rd_data = (i_rs1_data < i_rs2_data) ? 32'd1 : 32'd0;

            // JAL / JALR: rd = PC + 4
            ALUOP_JAL, ALUOP_JALR: rd_data = i_address + 32'd4;

            // LUI: rd = imm_u
            ALUOP_LUI: rd_data = i_rs2_data;

            // AUIPC: rd = PC + imm_u
            ALUOP_AUIPC: rd_data = i_address + i_rs2_data;

            default: rd_data = INST_DEAD;
        endcase
    end

endmodule