`include "core_config.svh"
package riscv_pkg;

  // ── Instruction constants ─────────────────────────────────────────────────
  localparam logic [31:0] INST_NOP  = 32'h0000_0013; // ADDI x0, x0, 0
  localparam logic [31:0] INST_DEAD = 32'hDEAD_BEEF; // Debug sentinel (ALU default)

  // ── PC increment (RV32I = 4 bytes) ───────────────────────────────────────
  localparam logic [31:0] PC_INC = 32'd4;

  // ── Register indices ──────────────────────────────────────────────────────
  localparam logic [4:0] REG_ZERO = 5'd0; // x0: hardwired zero

  // ── Opcodes (7-bit) ───────────────────────────────────────────────────────
  localparam logic [6:0] NOP_IMM   = 7'b0010011; // Opcode used when inserting a NOP/bubble (ADDI x0,x0,0)
  localparam logic [6:0] OP_R_TYPE = 7'b0110011; // ADD, SUB, XOR, OR, AND, SLL, SRL, SRA, SLT, SLTU
  localparam logic [6:0] OP_IMM    = 7'b0010011; // ADDI, XORI, ORI, ANDI, SLLI, SRLI, SRAI, SLTI, SLTIU
  localparam logic [6:0] OP_LOAD   = 7'b0000011; // LB, LH, LW, LBU, LHU
  localparam logic [6:0] OP_STORE  = 7'b0100011; // SB, SH, SW
  localparam logic [6:0] OP_BRANCH = 7'b1100011; // BEQ, BNE, BLT, BGE, BLTU, BGEU
  localparam logic [6:0] OP_JAL    = 7'b1101111;
  localparam logic [6:0] OP_JALR   = 7'b1100111;
  localparam logic [6:0] OP_LUI    = 7'b0110111;
  localparam logic [6:0] OP_AUIPC  = 7'b0010111;
  localparam logic [6:0] OP_FENCE  = 7'b0001111;
  localparam logic [6:0] OP_SYSTEM = 7'b1110011;

  // ── funct7 ────────────────────────────────────────────────────────────────
  localparam logic [6:0] F7_NORMAL = 7'h00; // ADD, XOR, OR, AND, SLL, SRL, SLT, SLTU
  localparam logic [6:0] F7_ALT    = 7'h20; // SUB, SRA, SRAI

  // ── funct3: arithmetic (R-type and I-type) ────────────────────────────────
  localparam logic [2:0] F3_ADD_SUB = 3'h0; // ADD, SUB, ADDI
  localparam logic [2:0] F3_SLL     = 3'h1; // SLL, SLLI
  localparam logic [2:0] F3_SLT     = 3'h2; // SLT, SLTI
  localparam logic [2:0] F3_SLTU    = 3'h3; // SLTU, SLTIU
  localparam logic [2:0] F3_XOR     = 3'h4; // XOR, XORI
  localparam logic [2:0] F3_SRL_SRA = 3'h5; // SRL, SRA, SRLI, SRAI
  localparam logic [2:0] F3_OR      = 3'h6; // OR, ORI
  localparam logic [2:0] F3_AND     = 3'h7; // AND, ANDI

  // ── funct3: memory width (loads and stores) ───────────────────────────────
  localparam logic [2:0] F3_BYTE   = 3'h0; // LB, SB
  localparam logic [2:0] F3_HALF   = 3'h1; // LH, SH
  localparam logic [2:0] F3_WORD   = 3'h2; // LW, SW
  localparam logic [2:0] F3_BYTE_U = 3'h4; // LBU
  localparam logic [2:0] F3_HALF_U = 3'h5; // LHU

  // ── funct3: branch conditions ─────────────────────────────────────────────
  localparam logic [2:0] F3_BEQ  = 3'h0;
  localparam logic [2:0] F3_BNE  = 3'h1;
  localparam logic [2:0] F3_BLT  = 3'h4;
  localparam logic [2:0] F3_BGE  = 3'h5;
  localparam logic [2:0] F3_BLTU = 3'h6;
  localparam logic [2:0] F3_BGEU = 3'h7;

  // ── ALUOp encodings ───────────────────────────────────────────────────────
  // R-type arithmetic
  localparam int ALUOP_ADD   = 0;
  localparam int ALUOP_SUB   = 1;
  localparam int ALUOP_XOR   = 2;
  localparam int ALUOP_OR    = 3;
  localparam int ALUOP_AND   = 4;
  localparam int ALUOP_SLL   = 5;
  localparam int ALUOP_SRL   = 6;
  localparam int ALUOP_SRA   = 7;
  localparam int ALUOP_SLT   = 8;
  localparam int ALUOP_SLTU  = 9;
  // I-type arithmetic
  localparam int ALUOP_ADDI  = 10;
  localparam int ALUOP_XORI  = 11;
  localparam int ALUOP_ORI   = 12;
  localparam int ALUOP_ANDI  = 13;
  localparam int ALUOP_SLLI  = 14;
  localparam int ALUOP_SRLI  = 15;
  localparam int ALUOP_SRAI  = 16;
  localparam int ALUOP_SLTI  = 17;
  localparam int ALUOP_SLTIU = 18;
  // Loads
  localparam int ALUOP_LB    = 19;
  localparam int ALUOP_LH    = 20;
  localparam int ALUOP_LW    = 21;
  localparam int ALUOP_LBU   = 22;
  localparam int ALUOP_LHU   = 23;
  // Stores
  localparam int ALUOP_SB    = 24;
  localparam int ALUOP_SH    = 25;
  localparam int ALUOP_SW    = 26;
  // Branches
  localparam int ALUOP_BEQ   = 27;
  localparam int ALUOP_BNE   = 28;
  localparam int ALUOP_BLT   = 29;
  localparam int ALUOP_BGE   = 30;
  localparam int ALUOP_BLTU  = 31;
  localparam int ALUOP_BGEU  = 32;
  // Jumps and upper-immediate
  localparam int ALUOP_JAL   = 33;
  localparam int ALUOP_JALR  = 34;
  localparam int ALUOP_LUI   = 35;
  localparam int ALUOP_AUIPC = 36;
  // Convenience ranges
  localparam int ALUOP_MEM_FIRST = ALUOP_LB;  // 19: first load/store opcode
  localparam int ALUOP_MEM_LAST  = ALUOP_SW;  // 26: last  load/store opcode
  localparam int ALUOP_LOAD_LAST = ALUOP_LHU; // 23: last  load opcode

  // ── IFID branch-flush counter states ─────────────────────────────────────
  localparam logic [1:0] NO_FLUSH   = 2'b10; // Normal: no flush in progress
  localparam logic [1:0] FLUSH_ONE  = 2'b01; // One more bubble cycle to emit
  localparam logic [1:0] FLUSH_DONE = 2'b00; // Flush done, latch real instruction

  // ── Forwarding MUX select codes ───────────────────────────────────────────
  localparam logic [1:0] FWD_NONE = 2'b00; // Use register-file value
  localparam logic [1:0] FWD_MEM  = 2'b10; // Forward from MEM stage
  localparam logic [1:0] FWD_WB   = 2'b01; // Forward from WB stage

  // ── RVFI mode / XLEN fields ───────────────────────────────────────────────
  localparam logic [1:0] PRIV_MACHINE = 2'b11; // Machine-mode privilege
  localparam logic [1:0] RV32_IXL    = 2'b01;  // XLEN = 32

endpackage
