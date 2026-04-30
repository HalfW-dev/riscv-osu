////////
//The EX stage of the architecture
///////

module EX_stage #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32, // for RV32I
    parameter DATA_WIDTH = 32,
    parameter INST_COUNT = 37  //for RV32I without ecall and ebreak
)(
    input  logic                   clk,
    input  logic                   resetn,

    input  logic [DATA_WIDTH-1:0]  i_rs1_data,
    input  logic [DATA_WIDTH-1:0]  i_rs2_data,
    input  logic [DATA_WIDTH-1:0]  i_imm,

    input  logic [ADDR_WIDTH-1:0]  i_address,

    // Control signals from CU
    input  logic                          i_ALUSrc,
    input  logic [$clog2(INST_COUNT)-1:0] i_ALUOp,

    output logic [ADDR_WIDTH-1:0]  o_branch_address,
    output logic                   o_branch_taken,
    output logic [DATA_WIDTH-1:0]  o_alu_result,
    output logic [DATA_WIDTH-1:0]  o_rs1_data,
    output logic [DATA_WIDTH-1:0]  o_rs2_data
);

localparam W = $clog2(INST_COUNT);
typedef logic [W-1:0] aluop_t;

// Internal
logic [ADDR_WIDTH-1:0]  branch_address;
logic                   branch_taken;
logic [DATA_WIDTH-1:0]  alu_result;
logic [DATA_WIDTH-1:0]  rs1_data;
logic [DATA_WIDTH-1:0]  rs2_data;

assign rs1_data = i_rs1_data;
// ALUSrc mux: select between rs2 and imm
assign rs2_data = i_ALUSrc ? i_imm : i_rs2_data;

// Outputs
assign o_branch_address = branch_address;
assign o_branch_taken   = branch_taken;
assign o_alu_result     = alu_result;
assign o_rs1_data       = rs1_data;
//assign o_rs2_data       = rs2_data;
assign o_rs2_data       = i_rs2_data;

alu #(
    .ADDR_WIDTH (ADDR_WIDTH),
    //.INST_WIDTH (INST_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .INST_COUNT (INST_COUNT)
) u_alu (
    .i_rs1_data           (rs1_data),
    .i_rs2_data           (rs2_data),
    .i_address            (i_address),
    .i_ALUOp              (i_ALUOp),
    .i_invalid_instruction(1'b0),   // or connect from CU later
    .o_rd_data            (alu_result)
);

branch #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .INST_WIDTH (INST_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .INST_COUNT (INST_COUNT)
) u_branch (
    .i_address            (i_address),
    .i_rs1_data           (rs1_data),
    .i_rs2_data           (rs2_data),
    .i_imm                (i_imm),
    .i_ALUOp              (i_ALUOp),
    .i_invalid_instruction(1'b0),   // or connect from CU later
    .o_branch_address     (branch_address),
    .o_branch_taken       (branch_taken)
);

endmodule
