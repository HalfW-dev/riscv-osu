////////
// Branch / jump decision unit
///////

import riscv_pkg::*;
module branch #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32, //for RV32I
    parameter DATA_WIDTH = 32,
    parameter INST_COUNT = 37  //for RV32I without ecall and ebreak
)(
    input  logic [ADDR_WIDTH-1:0]         i_address,   // usually PC

    input  logic [DATA_WIDTH-1:0]         i_rs1_data,
    input  logic [DATA_WIDTH-1:0]         i_rs2_data,
    input  logic [DATA_WIDTH-1:0]         i_imm,       // branch/jump imm (see note below)
    
    input  logic [$clog2(INST_COUNT)-1:0] i_ALUOp,
    input  logic                          i_invalid_instruction, // not used here

    output logic [ADDR_WIDTH-1:0]         o_branch_address,
    output logic                          o_branch_taken
);
    
    // logic [W-1:0] aluop_t typedef removed to avoid synthesis confusion

    logic [ADDR_WIDTH-1:0] branch_address;
    logic                  branch_taken;

    // temp for JALR sum (full data width)
    logic [DATA_WIDTH-1:0] jalr_sum_full;

    assign o_branch_address = branch_address;
    assign o_branch_taken   = branch_taken;

    always_comb begin
        // Defaults
        branch_address = i_address + $signed(i_imm[ADDR_WIDTH-1:0]);  // PC + imm (branches/JAL)
        branch_taken   = 1'b0;
        jalr_sum_full  = '0;

        unique case (i_ALUOp)

            // ----------------------------------------
            // BEQ / BNE / BLT / BGE / BLTU / BGEU
            // ----------------------------------------
            ALUOP_BEQ:  branch_taken = (i_rs1_data == i_rs2_data);
            ALUOP_BNE:  branch_taken = (i_rs1_data != i_rs2_data);
            ALUOP_BLT:  branch_taken = ($signed(i_rs1_data) <  $signed(i_rs2_data));
            ALUOP_BGE:  branch_taken = ($signed(i_rs1_data) >= $signed(i_rs2_data));
            ALUOP_BLTU: branch_taken = (i_rs1_data <  i_rs2_data);
            ALUOP_BGEU: branch_taken = (i_rs1_data >= i_rs2_data);

            // ----------------------------------------
            // JAL: unconditional PC-relative jump
            // ----------------------------------------
            ALUOP_JAL: begin
                // branch_address already = PC + imm
                branch_taken = 1'b1;
            end

            // ----------------------------------------
            // JALR: rd = PC+4; PC = (rs1 + imm) & ~1
            // ----------------------------------------
            ALUOP_JALR: begin
                jalr_sum_full = i_rs1_data + i_imm;
                branch_address = { jalr_sum_full[ADDR_WIDTH-1:1], 1'b0 };
                branch_taken   = 1'b1;
            end

            default: begin
                // keep defaults
            end

        endcase
    end

endmodule