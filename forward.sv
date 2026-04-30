import riscv_pkg::*;
module forward (
    // Current Instruction (in EX)
    input  logic [4:0] i_rs1_ex,
    input  logic [4:0] i_rs2_ex,

    // Instruction in MEM Stage
    input  logic [4:0] i_rd_mem,
    input  logic       i_regwrite_mem,

    // Instruction in WB Stage
    input  logic [4:0] i_rd_wb,
    input  logic       i_regwrite_wb,

    // Forwarding Control Signals (Selects for MUXes)
    // 00 = Original (RegFile value)
    // 10 = Forward from MEM (Most recent)
    // 01 = Forward from WB (Second most recent)
    output logic [1:0] o_forward_rs1,
    output logic [1:0] o_forward_rs2
);

    always_comb begin
        // ---------------------------------------------------------
        // Forward A Logic (for RS1)
        // ---------------------------------------------------------
        
        // Priority 1: Forward from MEM stage (The "Youngest" Result)
        if (i_regwrite_mem && (i_rd_mem != 5'd0) && (i_rd_mem == i_rs1_ex)) begin
            o_forward_rs1 = FWD_MEM;

        // Priority 2: Forward from WB stage
        // Note: Only forward if MEM didn't already catch it! (Double Hazard)
        end else if (i_regwrite_wb && (i_rd_wb != 5'd0) && (i_rd_wb == i_rs1_ex)) begin
            o_forward_rs1 = FWD_WB;

        // Default: No Forwarding
        end else begin
            o_forward_rs1 = FWD_NONE;
        end

        // ---------------------------------------------------------
        // Forward B Logic (for RS2)
        // ---------------------------------------------------------

        // Priority 1: Forward from MEM stage
        if (i_regwrite_mem && (i_rd_mem != 5'd0) && (i_rd_mem == i_rs2_ex)) begin
            o_forward_rs2 = FWD_MEM;

        // Priority 2: Forward from WB stage
        end else if (i_regwrite_wb && (i_rd_wb != 5'd0) && (i_rd_wb == i_rs2_ex)) begin
            o_forward_rs2 = FWD_WB;

        // Default: No Forwarding
        end else begin
            o_forward_rs2 = FWD_NONE;
        end
    end

endmodule