////////
// IF/ID register
// Updated to support Load-Use Stall while keeping 2-cycle Branch Flush
///////

import riscv_pkg::*;
module IFID_reg #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32
)(
    input  logic                   clk,
    input  logic                   resetn,
    
    input  logic                   i_branch_taken, // Flush Trigger
    input  logic                   i_stall,        // Freeze Trigger (NEW)

    input  logic [ADDR_WIDTH-1:0]  i_address,
    input  logic [INST_WIDTH-1:0]  i_instruction,

    output logic [ADDR_WIDTH-1:0]  o_address,
    output logic [INST_WIDTH-1:0]  o_instruction

`ifdef RISCV_FORMAL
    , output logic o_rvfi_valid
`endif
);

    logic [ADDR_WIDTH-1:0] address;
    logic [INST_WIDTH-1:0] instruction;
    logic [1:0] ins_kill_count; 

    assign o_address = address;
    assign o_instruction = instruction;
`ifdef RISCV_FORMAL
    // Valid only when ins_kill_count is idle (not in a flush sequence).
    // Suppresses both branch bubbles and the reset-init NOP.
    assign o_rvfi_valid = (ins_kill_count == NO_FLUSH);
`endif

    always_ff @(posedge clk or negedge resetn) begin : propagate
        if(!resetn) begin
            address        <= '0;
            instruction    <= INST_NOP;
`ifdef RISCV_FORMAL
            ins_kill_count <= FLUSH_ONE; // Start in flush mode: treats reset-init NOP as a bubble
`else
            ins_kill_count <= NO_FLUSH;
`endif
        end
        else if(i_branch_taken) begin
            // Priority 1: Branch Taken - Start Flushing
            address        <= '0;
            instruction    <= INST_NOP;
            ins_kill_count <= ins_kill_count - 2'b01;
        end
        else if(ins_kill_count != NO_FLUSH) begin
            // Priority 2: Continue Flushing Sequence
            if(ins_kill_count == FLUSH_DONE) begin
                address        <= i_address;
                instruction    <= i_instruction;
                ins_kill_count <= NO_FLUSH;
            end else begin
                address        <= '0;
                instruction    <= INST_NOP;
                ins_kill_count <= ins_kill_count - 2'b01;
            end
        end 
        // ---------------------------------------------------------
        // Priority 3: Stall Check (Inserted Here)
        // ---------------------------------------------------------
        else if (i_stall) begin
            // If stalled, FREEZE everything.
            // Do not update address or instruction.
            // Do not change ins_kill_count.
        end 
        else begin
            // Priority 4: Normal Fetch
            address     <= i_address;
            instruction <= i_instruction;
        end
    end

endmodule