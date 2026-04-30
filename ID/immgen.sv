////////
// Immediate Generator for RV32I
//  - Supports I, S, B, U, J formats
//  - Takes full 32-bit instruction
//  - Outputs 32-bit sign-extended immediate
///////

import riscv_pkg::*;
module immgen #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic [INST_WIDTH-1:0] i_instruction,
    output logic [DATA_WIDTH-1:0] o_imm
);

    // Extract opcode
    logic [6:0] opcode;
    assign opcode = i_instruction[6:0];

    always_comb begin
        // Default immediate = 0
        o_imm = '0;

        unique case (opcode)

            // -------------------------------------------------
            // I-type: immediate arithmetic, loads, JALR, etc.
            // 0010011 : OP-IMM  (ADDI, ANDI, ORI, etc.)
            // 0000011 : LOAD    (LB, LH, LW, LBU, LHU)
            // 1100111 : JALR
            // 0001111 : FENCE (uses imm, but rarely needed)
            // 1110011 : SYSTEM (ECALL/EBREAK/CSR)
            // -------------------------------------------------
            OP_IMM,
            OP_LOAD,
            OP_JALR,
            OP_FENCE,
            OP_SYSTEM: begin
                // imm[31:0] = sign-extend(inst[31:20])
                o_imm = {{20{i_instruction[31]}}, i_instruction[31:20]};
            end

            // -------------------------------------------------
            // S-type: stores (SB, SH, SW)
            // 0100011
            // -------------------------------------------------
            OP_STORE: begin
                // imm[11:5] = inst[31:25]
                // imm[4:0]  = inst[11:7]
                o_imm = {{20{i_instruction[31]}},
                          i_instruction[31:25],
                          i_instruction[11:7]};
            end

            // -------------------------------------------------
            // B-type: branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            // 1100011
            // -------------------------------------------------
            OP_BRANCH: begin
                // Branch offset (note the bit positions):
                // imm[12]   = inst[31]
                // imm[10:5] = inst[30:25]
                // imm[4:1]  = inst[11:8]
                // imm[11]   = inst[7]
                // imm[0]    = 0
                o_imm = {{19{i_instruction[31]}},
                          i_instruction[31],
                          i_instruction[7],
                          i_instruction[30:25],
                          i_instruction[11:8],
                          1'b0};
            end

            // -------------------------------------------------
            // U-type: LUI / AUIPC
            // 0110111 : LUI
            // 0010111 : AUIPC
            // -------------------------------------------------
            OP_LUI,
            OP_AUIPC: begin
                // imm[31:12] = inst[31:12], lower 12 bits are zero
                o_imm = {i_instruction[31:12], 12'b0};
            end

            // -------------------------------------------------
            // J-type: JAL
            // 1101111
            // -------------------------------------------------
            OP_JAL: begin
                // JAL offset:
                // imm[20]   = inst[31]
                // imm[10:1] = inst[30:21]
                // imm[11]   = inst[20]
                // imm[19:12]= inst[19:12]
                // imm[0]    = 0
                o_imm = {{11{i_instruction[31]}},
                          i_instruction[31],
                          i_instruction[19:12],
                          i_instruction[20],
                          i_instruction[30:21],
                          1'b0};
            end

            default: begin
                // For unknown opcodes, keep o_imm = 0
                o_imm = '0;
            end
        endcase
    end

endmodule
