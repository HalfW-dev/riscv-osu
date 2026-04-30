////////
// Global control unit of the architecture
///////

import riscv_pkg::*;
module cu #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32, //for RV32I
    parameter DATA_WIDTH = 32,
    parameter INST_COUNT = 37  //for RV32I without ecall and ebreak
)(
    input  logic                         clk,
    input  logic                         resetn,

    // Decoded fields from ID
    input  logic [6:0]                   i_opcode,
    input  logic [2:0]                   i_funct3,
    input  logic [6:0]                   i_funct7,

    output logic                         o_ALUSrc,
    output logic [$clog2(INST_COUNT)-1:0] o_ALUOp,
    output logic                         o_MemWrite,
    output logic                         o_MemRead,
    output logic                         o_RegWrite,
    output logic                         o_MemToReg,
    output logic                         o_invalid_instruction
);

localparam W = $clog2(INST_COUNT);
typedef logic [W-1:0] aluop_t;

// decode outputs
aluop_t ALU_op;
logic   ALU_src;
logic   invalid_instruction;
logic   MemWrite;
logic   MemRead;
logic   RegWrite;
logic   MemToReg;

assign o_ALUOp               = ALU_op;
assign o_ALUSrc              = ALU_src;
assign o_invalid_instruction = invalid_instruction;
assign o_MemWrite            = MemWrite;
assign o_MemRead             = MemRead;
assign o_RegWrite            = RegWrite;
assign o_MemToReg            = MemToReg;


// ---------------------------------------------------------------------
// Decode -> ALU_op + ALUSrc only
// ---------------------------------------------------------------------
always_comb begin : decode_ctrl

    invalid_instruction = 1'b0;
    ALU_op              = aluop_t'(0);
    ALU_src             = 1'b0;     // default: use rs2
    MemWrite            = 1'b0;
    MemRead             = 1'b0;
    RegWrite            = 1'b1;
    MemToReg            = 1'b0;

    unique case (i_opcode)

        // ---------------- R-type ----------------
        OP_R_TYPE: begin
            ALU_src = 1'b0;  // rs2
            unique case (i_funct3)
                F3_ADD_SUB: begin
                    if      (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_ADD); // ADD
                    else if (i_funct7 == F7_ALT)    ALU_op = aluop_t'(ALUOP_SUB); // SUB
                    else                            invalid_instruction = 1'b1;
                end
                F3_XOR:     if (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_XOR);  else invalid_instruction = 1'b1;
                F3_OR:      if (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_OR);   else invalid_instruction = 1'b1;
                F3_AND:     if (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_AND);  else invalid_instruction = 1'b1;
                F3_SLL:     if (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_SLL);  else invalid_instruction = 1'b1;
                F3_SRL_SRA: begin
                    if      (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_SRL); // SRL
                    else if (i_funct7 == F7_ALT)    ALU_op = aluop_t'(ALUOP_SRA); // SRA
                    else                            invalid_instruction = 1'b1;
                end
                F3_SLT:     if (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_SLT);  else invalid_instruction = 1'b1;
                F3_SLTU:    if (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_SLTU); else invalid_instruction = 1'b1;
                default: invalid_instruction = 1'b1;
            endcase
        end

        // -------------- I-type arithmetic --------------
        OP_IMM: begin
            ALU_src = 1'b1; // use immediate
            unique case (i_funct3)
                F3_ADD_SUB: ALU_op = aluop_t'(ALUOP_ADDI);
                F3_XOR:     ALU_op = aluop_t'(ALUOP_XORI);
                F3_OR:      ALU_op = aluop_t'(ALUOP_ORI);
                F3_AND:     ALU_op = aluop_t'(ALUOP_ANDI);
                F3_SLL: begin
                    if (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_SLLI);
                    else                       invalid_instruction = 1'b1;
                end
                F3_SRL_SRA: begin
                    if      (i_funct7 == F7_NORMAL) ALU_op = aluop_t'(ALUOP_SRLI);
                    else if (i_funct7 == F7_ALT)    ALU_op = aluop_t'(ALUOP_SRAI);
                    else                            invalid_instruction = 1'b1;
                end
                F3_SLT:  ALU_op = aluop_t'(ALUOP_SLTI);
                F3_SLTU: ALU_op = aluop_t'(ALUOP_SLTIU);
                default: invalid_instruction = 1'b1;
            endcase
        end

        // -------------- Loads --------------
        OP_LOAD: begin
            ALU_src  = 1'b1;
            MemToReg = 1'b1;
            MemRead  = 1'b1;
            unique case (i_funct3)
                F3_BYTE:   ALU_op = aluop_t'(ALUOP_LB);
                F3_HALF:   ALU_op = aluop_t'(ALUOP_LH);
                F3_WORD:   ALU_op = aluop_t'(ALUOP_LW);
                F3_BYTE_U: ALU_op = aluop_t'(ALUOP_LBU);
                F3_HALF_U: ALU_op = aluop_t'(ALUOP_LHU);
                default:   invalid_instruction = 1'b1;
            endcase
        end

        // -------------- Stores --------------
        OP_STORE: begin
            ALU_src  = 1'b1;
            MemWrite = 1'b1;
            RegWrite = 1'b0;
            unique case (i_funct3)
                F3_BYTE:  ALU_op = aluop_t'(ALUOP_SB);
                F3_HALF:  ALU_op = aluop_t'(ALUOP_SH);
                F3_WORD:  ALU_op = aluop_t'(ALUOP_SW);
                default:  invalid_instruction = 1'b1;
            endcase
        end

        // -------------- Branches --------------
        OP_BRANCH: begin
            ALU_src  = 1'b0;
            RegWrite = 1'b0;
            unique case (i_funct3)
                F3_BEQ:  ALU_op = aluop_t'(ALUOP_BEQ);
                F3_BNE:  ALU_op = aluop_t'(ALUOP_BNE);
                F3_BLT:  ALU_op = aluop_t'(ALUOP_BLT);
                F3_BGE:  ALU_op = aluop_t'(ALUOP_BGE);
                F3_BLTU: ALU_op = aluop_t'(ALUOP_BLTU);
                F3_BGEU: ALU_op = aluop_t'(ALUOP_BGEU);
                default: invalid_instruction = 1'b1;
            endcase
        end

        // JAL – PC-relative jump
        OP_JAL: begin
            ALU_src = 1'b1;
            ALU_op  = aluop_t'(ALUOP_JAL);
        end

        // JALR
        OP_JALR: begin
            ALU_src = 1'b1;
            if (i_funct3 == F3_ADD_SUB) ALU_op = aluop_t'(ALUOP_JALR);
            else                        invalid_instruction = 1'b1;
        end

        // LUI
        OP_LUI: begin
            ALU_src = 1'b1;
            ALU_op  = aluop_t'(ALUOP_LUI);
        end

        // AUIPC
        OP_AUIPC: begin
            ALU_src = 1'b1;
            ALU_op  = aluop_t'(ALUOP_AUIPC);
        end

        default: begin
            invalid_instruction = 1'b1;
        end
    endcase
end

endmodule
