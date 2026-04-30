////////
// The ID stage of the architecture
///////
import riscv_pkg::*;
module ID_stage #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                   clk,
    input  logic                   resetn,
    input  logic                   i_branch_taken,

    input  logic [INST_WIDTH-1:0]  i_instruction,
    input  logic [DATA_WIDTH-1:0]  i_write_data,
    input  logic                   i_write_ena,
    input  logic [4:0]             i_write_address,

    output logic [DATA_WIDTH-1:0]  o_rs1_data,
    output logic [DATA_WIDTH-1:0]  o_rs2_data,

    output logic [6:0]             o_opcode,
    output logic [2:0]             o_funct3,
    output logic [6:0]             o_funct7,

    output logic [4:0]             o_rs1,
    output logic [4:0]             o_rs2,
    output logic [4:0]             o_rd,

    output logic [DATA_WIDTH-1:0]  o_imm
);

    // Internal decoded fields
    logic [4:0] rs1, rs2, rd;
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;

    logic [DATA_WIDTH-1:0] rs1_data, rs2_data;
    logic [DATA_WIDTH-1:0] imm;

    assign o_opcode   = opcode;
    assign o_funct3   = funct3;
    assign o_funct7   = funct7;
    assign o_imm      = imm;
    assign o_rs1_data = rs1_data;
    assign o_rs2_data = rs2_data;
    assign o_rs1      = rs1;
    assign o_rs2      = rs2;
    assign o_rd       = rd;

    // -------------------------------
    // Register file reads
    // -------------------------------
    regfile regfile(
        .clk       (clk),
        .resetn    (resetn),

        .i_rs1     (rs1),
        .o_rs1_data(rs1_data),

        .i_rs2     (rs2),
        .o_rs2_data(rs2_data),

        .i_write_ena(i_write_ena),
        .i_rd       (i_write_address),
        .i_rd_data  (i_write_data)
    );

    // Immediate generator (always sees the raw instruction;
    // we will mask it at the outputs when flushing)
    immgen immgen(
        .i_instruction(i_instruction),
        .o_imm        (imm)
    );

    // ===========================================================
    // Decode logic
    // ===========================================================
    always_comb begin : decode
        // Defaults
        rs1    = 5'd0;
        rs2    = 5'd0;
        rd     = 5'd0;
        funct3 = 3'd0;
        funct7 = 7'd0;
        opcode = i_instruction[6:0];

        case (opcode)

            // ---------- R-type ----------
            OP_R_TYPE: begin
                rd     = i_instruction[11:7];
                funct3 = i_instruction[14:12];
                rs1    = i_instruction[19:15];
                rs2    = i_instruction[24:20];
                funct7 = i_instruction[31:25];
            end

            // ---------- I-type (ALU Immediates AND Loads) ----------
            OP_IMM,
            OP_LOAD,
            OP_JALR: begin
                rd     = i_instruction[11:7];
                funct3 = i_instruction[14:12];
                rs1    = i_instruction[19:15];
                funct7 = i_instruction[31:25];
            end

            // ---------- S-type ----------
            OP_STORE: begin
                funct3 = i_instruction[14:12];
                rs1    = i_instruction[19:15];
                rs2    = i_instruction[24:20];
            end

            // ---------- B-type ----------
            OP_BRANCH: begin
                funct3 = i_instruction[14:12];
                rs1    = i_instruction[19:15];
                rs2    = i_instruction[24:20];
            end

            // ---------- U-type (LUI / AUIPC) ----------
            OP_LUI,
            OP_AUIPC: begin
                rd = i_instruction[11:7];
            end

            // ---------- J-type (JAL) ----------
            OP_JAL: begin
                rd = i_instruction[11:7];
            end

            default: begin
                // keep defaults
            end

        endcase
    end

endmodule