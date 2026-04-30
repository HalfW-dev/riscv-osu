////////
// Topmodule of the RISCV architecture
// Modified for physical synthesis (RVFI stripped via macros)
///////

import riscv_pkg::*;
module topmodule_RISCV #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32, // for RV32I
    parameter DATA_WIDTH = 32,
    parameter INST_COUNT = 37  // for RV32I without ecall and ebreak
)(
    input  logic clk,
    input  logic resetn,

    // =========================================================================
    // DEBUG ANCHORS — prevent logic elimination during synthesis
    // =========================================================================
    output logic [DATA_WIDTH-1:0] o_dbg_wb_data,
    output logic [4:0]            o_dbg_wb_rd,
    output logic                  o_dbg_wb_regwrite

`ifdef MEM_WISHBONE
    // =========================================================================
    // WISHBONE B4 INSTRUCTION BUS
    // =========================================================================
    , output logic                  o_ibus_cyc,
    output logic                   o_ibus_stb,
    output logic [ADDR_WIDTH-1:0]  o_ibus_adr,
    input  logic [INST_WIDTH-1:0]  i_ibus_dat,
    input  logic                   i_ibus_ack,
    // WISHBONE B4 DATA BUS
    output logic                   o_dbus_cyc,
    output logic                   o_dbus_stb,
    output logic                   o_dbus_we,
    output logic [ADDR_WIDTH-1:0]  o_dbus_adr,
    output logic [DATA_WIDTH-1:0]  o_dbus_dat,
    output logic [3:0]             o_dbus_sel,
    input  logic [DATA_WIDTH-1:0]  i_dbus_dat,
    input  logic                   i_dbus_ack
`elsif MEM_AXI4LITE
    // =========================================================================
    // AXI4-LITE INSTRUCTION BUS (read only)
    // =========================================================================
    , output logic [ADDR_WIDTH-1:0] o_ibus_araddr,
    output logic                   o_ibus_arvalid,
    input  logic                   i_ibus_arready,
    input  logic [INST_WIDTH-1:0]  i_ibus_rdata,
    input  logic [1:0]             i_ibus_rresp,
    input  logic                   i_ibus_rvalid,
    output logic                   o_ibus_rready,
    // AXI4-LITE DATA BUS (read + write)
    output logic [ADDR_WIDTH-1:0]  o_dbus_araddr,
    output logic                   o_dbus_arvalid,
    input  logic                   i_dbus_arready,
    input  logic [DATA_WIDTH-1:0]  i_dbus_rdata,
    input  logic [1:0]             i_dbus_rresp,
    input  logic                   i_dbus_rvalid,
    output logic                   o_dbus_rready,
    output logic [ADDR_WIDTH-1:0]  o_dbus_awaddr,
    output logic                   o_dbus_awvalid,
    input  logic                   i_dbus_awready,
    output logic [DATA_WIDTH-1:0]  o_dbus_wdata,
    output logic [3:0]             o_dbus_wstrb,
    output logic                   o_dbus_wvalid,
    input  logic                   i_dbus_wready,
    input  logic [1:0]             i_dbus_bresp,
    input  logic                   i_dbus_bvalid,
    output logic                   o_dbus_bready
`endif

`ifdef RISCV_FORMAL
    , // =========================================================================
    // RISC-V FORMAL INTERFACE (RVFI) OUTPUTS
    // =========================================================================
    output logic        rvfi_valid,
    output logic [63:0] rvfi_order,
    output logic [31:0] rvfi_insn,
    output logic        rvfi_trap,
    output logic        rvfi_halt,
    output logic        rvfi_intr,
    output logic [ 1:0] rvfi_mode,
    output logic [ 1:0] rvfi_ixl,

    output logic [ 4:0] rvfi_rs1_addr,
    output logic [ 4:0] rvfi_rs2_addr,
    output logic [31:0] rvfi_rs1_rdata,
    output logic [31:0] rvfi_rs2_rdata,

    output logic [ 4:0] rvfi_rd_addr,
    output logic [31:0] rvfi_rd_wdata,

    output logic [31:0] rvfi_pc_rdata,
    output logic [31:0] rvfi_pc_wdata,

    output logic [31:0] rvfi_mem_addr,
    output logic [ 3:0] rvfi_mem_rmask,
    output logic [ 3:0] rvfi_mem_wmask,
    output logic [31:0] rvfi_mem_rdata,
    output logic [31:0] rvfi_mem_wdata
`endif
);

    localparam W = $clog2(INST_COUNT);

    // =========================================================================
    // STANDARD PIPELINE SIGNALS
    // =========================================================================
    logic [ADDR_WIDTH-1:0] reg_EX_pc; // Kept outside macro (used for standard Next PC calculation)

`ifdef RISCV_FORMAL
    // =========================================================================
    // PIPELINE WIRES FOR RVFI (Ignored during physical synthesis)
    // =========================================================================
    logic [INST_WIDTH-1:0] reg_EX_insn;
    logic [DATA_WIDTH-1:0] reg_EX_rs1_data_rvfi;
    logic [DATA_WIDTH-1:0] reg_EX_rs2_data_rvfi;
    logic [ADDR_WIDTH-1:0] EX_branch_next_pc_rvfi;

    logic [ADDR_WIDTH-1:0] reg_MEM_pc;
    logic [INST_WIDTH-1:0] reg_MEM_insn;
    logic [ADDR_WIDTH-1:0] reg_MEM_next_pc;
    logic [DATA_WIDTH-1:0] reg_MEM_rs1_data_rvfi;
    logic [DATA_WIDTH-1:0] reg_MEM_rs2_data_rvfi;
    logic [DATA_WIDTH-1:0] reg_MEM_mem_wdata;
    logic [ADDR_WIDTH-1:0] MEM_branch_next_pc_rvfi;

    logic [ADDR_WIDTH-1:0] reg_WB_pc;
    logic [INST_WIDTH-1:0] reg_WB_insn;
    logic [ADDR_WIDTH-1:0] reg_WB_next_pc;
    logic [DATA_WIDTH-1:0] reg_WB_rs1_data_rvfi;
    logic [DATA_WIDTH-1:0] reg_WB_rs2_data_rvfi;
    logic [DATA_WIDTH-1:0] reg_WB_mem_addr;
    logic [DATA_WIDTH-1:0] reg_WB_mem_wdata;
    logic [DATA_WIDTH-1:0] reg_WB_mem_rdata_raw;
    logic [ADDR_WIDTH-1:0] WB_branch_next_pc_rvfi;

    logic IFID_rvfi_valid;
    logic reg_EX_rvfi_valid;
    logic reg_MEM_rvfi_valid;
    logic reg_WB_rvfi_valid;

    logic [DATA_WIDTH-1:0] reg_MEM_dmem_rdata_raw;

    logic [63:0] insn_order;
`endif

    // Control signals from CU
    logic        CU_ID_ALUSrc;
    logic [W-1:0] CU_ID_ALUOp;
    logic        CU_ID_MemRead;
    logic        CU_ID_MemWrite;
    logic        CU_ID_RegWrite;
    logic        CU_ID_MemToReg;

    logic        CU_EX_reg_ALUSrc;
    logic [W-1:0] CU_EX_reg_ALUOp;
    logic        CU_EX_reg_MemRead;
    logic        CU_EX_reg_MemWrite;
    logic        CU_EX_reg_RegWrite;
    logic        CU_EX_reg_MemToReg;

    logic [1:0]  FW_EX_forward_rs1;
    logic [1:0]  FW_EX_forward_rs2;

    logic [DATA_WIDTH-1:0] EX_rs1_data_fwd;
    logic [DATA_WIDTH-1:0] EX_rs2_data_fwd;

    logic stall_pipeline;

    // =========================================================================
    // MEMORY STALL SIGNALS (bus modes only)
    // =========================================================================
`ifdef MEM_WISHBONE
    logic if_imem_stall;
    logic mem_dmem_stall;
`elsif MEM_AXI4LITE
    logic if_imem_stall;
    logic mem_dmem_stall;
`endif

    // Effective stall combines hazard stall with memory bus stalls
`ifdef MEM_WISHBONE
    logic effective_stall;
    assign effective_stall = stall_pipeline || if_imem_stall || mem_dmem_stall;
`elsif MEM_AXI4LITE
    logic effective_stall;
    assign effective_stall = stall_pipeline || if_imem_stall || mem_dmem_stall;
`else
    wire effective_stall = stall_pipeline;
`endif

    // IF stage outputs
    logic [ADDR_WIDTH-1:0] IF_reg_address;
    logic [INST_WIDTH-1:0] IF_reg_instruction;

    // IF/ID register outputs
    logic [ADDR_WIDTH-1:0] reg_ID_address;
    logic [INST_WIDTH-1:0] reg_ID_instruction;

    assign o_dbg_wb_data     = WB_ID_rd_data;
    assign o_dbg_wb_rd       = WB_ID_rd;
    assign o_dbg_wb_regwrite = WB_ID_RegWrite;

    // ID stage output
    logic [DATA_WIDTH-1:0] ID_reg_rs1_data;
    logic [DATA_WIDTH-1:0] ID_reg_rs2_data;
    logic [DATA_WIDTH-1:0] ID_reg_imm;
    logic [6:0] ID_reg_opcode;
    logic [2:0] ID_reg_funct3;
    logic [6:0] ID_reg_funct7;
    logic [4:0] ID_reg_rs1;
    logic [4:0] ID_reg_rs2;
    logic [4:0] ID_reg_rd;

    logic [DATA_WIDTH-1:0] ID_final_rs1_data;
    logic [DATA_WIDTH-1:0] ID_final_rs2_data;

    // ID/EX register outputs
    logic [DATA_WIDTH-1:0] reg_EX_rs1_data;
    logic [DATA_WIDTH-1:0] reg_EX_rs2_data;
    logic [DATA_WIDTH-1:0] reg_EX_imm;
    logic [ADDR_WIDTH-1:0] reg_EX_address;
    logic [6:0] reg_EX_opcode;
    logic [2:0] reg_EX_funct3;
    logic [6:0] reg_EX_funct7;
    logic [4:0] reg_EX_reg_rs1;
    logic [4:0] reg_EX_reg_rs2;
    logic [4:0] reg_EX_reg_rd;

    // Branch signals
    logic [ADDR_WIDTH-1:0] branch_address;
    logic                  branch_taken;

    // EX stage output
    logic [DATA_WIDTH-1:0] EX_reg_rs1_data;
    logic [DATA_WIDTH-1:0] EX_reg_rs2_data;
    logic [DATA_WIDTH-1:0] EX_reg_rd_data;
    logic [ADDR_WIDTH-1:0] EX_next_pc_calc;

    // EX/MEM register outputs
    logic [DATA_WIDTH-1:0] reg_MEM_rs1_data;
    logic [DATA_WIDTH-1:0] reg_MEM_rs2_data;
    logic [DATA_WIDTH-1:0] reg_MEM_rd_data;
    logic [W-1:0] reg_MEM_ALUOp;
    logic reg_MEM_MemRead;
    logic reg_MEM_MemWrite;
    logic reg_MEM_RegWrite;
    logic reg_MEM_MemToReg;
    logic [4:0] reg_MEM_reg_rd;
    logic [4:0] reg_MEM_reg_rs1;
    logic [4:0] reg_MEM_reg_rs2;

    // MEM stage output
    logic [DATA_WIDTH-1:0] MEM_reg_dmem_data;
    logic [DATA_WIDTH-1:0] MEM_reg_rd_data;
    logic MEM_reg_RegWrite;
    logic MEM_reg_MemToReg;

    // MEM/WB register outputs
    logic [DATA_WIDTH-1:0] reg_WB_dmem_data;
    logic [DATA_WIDTH-1:0] reg_WB_rd_data;
    logic [4:0] reg_WB_rd;
    logic [4:0] reg_WB_rs1;
    logic [4:0] reg_WB_rs2;
    logic reg_WB_RegWrite;
    logic reg_WB_MemToReg;

    // WB/ID signals
    logic WB_ID_RegWrite;
    logic [4:0] WB_ID_rd;
    logic [DATA_WIDTH-1:0] WB_ID_rd_data;

    // =========================================================================
    // SUBMODULE INSTANTIATIONS
    // =========================================================================

    cu cu (
        .clk(clk),
        .resetn(resetn),
        .i_opcode(ID_reg_opcode),
        .i_funct3(ID_reg_funct3),
        .i_funct7(ID_reg_funct7),
        .o_ALUSrc(CU_ID_ALUSrc),
        .o_ALUOp(CU_ID_ALUOp),
        .o_MemRead(CU_ID_MemRead),
        .o_MemWrite(CU_ID_MemWrite),
        .o_RegWrite(CU_ID_RegWrite),
        .o_MemToReg(CU_ID_MemToReg),
        .o_invalid_instruction()
    );

    forward forward(
        .i_rs1_ex(reg_EX_reg_rs1),
        .i_rs2_ex(reg_EX_reg_rs2),
        .i_rd_mem(reg_MEM_reg_rd),
        .i_regwrite_mem(reg_MEM_RegWrite),
        .i_rd_wb(reg_WB_rd),
        .i_regwrite_wb(reg_WB_RegWrite),
        .o_forward_rs1(FW_EX_forward_rs1),
        .o_forward_rs2(FW_EX_forward_rs2)
    );

    hazard_unit hazard_unit (
        .i_rs1_id      (ID_reg_rs1),
        .i_rs2_id      (ID_reg_rs2),
        .i_rd_ex       (reg_EX_reg_rd),
        .i_mem_read_ex (CU_EX_reg_MemRead),
        .o_stall       (stall_pipeline)
    );

    IF_stage IF_stage (
        .clk(clk),
        .resetn(resetn),
        .i_branch_addr(branch_address),
        .i_branch_inst(branch_taken),
        .i_pipeline_stall(effective_stall),
        .o_address(IF_reg_address),
        .o_instruction(IF_reg_instruction)
`ifdef MEM_WISHBONE
        , .o_ibus_cyc(o_ibus_cyc),
        .o_ibus_stb(o_ibus_stb),
        .o_ibus_adr(o_ibus_adr),
        .i_ibus_dat(i_ibus_dat),
        .i_ibus_ack(i_ibus_ack),
        .o_imem_stall(if_imem_stall)
`elsif MEM_AXI4LITE
        , .o_ibus_araddr(o_ibus_araddr),
        .o_ibus_arvalid(o_ibus_arvalid),
        .i_ibus_arready(i_ibus_arready),
        .i_ibus_rdata(i_ibus_rdata),
        .i_ibus_rresp(i_ibus_rresp),
        .i_ibus_rvalid(i_ibus_rvalid),
        .o_ibus_rready(o_ibus_rready),
        .o_imem_stall(if_imem_stall)
`endif
    );

    // idex_stall_gate: only inject a bubble for hazard stalls.
    // Bus stalls (IMEM/DMEM AXI) are handled by freezing IDEX/EXMEM/MEMWB
    // via bus_freeze, so we must NOT also inject a bubble or the frozen
    // instruction gets overwritten.
    // branch_taken_qual: in bus modes branch flushes even during AXI stalls
    // so the fetch of the correct target isn't delayed by a stale transaction.
`ifdef MEM_AXI4LITE
    wire branch_taken_qual = branch_taken;
    wire idex_stall_gate   = stall_pipeline;
    // Freeze IDEX/EXMEM/MEMWB during AXI bus stalls so instructions are not
    // overwritten before their transactions complete.
    wire bus_freeze        = if_imem_stall || mem_dmem_stall;
`elsif MEM_WISHBONE
    wire branch_taken_qual = branch_taken;
    wire idex_stall_gate   = stall_pipeline;
`else
    wire branch_taken_qual = branch_taken && !effective_stall;
    wire idex_stall_gate   = stall_pipeline;
`endif

    IFID_reg IFID_reg (
        .clk(clk),
        .resetn(resetn),
        .i_branch_taken(branch_taken_qual),
        .i_stall(effective_stall),
        .i_address(IF_reg_address),
        .i_instruction(IF_reg_instruction),
        .o_address(reg_ID_address),
        .o_instruction(reg_ID_instruction)
`ifdef RISCV_FORMAL
        , .o_rvfi_valid(IFID_rvfi_valid)
`endif
    );

    ID_stage ID_stage (
        .clk(clk),
        .resetn(resetn),
        .i_branch_taken(branch_taken),
        .i_instruction(reg_ID_instruction),
        .i_write_data(WB_ID_rd_data),
        .i_write_ena(WB_ID_RegWrite),
        .i_write_address(WB_ID_rd),
        .o_rs1_data(ID_reg_rs1_data),
        .o_rs2_data(ID_reg_rs2_data),
        .o_opcode(ID_reg_opcode),
        .o_funct3(ID_reg_funct3),
        .o_funct7(ID_reg_funct7),
        .o_rs1(ID_reg_rs1),
        .o_rs2(ID_reg_rs2),
        .o_rd(ID_reg_rd),
        .o_imm(ID_reg_imm)
    );

    // ID Forwarding Logic
    always_comb begin
        if (WB_ID_RegWrite && (WB_ID_rd == ID_reg_rs1) && (WB_ID_rd != 5'd0))
            ID_final_rs1_data = WB_ID_rd_data;
        else
            ID_final_rs1_data = ID_reg_rs1_data;
    end
    always_comb begin
        if (WB_ID_RegWrite && (WB_ID_rd == ID_reg_rs2) && (WB_ID_rd != 5'd0))
            ID_final_rs2_data = WB_ID_rd_data;
        else
            ID_final_rs2_data = ID_reg_rs2_data;
    end

    IDEX_reg IDEX_reg(
        .clk(clk),
        .resetn(resetn),
`ifdef MEM_AXI4LITE
        .i_stall(bus_freeze),
`endif
        .i_branch_taken(branch_taken),
        .i_rs1_data(ID_final_rs1_data),
        .i_rs2_data(ID_final_rs2_data),
        .i_imm(ID_reg_imm),
        .i_address(reg_ID_address),
        .i_opcode ( idex_stall_gate ? 7'b0 : ID_reg_opcode ),
        .i_funct3 ( idex_stall_gate ? 3'b0 : ID_reg_funct3 ),
        .i_funct7 ( idex_stall_gate ? 7'b0 : ID_reg_funct7 ),
        .i_rd(ID_reg_rd),
        .i_rs1(ID_reg_rs1),
        .i_rs2(ID_reg_rs2),
        .i_ALUSrc   ( idex_stall_gate ? 1'b0 : CU_ID_ALUSrc   ),
        .i_ALUOp    ( idex_stall_gate ? 1'b0 : CU_ID_ALUOp    ),
        .i_RegWrite ( idex_stall_gate ? 1'b0 : CU_ID_RegWrite  ),
        .i_MemRead  ( idex_stall_gate ? 1'b0 : CU_ID_MemRead   ),
        .i_MemWrite ( idex_stall_gate ? 1'b0 : CU_ID_MemWrite  ),
        .i_MemToReg ( idex_stall_gate ? 1'b0 : CU_ID_MemToReg  ),

        .o_address(reg_EX_pc), // Used for EX_next_pc_calc
        .o_ALUSrc(CU_EX_reg_ALUSrc),
        .o_ALUOp(CU_EX_reg_ALUOp),
        .o_MemRead(CU_EX_reg_MemRead),
        .o_MemWrite(CU_EX_reg_MemWrite),
        .o_RegWrite(CU_EX_reg_RegWrite),
        .o_MemToReg(CU_EX_reg_MemToReg),
        .o_rs1_data(reg_EX_rs1_data),
        .o_rs2_data(reg_EX_rs2_data),
        .o_imm(reg_EX_imm),
        .o_opcode(reg_EX_opcode),
        .o_funct3(reg_EX_funct3),
        .o_funct7(reg_EX_funct7),
        .o_rd(reg_EX_reg_rd),
        .o_rs1(reg_EX_reg_rs1),
        .o_rs2(reg_EX_reg_rs2)
`ifdef RISCV_FORMAL
        ,
        .i_instruction( (stall_pipeline) ? INST_NOP : reg_ID_instruction ),
        .o_instruction(reg_EX_insn),
        .i_rvfi_valid( resetn && !stall_pipeline && IFID_rvfi_valid ),
        .o_rvfi_valid(reg_EX_rvfi_valid)
`endif
    );

    // Forwarding MUXes
    always_comb begin : MUX_FORWARD_A
        case (FW_EX_forward_rs1)
            FWD_NONE: EX_rs1_data_fwd = reg_EX_rs1_data;
            FWD_MEM:  EX_rs1_data_fwd = reg_MEM_rd_data;
            FWD_WB:   EX_rs1_data_fwd = WB_ID_rd_data;
            default:  EX_rs1_data_fwd = reg_EX_rs1_data;
        endcase
    end

    always_comb begin : MUX_FORWARD_B
        case (FW_EX_forward_rs2)
            FWD_NONE: EX_rs2_data_fwd = reg_EX_rs2_data;
            FWD_MEM:  EX_rs2_data_fwd = reg_MEM_rd_data;
            FWD_WB:   EX_rs2_data_fwd = WB_ID_rd_data;
            default:  EX_rs2_data_fwd = reg_EX_rs2_data;
        endcase
    end

    // Calc Next PC
    assign EX_next_pc_calc = branch_taken ? branch_address : (reg_EX_pc + 4);

`ifdef RISCV_FORMAL
    assign EX_branch_next_pc_rvfi = EX_next_pc_calc;
`endif

    EX_stage EX_stage (
        .clk(clk),
        .resetn(resetn),
        .i_rs1_data(EX_rs1_data_fwd),
        .i_rs2_data(EX_rs2_data_fwd),
        .i_imm(reg_EX_imm),
        .i_address(reg_EX_pc),
        .i_ALUSrc(CU_EX_reg_ALUSrc),
        .i_ALUOp(CU_EX_reg_ALUOp),
        .o_branch_address(branch_address),
        .o_branch_taken(branch_taken),
        .o_alu_result(EX_reg_rd_data),
        .o_rs1_data(EX_reg_rs1_data),
        .o_rs2_data(EX_reg_rs2_data)
    );

    EXMEM_reg EXMEM_reg (
        .clk(clk),
        .resetn(resetn),
`ifdef MEM_AXI4LITE
        .i_stall(bus_freeze),
`endif
        .i_rs1_data(EX_reg_rs1_data),
        .i_rs2_data(EX_reg_rs2_data),
        .i_rd_data(EX_reg_rd_data),
        .i_ALUOp(CU_EX_reg_ALUOp),
        .i_MemRead(CU_EX_reg_MemRead),
        .i_MemWrite(CU_EX_reg_MemWrite),
        .i_RegWrite(CU_EX_reg_RegWrite),
        .i_MemToReg(CU_EX_reg_MemToReg),
        .i_rd(reg_EX_reg_rd),
        .i_rs1(reg_EX_reg_rs1),
        .i_rs2(reg_EX_reg_rs2),

        .o_rs1_data(reg_MEM_rs1_data),
        .o_rs2_data(reg_MEM_rs2_data),
        .o_rd_data(reg_MEM_rd_data),
        .o_ALUOp(reg_MEM_ALUOp),
        .o_MemRead(reg_MEM_MemRead),
        .o_MemWrite(reg_MEM_MemWrite),
        .o_RegWrite(reg_MEM_RegWrite),
        .o_MemToReg(reg_MEM_MemToReg),
        .o_rd(reg_MEM_reg_rd),
        .o_rs1(reg_MEM_reg_rs1),
        .o_rs2(reg_MEM_reg_rs2)
`ifdef RISCV_FORMAL
        ,
        .i_pc(reg_EX_pc),
        .i_instruction(reg_EX_insn),
        .i_next_pc(EX_next_pc_calc),
        .i_rs1_data_rvfi(EX_rs1_data_fwd),
        .i_rs2_data_rvfi(EX_rs2_data_fwd),
        .i_branch_next_pc_rvfi(EX_branch_next_pc_rvfi),
        .i_rvfi_valid(reg_EX_rvfi_valid),
        .o_pc(reg_MEM_pc),
        .o_instruction(reg_MEM_insn),
        .o_next_pc(reg_MEM_next_pc),
        .o_rs1_data_rvfi(reg_MEM_rs1_data_rvfi),
        .o_rs2_data_rvfi(reg_MEM_rs2_data_rvfi),
        .o_branch_next_pc_rvfi(MEM_branch_next_pc_rvfi),
        .o_rvfi_valid(reg_MEM_rvfi_valid)
`endif
    );

    MEM_stage MEM_stage (
        .clk(clk),
        .resetn(resetn),
        .i_rs1_data(reg_MEM_rs1_data),
        .i_rs2_data(reg_MEM_rs2_data),
        .i_EX_rd_data(reg_MEM_rd_data),
        .i_ALUOp(reg_MEM_ALUOp),
        .i_MemRead(reg_MEM_MemRead),
        .i_MemWrite(reg_MEM_MemWrite),
        .i_RegWrite(reg_MEM_RegWrite),
        .i_MemToReg(reg_MEM_MemToReg),
        .o_EX_rd_data(MEM_reg_rd_data),
        .o_dmem_data(MEM_reg_dmem_data),
        .o_RegWrite(MEM_reg_RegWrite),
        .o_MemToReg(MEM_reg_MemToReg)
`ifdef MEM_WISHBONE
        , .o_dbus_cyc(o_dbus_cyc),
        .o_dbus_stb(o_dbus_stb),
        .o_dbus_we(o_dbus_we),
        .o_dbus_adr(o_dbus_adr),
        .o_dbus_dat(o_dbus_dat),
        .o_dbus_sel(o_dbus_sel),
        .i_dbus_dat(i_dbus_dat),
        .i_dbus_ack(i_dbus_ack),
        .o_dmem_stall(mem_dmem_stall)
`elsif MEM_AXI4LITE
        , .o_dbus_araddr(o_dbus_araddr),
        .o_dbus_arvalid(o_dbus_arvalid),
        .i_dbus_arready(i_dbus_arready),
        .i_dbus_rdata(i_dbus_rdata),
        .i_dbus_rresp(i_dbus_rresp),
        .i_dbus_rvalid(i_dbus_rvalid),
        .o_dbus_rready(o_dbus_rready),
        .o_dbus_awaddr(o_dbus_awaddr),
        .o_dbus_awvalid(o_dbus_awvalid),
        .i_dbus_awready(i_dbus_awready),
        .o_dbus_wdata(o_dbus_wdata),
        .o_dbus_wstrb(o_dbus_wstrb),
        .o_dbus_wvalid(o_dbus_wvalid),
        .i_dbus_wready(i_dbus_wready),
        .i_dbus_bresp(i_dbus_bresp),
        .i_dbus_bvalid(i_dbus_bvalid),
        .o_dbus_bready(o_dbus_bready),
        .o_dmem_stall(mem_dmem_stall),
        .i_imem_stall(if_imem_stall)
`endif
`ifdef RISCV_FORMAL
        , .o_dmem_rdata_raw(reg_MEM_dmem_rdata_raw)
`endif
    );

    MEMWB_reg MEMWB_reg (
        .clk(clk),
        .resetn(resetn),
`ifdef MEM_AXI4LITE
        .i_stall(bus_freeze),
`endif
        .i_dmem_data(MEM_reg_dmem_data),
        .i_rd_data(MEM_reg_rd_data),
        .i_rd(reg_MEM_reg_rd),
        .i_rs1(reg_MEM_reg_rs1),
        .i_rs2(reg_MEM_reg_rs2),
        .i_RegWrite(MEM_reg_RegWrite),
        .i_MemToReg(MEM_reg_MemToReg),

        .o_dmem_data(reg_WB_dmem_data),
        .o_rd_data(reg_WB_rd_data),
        .o_rd(reg_WB_rd),
        .o_rs1(reg_WB_rs1),
        .o_rs2(reg_WB_rs2),
        .o_RegWrite(reg_WB_RegWrite),
        .o_MemToReg(reg_WB_MemToReg)
`ifdef RISCV_FORMAL
        ,
        .i_pc(reg_MEM_pc),
        .i_instruction(reg_MEM_insn),
        .i_next_pc(reg_MEM_next_pc),
        .i_rs1_data_rvfi(reg_MEM_rs1_data_rvfi),
        .i_rs2_data_rvfi(reg_MEM_rs2_data_rvfi),
        .i_branch_next_pc_rvfi(MEM_branch_next_pc_rvfi),
        .i_mem_addr(reg_MEM_rd_data),
        .i_mem_wdata(reg_MEM_rs2_data),
        .i_mem_rdata_raw(reg_MEM_dmem_rdata_raw),
        .i_rvfi_valid(reg_MEM_rvfi_valid),
        .o_pc(reg_WB_pc),
        .o_instruction(reg_WB_insn),
        .o_next_pc(reg_WB_next_pc),
        .o_rs1_data_rvfi(reg_WB_rs1_data_rvfi),
        .o_rs2_data_rvfi(reg_WB_rs2_data_rvfi),
        .o_branch_next_pc_rvfi(WB_branch_next_pc_rvfi),
        .o_mem_addr(reg_WB_mem_addr),
        .o_mem_wdata(reg_WB_mem_wdata),
        .o_mem_rdata_raw(reg_WB_mem_rdata_raw),
        .o_rvfi_valid(reg_WB_rvfi_valid)
`endif
    );

    WB_stage WB_stage (
        .i_rd_data(reg_WB_rd_data),
        .i_dmem_data(reg_WB_dmem_data),
        .i_rd(reg_WB_rd),
        .i_MemToReg(reg_WB_MemToReg),
        .i_RegWrite(reg_WB_RegWrite),
        .o_RegWrite(WB_ID_RegWrite),
        .o_rd(WB_ID_rd),
        .o_rf_write_data(WB_ID_rd_data)
    );

`ifdef RISCV_FORMAL
    // =========================================================================
    // RVFI SIGNAL DRIVERS
    // =========================================================================

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) insn_order <= '0;
        else if (rvfi_valid) insn_order <= insn_order + 1;
    end

    assign rvfi_valid     = reg_WB_rvfi_valid;
    assign rvfi_order     = insn_order;
    assign rvfi_insn      = reg_WB_insn;

    wire is_branch_wb = (reg_WB_insn[6:0] == OP_BRANCH);
    wire is_jal_wb    = (reg_WB_insn[6:0] == OP_JAL);
    wire is_jalr_wb   = (reg_WB_insn[6:0] == OP_JALR);

    wire target_misaligned = (WB_branch_next_pc_rvfi[1:0] != 2'b00);
    assign rvfi_trap = (is_branch_wb || is_jal_wb || is_jalr_wb) && target_misaligned;

    assign rvfi_halt      = 1'b0;
    assign rvfi_intr      = 1'b0;
    assign rvfi_mode      = PRIV_MACHINE;
    assign rvfi_ixl       = RV32_IXL;

    assign rvfi_rs1_addr  = reg_WB_rs1;
    assign rvfi_rs2_addr  = reg_WB_rs2;
    assign rvfi_rs1_rdata = reg_WB_rs1_data_rvfi;
    assign rvfi_rs2_rdata = reg_WB_rs2_data_rvfi;

    assign rvfi_rd_addr   = (WB_ID_RegWrite) ? WB_ID_rd : 5'd0;
    assign rvfi_rd_wdata  = (WB_ID_RegWrite && WB_ID_rd != 0) ? WB_ID_rd_data : 32'd0;

    assign rvfi_pc_rdata  = reg_WB_pc;
    assign rvfi_pc_wdata = (is_branch_wb || is_jal_wb || is_jalr_wb) ?
                            WB_branch_next_pc_rvfi :
                            (reg_WB_pc + 4);

    wire [2:0] wb_funct3        = reg_WB_insn[14:12];
    wire       is_store_wb      = (reg_WB_insn[6:0] == OP_STORE);
    wire       is_load_wb       = (reg_WB_insn[6:0] == OP_LOAD);
    wire [1:0] mem_byte_offset  = reg_WB_mem_addr[1:0];

    assign rvfi_mem_addr  = (is_load_wb || is_store_wb) ? reg_WB_mem_addr     : 32'b0;
    assign rvfi_mem_rdata = is_load_wb                  ? reg_WB_mem_rdata_raw : 32'b0;

    logic [3:0] formal_wmask;
    logic [3:0] formal_rmask;

    always_comb begin
        formal_wmask = 4'b0000;
        formal_rmask = 4'b0000;

        if (is_store_wb) begin
            case (wb_funct3)
                F3_BYTE: formal_wmask = 4'b0001 << mem_byte_offset; // SB
                F3_HALF: formal_wmask = 4'b0011 << mem_byte_offset; // SH
                F3_WORD: formal_wmask = 4'b1111;                    // SW
                default: ;
            endcase
        end else if (is_load_wb) begin
            case (wb_funct3)
                F3_BYTE, F3_BYTE_U: formal_rmask = 4'b0001 << mem_byte_offset; // LB, LBU
                F3_HALF, F3_HALF_U: formal_rmask = 4'b0011 << mem_byte_offset; // LH, LHU
                F3_WORD:            formal_rmask = 4'b1111;                     // LW
                default: ;
            endcase
        end
    end

    assign rvfi_mem_wmask = formal_wmask;
    assign rvfi_mem_rmask = formal_rmask;
    assign rvfi_mem_wdata = is_store_wb
        ? (reg_WB_rs2_data_rvfi << (mem_byte_offset * 8))
        : 32'b0;

`endif

endmodule
